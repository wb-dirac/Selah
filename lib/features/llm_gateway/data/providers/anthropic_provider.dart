import 'dart:convert';

import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/anthropic_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
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

  /// Converts a [ChatMessage] to Anthropic's message format.
  /// Anthropic tool results are wrapped inside a user-role message with
  /// a `tool_result` content block, not as a separate role.
  static Map<String, dynamic> _serializeMessage(ChatMessage message) {
    if (message.role == ChatRole.tool) {
      // Tool result: wrap as user message with tool_result content block
      return {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': message.toolCallId ?? '',
            'content': message.content,
          },
        ],
      };
    }
    if (message.hasToolCalls) {
      // Assistant message requesting tool uses
      return {
        'role': 'assistant',
        'content': [
          if (message.content.isNotEmpty)
            {'type': 'text', 'text': message.content},
          ...message.toolCalls!.map(
            (tc) => {
              'type': 'tool_use',
              'id': tc.callId,
              'name': tc.name,
              'input': tc.arguments,
            },
          ),
        ],
      };
    }
    return {
      'role': message.role == ChatRole.assistant ? 'assistant' : 'user',
      'content': message.content,
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

    final nonSystemMessages = messages
        .where((m) => m.role != ChatRole.system)
        .map(_serializeMessage)
        .toList(growable: false);
    final system = messages
        .where((m) => m.role == ChatRole.system)
        .map((m) => m.content)
        .join('\n');

    final hasTools = options.tools != null && options.tools!.isNotEmpty;

    final response = await _httpClient.post(
      _config.endpoint.resolve('messages'),
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
        if (hasTools)
          'tools': options.tools!
              .map(
                (t) => {
                  'name': t.name,
                  'description': t.description,
                  'input_schema': t.parameters.toJson(),
                },
              )
              .toList(),
        if (hasTools) 'tool_choice': {'type': 'auto'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Anthropic chat failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final contentItems = (json['content'] as List<dynamic>? ?? const []);

    // Collect text and tool_use blocks
    final textParts = <String>[];
    final toolCalls = <ToolCallRequest>[];

    for (final item in contentItems.whereType<Map<String, dynamic>>()) {
      final type = item['type'] as String?;
      if (type == 'text') {
        textParts.add(item['text'] as String? ?? '');
      } else if (type == 'tool_use') {
        final input = item['input'];
        final args = input is Map<String, dynamic> ? input : const <String, dynamic>{};
        toolCalls.add(
          ToolCallRequest(
            callId: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            arguments: args,
          ),
        );
      }
    }

    final text = textParts.join();
    final usage = json['usage'] as Map<String, dynamic>?;

    if (toolCalls.isNotEmpty) {
      yield ChatChunk(
        textDelta: text,
        toolCalls: toolCalls,
        inputTokens: usage?['input_tokens'] as int?,
        outputTokens: usage?['output_tokens'] as int?,
      );
      yield const ChatChunk(textDelta: '', isDone: true);
      return;
    }

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
      _config.endpoint.resolve('models'),
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