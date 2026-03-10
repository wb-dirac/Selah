import 'dart:convert';

import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/ollama_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class OllamaProvider implements LlmGateway {
  OllamaProvider({
    required OllamaProviderConfig config,
    required LocalHttpClient httpClient,
  })  : _config = config,
        _httpClient = httpClient;

  final OllamaProviderConfig _config;
  final LocalHttpClient _httpClient;

  /// Serialises a [ChatMessage] for Ollama's OpenAI-compatible /api/chat format.
  static Map<String, dynamic> _serializeMessage(ChatMessage message) {
    if (message.role == ChatRole.tool) {
      return {
        'role': 'tool',
        'content': message.content,
      };
    }
    if (message.hasToolCalls) {
      return {
        'role': 'assistant',
        'content': message.content,
        'tool_calls': message.toolCalls!
            .map(
              (tc) => {
                'function': {
                  'name': tc.name,
                  'arguments': tc.arguments,
                },
              },
            )
            .toList(),
      };
    }
    return {
      'role': message.role.name,
      'content': message.content,
    };
  }

  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    final hasTools = options.tools != null && options.tools!.isNotEmpty;

    final response = await _httpClient.post(
      _config.endpoint.resolve('api/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': options.model ?? _config.defaultModel,
        'stream': false,
        'messages': messages.map(_serializeMessage).toList(growable: false),
        if (hasTools)
          'tools': options.tools!
              .map((t) => {'type': 'function', 'function': t.toJson()})
              .toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Ollama chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final message = json['message'] as Map<String, dynamic>?;

    // Ollama returns tool_calls as a list of {function: {name, arguments}} objects.
    // Unlike OpenAI, arguments is already an object (not a JSON string).
    final rawToolCalls = message?['tool_calls'] as List<dynamic>?;
    if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
      final toolCalls = rawToolCalls.map((tc) {
        final tcMap = tc as Map<String, dynamic>;
        final func = tcMap['function'] as Map<String, dynamic>;
        final args = func['arguments'];
        final argsMap = args is Map<String, dynamic>
            ? args
            : const <String, dynamic>{};
        return ToolCallRequest(
          callId: '${func['name']}_${DateTime.now().millisecondsSinceEpoch}',
          name: func['name'] as String? ?? '',
          arguments: argsMap,
        );
      }).toList();

      yield ChatChunk(
        textDelta: message?['content'] as String? ?? '',
        toolCalls: toolCalls,
        inputTokens: json['prompt_eval_count'] as int?,
        outputTokens: json['eval_count'] as int?,
      );
      yield const ChatChunk(textDelta: '', isDone: true);
      return;
    }

    yield ChatChunk(
      textDelta: message?['content'] as String? ?? '',
      inputTokens: json['prompt_eval_count'] as int?,
      outputTokens: json['eval_count'] as int?,
    );
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(
    String text, {
    String? model,
  }) async {
    final response = await _httpClient.post(
      _config.endpoint.resolve('api/embeddings'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model ?? _config.defaultModel,
        'prompt': text,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Ollama embed failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final embedding = (json['embedding'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(growable: false);
    return EmbeddingVector(
      values: embedding,
      model: model ?? _config.defaultModel,
    );
  }

  @override
  Future<List<LlmModelInfo>> listModels() async {
    final response = await _httpClient.get(
      _config.endpoint.resolve('api/tags'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Ollama list models failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (json['models'] as List<dynamic>? ?? const []);
    return models.map((item) {
      final model = item as Map<String, dynamic>;
      final name = model['name'] as String;
      return LlmModelInfo(
        id: name,
        displayName: name,
        provider: _config.providerId,
      );
    }).toList(growable: false);
  }
}

