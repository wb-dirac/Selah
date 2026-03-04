## 9. Tool Bridge 编码规范

### 9.1 权限检查规范

```dart
// 权限检查必须在工具执行前进行，不可绕过
abstract class NativeTool {
  PermissionLevel get requiredPermissionLevel;
  String get toolName;
  String get toolDescription;

  Future<Result<ToolResult, ToolException>> execute(
    Map<String, dynamic> args,
    PermissionContext context,
  );
}

// 工具执行器：统一执行前检查
class ToolBridge {
  Future<Result<ToolResult, ToolException>> executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final tool = _registry.get(toolName);
    if (tool == null) return Result.failure(UnknownToolException(toolName));

    // L0：直接执行
    if (tool.requiredPermissionLevel == PermissionLevel.l0) {
      return tool.execute(args, PermissionContext.granted());
    }

    // L1：检查是否已授权
    final granted = await _permissionStore.isGranted(toolName);
    if (!granted) {
      // 请求授权（UI 层处理弹窗）
      final userDecision = await _permissionRequester.request(tool);
      if (!userDecision.granted) {
        return Result.failure(ToolPermissionDeniedException(toolName));
      }
      if (userDecision.rememberChoice) {
        await _permissionStore.grant(toolName);
      }
    }

    // L2/L3：每次都需要用户确认（通过 UI 层弹窗）
    if (tool.requiredPermissionLevel >= PermissionLevel.l2) {
      final preview = tool.buildPreview(args);
      final confirmed = await _confirmationDialog.show(preview);
      if (!confirmed) {
        return Result.failure(ToolActionCancelledException(toolName));
      }
    }

    return tool.execute(args, PermissionContext.granted());
  }
}
```

### 9.2 工具调用记录规范

```dart
// 每次工具调用必须记录，用于用户审查
class ToolCallRecord {
  final String toolName;
  final Map<String, dynamic> args;    // 脱敏处理后的参数
  final ToolCallStatus status;
  final DateTime timestamp;
  final String conversationId;

  // 注意：不记录工具调用结果（可能包含敏感数据，如联系人信息）
  // 只记录调用本身，结果由用户在对话中查看
}
```

---

