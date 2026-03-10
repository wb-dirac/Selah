import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/calendar_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/communication_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/contact_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/location_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/system_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_confirmation_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';

class ToolBridgeExecutor {
  ToolBridgeExecutor({
    required ToolCallConfirmationService confirmationService,
    required Map<String, ToolExecutor> executors,
  })  : _confirmationService = confirmationService,
        _executors = executors;

  final ToolCallConfirmationService _confirmationService;
  final Map<String, ToolExecutor> _executors;

  /// Interactive invocation — shows confirmation dialog when required.
  /// Use this when a [BuildContext] is available (e.g., from a UI widget).
  Future<ToolCallResult> invoke({
    required String toolId,
    required BuildContext context,
    Map<String, dynamic>? arguments,
  }) async {
    final executor = _executors[toolId];
    if (executor == null) {
      return ToolCallResult.error(
        toolId: toolId,
        errorMessage: '未找到工具：$toolId',
      );
    }

    final decision = await _confirmationService.checkAndConfirm(
      toolId: toolId,
      context: context,
      arguments: arguments,
    );

    switch (decision) {
      case ToolCallDecision.denied:
        return ToolCallResult.error(
          toolId: toolId,
          errorMessage: '用户拒绝了工具调用',
        );
      case ToolCallDecision.unknownTool:
        return ToolCallResult.error(
          toolId: toolId,
          errorMessage: '未知工具：$toolId',
        );
      case ToolCallDecision.allowed:
        return executor.execute(arguments ?? const <String, dynamic>{});
    }
  }

  /// Background invocation used by the LLM agentic loop when no UI context
  /// is available. L0 tools execute directly; L1+ tools check cached permission
  /// and execute only if the user has previously granted access.
  Future<ToolCallResult> invokeBackground({
    required String toolId,
    Map<String, dynamic>? arguments,
  }) async {
    final executor = _executors[toolId];
    if (executor == null) {
      return ToolCallResult.error(
        toolId: toolId,
        errorMessage: '未找到工具：$toolId',
      );
    }

    final definitions = _confirmationService.permissionService.listDefinitions();
    final definition = definitions.cast<ToolDefinition?>().firstWhere(
      (d) => d!.id == toolId,
      orElse: () => null,
    );

    if (definition == null) {
      return ToolCallResult.error(
        toolId: toolId,
        errorMessage: '未知工具：$toolId',
      );
    }

    // L0: always allowed without any confirmation
    if (definition.permissionLevel == ToolPermissionLevel.l0) {
      return executor.execute(arguments ?? const <String, dynamic>{});
    }

    // L1/L2/L3: check cached permission status
    final records = await _confirmationService.permissionService.permissionMap();
    final record = records[toolId];
    final status = record?.status ?? ToolPermissionStatus.notDetermined;

    if (status == ToolPermissionStatus.granted) {
      return executor.execute(arguments ?? const <String, dynamic>{});
    }

    return ToolCallResult.error(
      toolId: toolId,
      errorMessage: '工具 "$toolId" 需要用户授权，请在设置中启用该工具权限后重试',
    );
  }
}

final toolBridgeExecutorProvider = Provider<ToolBridgeExecutor>((ref) {
  return ToolBridgeExecutor(
    confirmationService: ref.watch(toolCallConfirmationServiceProvider),
    executors: const <String, ToolExecutor>{
      'contacts.read': ContactReadTool(),
      'contacts.search': ContactSearchTool(),
      'contacts.create': ContactCreateTool(),
      'mail.compose': MailComposeTool(),
      'sms.send': SmsSendTool(),
      'phone.call': PhoneCallTool(),
      'calendar.read': CalendarReadTool(),
      'calendar.create': CalendarCreateTool(),
      'calendar.update_delete': CalendarUpdateDeleteTool(),
      'location.current': LocationCurrentTool(),
      'location.search': LocationSearchTool(),
      'clipboard.read': ClipboardReadTool(),
      'clipboard.write': ClipboardWriteTool(),
      'system.share': SystemShareTool(),
    },
  );
});

final toolCallStatusProvider =
    NotifierProvider<ToolCallStatusNotifier, String?>(() {
  return ToolCallStatusNotifier();
});

class ToolCallStatusNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String toolDisplayName) {
    state = '正在调用：$toolDisplayName…';
  }

  void clear() {
    state = null;
  }
}
