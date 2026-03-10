import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/tool_permission_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_bridge_executor.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_confirmation_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _MemoryKeychain implements KeychainService {
  final _store = <String, String>{};

  @override
  Future<void> delete({required String key}) async => _store.remove(key);
  @override
  Future<void> deleteAll() async => _store.clear();
  @override
  Future<String?> read({required String key}) async => _store[key];
  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }
}

class _CountingExecutor implements ToolExecutor {
  _CountingExecutor(this.toolId);

  @override
  final String toolId;

  int callCount = 0;

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    callCount++;
    return ToolCallResult.success(toolId: toolId, output: 'executed');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ToolBridgeExecutor _makeExecutor(Map<String, ToolExecutor> executors) {
  final keychain = _MemoryKeychain();
  final prefs = KeychainPreferencesStore(keychain);
  final permService = ToolPermissionService(preferences: prefs);
  final confirmService = ToolCallConfirmationService(permissionService: permService);
  return ToolBridgeExecutor(
    confirmationService: confirmService,
    executors: executors,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ToolBridgeExecutor.invokeBackground', () {
    test('L0 tool (clipboard.write) executes without permission check', () async {
      final fakeExecutor = _CountingExecutor('clipboard.write');
      final executor = _makeExecutor({'clipboard.write': fakeExecutor});

      final result = await executor.invokeBackground(
        toolId: 'clipboard.write',
        arguments: {'text': 'hello'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.output, equals('executed'));
      expect(fakeExecutor.callCount, equals(1));
    });

    test('L0 tool (location.search) executes without permission check', () async {
      final fakeExecutor = _CountingExecutor('location.search');
      final executor = _makeExecutor({'location.search': fakeExecutor});

      final result = await executor.invokeBackground(
        toolId: 'location.search',
        arguments: {'query': 'coffee'},
      );

      expect(result.isSuccess, isTrue);
      expect(fakeExecutor.callCount, equals(1));
    });

    test('L1 tool (contacts.read) with granted permission executes', () async {
      final fakeExecutor = _CountingExecutor('contacts.read');
      final keychain = _MemoryKeychain();
      final prefs = KeychainPreferencesStore(keychain);
      final permService = ToolPermissionService(preferences: prefs);
      // Pre-grant permission
      await permService.setPermissionStatus(
        'contacts.read',
        ToolPermissionStatus.granted,
      );
      final confirmService =
          ToolCallConfirmationService(permissionService: permService);
      final executor = ToolBridgeExecutor(
        confirmationService: confirmService,
        executors: {'contacts.read': fakeExecutor},
      );

      final result = await executor.invokeBackground(
        toolId: 'contacts.read',
      );

      expect(result.isSuccess, isTrue);
      expect(fakeExecutor.callCount, equals(1));
    });

    test('L1 tool (contacts.read) without cached permission returns error', () async {
      final fakeExecutor = _CountingExecutor('contacts.read');
      final executor = _makeExecutor({'contacts.read': fakeExecutor});

      final result = await executor.invokeBackground(toolId: 'contacts.read');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('需要用户授权'));
      expect(fakeExecutor.callCount, equals(0));
    });

    test('L1 tool with explicitly denied permission returns error', () async {
      final fakeExecutor = _CountingExecutor('contacts.read');
      final keychain = _MemoryKeychain();
      final prefs = KeychainPreferencesStore(keychain);
      final permService = ToolPermissionService(preferences: prefs);
      await permService.setPermissionStatus(
        'contacts.read',
        ToolPermissionStatus.denied,
      );
      final confirmService =
          ToolCallConfirmationService(permissionService: permService);
      final executor = ToolBridgeExecutor(
        confirmationService: confirmService,
        executors: {'contacts.read': fakeExecutor},
      );

      final result = await executor.invokeBackground(toolId: 'contacts.read');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('需要用户授权'));
      expect(fakeExecutor.callCount, equals(0));
    });

    test('unknown tool ID returns error without executing', () async {
      final executor = _makeExecutor({});

      final result = await executor.invokeBackground(
        toolId: 'nonexistent.tool',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('未找到工具'));
    });

    test('executor not registered for a known tool returns error', () async {
      // clipboard.write is a valid L0 tool but not registered in executors
      final executor = _makeExecutor({});

      final result = await executor.invokeBackground(
        toolId: 'clipboard.write',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('未找到工具'));
    });
  });
}
