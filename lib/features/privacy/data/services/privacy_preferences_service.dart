import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

enum ImageProcessingMode {
  localOnly,
  localOcrThenCloud,
  cloudOnly,
}

extension ImageProcessingModeX on ImageProcessingMode {
  String get value {
    switch (this) {
      case ImageProcessingMode.localOnly:
        return 'local_only';
      case ImageProcessingMode.localOcrThenCloud:
        return 'local_ocr_then_cloud';
      case ImageProcessingMode.cloudOnly:
        return 'cloud_only';
    }
  }

  String get label {
    switch (this) {
      case ImageProcessingMode.localOnly:
        return '仅本地处理';
      case ImageProcessingMode.localOcrThenCloud:
        return '本地 OCR + 云端理解';
      case ImageProcessingMode.cloudOnly:
        return '完全云端';
    }
  }

  static ImageProcessingMode fromValue(String? value) {
    for (final mode in ImageProcessingMode.values) {
      if (mode.value == value) {
        return mode;
      }
    }
    return ImageProcessingMode.localOcrThenCloud;
  }
}

class PrivacyPreferences {
  const PrivacyPreferences({
    this.piiDetectionEnabled = true,
    this.sendBeforeConfirmEnabled = false,
    this.replaceContactNamesEnabled = true,
    this.imageCloudConfirmationEnabled = true,
    this.imageProcessingMode = ImageProcessingMode.localOcrThenCloud,
  });

  final bool piiDetectionEnabled;
  final bool sendBeforeConfirmEnabled;
  final bool replaceContactNamesEnabled;
  final bool imageCloudConfirmationEnabled;
  final ImageProcessingMode imageProcessingMode;

  PrivacyPreferences copyWith({
    bool? piiDetectionEnabled,
    bool? sendBeforeConfirmEnabled,
    bool? replaceContactNamesEnabled,
    bool? imageCloudConfirmationEnabled,
    ImageProcessingMode? imageProcessingMode,
  }) {
    return PrivacyPreferences(
      piiDetectionEnabled: piiDetectionEnabled ?? this.piiDetectionEnabled,
      sendBeforeConfirmEnabled:
          sendBeforeConfirmEnabled ?? this.sendBeforeConfirmEnabled,
      replaceContactNamesEnabled:
          replaceContactNamesEnabled ?? this.replaceContactNamesEnabled,
      imageCloudConfirmationEnabled:
          imageCloudConfirmationEnabled ?? this.imageCloudConfirmationEnabled,
      imageProcessingMode: imageProcessingMode ?? this.imageProcessingMode,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'pii_detection_enabled': piiDetectionEnabled,
      'send_before_confirm_enabled': sendBeforeConfirmEnabled,
      'replace_contact_names_enabled': replaceContactNamesEnabled,
      'image_cloud_confirmation_enabled': imageCloudConfirmationEnabled,
      'image_processing_mode': imageProcessingMode.value,
    };
  }

  factory PrivacyPreferences.fromJson(Map<String, dynamic> json) {
    return PrivacyPreferences(
      piiDetectionEnabled: json['pii_detection_enabled'] as bool? ?? true,
      sendBeforeConfirmEnabled:
          json['send_before_confirm_enabled'] as bool? ?? false,
      replaceContactNamesEnabled:
          json['replace_contact_names_enabled'] as bool? ?? true,
      imageCloudConfirmationEnabled:
          json['image_cloud_confirmation_enabled'] as bool? ?? true,
      imageProcessingMode: ImageProcessingModeX.fromValue(
        json['image_processing_mode'] as String?,
      ),
    );
  }
}

class PrivacyPreferencesService {
  const PrivacyPreferencesService({required this.preferences});

  static const String _settingsKey = 'privacy.preferences.v1';

  final KeychainPreferencesStore preferences;

  Future<PrivacyPreferences> load() async {
    final raw = await preferences.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const PrivacyPreferences();
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return PrivacyPreferences.fromJson(decoded);
  }

  Future<void> save(PrivacyPreferences value) async {
    await preferences.saveString(_settingsKey, jsonEncode(value.toJson()));
  }
}

final privacyPreferencesServiceProvider = Provider<PrivacyPreferencesService>((
  ref,
) {
  return PrivacyPreferencesService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});

final privacyPreferencesProvider = FutureProvider<PrivacyPreferences>((ref) {
  return ref.watch(privacyPreferencesServiceProvider).load();
});
