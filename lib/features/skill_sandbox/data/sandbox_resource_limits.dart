import 'dart:async';

import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_sandbox.dart';

class SandboxResourceLimits {
  const SandboxResourceLimits._();

  static const Duration hardTimeout = Duration(seconds: 30);
  static const int maxMemoryMb = 128;
  static const int maxTempFileSizeMb = 100;

  static Future<SandboxResult> runWithLimits(
    Future<SandboxResult> Function() fn, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? hardTimeout;
    try {
      return await fn().timeout(
        effectiveTimeout,
        onTimeout: () => SandboxError(
          message: '沙箱执行超时（${effectiveTimeout.inSeconds}秒）',
          type: SandboxErrorType.timeout,
        ),
      );
    } catch (e) {
      return SandboxError(message: '沙箱执行异常: $e');
    }
  }
}
