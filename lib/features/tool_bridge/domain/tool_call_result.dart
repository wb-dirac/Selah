class ToolCallResult {
  const ToolCallResult._({
    required this.toolId,
    this.output,
    this.errorMessage,
  });

  const ToolCallResult.success({
    required String toolId,
    String? output,
  }) : this._(toolId: toolId, output: output);

  const ToolCallResult.error({
    required String toolId,
    required String errorMessage,
  }) : this._(toolId: toolId, errorMessage: errorMessage);

  final String toolId;
  final String? output;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

abstract class ToolExecutor {
  String get toolId;

  Future<ToolCallResult> execute(Map<String, dynamic> arguments);
}
