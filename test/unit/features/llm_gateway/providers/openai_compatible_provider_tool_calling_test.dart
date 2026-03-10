import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/openai_compatible_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/openai_compatible_provider.dart';

class _FakeKeyStore extends ProviderApiKeyStore {
  _FakeKeyStore(this._value) : super(_NoopKeychain());
  final String? _value;
  @override
  Future<String?> read({required String providerId}) async => _value;
}

class _NoopKeychain implements KeychainService {
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> write({required String key, required String value}) async {}
}

void main() {
  group('OpenAiCompatibleProvider – function calling', () {
    test('serialises tools and tool_choice in request body', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Sure',
                },
              }
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = OpenAiCompatibleProvider(
        config: OpenAiCompatibleProviderConfig(
          providerId: 'test',
          baseUrl: Uri.parse('https://api.openai.com/v1/'),
        ),
        keyStore: _FakeKeyStore('sk-test-1234567890123456'),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final tools = [
        const ToolSpec(
          name: 'clipboard.read',
          description: '读取剪贴板',
        ),
      ];

      final chunks = await provider
          .chat(
            [const ChatMessage(role: ChatRole.user, content: 'hi')],
            options: LlmChatOptions(tools: tools),
          )
          .toList();

      expect(chunks, isNotEmpty);

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body['tools'], isNotNull);
      final sentTools = body['tools'] as List;
      expect(sentTools, hasLength(1));
      expect(sentTools.first['type'], equals('function'));
      expect(sentTools.first['function']['name'], equals('clipboard.read'));
      expect(body['tool_choice'], equals('auto'));
    });

    test('parses tool_calls in response into ChatChunk.toolCalls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_abc123',
                      'type': 'function',
                      'function': {
                        'name': 'location.search',
                        'arguments': '{"query":"coffee shop"}',
                      },
                    }
                  ],
                },
              }
            ],
            'usage': {'prompt_tokens': 15, 'completion_tokens': 8},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = OpenAiCompatibleProvider(
        config: OpenAiCompatibleProviderConfig(
          providerId: 'test',
          baseUrl: Uri.parse('https://api.openai.com/v1/'),
        ),
        keyStore: _FakeKeyStore('sk-test-1234567890123456'),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final chunks = await provider
          .chat(
            [const ChatMessage(role: ChatRole.user, content: '附近的咖啡厅')],
            options: LlmChatOptions(
              tools: [
                const ToolSpec(
                  name: 'location.search',
                  description: '地点搜索',
                  parameters: ToolParameterSchema(
                    properties: {
                      'query': ToolParamProperty(
                        type: ToolParamType.string,
                        description: '关键词',
                      ),
                    },
                    required: ['query'],
                  ),
                ),
              ],
            ),
          )
          .toList();

      final dataChunk = chunks.first;
      expect(dataChunk.hasToolCalls, isTrue);
      expect(dataChunk.toolCalls, hasLength(1));
      expect(dataChunk.toolCalls!.first.callId, equals('call_abc123'));
      expect(dataChunk.toolCalls!.first.name, equals('location.search'));
      expect(
        dataChunk.toolCalls!.first.arguments['query'],
        equals('coffee shop'),
      );
    });

    test('sends tool role message correctly in history', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Found coffee shops near you.',
                },
              }
            ],
            'usage': {'prompt_tokens': 20, 'completion_tokens': 10},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = OpenAiCompatibleProvider(
        config: OpenAiCompatibleProviderConfig(
          providerId: 'test',
          baseUrl: Uri.parse('https://api.openai.com/v1/'),
        ),
        keyStore: _FakeKeyStore('sk-test-1234567890123456'),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final history = [
        const ChatMessage(role: ChatRole.user, content: '附近的咖啡厅'),
        const ChatMessage(
          role: ChatRole.assistant,
          content: '',
          toolCalls: [
            ToolCallRequest(
              callId: 'call_xyz',
              name: 'location.search',
              arguments: {'query': 'coffee shop'},
            ),
          ],
        ),
        const ChatMessage(
          role: ChatRole.tool,
          content: '找到 3 家咖啡厅',
          toolCallId: 'call_xyz',
        ),
      ];

      await provider.chat(history).toList();

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      expect(messages, hasLength(3));

      final toolMsg = messages[2] as Map<String, dynamic>;
      expect(toolMsg['role'], equals('tool'));
      expect(toolMsg['tool_call_id'], equals('call_xyz'));
      expect(toolMsg['content'], equals('找到 3 家咖啡厅'));
    });
  });
}
