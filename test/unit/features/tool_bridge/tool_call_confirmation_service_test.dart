import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/tool_permission_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_confirmation_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

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

ToolPermissionService _makeService() {
  return ToolPermissionService(
    preferences: KeychainPreferencesStore(_MemoryKeychain()),
  );
}

void main() {
  group('ToolCallConfirmationService', () {
    testWidgets('L0 tool is auto-approved without dialog', (tester) async {
      final permService = _makeService();
      final service = ToolCallConfirmationService(
        permissionService: permService,
      );

      late ToolCallDecision result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await service.checkAndConfirm(
                    toolId: 'clipboard.write',
                    context: context,
                  );
                },
                child: const Text('test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('test'));
      await tester.pumpAndSettle();

      expect(result, ToolCallDecision.allowed);
    });

    testWidgets('unknown tool returns unknownTool decision', (tester) async {
      final permService = _makeService();
      final service = ToolCallConfirmationService(
        permissionService: permService,
      );

      late ToolCallDecision result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await service.checkAndConfirm(
                    toolId: 'non.existent.tool',
                    context: context,
                  );
                },
                child: const Text('test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('test'));
      await tester.pumpAndSettle();

      expect(result, ToolCallDecision.unknownTool);
    });

    testWidgets('denied tool is auto-denied without dialog', (tester) async {
      final permService = _makeService();
      await permService.setPermissionStatus(
        'contacts.read',
        ToolPermissionStatus.denied,
      );
      final service = ToolCallConfirmationService(
        permissionService: permService,
      );

      late ToolCallDecision result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await service.checkAndConfirm(
                    toolId: 'contacts.read',
                    context: context,
                  );
                },
                child: const Text('test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('test'));
      await tester.pumpAndSettle();

      expect(result, ToolCallDecision.denied);
    });

    testWidgets('L1 tool with granted status is auto-approved', (tester) async {
      final permService = _makeService();
      await permService.setPermissionStatus(
        'contacts.read',
        ToolPermissionStatus.granted,
      );
      final service = ToolCallConfirmationService(
        permissionService: permService,
      );

      late ToolCallDecision result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  result = await service.checkAndConfirm(
                    toolId: 'contacts.read',
                    context: context,
                  );
                },
                child: const Text('test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('test'));
      await tester.pumpAndSettle();

      expect(result, ToolCallDecision.allowed);
    });
  });
}
