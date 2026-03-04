## 7. Skill 沙箱编码规范

### 7.1 Skill 加载规范

```dart
// Skill 加载流程：每一步都必须有明确的失败处理
class SkillLoader {
  Future<Result<LoadedSkill, SkillLoadException>> load(
    SkillPackage package,
  ) async {
    // 步骤1：结构校验
    final structureResult = await _validateStructure(package);
    if (structureResult.isFailure) return structureResult.cast();

    // 步骤2：YAML frontmatter 解析和字段校验
    final manifestResult = await _parseManifest(package.skillMd);
    if (manifestResult.isFailure) return manifestResult.cast();
    final manifest = manifestResult.value;

    // 步骤3：name 字段规范校验（对齐 Anthropic 标准）
    if (!_isValidSkillName(manifest.name)) {
      return Result.failure(InvalidSkillNameException(manifest.name));
    }

    // 步骤4：安全扫描
    final scanResult = await _securityScanner.scan(package);
    if (scanResult.severity == ScanSeverity.rejected) {
      return Result.failure(SkillSecurityRejectedException(
        skillName: manifest.name,
        findings: scanResult.findings,
      ));
    }

    // 步骤5：创建沙箱实例（隔离，不访问宿主文件系统）
    final sandbox = await _sandboxFactory.create(
      manifest: manifest,
      scripts: package.scripts,
      allowedNetworkHosts: [],  // 沙箱内无网络访问（对齐 Anthropic API 标准）
    );

    return Result.success(LoadedSkill(manifest: manifest, sandbox: sandbox));
  }

  bool _isValidSkillName(String name) {
    // 对齐 Anthropic 标准：小写字母、数字、连字符，最多 64 字符
    // 不能包含保留词 "anthropic" 或 "claude"
    final validPattern = RegExp(r'^[a-z0-9][a-z0-9\-]{0,62}[a-z0-9]$');
    if (!validPattern.hasMatch(name)) return false;
    if (name.contains('anthropic') || name.contains('claude')) return false;
    return true;
  }
}
```

### 7.2 沙箱执行规范

```dart
// 沙箱执行必须有超时和资源限制
abstract class SkillSandbox {
  /// 执行 Skill 脚本，返回 stdout 文本
  /// 沙箱保证：脚本代码本身不进入 LLM context，只有输出进入
  Future<Result<String, SandboxException>> execute({
    required String scriptPath,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),  // 硬性超时
  });
}

// Pyodide（WASM）沙箱实现要点：
class PyodideSandbox implements SkillSandbox {
  // 禁用的 Python 模块列表
  static const _blockedModules = [
    'os', 'subprocess', 'sys', 'shutil',    // 文件系统/进程
    'socket', 'urllib', 'http', 'requests', // 网络（沙箱内无网络）
    'pickle', 'shelve',                      // 反序列化安全风险
    'ctypes', 'cffi',                        // 原生代码调用
    '__builtins__',                          // 会被受限版本替换
  ];

  @override
  Future<Result<String, SandboxException>> execute({
    required String scriptPath,
    required Map<String, dynamic> args,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _runWithTimeout(
      () => _doExecute(scriptPath, args),
      timeout: timeout,
      onTimeout: () => Result.failure(
        SandboxTimeoutException(scriptPath: scriptPath, timeout: timeout),
      ),
    );
  }
}

// 可验证：沙箱逃逸测试（必须全部失败）
group('sandbox escape prevention', () {
  test('cannot read host filesystem', () async {
    final result = await sandbox.execute(
      scriptPath: 'test_fs.py',
      args: {'path': '/etc/passwd'},
    );
    expect(result, isA<Failure>());
    expect(result.failure, isA<SandboxSecurityException>());
  });

  test('cannot make network requests', () async {
    final result = await sandbox.execute(
      scriptPath: 'test_network.py',
      args: {'url': 'https://example.com'},
    );
    expect(result, isA<Failure>());
  });

  test('exceeds time limit and is killed', () async {
    final result = await sandbox.execute(
      scriptPath: 'test_infinite_loop.py',
      args: {},
      timeout: const Duration(seconds: 2),
    );
    expect(result, isA<Failure>());
    expect(result.failure, isA<SandboxTimeoutException>());
  });
});
```

### 7.3 Skill 安全扫描规范

```dart
// 安全扫描必须覆盖的检测点
class SkillSecurityScanner {
  static const _dangerousPatterns = {
    'python': [
      r'import\s+os',
      r'import\s+subprocess',
      r'import\s+socket',
      r'import\s+urllib',
      r'__import__\s*\(',
      r'eval\s*\(',
      r'exec\s*\(',
      r'open\s*\(',              // 文件操作
      r'compile\s*\(',
    ],
    'shell': [
      r'curl\s+',
      r'wget\s+',
      r'nc\s+',
      r'rm\s+-rf',
      r'chmod\s+',
      r'\$\(.*\)',               // 命令替换
    ],
  };

  // SKILL.md 内容扫描：检测 prompt injection 特征
  static const _promptInjectionPatterns = [
    r'ignore\s+previous\s+instructions',
    r'你现在是',
    r'forget.*you.*are',
    r'system\s*prompt',
    r'<\s*system\s*>',
  ];
}
```

---

