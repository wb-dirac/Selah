import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/anthropic_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/anthropic_provider.dart';

class _FakeKeyStore extends ProviderApiKeyStore {
  _FakeKeyStore(this._value) : super(_NoopKeychain());

  final String? _value;

  @override
  Future<String?> read({required String providerId}) async => _value;
}

class _NoopKeychain implements dynamic {
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
  test('AnthropicProvider listModels parses response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.toString(), contains('/models'));
      return http.Response(
        '{"data":[{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"}]}',
        200,
      );
    });

    final provider = AnthropicProvider(
      config: const AnthropicProviderConfig(),
      keyStore: _FakeKeyStore('sk-ant-test-12345678901234567890'),
      httpClient: SecureHttpClient(client: mockClient),
    );

    final models = await provider.listModels();
    expect(models, hasLength(1));
    expect(models.first.id, equals('claude-sonnet-4-6'));
  });
}
