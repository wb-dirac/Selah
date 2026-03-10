import 'dart:async';
import 'dart:io';

import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_sandbox.dart';

class ShellSandbox implements SkillSandbox {
  ShellSandbox({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  static const List<String> _allowedCommands = <String>[
    'echo',
    'cat',
    'grep',
    'sed',
    'awk',
    'sort',
    'uniq',
    'date',
    'wc',
    'head',
    'tail',
    'printf',
    'test',
    'expr',
    'true',
    'false',
    'ls',
  ];

  static final RegExp _commandSubstitutionBacktick =
      RegExp(r'`[^`]*`', multiLine: true);
  static final RegExp _commandSubstitutionDollar =
      RegExp(r'\$\([^)]*\)', multiLine: true);
  static final RegExp _fileRedirection =
      RegExp(r'>{1,2}\s*\S', multiLine: true);

  @override
  Future<SandboxResult> execute({
    required String scriptContent,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (Platform.isWindows) {
      return SandboxError(
        message: 'Shell sandbox not available on Windows. Use Python or JS sandbox.',
        type: SandboxErrorType.runtime,
      );
    }

    final violation = _validateScript(scriptContent);
    if (violation != null) {
      return SandboxError(
        message: violation,
        type: SandboxErrorType.securityViolation,
      );
    }

    try {
      final start = DateTime.now().millisecondsSinceEpoch;

      final result = await Process.run(
        'bash',
        ['-c', '--', scriptContent],
        runInShell: false,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(timeout);

      final elapsed = DateTime.now().millisecondsSinceEpoch - start;

      if (result.exitCode == 0) {
        return SandboxSuccess(
          stdout: result.stdout as String,
          executionMs: elapsed,
        );
      } else {
        final stderr = result.stderr as String;
        return SandboxError(
          message: stderr.isNotEmpty
              ? stderr
              : 'Shell script exited with code ${result.exitCode}',
        );
      }
    } on TimeoutException {
      return SandboxError(
        message: '沙箱执行超时（${timeout.inSeconds}秒）',
        type: SandboxErrorType.timeout,
      );
    } catch (e, st) {
      _logger?.error('ShellSandbox.execute failed', error: e, stackTrace: st);
      return SandboxError(message: '沙箱执行异常: $e');
    }
  }

  @override
  Future<void> dispose() async {}

  String? _validateScript(String script) {
    if (_commandSubstitutionBacktick.hasMatch(script)) {
      return '安全违规：脚本中包含禁止的反引号命令替换';
    }
    if (_commandSubstitutionDollar.hasMatch(script)) {
      return '安全违规：脚本中包含禁止的 \$(...) 命令替换';
    }
    if (_fileRedirection.hasMatch(script)) {
      return '安全违规：脚本中包含禁止的文件重定向操作';
    }

    final lines = script.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final stripped = raw.trim();

      if (stripped.isEmpty || stripped.startsWith('#')) continue;

      final withoutComment = stripped.contains('#')
          ? stripped.substring(0, stripped.indexOf('#')).trim()
          : stripped;

      if (withoutComment.isEmpty) continue;

      final segments = withoutComment
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final segment in segments) {
        final firstWord = segment.split(RegExp(r'\s+')).first;
        if (!_allowedCommands.contains(firstWord)) {
          return '安全违规：第 ${i + 1} 行包含不允许的命令 "$firstWord"'
              '（允许命令列表：${_allowedCommands.join(', ')}）';
        }
      }
    }

    return null;
  }
}
