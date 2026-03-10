import 'dart:convert';

import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/gemini_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
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

  /// Converts a [ChatMessage] to Gemini's content format.
  /// Tool result messages use role "function" with a functionResponse part.
  static Map<String, dynamic> _serializeMessage(ChatMessage message) {
    if (message.role == ChatRole.tool) {
      return {
        'role': 'function',
        'parts': [
          {
            'functionResponse': {
              'name': message.name ?? '',
              'response': {'output': message.content},
            },
          },
        ],
      };
    }
    if (message.hasToolCalls) {
      return {
        'role': 'model',
        'parts': [
          if (message.content.isNotEmpty) {'text': message.content},
          ...message.toolCalls!.map(
            (tc) => {
              'functionCall': {
                'name': tc.name,
                'args': tc.arguments,
              },
              if (tc.thoughtSignature != null)
                'thoughtSignature': tc.thoughtSignature,
            },
          ),
        ],
      };
    }
    return {
      'role': message.role == ChatRole.assistant ? 'model' : 'user',
      'parts': [
        {'text': message.content},
      ],
    };
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

    final hasTools = options.tools != null && options.tools!.isNotEmpty;
    final nonSystemMessages = messages.where((m) => m.role != ChatRole.system).toList();

    final response = await _httpClient.post(
      _buildUri('models/$modelId:generateContent'),
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': nonSystemMessages.map(_serializeMessage).toList(growable: false),
        if (options.temperature != null)
          'generationConfig': {
            'temperature': options.temperature,
            if (options.maxOutputTokens != null)
              'maxOutputTokens': options.maxOutputTokens,
            if (options.topP != null) 'topP': options.topP,
          },
        if (hasTools)
          'tools': [
            {
              'functionDeclarations': options.tools!
                  .map(
                    (t) => {
                      'name': t.name,
                      'description': t.description,
                      'parameters': t.parameters.toJson(),
                    },
                  )
                  .toList(),
            },
          ],
        if (hasTools) 'toolConfig': {'functionCallingConfig': {'mode': 'AUTO'}},
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
    final usage = json['usageMetadata'] as Map<String, dynamic>?;

    // Separate text parts from functionCall parts
    final textParts = <String>[];
    final toolCalls = <ToolCallRequest>[];

    for (final part in parts.whereType<Map<String, dynamic>>()) {
      if (part.containsKey('text')) {
        textParts.add(part['text'] as String? ?? '');
      } else if (part.containsKey('functionCall')) {
        final fc = part['functionCall'] as Map<String, dynamic>;
        final args = fc['args'];
        final thoughtSignature =
            part['thoughtSignature'] as String? ??
            part['thought_signature'] as String?;
        toolCalls.add(
          ToolCallRequest(
            callId: '${fc['name']}_${DateTime.now().millisecondsSinceEpoch}',
            name: fc['name'] as String? ?? '',
            arguments: args is Map<String, dynamic> ? args : const {},
            thoughtSignature: thoughtSignature,
          ),
        );
      }
    }

    final text = textParts.join();

    if (toolCalls.isNotEmpty) {
      yield ChatChunk(
        textDelta: text,
        toolCalls: toolCalls,
        inputTokens: usage?['promptTokenCount'] as int?,
        outputTokens: usage?['candidatesTokenCount'] as int?,
      );
      yield const ChatChunk(textDelta: '', isDone: true);
      return;
    }

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

