import 'dart:convert';

import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/ollama_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class OllamaProvider implements LlmGateway {
  OllamaProvider({
    required OllamaProviderConfig config,
    required LocalHttpClient httpClient,
  })  : _config = config,
        _httpClient = httpClient;

  final OllamaProviderConfig _config;
  final LocalHttpClient _httpClient;

  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    final response = await _httpClient.post(
      _config.endpoint.resolve('api/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': options.model ?? _config.defaultModel,
        'stream': false,
        'messages': messages
            .map(
              (m) => {
                'role': m.role.name,
                'content': m.content,
              },
            )
            .toList(growable: false),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Ollama chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final message = json['message'] as Map<String, dynamic>?;
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