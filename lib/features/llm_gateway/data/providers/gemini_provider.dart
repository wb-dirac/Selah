import 'dart:convert';

import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/gemini_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class GeminiProvider implements LlmGateway {
  GeminiProvider({
    required GeminiProviderConfig config,
    required ProviderApiKeyStore keyStore,
    required SecureHttpClient httpClient,
  })  : _config = config,
        _keyStore = keyStore,
        _httpClient = httpClient;

  final GeminiProviderConfig _config;
  final ProviderApiKeyStore _keyStore;
  final SecureHttpClient _httpClient;

  Uri _buildUri(String relativePath) {
    final baseEndpoint = _normalizeBaseEndpoint(_config.endpoint);
    final normalizedPath = baseEndpoint.path.toLowerCase();
    final hasVersionPrefix =
        normalizedPath.endsWith('/v1') ||
        normalizedPath.endsWith('/v1beta') ||
        normalizedPath.contains('/v1/') ||
        normalizedPath.contains('/v1beta/');
    final path = hasVersionPrefix ? relativePath : 'v1beta/$relativePath';
    return baseEndpoint.resolve(path);
  }

  Uri _normalizeBaseEndpoint(Uri endpoint) {
    final text = endpoint.toString();
    if (text.endsWith('/')) {
      return endpoint;
    }
    return Uri.parse('$text/');
  }

  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    final apiKey = await _keyStore.read(providerId: _config.providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('API key not configured for ${_config.providerId}');
    }

    final modelId = options.model ?? _config.defaultModel;
    if (modelId == null || modelId.isEmpty) {
      throw StateError('Gemini model must be configured');
    }

    final response = await _httpClient.post(
      _buildUri('models/$modelId:generateContent'),
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': messages
            .where((m) => m.role != ChatRole.system)
            .map(
              (m) => {
                'role': m.role == ChatRole.assistant ? 'model' : 'user',
                'parts': [
                  {'text': m.content},
                ],
              },
            )
            .toList(growable: false),
        if (options.temperature != null)
          'generationConfig': {
            'temperature': options.temperature,
            if (options.maxOutputTokens != null)
              'maxOutputTokens': options.maxOutputTokens,
            if (options.topP != null) 'topP': options.topP,
          },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = (json['candidates'] as List<dynamic>? ?? const []);
    final first = candidates.isNotEmpty
        ? candidates.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final content = first['content'] as Map<String, dynamic>?;
    final parts = (content?['parts'] as List<dynamic>? ?? const []);
    final text = parts
        .whereType<Map<String, dynamic>>()
        .map((p) => p['text'] as String? ?? '')
        .join();
    final usage = json['usageMetadata'] as Map<String, dynamic>?;

    yield ChatChunk(
      textDelta: text,
      inputTokens: usage?['promptTokenCount'] as int?,
      outputTokens: usage?['candidatesTokenCount'] as int?,
    );
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(
    String text, {
    String? model,
  }) async {
    final apiKey = await _keyStore.read(providerId: _config.providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('API key not configured for ${_config.providerId}');
    }

    final modelId = model ?? _config.defaultModel;
    if (modelId == null || modelId.isEmpty) {
      throw StateError('Gemini model must be configured');
    }

    final response = await _httpClient.post(
      _buildUri('models/$modelId:embedContent'),
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini embed failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final values = (json['embedding'] as Map<String, dynamic>? ?? const {})['values']
            as List<dynamic>? ??
        const [];
    return EmbeddingVector(
      values: values.map((v) => (v as num).toDouble()).toList(growable: false),
      model: modelId,
    );
  }

  @override
  Future<List<LlmModelInfo>> listModels() async {
    final apiKey = await _keyStore.read(providerId: _config.providerId);
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('API key not configured for ${_config.providerId}');
    }

    final response = await _httpClient.get(
      _buildUri('models'),
      headers: {'x-goog-api-key': apiKey},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini list models failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (json['models'] as List<dynamic>? ?? const []);
    return models.map((item) {
      final model = item as Map<String, dynamic>;
      final name = model['name'] as String;
      return LlmModelInfo(
        id: name.replaceFirst('models/', ''),
        displayName: model['displayName'] as String? ?? name,
        provider: _config.providerId,
      );
    }).toList(growable: false);
  }
}