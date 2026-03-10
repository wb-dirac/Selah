import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

typedef SkillHandler = Future<String> Function(
  String skillId,
  Map<String, dynamic> input,
);

class A2ARemoteServer {
  A2ARemoteServer(this._agentCard, this._skillHandler, {this.serverApiKey});

  final AgentCard _agentCard;
  final SkillHandler _skillHandler;

  // Optional API key to authenticate incoming requests.
  // When set, requests missing or with wrong Authorization header return 401.
  final String? serverApiKey;

  HttpServer? _server;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start({int port = 7890}) async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _serve(_server!);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _serve(HttpServer server) {
    server.listen(
      _handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (request.method == 'GET' && path == '/.well-known/agent.json') {
        await _handleAgentCard(request);
        return;
      }

      if (request.method == 'POST' && path == '/a2a') {
        if (!_isAuthorized(request)) {
          await _sendHttpError(request.response, 401, 'Unauthorized');
          return;
        }
        await _handleA2A(request);
        return;
      }

      await _sendHttpError(request.response, 404, 'Not Found');
    } catch (_) {
      try {
        await _sendHttpError(request.response, 500, 'Internal Server Error');
      } catch (_) {}
    }
  }

  bool _isAuthorized(HttpRequest request) {
    if (serverApiKey == null) return true;
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null) return false;
    if (!authHeader.startsWith('Bearer ')) return false;
    final token = authHeader.substring(7);
    return token == serverApiKey;
  }

  Future<void> _handleAgentCard(HttpRequest request) async {
    final body = jsonEncode(_agentCard.toJson());
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(body);
    await request.response.close();
  }

  Future<void> _handleA2A(HttpRequest request) async {
    final bodyStr = await utf8.decodeStream(request.cast<List<int>>());
    Map<String, dynamic> rpcRequest;

    try {
      rpcRequest = jsonDecode(bodyStr) as Map<String, dynamic>;
    } catch (_) {
      await _sendRpcError(
        response: request.response,
        id: null,
        code: -32700,
        message: 'Parse error',
      );
      return;
    }

    final jsonrpc = rpcRequest['jsonrpc'] as String?;
    final id = rpcRequest['id'];
    final method = rpcRequest['method'] as String?;
    final params = rpcRequest['params'] as Map<String, dynamic>?;

    if (jsonrpc != '2.0' || method == null) {
      await _sendRpcError(response: request.response, id: id, code: -32600, message: 'Invalid Request');
      return;
    }

    if (method != 'tasks/send' && method != 'tasks/sendSubscribe') {
      await _sendRpcError(
        response: request.response,
        id: id,
        code: -32601,
        message: 'Method not found: $method',
      );
      return;
    }

    if (params == null) {
      await _sendRpcError(
        response: request.response,
        id: id,
        code: -32602,
        message: 'Invalid params',
      );
      return;
    }

    final taskId = params['id'] as String? ?? _generateId();
    final message = params['message'] as Map<String, dynamic>?;
    final parts = message?['parts'] as List<dynamic>?;
    final inputText =
        (parts?.firstOrNull as Map<String, dynamic>?)?['text'] as String? ?? '';

    final skillId = params['skillId'] as String? ??
        (_agentCard.skills.isNotEmpty ? _agentCard.skills.first.id : 'default');

    try {
      final result = await _skillHandler(
        skillId,
        <String, dynamic>{'text': inputText, ...?params['metadata'] as Map?},
      );

      await _sendRpcSuccess(request.response, id, taskId, result);
    } catch (e) {
      await _sendRpcError(
        response: request.response,
        id: id,
        code: -32000,
        message: 'Skill execution failed: $e',
      );
    }
  }

  Future<void> _sendRpcSuccess(
    HttpResponse response,
    dynamic id,
    String taskId,
    String resultText,
  ) async {
    final body = jsonEncode(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': <String, dynamic>{
        'id': taskId,
        'status': <String, dynamic>{'state': 'completed'},
        'message': <String, dynamic>{
          'role': 'agent',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': resultText},
          ],
        },
      },
    });
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(body);
    await response.close();
  }

  Future<void> _sendRpcError({
    required HttpResponse response,
    required dynamic id,
    required int code,
    required String message,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
      },
    });
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(body);
    await response.close();
  }

  Future<void> _sendHttpError(
    HttpResponse response,
    int statusCode,
    String message,
  ) async {
    response
      ..statusCode = statusCode
      ..write(message);
    await response.close();
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
