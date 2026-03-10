import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/anthropic_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/anthropic_provider.dart';

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
  const _apiKey = 'sk-ant-test-1234567890123456789012345678901234567890';

  group('AnthropicProvider – function calling', () {
    test('serialises tools in Anthropic format (name/description/input_schema)', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'OK'},
            ],
            'usage': {'input_tokens': 10, 'output_tokens': 2},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicProviderConfig(),
        keyStore: _FakeKeyStore(_apiKey),
        httpClient: SecureHttpClient(client: mockClient),
      );

      await provider
          .chat(
            [const ChatMessage(role: ChatRole.user, content: 'hi')],
            options: LlmChatOptions(
              tools: [
                const ToolSpec(
                  name: 'clipboard.read',
                  description: '读取剪贴板',
                ),
              ],
            ),
          )
          .toList();

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(body.containsKey('tools'), isTrue);
      final tools = body['tools'] as List;
      expect(tools, hasLength(1));
      expect(tools.first['name'], equals('clipboard.read'));
      expect(tools.first['description'], equals('读取剪贴板'));
      expect(tools.first.containsKey('input_schema'), isTrue);
      expect(body['tool_choice'], equals({'type': 'auto'}));
    });

    test('parses tool_use content block into ChatChunk.toolCalls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'tool_use',
                'id': 'toolu_01',
                'name': 'location.search',
                'input': {'query': 'coffee shop'},
              }
            ],
            'usage': {'input_tokens': 20, 'output_tokens': 10},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicProviderConfig(),
        keyStore: _FakeKeyStore(_apiKey),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final chunks = await provider
          .chat(
            [const ChatMessage(role: ChatRole.user, content: '附近的咖啡厅')],
            options: LlmChatOptions(
              tools: [
                const ToolSpec(
                  name: 'location.search',
                  description: '位置搜索',
                ),
              ],
            ),
          )
          .toList();

      final dataChunk = chunks.first;
      expect(dataChunk.hasToolCalls, isTrue);
      expect(dataChunk.toolCalls, hasLength(1));
      expect(dataChunk.toolCalls!.first.callId, equals('toolu_01'));
      expect(dataChunk.toolCalls!.first.name, equals('location.search'));
      expect(dataChunk.toolCalls!.first.arguments['query'], equals('coffee shop'));
    });

    test('mixed text and tool_use returns both text and toolCalls', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Searching for coffee…'},
              {
                'type': 'tool_use',
                'id': 'toolu_02',
                'name': 'location.search',
                'input': {'query': 'coffee'},
              },
            ],
            'usage': {'input_tokens': 15, 'output_tokens': 8},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicProviderConfig(),
        keyStore: _FakeKeyStore(_apiKey),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final chunks = await provider
          .chat([const ChatMessage(role: ChatRole.user, content: '咖啡厅')])
          .toList();

      final dataChunk = chunks.first;
      expect(dataChunk.textDelta, equals('Searching for coffee…'));
      expect(dataChunk.hasToolCalls, isTrue);
      expect(dataChunk.toolCalls!.first.callId, equals('toolu_02'));
    });

    test('serialises tool result as user message with tool_result block', () async {
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': '找到 3 家咖啡厅'},
            ],
            'usage': {'input_tokens': 25, 'output_tokens': 5},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = AnthropicProvider(
        config: const AnthropicProviderConfig(),
        keyStore: _FakeKeyStore(_apiKey),
        httpClient: SecureHttpClient(client: mockClient),
      );

      final history = [
        const ChatMessage(role: ChatRole.user, content: '附近咖啡厅'),
        const ChatMessage(
          role: ChatRole.assistant,
          content: '',
          toolCalls: [
            ToolCallRequest(
              callId: 'toolu_03',
              name: 'location.search',
              arguments: {'query': 'coffee'},
            ),
          ],
        ),
        const ChatMessage(
          role: ChatRole.tool,
          content: '[{"name":"Starbucks","distance":"100m"}]',
          toolCallId: 'toolu_03',
        ),
      ];

      await provider.chat(history).toList();

      final body = jsonDecode(capturedBody) as Map<String, dynamic>;
      final messages = body['messages'] as List;

      // Tool result should be wrapped as a user message
      final toolResultMsg = messages.last as Map<String, dynamic>;
      expect(toolResultMsg['role'], equals('user'));
      final content = (toolResultMsg['content'] as List).first as Map;
      expect(content['type'], equals('tool_result'));
      expect(content['tool_use_id'], equals('toolu_03'));
    });
  });
}
