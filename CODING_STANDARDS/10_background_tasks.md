## 10. 后台任务编码规范

### 10.1 任务注册规范

```dart
// 后台任务必须使用平台推荐的 API，不得使用自定义 Timer/Isolate 实现持续后台
// iOS: BGTaskScheduler，Android: WorkManager

// 任务标识符必须全局唯一，使用反向域名格式
class ScheduledTaskIds {
  static const String morningBriefing = 'com.app.tasks.morning_briefing';
  static const String locationReminder = 'com.app.tasks.location_reminder';
  // 新增任务时必须在此统一注册
}

// 后台任务执行时间不保证精确，不得依赖精确时间做金融类操作
// 任务执行结果必须记录日志（本地，脱敏）
class TaskExecutionLog {
  final String taskId;
  final DateTime scheduledTime;
  final DateTime actualExecutionTime;
  final TaskExecutionResult result;
  final int inferenceTimeMs;    // 轻量模型推理耗时
  final bool usedLocalModel;    // 必须记录，用于电量分析
}
```

### 10.2 轻量推理规范

```dart
// 后台任务推理必须使用本地轻量模型（< 4B 参数）
// 严禁后台任务向云端发起 LLM 请求（用户不知情时不发云端请求）
class BackgroundInferenceService {
  BackgroundInferenceService({required this.localModelService});

  // 明确类型：只允许本地模型
  final LocalModelService localModelService;

  Future<InferenceResult> decide(TaskContext context) async {
    // 不接受 LlmGateway（可能路由到云端），只接受 LocalModelService
    return localModelService.infer(
      prompt: _buildDecisionPrompt(context),
      maxTokens: 256,    // 后台推理限制输出长度
      timeout: const Duration(seconds: 10),
    );
  }
}
```

---

