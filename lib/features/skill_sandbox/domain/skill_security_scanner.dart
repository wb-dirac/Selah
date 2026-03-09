class ScanFinding {
  const ScanFinding({
    required this.severity,
    required this.category,
    required this.message,
    this.lineNumber,
    this.snippet,
  });

  final ScanSeverity severity;
  final ScanCategory category;
  final String message;
  final int? lineNumber;
  final String? snippet;

  @override
  String toString() {
    final loc = lineNumber != null ? ' (line $lineNumber)' : '';
    return '[${severity.name.toUpperCase()}]$loc ${category.name}: $message';
  }
}

enum ScanSeverity { warning, critical }

enum ScanCategory { networkAccess, processExecution, fileSystem, promptInjection }

class ScanResult {
  const ScanResult({required this.findings});

  final List<ScanFinding> findings;

  bool get isSafe => criticalFindings.isEmpty;
  List<ScanFinding> get criticalFindings =>
      findings.where((f) => f.severity == ScanSeverity.critical).toList();
  List<ScanFinding> get warnings =>
      findings.where((f) => f.severity == ScanSeverity.warning).toList();
}

class SkillSecurityScanner {
  const SkillSecurityScanner();

  static final List<_PythonPattern> _pythonPatterns = [
    _PythonPattern(
      pattern: RegExp(r'\bos\.system\s*\(', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 os.system() 调用，可能执行任意系统命令',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bsubprocess\.', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 subprocess 模块使用，可能执行子进程',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bos\.popen\s*\(', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 os.popen() 调用，可能执行系统命令',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bexec\s*\(', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 exec() 调用，可能执行动态代码',
    ),
    _PythonPattern(
      pattern: RegExp(r'\beval\s*\(', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 eval() 调用，可能执行动态代码',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bsocket\.', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.networkAccess,
      message: '检测到 socket 模块使用，Skill 沙箱禁止网络访问',
    ),
    _PythonPattern(
      pattern: RegExp(r'\burllib\b', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.networkAccess,
      message: '检测到 urllib 模块导入，Skill 沙箱禁止网络访问',
    ),
    _PythonPattern(
      pattern: RegExp(r'\brequests\b', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.networkAccess,
      message: '检测到 requests 模块导入，Skill 沙箱禁止网络访问',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bhttpx\b', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.networkAccess,
      message: '检测到 httpx 模块导入，Skill 沙箱禁止网络访问',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bopen\s*\(', multiLine: true),
      severity: ScanSeverity.warning,
      category: ScanCategory.fileSystem,
      message: '检测到 open() 调用，Skill 沙箱应限制文件系统访问',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bshutil\b', multiLine: true),
      severity: ScanSeverity.warning,
      category: ScanCategory.fileSystem,
      message: '检测到 shutil 模块，可能执行文件系统操作',
    ),
    _PythonPattern(
      pattern: RegExp(r'\b__import__\s*\(', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 __import__() 动态导入，可能绕过安全限制',
    ),
    _PythonPattern(
      pattern: RegExp(r'\bimportlib\b', multiLine: true),
      severity: ScanSeverity.critical,
      category: ScanCategory.processExecution,
      message: '检测到 importlib 动态导入，可能绕过安全限制',
    ),
  ];

  static final List<_InjectionPattern> _injectionPatterns = [
    _InjectionPattern(
      pattern: RegExp(
        r'ignore\s+(all\s+)?(previous|above|prior)\s+(instructions?|prompt)',
        caseSensitive: false,
      ),
      message: '检测到 prompt injection 尝试："忽略之前指令"',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'(you\s+are\s+now|act\s+as|pretend\s+(you\s+are|to\s+be)|role\s*play)',
        caseSensitive: false,
      ),
      message: '检测到角色覆盖指令，可能试图更改 AI 身份',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'(disregard|forget|override)\s+(your\s+)?(instructions?|rules?|guidelines?)',
        caseSensitive: false,
      ),
      message: '检测到规则覆盖指令，可能试图绕过安全限制',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'(reveal|show|print|output|display)\s+(your\s+)?(system\s+prompt|instructions?|training\s+data)',
        caseSensitive: false,
      ),
      message: '检测到系统 prompt 提取尝试',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'(DAN|jailbreak|JAILBREAK|jail\s*break)',
        caseSensitive: false,
      ),
      message: '检测到已知 jailbreak 关键词',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'<\s*(system|SYSTEM)\s*>',
        caseSensitive: false,
      ),
      message: '检测到伪造 system 标签，可能试图注入系统级指令',
    ),
    _InjectionPattern(
      pattern: RegExp(
        r'\[INST\]|\[/INST\]|<\|im_start\|>|<\|im_end\|>',
      ),
      message: '检测到模型特殊 token，可能试图操控对话结构',
    ),
  ];

  ScanResult scanPythonCode(String source) {
    final findings = <ScanFinding>[];
    final lines = source.split('\n');

    for (final entry in _pythonPatterns) {
      final matches = entry.pattern.allMatches(source);
      for (final match in matches) {
        final lineNum = _lineOf(source, match.start);
        final snippet = lines[lineNum - 1].trim();
        findings.add(ScanFinding(
          severity: entry.severity,
          category: entry.category,
          message: entry.message,
          lineNumber: lineNum,
          snippet: snippet,
        ));
      }
    }

    return ScanResult(findings: findings);
  }

  ScanResult scanPromptText(String promptContent) {
    final findings = <ScanFinding>[];
    final lines = promptContent.split('\n');

    for (final pattern in _injectionPatterns) {
      final matches = pattern.pattern.allMatches(promptContent);
      for (final match in matches) {
        final lineNum = _lineOf(promptContent, match.start);
        final snippet = lines[lineNum - 1].trim();
        findings.add(ScanFinding(
          severity: ScanSeverity.critical,
          category: ScanCategory.promptInjection,
          message: pattern.message,
          lineNumber: lineNum,
          snippet: snippet,
        ));
      }
    }

    return ScanResult(findings: findings);
  }

  ScanResult scanSkillDirectory({
    required Map<String, String> pythonFiles,
    required Map<String, String> promptFiles,
  }) {
    final allFindings = <ScanFinding>[];

    for (final entry in pythonFiles.entries) {
      final result = scanPythonCode(entry.value);
      allFindings.addAll(result.findings);
    }

    for (final entry in promptFiles.entries) {
      final result = scanPromptText(entry.value);
      allFindings.addAll(result.findings);
    }

    return ScanResult(findings: allFindings);
  }

  int _lineOf(String source, int charOffset) {
    int line = 1;
    for (int i = 0; i < charOffset && i < source.length; i++) {
      if (source[i] == '\n') line++;
    }
    return line;
  }
}

class _PythonPattern {
  const _PythonPattern({
    required this.pattern,
    required this.severity,
    required this.category,
    required this.message,
  });

  final RegExp pattern;
  final ScanSeverity severity;
  final ScanCategory category;
  final String message;
}

class _InjectionPattern {
  const _InjectionPattern({required this.pattern, required this.message});

  final RegExp pattern;
  final String message;
}
