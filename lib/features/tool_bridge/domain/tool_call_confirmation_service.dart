import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/tool_permission_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';
import 'package:personal_ai_assistant/features/tool_bridge/presentation/widgets/tool_call_confirmation_dialog.dart';

enum ToolCallDecision { allowed, denied, unknownTool }

class ToolCallConfirmationService {
  ToolCallConfirmationService({required ToolPermissionService permissionService})
      : _permissionService = permissionService;

  final ToolPermissionService _permissionService;

  /// Exposes the underlying permission service for background tool invocation.
  ToolPermissionService get permissionService => _permissionService;

  Future<ToolCallDecision> checkAndConfirm({
    required String toolId,
    required BuildContext context,
    Map<String, dynamic>? arguments,
  }) async {
    final definitions = _permissionService.listDefinitions();
    final definition = definitions.cast<ToolDefinition?>().firstWhere(
      (d) => d!.id == toolId,
      orElse: () => null,
    );

    if (definition == null) return ToolCallDecision.unknownTool;

    final records = await _permissionService.permissionMap();
    final record = records[toolId];
    final status = record?.status ?? _defaultStatus(definition.permissionLevel);

    if (status == ToolPermissionStatus.denied) {
      await _record(toolId: toolId, allowed: false, summary: '已拒绝');
      return ToolCallDecision.denied;
    }

    if (!context.mounted) return ToolCallDecision.denied;

    return switch (definition.permissionLevel) {
      ToolPermissionLevel.l0 => ToolCallDecision.allowed,
      ToolPermissionLevel.l1 => _handleL1(
          context: context,
          definition: definition,
          status: status,
        ),
      ToolPermissionLevel.l2 => _handleL2(
          context: context,
          definition: definition,
          status: status,
          arguments: arguments,
        ),
      ToolPermissionLevel.l3 => _handleL3(
          context: context,
          definition: definition,
          arguments: arguments,
        ),
    };
  }

  Future<ToolCallDecision> _handleL1({
    required BuildContext context,
    required ToolDefinition definition,
    required ToolPermissionStatus status,
  }) async {
    if (status == ToolPermissionStatus.granted) {
      return ToolCallDecision.allowed;
    }

    if (!context.mounted) return ToolCallDecision.denied;

    final approved = await showToolCallL1Dialog(
      context: context,
      definition: definition,
    );

    if (approved) {
      await _permissionService.setPermissionStatus(
        definition.id,
        ToolPermissionStatus.granted,
      );
      await _record(toolId: definition.id, allowed: true, summary: 'L1 首次授权');
      return ToolCallDecision.allowed;
    }

    await _permissionService.setPermissionStatus(
      definition.id,
      ToolPermissionStatus.denied,
    );
    await _record(toolId: definition.id, allowed: false, summary: 'L1 拒绝授权');
    return ToolCallDecision.denied;
  }

  Future<ToolCallDecision> _handleL2({
    required BuildContext context,
    required ToolDefinition definition,
    required ToolPermissionStatus status,
    Map<String, dynamic>? arguments,
  }) async {
    if (status == ToolPermissionStatus.granted) {
      await _record(toolId: definition.id, allowed: true, summary: 'L2 自动允许');
      return ToolCallDecision.allowed;
    }

    if (!context.mounted) return ToolCallDecision.denied;

    final approved = await showToolCallL2Dialog(
      context: context,
      definition: definition,
      arguments: arguments,
    );

    await _record(
      toolId: definition.id,
      allowed: approved,
      summary: approved ? 'L2 确认执行' : 'L2 取消',
    );
    return approved ? ToolCallDecision.allowed : ToolCallDecision.denied;
  }

  Future<ToolCallDecision> _handleL3({
    required BuildContext context,
    required ToolDefinition definition,
    Map<String, dynamic>? arguments,
  }) async {
    if (!context.mounted) return ToolCallDecision.denied;

    final approved = await showToolCallL3Dialog(
      context: context,
      definition: definition,
      arguments: arguments,
    );

    await _record(
      toolId: definition.id,
      allowed: approved,
      summary: approved ? 'L3 确认执行' : 'L3 取消',
    );
    return approved ? ToolCallDecision.allowed : ToolCallDecision.denied;
  }

  Future<void> _record({
    required String toolId,
    required bool allowed,
    String? summary,
  }) async {
    await _permissionService.addInvocationRecord(
      ToolInvocationRecord(
        toolId: toolId,
        allowed: allowed,
        timestamp: DateTime.now(),
        summary: summary,
      ),
    );
  }

  ToolPermissionStatus _defaultStatus(ToolPermissionLevel level) {
    return switch (level) {
      ToolPermissionLevel.l0 => ToolPermissionStatus.granted,
      ToolPermissionLevel.l1 => ToolPermissionStatus.notDetermined,
      ToolPermissionLevel.l2 ||
      ToolPermissionLevel.l3 => ToolPermissionStatus.askEveryTime,
    };
  }
}

final toolCallConfirmationServiceProvider =
    Provider<ToolCallConfirmationService>((ref) {
  return ToolCallConfirmationService(
    permissionService: ref.watch(toolPermissionServiceProvider),
  );
});
