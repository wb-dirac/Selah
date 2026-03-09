import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class ToolPermissionService {
  ToolPermissionService({required KeychainPreferencesStore preferences})
    : _preferences = preferences;

  static const String _permissionsKey = 'tool_bridge.permissions.v1';
  static const String _historyKey = 'tool_bridge.history.v1';

  final KeychainPreferencesStore _preferences;

  List<ToolDefinition> listDefinitions() {
    return List<ToolDefinition>.unmodifiable(builtInToolDefinitions);
  }

  Future<List<ToolPermissionRecord>> listPermissionRecords() async {
    final raw = await _preferences.readString(_permissionsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolPermissionRecord>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ToolPermissionRecord.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, ToolPermissionRecord>> permissionMap() async {
    final items = await listPermissionRecords();
    return <String, ToolPermissionRecord>{
      for (final item in items) item.toolId: item,
    };
  }

  Future<void> setPermissionStatus(
    String toolId,
    ToolPermissionStatus status,
  ) async {
    final items = List<ToolPermissionRecord>.from(await listPermissionRecords());
    final updated = ToolPermissionRecord(
      toolId: toolId,
      status: status,
      updatedAt: DateTime.now(),
    );
    final index = items.indexWhere((item) => item.toolId == toolId);
    if (index >= 0) {
      items[index] = updated;
    } else {
      items.add(updated);
    }
    await _preferences.saveString(
      _permissionsKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  Future<void> revokePermission(String toolId) async {
    await setPermissionStatus(toolId, ToolPermissionStatus.notDetermined);
  }

  Future<List<ToolInvocationRecord>> listRecentInvocations({int limit = 50}) async {
    final raw = await _preferences.readString(_historyKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <ToolInvocationRecord>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    final items = decoded
        .whereType<Map<String, dynamic>>()
        .map(ToolInvocationRecord.fromJson)
        .toList(growable: false)
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
    if (items.length <= limit) {
      return items;
    }
    return items.take(limit).toList(growable: false);
  }

  Future<void> addInvocationRecord(ToolInvocationRecord record) async {
    final items = List<ToolInvocationRecord>.from(
      await listRecentInvocations(limit: 200),
    );
    items.add(record);
    items.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    final trimmed = items.take(200).toList(growable: false);
    await _preferences.saveString(
      _historyKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}

final toolPermissionServiceProvider = Provider<ToolPermissionService>((ref) {
  return ToolPermissionService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});

final toolPermissionRecordsProvider = FutureProvider<List<ToolPermissionRecord>>((
  ref,
) {
  return ref.watch(toolPermissionServiceProvider).listPermissionRecords();
});

final toolInvocationHistoryProvider = FutureProvider<List<ToolInvocationRecord>>((
  ref,
) {
  return ref.watch(toolPermissionServiceProvider).listRecentInvocations();
});
