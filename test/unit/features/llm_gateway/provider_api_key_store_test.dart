import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';

class _InMemoryKeychainService implements KeychainService {
  final Map<String, String> _map = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _map.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _map[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _map[key] = value;
  }
}

void main() {
  group('ProviderApiKeyStore', () {
    test('saves and reads provider api key', () async {
      final keychain = _InMemoryKeychainService();
      final store = ProviderApiKeyStore(keychain);

      await store.save(providerId: 'openai', apiKey: 'sk-test-1234567890abcdef');

      final value = await store.read(providerId: 'openai');
      expect(value, equals('sk-test-1234567890abcdef'));
    });

    test('deletes provider api key', () async {
      final keychain = _InMemoryKeychainService();
      final store = ProviderApiKeyStore(keychain);

      await store.save(providerId: 'gemini', apiKey: 'AIza12345678901234567890123456789012345');
      await store.delete(providerId: 'gemini');

      final value = await store.read(providerId: 'gemini');
      expect(value, isNull);
    });
  });
}