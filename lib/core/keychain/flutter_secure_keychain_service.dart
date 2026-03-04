import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';

class FlutterSecureKeychainService implements KeychainService {
	FlutterSecureKeychainService({FlutterSecureStorage? secureStorage})
			: _secureStorage = secureStorage ??
						const FlutterSecureStorage(
							aOptions: AndroidOptions(
								encryptedSharedPreferences: true,
							),
							iOptions: IOSOptions(
								accessibility: KeychainAccessibility.first_unlock,
							),
							mOptions: MacOsOptions(
								accessibility: KeychainAccessibility.first_unlock,
							),
							wOptions: WindowsOptions(
								useBackwardCompatibility: false,
							),
						);

	final FlutterSecureStorage _secureStorage;

	@override
	Future<void> write({required String key, required String value}) {
		return _secureStorage.write(key: key, value: value);
	}

	@override
	Future<String?> read({required String key}) {
		return _secureStorage.read(key: key);
	}

	@override
	Future<void> delete({required String key}) {
		return _secureStorage.delete(key: key);
	}

	@override
	Future<void> deleteAll() {
		return _secureStorage.deleteAll();
	}
}

final keychainServiceProvider = Provider<KeychainService>((ref) {
	return FlutterSecureKeychainService();
});