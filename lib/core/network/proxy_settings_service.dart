import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

enum ProxyMode {
  system,
  custom,
}

enum ProxyType {
  http,
  socks5,
}

class ProxySettings {
  const ProxySettings({
    this.mode = ProxyMode.system,
    this.type = ProxyType.http,
    this.host,
    this.port,
  });

  final ProxyMode mode;
  final ProxyType type;
  final String? host;
  final int? port;

  bool get isCustomReady {
    if (mode != ProxyMode.custom) return true;
    return (host?.trim().isNotEmpty ?? false) && (port ?? 0) > 0;
  }

  ProxySettings copyWith({
    ProxyMode? mode,
    ProxyType? type,
    String? host,
    int? port,
  }) {
    return ProxySettings(
      mode: mode ?? this.mode,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'mode': mode.name,
      'type': type.name,
      'host': host,
      'port': port,
    };
  }

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    return ProxySettings(
      mode: ProxyMode.values.firstWhere(
        (item) => item.name == (json['mode'] as String? ?? ''),
        orElse: () => ProxyMode.system,
      ),
      type: ProxyType.values.firstWhere(
        (item) => item.name == (json['type'] as String? ?? ''),
        orElse: () => ProxyType.http,
      ),
      host: json['host'] as String?,
      port: json['port'] as int?,
    );
  }
}

class ProxySettingsService {
  const ProxySettingsService({required KeychainPreferencesStore preferences})
    : _preferences = preferences;

  static const _settingsKey = 'network.proxy.settings.v1';

  final KeychainPreferencesStore _preferences;

  Future<ProxySettings> load() async {
    final raw = await _preferences.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const ProxySettings();
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ProxySettings.fromJson(decoded);
  }

  Future<void> save(ProxySettings settings) async {
    final payload = jsonEncode(settings.toJson());
    await _preferences.saveString(_settingsKey, payload);
  }
}

final proxySettingsServiceProvider = Provider<ProxySettingsService>((ref) {
  return ProxySettingsService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});
