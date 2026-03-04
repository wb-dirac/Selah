## 13. 可验证机制：自动检查清单

### 13.1 本地验证脚本（`tool/verify.dart`）

每次提交代码前，Coding Agent **必须主动运行**此脚本并确认全部通过：

```dart
// tool/verify.dart
// 运行方式: dart tool/verify.dart
// 单项运行: dart tool/verify.dart --only=security

import 'dart:io';

void main(List<String> args) async {
  final only = args.firstWhereOrNull((a) => a.startsWith('--only='))
    ?.split('=').last;

  final checks = [
    VerifyCheck(
      id: 'format',
      name: '代码格式化',
      command: ['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test'],
      errorMessage: '发现未格式化的文件，运行 dart format lib test 修复',
    ),
    VerifyCheck(
      id: 'analyze',
      name: '静态分析',
      command: ['dart', 'analyze', '--fatal-infos', '--fatal-warnings'],
      errorMessage: '静态分析发现问题',
    ),
    VerifyCheck(
      id: 'security',
      name: '密钥泄漏扫描',
      command: ['bash', 'tool/check_secrets.sh'],
      errorMessage: '发现潜在的密钥泄漏',
    ),
    VerifyCheck(
      id: 'forbidden',
      name: '禁止模式检查',
      command: ['dart', 'tool/check_forbidden.dart'],
      errorMessage: '发现被禁止的代码模式',
    ),
    VerifyCheck(
      id: 'test-unit',
      name: '单元测试',
      command: ['flutter', 'test', 'test/unit', '--coverage'],
      errorMessage: '单元测试失败',
    ),
    VerifyCheck(
      id: 'test-security',
      name: '安全专项测试',
      command: ['flutter', 'test', 'test/security'],
      errorMessage: '安全测试失败（严重，必须修复）',
      isCritical: true,
    ),
    VerifyCheck(
      id: 'coverage',
      name: '测试覆盖率检查',
      command: ['dart', 'tool/check_coverage.dart'],
      errorMessage: '测试覆盖率未达标',
    ),
  ];

  // 执行检查
  bool allPassed = true;
  for (final check in checks) {
    if (only != null && check.id != only) continue;

    stdout.write('  ${check.name}... ');
    final result = await Process.run(check.command[0], check.command.sublist(1));

    if (result.exitCode == 0) {
      stdout.writeln('✅');
    } else {
      stdout.writeln('❌');
      stderr.writeln(check.errorMessage);
      stderr.writeln(result.stderr);
      allPassed = false;
      if (check.isCritical) {
        stderr.writeln('⛔ 关键安全检查失败，立即停止');
        exit(1);
      }
    }
  }

  exit(allPassed ? 0 : 1);
}
```

### 13.2 禁止模式检查（`tool/check_forbidden.dart`）

```dart
// 自动扫描代码库中的禁止模式
final forbiddenPatterns = [
  ForbiddenPattern(
    pattern: RegExp(r'\bprint\s*\('),
    message: '禁止使用 print()，请使用 AppLogger',
    excludePaths: ['test/', 'tool/'],
  ),
  ForbiddenPattern(
    pattern: RegExp(r'SharedPreferences.*set(String|Int|Bool)\s*\(.*key[^,]*,.*[Kk]ey'),
    message: '疑似将敏感 Key 存入 SharedPreferences，请使用 KeychainService',
  ),
  ForbiddenPattern(
    pattern: RegExp(r"(sk-|sk-ant-|AIza)[a-zA-Z0-9\-_]{10,}"),
    message: '代码中发现疑似硬编码的 API Key！',
    excludePaths: ['test/fixtures/', 'AGENTS.md', 'CODING_AGENT_STANDARDS.md'],
  ),
  ForbiddenPattern(
    pattern: RegExp(r'import\s+[\'"]dart:mirrors[\'"]'),
    message: '禁止使用 dart:mirrors（影响 tree-shaking）',
  ),
  ForbiddenPattern(
    pattern: RegExp(r'\.rawQuery\s*\(\s*[\'"].*\$'),
    message: '疑似 SQL 注入风险，请使用参数化查询',
  ),
  ForbiddenPattern(
    pattern: RegExp(r'badCertificateCallback\s*=\s*\([^)]*\)\s*=>\s*true'),
    message: '禁止接受所有证书（会绕过 TLS 验证）',
  ),
  ForbiddenPattern(
    pattern: RegExp(r'catch\s*\(\s*[^)]+\)\s*\{\s*\}'),
    message: '禁止空 catch 块',
  ),
  ForbiddenPattern(
    pattern: RegExp(r'unawaited\s*\(.*\.log|await.*\.log'),
    message: '日志调用不需要 await，请使用 unawaited()',
    isSuggestion: true,
  ),
];
```

### 13.3 密钥泄漏扫描（`tool/check_secrets.sh`）

```bash
#!/bin/bash
# tool/check_secrets.sh

set -e

PATTERNS=(
  "sk-[a-zA-Z0-9\-_]{20,}"           # OpenAI
  "sk-ant-[a-zA-Z0-9\-_]{20,}"       # Anthropic
  "AIza[0-9A-Za-z\-_]{35}"           # Google
  "github_pat_[a-zA-Z0-9]{82}"       # GitHub PAT
  "ghp_[a-zA-Z0-9]{36}"              # GitHub Token
  "-----BEGIN.*PRIVATE KEY-----"      # 私钥文件
  "password\s*=\s*['\"][^'\"]{8,}"   # 硬编码密码
)

EXCLUDE_PATHS=(
  "*.md"
  "test/fixtures/*"
  "tool/check_secrets.sh"
)

FOUND=0

for pattern in "${PATTERNS[@]}"; do
  results=$(grep -rn \
    --include="*.dart" \
    --include="*.yaml" \
    --include="*.json" \
    --exclude-dir=".git" \
    --exclude-dir="build" \
    -E "$pattern" . 2>/dev/null || true)

  if [ -n "$results" ]; then
    echo "⚠️  发现可能的密钥泄漏 (pattern: $pattern):"
    echo "$results"
    FOUND=1
  fi
done

if [ $FOUND -eq 0 ]; then
  echo "✅ 未发现密钥泄漏"
  exit 0
else
  echo "❌ 发现潜在密钥泄漏，请检查并移除"
  exit 1
fi
```

### 13.4 覆盖率检查（`tool/check_coverage.dart`）

```dart
// 解析 lcov.info 并检查覆盖率达标情况
final coverageRequirements = {
  'lib/core/crypto': (line: 100, branch: 100),
  'lib/core/keychain': (line: 100, branch: 100),
  'lib/features/privacy': (line: 100, branch: 95),
  'lib/features/skill_sandbox': (line: 95, branch: 90),
  'lib/features/llm_gateway': (line: 90, branch: 85),
  'lib/features/tool_bridge': (line: 90, branch: 85),
  'lib/features/a2a': (line: 90, branch: 85),
  'lib/features/conversation': (line: 85, branch: 80),
};

// 读取 coverage/lcov.info 并逐模块检查
// 低于要求时输出具体未覆盖的文件和行号
```

---

