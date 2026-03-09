import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_config_import_export_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

enum SyncStatus {
  idle,
  success,
  failed,
}

extension SyncStatusX on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.idle:
        return 'idle';
      case SyncStatus.success:
        return 'success';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case SyncStatus.idle:
        return '未同步';
      case SyncStatus.success:
        return '成功';
      case SyncStatus.failed:
        return '失败';
    }
  }

  static SyncStatus fromValue(String? value) {
    for (final status in SyncStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return SyncStatus.idle;
  }
}

class SyncSettings {
  const SyncSettings({
    this.connected = false,
    this.githubUsername,
    this.lastSyncAt,
    this.lastSyncStatus = SyncStatus.idle,
    this.syncProviderConfigs = true,
    this.syncTaskDefinitions = true,
    this.syncPreferences = true,
    this.syncInstalledSkills = true,
    this.syncConversationHistory = false,
    this.passphraseConfigured = false,
  });

  final bool connected;
  final String? githubUsername;
  final DateTime? lastSyncAt;
  final SyncStatus lastSyncStatus;
  final bool syncProviderConfigs;
  final bool syncTaskDefinitions;
  final bool syncPreferences;
  final bool syncInstalledSkills;
  final bool syncConversationHistory;
  final bool passphraseConfigured;

  SyncSettings copyWith({
    bool? connected,
    String? githubUsername,
    DateTime? lastSyncAt,
    SyncStatus? lastSyncStatus,
    bool? syncProviderConfigs,
    bool? syncTaskDefinitions,
    bool? syncPreferences,
    bool? syncInstalledSkills,
    bool? syncConversationHistory,
    bool? passphraseConfigured,
    bool clearGithubUsername = false,
    bool clearLastSyncAt = false,
  }) {
    return SyncSettings(
      connected: connected ?? this.connected,
      githubUsername: clearGithubUsername
          ? null
          : githubUsername ?? this.githubUsername,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      syncProviderConfigs: syncProviderConfigs ?? this.syncProviderConfigs,
      syncTaskDefinitions: syncTaskDefinitions ?? this.syncTaskDefinitions,
      syncPreferences: syncPreferences ?? this.syncPreferences,
      syncInstalledSkills: syncInstalledSkills ?? this.syncInstalledSkills,
      syncConversationHistory:
          syncConversationHistory ?? this.syncConversationHistory,
      passphraseConfigured: passphraseConfigured ?? this.passphraseConfigured,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'connected': connected,
      'github_username': githubUsername,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'last_sync_status': lastSyncStatus.value,
      'sync_provider_configs': syncProviderConfigs,
      'sync_task_definitions': syncTaskDefinitions,
      'sync_preferences': syncPreferences,
      'sync_installed_skills': syncInstalledSkills,
      'sync_conversation_history': syncConversationHistory,
      'passphrase_configured': passphraseConfigured,
    };
  }

  factory SyncSettings.fromJson(Map<String, dynamic> json) {
    return SyncSettings(
      connected: json['connected'] as bool? ?? false,
      githubUsername: json['github_username'] as String?,
      lastSyncAt: DateTime.tryParse(json['last_sync_at'] as String? ?? ''),
      lastSyncStatus: SyncStatusX.fromValue(
        json['last_sync_status'] as String?,
      ),
      syncProviderConfigs: json['sync_provider_configs'] as bool? ?? true,
      syncTaskDefinitions: json['sync_task_definitions'] as bool? ?? true,
      syncPreferences: json['sync_preferences'] as bool? ?? true,
      syncInstalledSkills: json['sync_installed_skills'] as bool? ?? true,
      syncConversationHistory:
          json['sync_conversation_history'] as bool? ?? false,
      passphraseConfigured: json['passphrase_configured'] as bool? ?? false,
    );
  }
}

class SyncSettingsService {
  SyncSettingsService({
    required KeychainPreferencesStore preferences,
    required ProviderManagementService providerManagementService,
    ProviderConfigImportExportService? importExportService,
  }) : _preferences = preferences,
       _providerManagementService = providerManagementService,
       _importExportService =
           importExportService ?? const ProviderConfigImportExportService();

  static const String _settingsKey = 'sync.settings.v1';
  static const String _passphraseKey = 'sync.passphrase.v1';

  final KeychainPreferencesStore _preferences;
  final ProviderManagementService _providerManagementService;
  final ProviderConfigImportExportService _importExportService;

  Future<SyncSettings> load() async {
    final raw = await _preferences.readString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const SyncSettings();
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SyncSettings.fromJson(decoded);
  }

  Future<void> save(SyncSettings settings) async {
    await _preferences.saveString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> connect(String githubUsername) async {
    final current = await load();
    await save(
      current.copyWith(
        connected: true,
        githubUsername: githubUsername.trim(),
      ),
    );
  }

  Future<void> disconnect() async {
    final current = await load();
    await save(
      current.copyWith(
        connected: false,
        clearGithubUsername: true,
        clearLastSyncAt: true,
        lastSyncStatus: SyncStatus.idle,
      ),
    );
  }

  Future<void> setPassphrase(String passphrase) async {
    await _preferences.saveString(_passphraseKey, passphrase);
    final current = await load();
    await save(current.copyWith(passphraseConfigured: passphrase.trim().isNotEmpty));
  }

  Future<void> markManualSync({required bool success}) async {
    final current = await load();
    await save(
      current.copyWith(
        lastSyncAt: DateTime.now(),
        lastSyncStatus: success ? SyncStatus.success : SyncStatus.failed,
      ),
    );
  }

  Future<Map<String, Object?>> buildSyncPreviewPayload() async {
    final settings = await load();
    final providerConfigs = await _providerManagementService.listConfigs();
    final exportedJson = _importExportService.exportConfigurations(
      providerConfigs
          .map(
            (item) => ProviderConfiguration(
              providerId: item.providerId,
              displayName: item.displayName,
              baseUrl: item.baseUrl,
              defaultModel: item.defaultModel,
              enabled: item.enabled,
            ),
          )
          .toList(growable: false),
    );
    final providersDecoded = jsonDecode(exportedJson) as Map<String, dynamic>;
    final providerItems = ((providersDecoded['providers'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => Map<String, Object?>.from(item)
            ..remove('api_key'),
        )
        .toList(growable: false);

    return <String, Object?>{
      'sync_items': <String, Object?>{
        'provider_configs': settings.syncProviderConfigs,
        'task_definitions': settings.syncTaskDefinitions,
        'preferences': settings.syncPreferences,
        'installed_skills': settings.syncInstalledSkills,
        'conversation_history': settings.syncConversationHistory,
        'api_keys': false,
      },
      'providers': providerItems,
    };
  }
}

final syncSettingsServiceProvider = Provider<SyncSettingsService>((ref) {
  return SyncSettingsService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
    providerManagementService: ref.watch(providerManagementServiceProvider),
  );
});

final syncSettingsProvider = FutureProvider<SyncSettings>((ref) {
  return ref.watch(syncSettingsServiceProvider).load();
});
