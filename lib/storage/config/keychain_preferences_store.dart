import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/keychain/flutter_secure_keychain_service.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/storage/config/app_preferences_store.dart';

class KeychainPreferencesStore implements AppPreferencesStore {
  const KeychainPreferencesStore(this._keychainService);

  final KeychainService _keychainService;

  @override
  Future<String?> readString(String key) {
    return _keychainService.read(key: key);
  }

  @override
  Future<void> saveString(String key, String value) {
    return _keychainService.write(key: key, value: value);
  }

  @override
  Future<void> clearAll() {
    return _keychainService.deleteAll();
  }
}

final keychainPreferencesStoreProvider = Provider<KeychainPreferencesStore>((
  ref,
) {
  final keychain = ref.watch(keychainServiceProvider);
  return KeychainPreferencesStore(keychain);
});
