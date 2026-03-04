abstract class AppPreferencesStore {
  Future<void> saveString(String key, String value);
  Future<String?> readString(String key);
}
