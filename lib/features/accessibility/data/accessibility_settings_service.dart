import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class AccessibilitySettings {
  const AccessibilitySettings({
    this.forceHighContrast = false,
    this.reduceMotion = false,
    this.respectSystemTextScale = true,
  });

  final bool forceHighContrast;
  final bool reduceMotion;
  final bool respectSystemTextScale;

  AccessibilitySettings copyWith({
    bool? forceHighContrast,
    bool? reduceMotion,
    bool? respectSystemTextScale,
  }) {
    return AccessibilitySettings(
      forceHighContrast: forceHighContrast ?? this.forceHighContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      respectSystemTextScale:
          respectSystemTextScale ?? this.respectSystemTextScale,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'force_high_contrast': forceHighContrast,
      'reduce_motion': reduceMotion,
      'respect_system_text_scale': respectSystemTextScale,
    };
  }

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      forceHighContrast: json['force_high_contrast'] as bool? ?? false,
      reduceMotion: json['reduce_motion'] as bool? ?? false,
      respectSystemTextScale:
          json['respect_system_text_scale'] as bool? ?? true,
    );
  }
}

class AccessibilitySettingsService {
  const AccessibilitySettingsService({required KeychainPreferencesStore preferences})
    : _preferences = preferences;

  static const String _settingsKey = 'accessibility.settings.v1';

  final KeychainPreferencesStore _preferences;

  Future<AccessibilitySettings> load() async {
    final raw = await _preferences.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AccessibilitySettings();
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AccessibilitySettings.fromJson(decoded);
  }

  Future<void> save(AccessibilitySettings settings) async {
    await _preferences.saveString(_settingsKey, jsonEncode(settings.toJson()));
  }
}

final accessibilitySettingsServiceProvider = Provider<AccessibilitySettingsService>((
  ref,
) {
  return AccessibilitySettingsService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});

final accessibilitySettingsProvider = FutureProvider<AccessibilitySettings>((ref) {
  return ref.watch(accessibilitySettingsServiceProvider).load();
});
