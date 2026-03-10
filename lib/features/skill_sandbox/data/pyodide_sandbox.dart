import 'dart:async';
import 'dart:convert';

import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_sandbox.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _kPyodideCdnUrl =
    'https://cdn.jsdelivr.net/pyodide/v0.26.2/full/pyodide.js';

String _buildHtml() => '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<script src="$_kPyodideCdnUrl"></script>
<script>
var _pyodide = null;

async function initPyodide() {
  try {
    _pyodide = await loadPyodide({
      indexURL: "https://cdn.jsdelivr.net/pyodide/v0.26.2/full/"
    });
    // Block dangerous modules by patching __builtins__.__import__
    _pyodide.runPython(`
import sys
import builtins
_blocked = {'os', 'subprocess', 'sys', 'socket', 'urllib', 'http',
             'requests', 'pickle', 'ctypes', 'importlib', 'shutil',
             'threading', 'multiprocessing', 'signal', 'pty', 'tty',
             'termios', 'resource', 'rlcompleter', 'readline', 'code',
             'codeop', 'ast', 'dis', 'gc', 'inspect', 'tokenize',
             'tracemalloc', 'linecache', 'pdb', 'profile', 'cProfile'}
_real_import = builtins.__import__

def _safe_import(name, *args, **kwargs):
    top = name.split('.')[0]
    if top in _blocked:
        raise ImportError(f"Module '{name}' is blocked in this sandbox")
    return _real_import(name, *args, **kwargs)

builtins.__import__ = _safe_import
`);
    SkillBridge.postMessage(JSON.stringify({type: 'ready'}));
  } catch(e) {
    SkillBridge.postMessage(JSON.stringify({type: 'error', error: String(e)}));
  }
}

window.runPython = async function(code, argsJson) {
  if (!_pyodide) {
    SkillBridge.postMessage(JSON.stringify({
      type: 'result',
      success: false,
      stdout: '',
      error: 'Pyodide not initialised'
    }));
    return;
  }
  try {
    _pyodide.runPython(`
import io as _io
import sys as _sys
_stdout_capture = _io.StringIO()
_real_stdout = _sys.stdout
_sys.stdout = _stdout_capture
`);
    const argsSetup = 'import json as _json\\n_args = _json.loads(' +
      JSON.stringify(argsJson) + ')\\n';
    _pyodide.runPython(argsSetup + code);
    const captured = _pyodide.runPython(`
_sys.stdout = _real_stdout
_stdout_capture.getvalue()
`);
    SkillBridge.postMessage(JSON.stringify({
      type: 'result',
      success: true,
      stdout: captured,
      error: ''
    }));
  } catch(e) {
    try {
      _pyodide.runPython('import sys as _sys; _sys.stdout = _real_stdout');
    } catch(_) {}
    SkillBridge.postMessage(JSON.stringify({
      type: 'result',
      success: false,
      stdout: '',
      error: String(e)
    }));
  }
};

initPyodide();
</script>
</body>
</html>
''';

class PyodideSandbox implements SkillSandbox {
  PyodideSandbox({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  WebViewController? _controller;
  bool _ready = false;
  Completer<void>? _readyCompleter;

  Future<void> init() async {
    if (_ready) return;
    _readyCompleter = Completer<void>();

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel(
      'SkillBridge',
      onMessageReceived: _onBridgeMessage,
    );

    await controller.loadHtmlString(_buildHtml());
    _controller = controller;

    await _readyCompleter!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _logger?.warning('PyodideSandbox: Pyodide init timed out');
        throw TimeoutException('Pyodide init timed out', const Duration(seconds: 60));
      },
    );
  }

  Completer<Map<String, dynamic>>? _pendingResult;

  void _onBridgeMessage(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      if (type == 'ready') {
        _ready = true;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter!.complete();
        }
      } else if (type == 'error') {
        _ready = false;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter!.completeError(
            Exception(data['error'] as String? ?? 'unknown init error'),
          );
        }
      } else if (type == 'result') {
        _pendingResult?.complete(data);
        _pendingResult = null;
      }
    } catch (e, st) {
      _logger?.error('PyodideSandbox: bridge parse error', error: e, stackTrace: st);
    }
  }

  @override
  Future<SandboxResult> execute({
    required String scriptContent,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      if (!_ready) {
        await init();
      }

      final controller = _controller;
      if (controller == null) {
        return SandboxError(message: 'WebView controller not initialised');
      }

      final argsJson = jsonEncode(args);
      final escapedCode = _escapeJsString(scriptContent);
      final escapedArgs = _escapeJsString(argsJson);

      _pendingResult = Completer<Map<String, dynamic>>();
      final start = DateTime.now().millisecondsSinceEpoch;

      await controller.runJavaScript(
        'window.runPython($escapedCode, $escapedArgs);',
      );

      final resultData = await _pendingResult!.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResult = null;
          throw TimeoutException('Python execution timed out', timeout);
        },
      );

      final elapsed = DateTime.now().millisecondsSinceEpoch - start;
      final success = resultData['success'] as bool? ?? false;

      if (success) {
        return SandboxSuccess(
          stdout: resultData['stdout'] as String? ?? '',
          executionMs: elapsed,
        );
      } else {
        return SandboxError(
          message: resultData['error'] as String? ?? 'Python runtime error',
        );
      }
    } on TimeoutException {
      return SandboxError(
        message: '沙箱执行超时（${timeout.inSeconds}秒）',
        type: SandboxErrorType.timeout,
      );
    } catch (e, st) {
      _logger?.error('PyodideSandbox.execute failed', error: e, stackTrace: st);
      return SandboxError(message: '沙箱执行异常: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _pendingResult?.completeError(StateError('sandbox disposed'));
    _pendingResult = null;
    _controller = null;
    _ready = false;
  }

  String _escapeJsString(String raw) {
    final escaped = raw
        .replaceAll('\\', '\\\\')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');
    return '`$escaped`';
  }
}
