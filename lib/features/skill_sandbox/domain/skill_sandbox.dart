abstract class SkillSandbox {
  Future<SandboxResult> execute({
    required String scriptContent,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  });

  Future<void> dispose();
}

sealed class SandboxResult {}

class SandboxSuccess extends SandboxResult {
  SandboxSuccess({required this.stdout, required this.executionMs});

  final String stdout;
  final int executionMs;
}

class SandboxError extends SandboxResult {
  SandboxError({
    required this.message,
    this.type = SandboxErrorType.runtime,
  });

  final String message;
  final SandboxErrorType type;
}

enum SandboxErrorType { timeout, securityViolation, runtime, resourceLimit }
