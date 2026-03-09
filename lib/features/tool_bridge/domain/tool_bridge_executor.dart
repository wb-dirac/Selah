import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/system_tools.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_confirmation_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';

class ToolBridgeExecutor {
  ToolBridgeExecutor({
    required ToolCallConfirmationService confirmationService,
    required Map<String, ToolExecutor> executors,
  })  : _confirmationService = confirmationService,
        _executors = executors;

  final ToolCallConfirmationService _confirmationService;
  final Map<String, ToolExecutor> _executors;

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
}

final toolBridgeExecutorProvider = Provider<ToolBridgeExecutor>((ref) {
  return ToolBridgeExecutor(
    confirmationService: ref.watch(toolCallConfirmationServiceProvider),
    executors: const <String, ToolExecutor>{
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
