class A2ATaskResult {
  const A2ATaskResult({
    required this.taskId,
    required this.agentUrl,
    required this.rawPayload,
    required this.receivedAt,
  });

  final String taskId;
  final String agentUrl;
  final Map<String, dynamic> rawPayload;
  final DateTime receivedAt;
}

class SafeA2AResult {
  const SafeA2AResult({
    required this.taskId,
    required this.agentUrl,
    required this.text,
    required this.processedAt,
    this.metadata = const <String, String>{},
  });

  final String taskId;
  final String agentUrl;
  final String text;
  final DateTime processedAt;
  final Map<String, String> metadata;
}

sealed class A2ASandboxOutcome {}

class A2ASandboxSuccess extends A2ASandboxOutcome {
  A2ASandboxSuccess(this.result);
  final SafeA2AResult result;
}

class A2ASandboxRejected extends A2ASandboxOutcome {
  A2ASandboxRejected(this.reason);
  final String reason;
}
