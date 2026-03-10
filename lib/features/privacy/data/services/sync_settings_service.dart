import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_config_import_export_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/gist_encryption_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/github_gist_service.dart';
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
    this.gistId,
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
  final String? gistId;
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
    String? gistId,
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
    bool clearGistId = false,
  }) {
    return SyncSettings(
      connected: connected ?? this.connected,
      githubUsername: clearGithubUsername
          ? null
          : githubUsername ?? this.githubUsername,
      gistId: clearGistId ? null : gistId ?? this.gistId,
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
      'gist_id': gistId,
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
      gistId: json['gist_id'] as String?,
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

sealed class SyncResult {
  const SyncResult();
}

class SyncSuccess extends SyncResult {
  const SyncSuccess();
}

class SyncConflict extends SyncResult {
  const SyncConflict({
    required this.localPayload,
    required this.remotePayload,
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.gistId,
    required this.accessToken,
  });

  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> remotePayload;
  final DateTime? localTimestamp;
  final DateTime remoteTimestamp;
  final String gistId;
  final String accessToken;
}

class SyncError extends SyncResult {
  const SyncError({required this.message});

  final String message;
}

class SyncSettingsService {
  SyncSettingsService({
    required KeychainPreferencesStore preferences,
    required ProviderManagementService providerManagementService,
    required GistEncryptionService encryptionService,
    required GitHubGistService gistService,
    ProviderConfigImportExportService? importExportService,
  }) : _preferences = preferences,
       _providerManagementService = providerManagementService,
       _encryptionService = encryptionService,
       _gistService = gistService,
       _importExportService =
           importExportService ?? const ProviderConfigImportExportService();

  static const String _settingsKey = 'sync.settings.v1';

  final KeychainPreferencesStore _preferences;
  final ProviderManagementService _providerManagementService;
  final ProviderConfigImportExportService _importExportService;
  final GistEncryptionService _encryptionService;
  final GitHubGistService _gistService;

  String? _sessionPassphrase;

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
        clearGistId: true,
        lastSyncStatus: SyncStatus.idle,
      ),
    );
    await _gistService.clearStoredToken();
    _sessionPassphrase = null;
  }

  void setPassphrase(String passphrase) {
    _sessionPassphrase = passphrase.trim().isEmpty ? null : passphrase.trim();
    _persistPassphraseMarker(passphrase.trim().isNotEmpty);
  }

  bool get hasSessionPassphrase => _sessionPassphrase != null;

  void _persistPassphraseMarker(bool configured) {
    load().then((current) {
      save(current.copyWith(passphraseConfigured: configured));
    });
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
    final providerItems =
        ((providersDecoded['providers'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => Map<String, Object?>.from(item)..remove('api_key'),
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

  Future<GitHubDeviceCodeResponse> initiateDeviceFlow() {
    return _gistService.initiateDeviceFlow();
  }

  Stream<GitHubTokenResult> connectWithOAuth({
    required String deviceCode,
    required int intervalSeconds,
  }) async* {
    await for (final result in _gistService.pollForToken(
      deviceCode,
      intervalSeconds,
    )) {
      if (result is GitHubTokenSuccess) {
        try {
          final userInfo =
              await _gistService.getAuthenticatedUser(result.accessToken);
          await connect(userInfo.login);
        } catch (_) {
          // If user info fails, still mark connected with empty username
          await connect('');
        }
        yield result;
        return;
      }
      yield result;
    }
  }

  Future<SyncResult> performSync() async {
    final passphrase = _sessionPassphrase;
    if (passphrase == null || passphrase.isEmpty) {
      return const SyncError(message: '请先设置同步密码后再进行同步');
    }

    final accessToken = await _gistService.loadStoredToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const SyncError(message: '请先连接 GitHub 账号后再进行同步');
    }

    final settings = await load();
    final localPayload = await buildSyncPreviewPayload();

    if (_containsApiKey(localPayload)) {
      return const SyncError(message: '同步内容中检测到 API Key，已中止同步');
    }

    try {
      String resolvedGistId;

      if (settings.gistId != null && settings.gistId!.isNotEmpty) {
        resolvedGistId = settings.gistId!;
      } else {
        final found = await _gistService.findPrivateGistId(accessToken);
        if (found != null) {
          resolvedGistId = found;
          await save(settings.copyWith(gistId: found));
        } else {
          final encrypted = await _encryptionService.encrypt(
            jsonEncode(localPayload),
            passphrase,
          );
          final newId =
              await _gistService.createPrivateGist(accessToken, encrypted);
          await save(
            settings.copyWith(
              gistId: newId,
              lastSyncAt: DateTime.now(),
              lastSyncStatus: SyncStatus.success,
            ),
          );
          return const SyncSuccess();
        }
      }

      final gistData = await _gistService.readGist(accessToken, resolvedGistId);

      final localLastSync = settings.lastSyncAt;
      final remoteUpdatedAt = gistData.updatedAt;

      final hasConflict = localLastSync == null ||
          remoteUpdatedAt.isAfter(
            localLastSync.add(const Duration(seconds: 5)),
          );

      if (hasConflict) {
        Map<String, dynamic> remotePayload;
        try {
          final decrypted = await _encryptionService.decrypt(
            gistData.content,
            passphrase,
          );
          remotePayload = jsonDecode(decrypted) as Map<String, dynamic>;
        } catch (_) {
          remotePayload = const <String, dynamic>{};
        }

        return SyncConflict(
          localPayload: Map<String, dynamic>.from(localPayload),
          remotePayload: remotePayload,
          localTimestamp: localLastSync,
          remoteTimestamp: remoteUpdatedAt,
          gistId: resolvedGistId,
          accessToken: accessToken,
        );
      }

      final encrypted = await _encryptionService.encrypt(
        jsonEncode(localPayload),
        passphrase,
      );
      await _gistService.updateGist(accessToken, resolvedGistId, encrypted);
      await save(
        settings.copyWith(
          lastSyncAt: DateTime.now(),
          lastSyncStatus: SyncStatus.success,
        ),
      );

      return const SyncSuccess();
    } catch (e) {
      await markManualSync(success: false);
      return SyncError(message: '同步失败: $e');
    }
  }

  Future<void> pushLocalPayload(SyncConflict conflict) async {
    final passphrase = _sessionPassphrase;
    if (passphrase == null || passphrase.isEmpty) {
      throw StateError('Passphrase not set in session');
    }

    final encrypted = await _encryptionService.encrypt(
      jsonEncode(conflict.localPayload),
      passphrase,
    );
    await _gistService.updateGist(
      conflict.accessToken,
      conflict.gistId,
      encrypted,
    );

    final settings = await load();
    await save(
      settings.copyWith(
        lastSyncAt: DateTime.now(),
        lastSyncStatus: SyncStatus.success,
      ),
    );
  }

  Future<void> applyRemotePayload(SyncConflict conflict) async {
    final remoteProviders =
        (conflict.remotePayload['providers'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    if (remoteProviders.isNotEmpty) {
      final existingConfigs = await _providerManagementService.listConfigs();

      for (final remoteProvider in remoteProviders) {
        final providerId = remoteProvider['provider_id'] as String?;
        if (providerId == null || providerId.isEmpty) continue;

        final existingConfig = existingConfigs
            .where((c) => c.providerId == providerId)
            .firstOrNull;

        if (existingConfig != null) {
          await _providerManagementService.saveConfig(
            existingConfig.copyWith(
              displayName: remoteProvider['display_name'] as String? ??
                  existingConfig.displayName,
              baseUrl: remoteProvider['base_url'] as String?,
              defaultModel: remoteProvider['default_model'] as String?,
              enabled:
                  remoteProvider['enabled'] as bool? ?? existingConfig.enabled,
            ),
          );
        }
      }
    }

    final settings = await load();
    await save(
      settings.copyWith(
        lastSyncAt: DateTime.now(),
        lastSyncStatus: SyncStatus.success,
      ),
    );
  }

  bool _containsApiKey(Object? value) {
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        if (entry.key == 'api_key') {
          final v = entry.value;
          if (v is String && v.isNotEmpty) return true;
        }
        if (_containsApiKey(entry.value)) return true;
      }
    } else if (value is List<dynamic>) {
      for (final item in value) {
        if (_containsApiKey(item)) return true;
      }
    }
    return false;
  }
}

final syncSettingsServiceProvider = Provider<SyncSettingsService>((ref) {
  return SyncSettingsService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
    providerManagementService: ref.watch(providerManagementServiceProvider),
    encryptionService: ref.watch(gistEncryptionServiceProvider),
    gistService: ref.watch(githubGistServiceProvider),
  );
});

final syncSettingsProvider = FutureProvider<SyncSettings>((ref) {
  return ref.watch(syncSettingsServiceProvider).load();
});
