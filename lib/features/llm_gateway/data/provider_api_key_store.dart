import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/keychain/flutter_secure_keychain_service.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';

class ProviderApiKeyStore {
	const ProviderApiKeyStore(this._keychainService);

	final KeychainService _keychainService;

	Future<void> save({
		required String providerId,
		required String apiKey,
	}) async {
		await _keychainService.write(
			key: _buildStorageKey(providerId),
			value: apiKey,
		);
	}

	Future<String?> read({required String providerId}) {
		return _keychainService.read(key: _buildStorageKey(providerId));
	}

	Future<void> delete({required String providerId}) {
		return _keychainService.delete(key: _buildStorageKey(providerId));
	}

	String _buildStorageKey(String providerId) {
		return 'provider.$providerId.api_key';
	}
}

final providerApiKeyStoreProvider = Provider<ProviderApiKeyStore>((ref) {
	final keychainService = ref.watch(keychainServiceProvider);
	return ProviderApiKeyStore(keychainService);
});