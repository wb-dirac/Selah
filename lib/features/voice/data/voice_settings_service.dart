import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class VoiceSettings {
  const VoiceSettings({
    this.autoPlayVoiceReply = true,
    this.preferredTtsProviderId,
    this.preferredTtsModel,
    this.enableLocalTts = false,
    this.enableLocalStt = false,
  });

  final bool autoPlayVoiceReply;
  final String? preferredTtsProviderId;
  final String? preferredTtsModel;
  final bool enableLocalTts;
  final bool enableLocalStt;

  VoiceSettings copyWith({
    bool? autoPlayVoiceReply,
    String? preferredTtsProviderId,
    bool clearPreferredTtsProviderId = false,
    String? preferredTtsModel,
    bool clearPreferredTtsModel = false,
    bool? enableLocalTts,
    bool? enableLocalStt,
  }) {
    return VoiceSettings(
      autoPlayVoiceReply: autoPlayVoiceReply ?? this.autoPlayVoiceReply,
      preferredTtsProviderId: clearPreferredTtsProviderId
          ? null
          : (preferredTtsProviderId ?? this.preferredTtsProviderId),
      preferredTtsModel: clearPreferredTtsModel
          ? null
          : (preferredTtsModel ?? this.preferredTtsModel),
      enableLocalTts: enableLocalTts ?? this.enableLocalTts,
      enableLocalStt: enableLocalStt ?? this.enableLocalStt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'auto_play_voice_reply': autoPlayVoiceReply,
      'preferred_tts_provider_id': preferredTtsProviderId,
      'preferred_tts_model': preferredTtsModel,
      'enable_local_tts': enableLocalTts,
      'enable_local_stt': enableLocalStt,
    };
  }

  factory VoiceSettings.fromJson(Map<String, dynamic> json) {
    return VoiceSettings(
      autoPlayVoiceReply: json['auto_play_voice_reply'] as bool? ?? true,
      preferredTtsProviderId: (json['preferred_tts_provider_id'] as String?)
          ?.trim()
          .isEmpty ==
          true
          ? null
          : (json['preferred_tts_provider_id'] as String?),
      preferredTtsModel: (json['preferred_tts_model'] as String?)?.trim().isEmpty ==
              true
          ? null
          : (json['preferred_tts_model'] as String?),
      enableLocalTts: json['enable_local_tts'] as bool? ?? false,
      enableLocalStt: json['enable_local_stt'] as bool? ?? false,
    );
  }
}

class VoiceSettingsService {
  const VoiceSettingsService({required this.preferences});

  static const String _settingsKey = 'voice.settings.v1';

  final KeychainPreferencesStore preferences;

  Future<VoiceSettings> load() async {
    final raw = await preferences.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const VoiceSettings();
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return VoiceSettings.fromJson(decoded);
  }

  Future<void> save(VoiceSettings value) async {
    await preferences.saveString(_settingsKey, jsonEncode(value.toJson()));
  }
}

final voiceSettingsServiceProvider = Provider<VoiceSettingsService>((ref) {
  return VoiceSettingsService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});

final voiceSettingsProvider = FutureProvider<VoiceSettings>((ref) {
  return ref.watch(voiceSettingsServiceProvider).load();
});
