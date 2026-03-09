import 'package:flutter/services.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:share_plus/share_plus.dart';

class ClipboardReadTool implements ToolExecutor {
  const ClipboardReadTool();

  @override
  String get toolId => 'clipboard.read';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return const ToolCallResult.success(
        toolId: 'clipboard.read',
        output: '',
      );
    }
    return ToolCallResult.success(toolId: 'clipboard.read', output: text);
  }
}

class ClipboardWriteTool implements ToolExecutor {
  const ClipboardWriteTool();

  @override
  String get toolId => 'clipboard.write';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text']?.toString();
    if (text == null) {
      return const ToolCallResult.error(
        toolId: 'clipboard.write',
        errorMessage: '缺少参数 text',
      );
    }
    await Clipboard.setData(ClipboardData(text: text));
    return const ToolCallResult.success(
      toolId: 'clipboard.write',
      output: '已写入剪贴板',
    );
  }
}

class SystemShareTool implements ToolExecutor {
  const SystemShareTool();

  @override
  String get toolId => 'system.share';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text']?.toString();
    final subject = arguments['subject']?.toString();
    if (text == null || text.isEmpty) {
      return const ToolCallResult.error(
        toolId: 'system.share',
        errorMessage: '缺少参数 text',
      );
    }
    final result = await Share.share(text, subject: subject);
    final success = result.status != ShareResultStatus.dismissed;
    return success
        ? const ToolCallResult.success(
            toolId: 'system.share',
            output: '分享成功',
          )
        : const ToolCallResult.success(
            toolId: 'system.share',
            output: '用户取消了分享',
          );
  }
}
