import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:personal_ai_assistant/features/a2a/data/a2a_sandbox_processor.dart';
import 'package:personal_ai_assistant/features/a2a/data/tls_connection_policy.dart';
import 'package:personal_ai_assistant/features/a2a/domain/a2a_result.dart';
import 'package:personal_ai_assistant/features/a2a/domain/a2a_task.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

sealed class A2AStreamChunk {}

class A2AStreamText extends A2AStreamChunk {
  A2AStreamText(this.text);
  final String text;
}

class A2AStreamDone extends A2AStreamChunk {
  A2AStreamDone(this.result);
  final A2ASandboxOutcome result;
}

class A2AStreamError extends A2AStreamChunk {
  A2AStreamError(this.message);
  final String message;
}

class A2AHostClient {
  const A2AHostClient(this._tlsPolicy, this._sandbox);

  final TlsConnectionPolicy _tlsPolicy;
  final A2ASandboxProcessor _sandbox;

  Future<AgentCardValidationResult> fetchAgentCard(String baseUrl) async {
    final validation = _tlsPolicy.validateUrl(baseUrl);
    if (validation is TlsValidationFailed) {
      return AgentCardInvalid(<String>[validation.reason]);
    }

    final uri = Uri.parse(baseUrl);
    final wellKnownUri = uri.replace(path: '/.well-known/agent.json');
    final client = _tlsPolicy.buildSecureClient();

    try {
      final request = await client.getUrl(wellKnownUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode != 200) {
        return AgentCardInvalid(<String>[
          'Agent Card 请求失败，HTTP ${response.statusCode}',
        ]);
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return const AgentCardValidator().validate(json);
    } on SocketException catch (e) {
      return AgentCardInvalid(<String>['连接失败: ${e.message}']);
    } on TlsException catch (e) {
      return AgentCardInvalid(<String>['TLS 错误: ${e.message}']);
    } catch (e) {
      return AgentCardInvalid(<String>['获取 Agent Card 失败: $e']);
    } finally {
      client.close();
    }
  }

  // bearerToken is pre-resolved by the caller (e.g. from AgentAuthService).
  // Pass null for unauthenticated agents.
  Future<A2ASandboxOutcome> sendTask(
    A2ATask task, {
    String? bearerToken,
  }) async {
    final validation = _tlsPolicy.validateUrl(task.agentUrl);
    if (validation is TlsValidationFailed) {
      return A2ASandboxRejected(validation.reason);
    }

    final uri = Uri.parse(task.agentUrl);
    final body = _buildRpcBody('tasks/send', task);
    final client = _tlsPolicy.buildSecureClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (bearerToken != null) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      }
      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode == 401) {
        return A2ASandboxRejected('Agent 认证失败 (401 Unauthorized)');
      }
      if (response.statusCode != 200) {
        return A2ASandboxRejected(
          'Agent 请求失败，HTTP ${response.statusCode}',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;

      if (responseJson.containsKey('error')) {
        final error = responseJson['error'] as Map<String, dynamic>;
        return A2ASandboxRejected(
          'Agent 返回错误: ${error['message'] ?? error.toString()}',
        );
      }

      final result = responseJson['result'] as Map<String, dynamic>?;
      return _sandbox.process(_buildTaskResult(result, task.id, task.agentUrl));
    } on SocketException catch (e) {
      return A2ASandboxRejected('连接失败: ${e.message}');
    } on TlsException catch (e) {
      return A2ASandboxRejected('TLS 错误: ${e.message}');
    } catch (e) {
      return A2ASandboxRejected('发送任务失败: $e');
    } finally {
      client.close();
    }
  }

  // bearerToken is pre-resolved by the caller. Yields SSE chunks then final outcome.
  Stream<A2AStreamChunk> sendTaskStreaming(
    A2ATask task, {
    String? bearerToken,
  }) async* {
    final validation = _tlsPolicy.validateUrl(task.agentUrl);
    if (validation is TlsValidationFailed) {
      yield A2AStreamError(validation.reason);
      return;
    }

    final uri = Uri.parse(task.agentUrl);
    final body = _buildRpcBody('tasks/sendSubscribe', task);
    final client = _tlsPolicy.buildSecureClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      if (bearerToken != null) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      }
      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode == 401) {
        yield A2AStreamError('Agent 认证失败 (401 Unauthorized)');
        return;
      }
      if (response.statusCode != 200) {
        yield A2AStreamError('Agent 请求失败，HTTP ${response.statusCode}');
        return;
      }

      final buffer = StringBuffer();
      var accumulated = '';

      await for (final chunk in response.transform(utf8.decoder)) {
        buffer.write(chunk);
        final content = buffer.toString();
        final events = content.split('\n\n');

        for (var i = 0; i < events.length - 1; i++) {
          final event = events[i].trim();
          if (event.isEmpty) continue;

          for (final line in event.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data == '[DONE]') continue;

            try {
              final eventJson = jsonDecode(data) as Map<String, dynamic>;
              final text = _extractStreamText(eventJson);
              if (text != null && text.isNotEmpty) {
                accumulated += text;
                yield A2AStreamText(text);
              }
            } catch (_) {
              // skip malformed SSE data lines
            }
          }
        }

        buffer
          ..clear()
          ..write(events.last);
      }

      final finalResult = A2ATaskResult(
        taskId: task.id,
        agentUrl: task.agentUrl,
        rawPayload: <String, dynamic>{
          'text': accumulated,
          'taskId': task.id,
        },
        receivedAt: DateTime.now(),
      );
      yield A2AStreamDone(_sandbox.process(finalResult));
    } on SocketException catch (e) {
      yield A2AStreamError('连接失败: ${e.message}');
    } on TlsException catch (e) {
      yield A2AStreamError('TLS 错误: ${e.message}');
    } catch (e) {
      yield A2AStreamError('流式任务失败: $e');
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _buildRpcBody(String method, A2ATask task) {
    final inputText = task.input['text'] as String? ??
        task.input.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
      'id': task.id,
      'params': <String, dynamic>{
        'id': task.id,
        'message': <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': inputText},
          ],
        },
      },
    };
  }

  A2ATaskResult _buildTaskResult(
    Map<String, dynamic>? result,
    String taskId,
    String agentUrl,
  ) {
    var text = '';
    if (result != null) {
      final message = result['message'] as Map<String, dynamic>?;
      if (message != null) {
        final parts = message['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final first = parts.first as Map<String, dynamic>?;
          text = first?['text'] as String? ?? '';
        }
      }
      if (text.isEmpty) {
        text = result['text'] as String? ??
            result['content'] as String? ??
            result['result'] as String? ??
            '';
      }
    }
    return A2ATaskResult(
      taskId: taskId,
      agentUrl: agentUrl,
      rawPayload: <String, dynamic>{
        'text': text,
        if (result != null) ...result,
      },
      receivedAt: DateTime.now(),
    );
  }

  String? _extractStreamText(Map<String, dynamic> eventJson) {
    final result = eventJson['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final message = result['message'] as Map<String, dynamic>?;
    if (message != null) {
      final parts = message['parts'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        final first = parts.first as Map<String, dynamic>?;
        return first?['text'] as String?;
      }
    }
    return result['text'] as String? ??
        result['content'] as String? ??
        result['delta'] as String?;
  }
}
