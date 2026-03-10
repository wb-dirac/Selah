import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:personal_ai_assistant/features/skill_sandbox/data/pyodide_sandbox.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/data/quickjs_sandbox.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/data/shell_sandbox.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_sandbox.dart';

class UnsupportedSandboxError extends Error {
  UnsupportedSandboxError(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedSandboxError: $message';
}

class SkillSandboxFactory {
  const SkillSandboxFactory._();

  static SkillSandbox create(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.py' => PyodideSandbox(),
      '.js' => _createJsSandbox(),
      '.sh' => ShellSandbox(),
      _ => throw UnsupportedSandboxError('不支持的脚本类型: $ext'),
    };
  }

  static bool canHandle(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return ext == '.py' || ext == '.js' || ext == '.sh';
  }

  static SkillSandbox _createJsSandbox() {
    if (Platform.isIOS || Platform.isAndroid) {
      return QuickJsSandbox();
    }
    return ProcessBasedJsSandbox();
  }
}
