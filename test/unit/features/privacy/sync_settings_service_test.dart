import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_health_check_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/sync_settings_service.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class _InMemoryKeychainService implements KeychainService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }
}

void main() {
  group('SyncSettingsService', () {
    late SyncSettingsService service;
    late ProviderManagementService providerManagementService;

    setUp(() {
      final keychain = _InMemoryKeychainService();
      final preferences = KeychainPreferencesStore(keychain);
      final keyStore = ProviderApiKeyStore(keychain);
      final healthCheckService = ProviderHealthCheckService(
        keyStore: keyStore,
        secureHttpClient: SecureHttpClient(),
        localHttpClient: LocalHttpClient(),
      );
      providerManagementService = ProviderManagementService(
        preferencesStore: preferences,
        keyStore: keyStore,
        healthCheckService: healthCheckService,
        secureHttpClient: SecureHttpClient(),
        localHttpClient: LocalHttpClient(),
      );
      service = SyncSettingsService(
        preferences: preferences,
        providerManagementService: providerManagementService,
      );
    });

    test('excludes api key field from sync preview payload', () async {
      await providerManagementService.saveConfig(
        const ManagedProviderConfig(
          providerId: 'openai',
          type: ManagedProviderType.openAiCompatible,
          displayName: 'OpenAI',
          defaultModel: 'gpt-4o-mini',
        ),
        apiKey: 'sk-test-secret-value',
      );

      final payload = await service.buildSyncPreviewPayload();
      final providers = payload['providers']! as List<Map<String, Object?>>;

      expect(providers, hasLength(1));
      expect(providers.single.containsKey('api_key'), isFalse);
      expect(providers.single['provider_id'], equals('openai'));
    });
  });
}
