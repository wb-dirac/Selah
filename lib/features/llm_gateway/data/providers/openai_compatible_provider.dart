import 'dart:convert';

import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/openai_compatible_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class OpenAiCompatibleProvider implements LlmGateway {
	OpenAiCompatibleProvider({
		required OpenAiCompatibleProviderConfig config,
		required ProviderApiKeyStore keyStore,
		required SecureHttpClient httpClient,
	})  : _config = config,
				_keyStore = keyStore,
				_httpClient = httpClient;

	final OpenAiCompatibleProviderConfig _config;
	final ProviderApiKeyStore _keyStore;
	final SecureHttpClient _httpClient;

	/// Serialises a [ChatMessage] to the OpenAI Chat Completions format.
	/// Handles tool-call assistant messages and tool result messages.
	static Map<String, dynamic> _serializeMessage(ChatMessage message) {
		if (message.role == ChatRole.tool) {
			return {
				'role': 'tool',
				'tool_call_id': message.toolCallId ?? '',
				'content': message.content,
			};
		}
		if (message.hasToolCalls) {
			return {
				'role': 'assistant',
				if (message.content.isNotEmpty) 'content': message.content,
				'tool_calls': message.toolCalls!
						.map(
							(tc) => {
								'id': tc.callId,
								'type': 'function',
								'function': {
									'name': tc.name,
									'arguments': jsonEncode(tc.arguments),
								},
							},
						)
						.toList(),
			};
		}
		if (message.hasImages || message.hasAudios) {
			final contentParts = <Map<String, dynamic>>[
				if (message.content.trim().isNotEmpty)
					{
						'type': 'text',
						'text': message.content,
					},
				...?(message.images?.map((image) {
					final mime = image.mimeType.trim().isEmpty
							? 'image/jpeg'
							: image.mimeType;
					final data = base64Encode(image.bytes);
					return {
						'type': 'image_url',
						'image_url': {
							'url': 'data:$mime;base64,$data',
						},
					};
				})),
				...?(message.audios?.map((audio) {
					final format = audio.mimeType.contains('wav')
							? 'wav'
							: audio.mimeType.contains('mp3')
							? 'mp3'
							: 'm4a';
					return {
						'type': 'input_audio',
						'input_audio': {
							'data': base64Encode(audio.bytes),
							'format': format,
						},
					};
				})),
			];

			return {
				'role': message.role.name,
				'content': contentParts,
				if (message.name != null) 'name': message.name,
			};
		}

		return {
			'role': message.role.name,
			'content': message.content,
			if (message.name != null) 'name': message.name,
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

		final hasTools = options.tools != null && options.tools!.isNotEmpty;

		final response = await _httpClient.post(
			_config.baseUrl.resolve('chat/completions'),
			headers: {
				'Authorization': 'Bearer $apiKey',
				'Content-Type': 'application/json',
			},
			body: jsonEncode({
				'model': options.model ?? _config.defaultModel,
				'temperature': options.temperature,
				'max_tokens': options.maxOutputTokens,
				'top_p': options.topP,
				'stream': false,
				'messages': messages.map(_serializeMessage).toList(),
				if (hasTools)
					'tools': options.tools!
							.map((t) => {'type': 'function', 'function': t.toJson()})
							.toList(),
				if (hasTools) 'tool_choice': 'auto',
			}),
		);

		if (response.statusCode < 200 || response.statusCode >= 300) {
			throw StateError(
				'Chat request failed (${response.statusCode}): ${response.body}',
			);
		}

		final json = jsonDecode(response.body) as Map<String, dynamic>;
		final choices = (json['choices'] as List<dynamic>? ?? const []);
		final firstChoice = choices.isNotEmpty
				? choices.first as Map<String, dynamic>
				: const <String, dynamic>{};
		final message = firstChoice['message'] as Map<String, dynamic>?;
		final content = (message?['content'] as String?) ?? '';
		final usage = json['usage'] as Map<String, dynamic>?;

		// Parse tool calls if present
		final rawToolCalls = message?['tool_calls'] as List<dynamic>?;
		if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
			final toolCalls = rawToolCalls.map((tc) {
				final tcMap = tc as Map<String, dynamic>;
				final func = tcMap['function'] as Map<String, dynamic>;
				return ToolCallRequest.fromArgumentsJson(
					callId: tcMap['id'] as String? ?? '',
					name: func['name'] as String? ?? '',
					argumentsJson: func['arguments'] as String? ?? '{}',
				);
			}).toList();

			yield ChatChunk(
				textDelta: content,
				toolCalls: toolCalls,
				inputTokens: usage?['prompt_tokens'] as int?,
				outputTokens: usage?['completion_tokens'] as int?,
			);
			yield const ChatChunk(textDelta: '', isDone: true);
			return;
		}

		yield ChatChunk(
			textDelta: content,
			inputTokens: usage?['prompt_tokens'] as int?,
			outputTokens: usage?['completion_tokens'] as int?,
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

		final response = await _httpClient.post(
			_config.baseUrl.resolve('embeddings'),
			headers: {
				'Authorization': 'Bearer $apiKey',
				'Content-Type': 'application/json',
			},
			body: jsonEncode({
				'model': model ?? _config.defaultModel,
				'input': text,
			}),
		);

		if (response.statusCode < 200 || response.statusCode >= 300) {
			throw StateError(
				'Embed request failed (${response.statusCode}): ${response.body}',
			);
		}

		final json = jsonDecode(response.body) as Map<String, dynamic>;
		final data = (json['data'] as List<dynamic>? ?? const []);
		if (data.isEmpty) {
			throw StateError('Embedding response has no data');
		}

		final first = data.first as Map<String, dynamic>;
		final embedding =
				(first['embedding'] as List<dynamic>).map((e) => (e as num).toDouble());

		return EmbeddingVector(
			values: embedding.toList(growable: false),
			model: json['model'] as String?,
		);
	}

	@override
	Future<List<LlmModelInfo>> listModels() async {
		final apiKey = await _keyStore.read(providerId: _config.providerId);
		if (apiKey == null || apiKey.isEmpty) {
			throw StateError('API key not configured for ${_config.providerId}');
		}

		final response = await _httpClient.get(
			_config.baseUrl.resolve('models'),
			headers: {
				'Authorization': 'Bearer $apiKey',
			},
		);

		if (response.statusCode < 200 || response.statusCode >= 300) {
			throw StateError(
				'List models failed (${response.statusCode}): ${response.body}',
			);
		}

		final json = jsonDecode(response.body) as Map<String, dynamic>;
		final data = (json['data'] as List<dynamic>? ?? const []);

		return data.map((item) {
			final model = item as Map<String, dynamic>;
			final modelId = model['id'] as String;
			return LlmModelInfo(
				id: modelId,
				displayName: modelId,
				provider: _config.providerId,
			);
		}).toList(growable: false);
	}
}