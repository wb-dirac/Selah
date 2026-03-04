## 14. 可验证机制：CI/CD 流水线

### 14.1 GitHub Actions 工作流

```yaml
# .github/workflows/ci.yml

name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  # ── 阶段1：代码质量（并行运行，必须全部通过）──
  format:
    name: 代码格式
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: dart format --output=none --set-exit-if-changed lib test

  analyze:
    name: 静态分析
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze --fatal-infos --fatal-warnings

  secret-scan:
    name: 密钥扫描（阻断级）
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0    # 扫描完整历史
      - name: TruffleHog 深度扫描
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          extra_args: --only-verified
      - name: 自定义模式扫描
        run: bash tool/check_secrets.sh

  forbidden-patterns:
    name: 禁止模式检查
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: dart tool/check_forbidden.dart

  # ── 阶段2：测试（依赖阶段1通过）──
  security-tests:
    name: 安全专项测试（阻断级）
    needs: [format, analyze, secret-scan, forbidden-patterns]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/security --reporter=github
      # 安全测试失败直接阻断，不等其他测试

  unit-tests:
    name: 单元测试
    needs: [format, analyze, secret-scan, forbidden-patterns]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/unit --coverage --reporter=github
      - name: 上传覆盖率报告
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
      - name: 检查覆盖率达标
        run: dart tool/check_coverage.dart

  integration-tests:
    name: 集成测试
    needs: [unit-tests, security-tests]
    strategy:
      matrix:
        platform: [ios, android, macos]
    runs-on: ${{ matrix.platform == 'macos' && 'macos-latest' || 'ubuntu-latest' }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/integration

  performance-tests:
    name: 性能基准测试
    needs: [unit-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/performance
      - name: 与基准对比
        run: dart tool/compare_benchmarks.dart

  golden-tests:
    name: Golden 视觉测试
    needs: [format, analyze]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test test/golden
      - name: 上传 diff（测试失败时）
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: golden-failures
          path: test/golden/failures/

  # ── 阶段3：构建（仅 main 分支）──
  build:
    name: 多平台构建
    needs: [integration-tests, golden-tests]
    if: github.ref == 'refs/heads/main'
    strategy:
      matrix:
        include:
          - platform: ios
            runner: macos-latest
            command: flutter build ios --release --no-codesign
          - platform: android
            runner: ubuntu-latest
            command: flutter build apk --release
          - platform: macos
            runner: macos-latest
            command: flutter build macos --release
          - platform: windows
            runner: windows-latest
            command: flutter build windows --release
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: ${{ matrix.command }}
```

### 14.2 Pull Request 强制要求

```yaml
# .github/branch-protection.yml（通过 GitHub API 配置）
# main 分支保护规则：

required_status_checks:
  strict: true    # 必须基于最新 main
  contexts:
    - 代码格式
    - 静态分析
    - 密钥扫描（阻断级）       # 任何密钥泄漏直接拒绝合并
    - 禁止模式检查
    - 安全专项测试（阻断级）    # 安全测试失败直接拒绝合并
    - 单元测试
    - 集成测试 (ios)
    - 集成测试 (android)
    - Golden 视觉测试

dismiss_stale_reviews: true
require_code_owner_reviews: true
required_approving_review_count: 1
```

### 14.3 Dependabot 安全更新配置

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: pub
    directory: /
    schedule:
      interval: weekly
    # 安全更新立即创建 PR，不等到周计划
    open-pull-requests-limit: 10
    labels:
      - dependencies
      - security
```

---

