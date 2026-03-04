import 'dart:convert';

import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/anthropic_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class AnthropicProvider implements LlmGateway {
  AnthropicProvider({
    required AnthropicProviderConfig config,
    required ProviderApiKeyStore keyStore,
    required SecureHttpClient httpClient,
  })  : _config = config,
        _keyStore = keyStore,
        _httpClient = httpClient;

  final AnthropicProviderConfig _config;
  final ProviderApiKeyStore _keyStore;
  final SecureHttpClient _httpClient;

  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    final apiKey = await _keyStore.read(providerId: _config.providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('API key not configured for ${_config.providerId}');
    }

    final nonSystemMessages = messages
        .where((m) => m.role != ChatRole.system)
        .map(
          (m) => {
            'role': m.role == ChatRole.assistant ? 'assistant' : 'user',
            'content': m.content,
          },
        )
        .toList(growable: false);
    final system = messages
        .where((m) => m.role == ChatRole.system)
        .map((m) => m.content)
        .join('\n');

    final response = await _httpClient.post(
      _config.endpoint.resolve('/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _config.apiVersion,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': options.model ?? _config.defaultModel,
        'max_tokens': options.maxOutputTokens ?? 1024,
        if (options.temperature != null) 'temperature': options.temperature,
        if (system.isNotEmpty) 'system': system,
        'messages': nonSystemMessages,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Anthropic chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final contentItems = (json['content'] as List<dynamic>? ?? const []);
    final text = contentItems
        .whereType<Map<String, dynamic>>()
        .where((item) => item['type'] == 'text')
        .map((item) => item['text'] as String? ?? '')
        .join();

    final usage = json['usage'] as Map<String, dynamic>?;
    yield ChatChunk(
      textDelta: text,
      inputTokens: usage?['input_tokens'] as int?,
      outputTokens: usage?['output_tokens'] as int?,
    );
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(String text, {String? model}) {
    throw UnsupportedError('Anthropic provider does not support embeddings');
  }

  @override
  Future<List<LlmModelInfo>> listModels() async {
    final apiKey = await _keyStore.read(providerId: _config.providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('API key not configured for ${_config.providerId}');
    }

    final response = await _httpClient.get(
      _config.endpoint.resolve('/models'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _config.apiVersion,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Anthropic list models failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (json['data'] as List<dynamic>? ?? const []);
    return data.map((item) {
      final model = item as Map<String, dynamic>;
      final id = model['id'] as String;
      final displayName = model['display_name'] as String? ?? id;
      return LlmModelInfo(
        id: id,
        displayName: displayName,
        provider: _config.providerId,
      );
    }).toList(growable: false);
  }
}