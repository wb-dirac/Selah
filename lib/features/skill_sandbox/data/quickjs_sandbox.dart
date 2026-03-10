// Desktop JS sandbox: requires Node.js >=18 or Deno >=1.40 on PATH
//
// QuickJsSandbox would normally use flutter_qjs for in-process QuickJS execution
// on iOS/Android. However, flutter_qjs has an incompatible transitive ffi
// dependency with other packages in this project. The factory falls back to
// ProcessBasedJsSandbox on all platforms until a compatible QuickJS embedding
// is available.

import 'dart:async';
import 'dart:io';

import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_sandbox.dart';

class QuickJsSandbox implements SkillSandbox {
  QuickJsSandbox({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  @override
  Future<SandboxResult> execute({
    required String scriptContent,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _logger?.warning(
      'QuickJsSandbox: native QuickJS runtime not available; '
      'falling back to ProcessBasedJsSandbox',
    );
    final fallback = ProcessBasedJsSandbox(logger: _logger);
    return fallback.execute(
      scriptContent: scriptContent,
      args: args,
      timeout: timeout,
    );
  }

  @override
  Future<void> dispose() async {}
}

class ProcessBasedJsSandbox implements SkillSandbox {
  ProcessBasedJsSandbox({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  @override
  Future<SandboxResult> execute({
    required String scriptContent,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final runtime = await _detectRuntime();
    if (runtime == null) {
      return SandboxError(
        message:
            'JS sandbox requires Node.js >=18 or Deno >=1.40 on PATH',
        type: SandboxErrorType.runtime,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('skill_js_');
    final scriptFile = File('${tempDir.path}/script.js');

    try {
      final argsJson = _encodeArgs(args);
      final wrappedScript = _buildScript(scriptContent, argsJson);

      await scriptFile.writeAsString(wrappedScript);

      final start = DateTime.now().millisecondsSinceEpoch;
      ProcessResult result;

      if (runtime == _Runtime.deno) {
        result = await Process.run(
          'deno',
          ['run', '--no-prompt', scriptFile.path],
          runInShell: false,
        ).timeout(timeout);
      } else {
        result = await Process.run(
          'node',
          ['--max-heap-size=128', scriptFile.path],
          runInShell: false,
        ).timeout(timeout);
      }

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
              : '进程退出码 ${result.exitCode}',
        );
      }
    } on TimeoutException {
      return SandboxError(
        message: '沙箱执行超时（${timeout.inSeconds}秒）',
        type: SandboxErrorType.timeout,
      );
    } catch (e, st) {
      _logger?.error(
        'ProcessBasedJsSandbox.execute failed',
        error: e,
        stackTrace: st,
      );
      return SandboxError(message: '沙箱执行异常: $e');
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        _logger?.warning(
          'ProcessBasedJsSandbox: failed to clean temp dir',
          context: {'error': e.toString()},
        );
      }
    }
  }

  @override
  Future<void> dispose() async {}

  Future<_Runtime?> _detectRuntime() async {
    try {
      final denoResult = await Process.run(
        'deno',
        ['--version'],
        runInShell: true,
      );
      if (denoResult.exitCode == 0) return _Runtime.deno;
    } catch (_) {}

    try {
      final nodeResult = await Process.run(
        'node',
        ['--version'],
        runInShell: true,
      );
      if (nodeResult.exitCode == 0) return _Runtime.node;
    } catch (_) {}

    return null;
  }

  String _encodeArgs(Map<String, dynamic> args) {
    final sb = StringBuffer('{');
    var first = true;
    for (final entry in args.entries) {
      if (!first) sb.write(',');
      first = false;
      final key = entry.key
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"');
      sb.write('"$key":');
      sb.write(_encodeValue(entry.value));
    }
    sb.write('}');
    return sb.toString();
  }

  String _encodeValue(Object? v) {
    if (v == null) return 'null';
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    if (v is String) {
      final esc = v
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r');
      return '"$esc"';
    }
    if (v is List) {
      return '[${v.map(_encodeValue).join(',')}]';
    }
    if (v is Map) {
      final entries = v.entries
          .map((e) => '"${e.key}":${_encodeValue(e.value)}')
          .join(',');
      return '{$entries}';
    }
    return '"${v.toString()}"';
  }

  String _buildScript(String userCode, String argsJson) => '''
const args = $argsJson;
const __lines = [];
console.log = (...a) => { __lines.push(a.map(String).join(' ')); };
console.error = (...a) => { __lines.push(a.map(String).join(' ')); };
console.warn = (...a) => { __lines.push(a.map(String).join(' ')); };

(function() {
$userCode
})();

process.stdout.write(__lines.join('\\n') + (__lines.length > 0 ? '\\n' : ''));
''';
}

enum _Runtime { node, deno }
