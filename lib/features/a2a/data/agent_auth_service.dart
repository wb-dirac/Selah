import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';

class AgentAuthService {
  const AgentAuthService(this._storage);

  final FlutterSecureStorage _storage;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const AgentAuthService instance = AgentAuthService(_defaultStorage);

  String _keychainKey(String agentUrl) {
    final encoded = base64Url.encode(utf8.encode(agentUrl));
    return 'a2a.auth.$encoded.v1';
  }

  Future<void> saveApiKey(String agentUrl, String apiKey) async {
    await _storage.write(key: _keychainKey(agentUrl), value: apiKey);
  }

  Future<String?> getApiKey(String agentUrl) async {
    return _storage.read(key: _keychainKey(agentUrl));
  }

  Future<void> removeCredentials(String agentUrl) async {
    await _storage.delete(key: _keychainKey(agentUrl));
  }

  Future<AgentAuthConfig?> getAuthConfig(String agentUrl) async {
    final key = _keychainKey(agentUrl);
    final token = await _storage.read(key: key);
    if (token == null) return null;
    return AgentAuthConfig(
      type: AgentAuthType.apiKey,
      tokenKeychainKey: key,
    );
  }
}
