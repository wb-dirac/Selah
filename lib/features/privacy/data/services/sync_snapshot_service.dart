import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/sync_settings_service.dart';
import 'package:personal_ai_assistant/features/privacy/domain/sync_snapshot.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class SyncSnapshotService {
  SyncSnapshotService({
    required KeychainPreferencesStore preferences,
    required SyncSettingsService syncSettingsService,
    SyncSnapshotStore? store,
  })  : _preferences = preferences,
        _syncSettingsService = syncSettingsService,
        _store = store ?? const SyncSnapshotStore();

  static const String _snapshotsKey = 'sync.snapshots.v1';

  final KeychainPreferencesStore _preferences;
  final SyncSettingsService _syncSettingsService;
  final SyncSnapshotStore _store;

  Future<List<SyncSnapshot>> loadAll() async {
    final raw = await _preferences.readString(_snapshotsKey);
    if (raw == null || raw.trim().isEmpty) return const <SyncSnapshot>[];
    try {
      return _store.decode(raw);
    } catch (_) {
      return const <SyncSnapshot>[];
    }
  }

  Future<SyncSnapshot> createBeforeSync() async {
    final payload = await _syncSettingsService.buildSyncPreviewPayload();
    final snapshot = SyncSnapshot.create(payload);

    final existing = await loadAll();
    final updated = <SyncSnapshot>[...existing, snapshot];
    await _save(updated);

    return snapshot;
  }

  Future<void> pruneExpired() async {
    final snapshots = await loadAll();
    final valid = snapshots.where((s) => !s.isExpired).toList();
    if (valid.length == snapshots.length) return;
    await _save(valid);
  }

  Future<void> deleteSnapshot(String id) async {
    final snapshots = await loadAll();
    final updated = snapshots.where((s) => s.id != id).toList();
    await _save(updated);
  }

  Future<SyncSnapshot?> findById(String id) async {
    final snapshots = await loadAll();
    for (final s in snapshots) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _save(List<SyncSnapshot> snapshots) async {
    final json = jsonEncode(snapshots.map((s) => s.toJson()).toList());
    await _preferences.saveString(_snapshotsKey, json);
  }
}

final syncSnapshotServiceProvider = Provider<SyncSnapshotService>((ref) {
  return SyncSnapshotService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
    syncSettingsService: ref.watch(syncSettingsServiceProvider),
  );
});
