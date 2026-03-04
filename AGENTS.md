# AGENTS.md
# 本文件供 Coding Agent 快速了解项目工作规范

## 关键文档
- [完整规范索引](CODING_STANDARDS/index.md)
- [产品需求索引](PRD/index.md)
- [UI/UX 规范索引](UI/index.md)

## 技术栈速查
- 框架：Flutter（Dart）
- 状态管理：Riverpod
- 数据库：SQLite + SQLCipher
- 加密：AES-256-GCM + Argon2id

## 提交前必做
dart tool/verify.dart

## 高风险目录（改动需特别谨慎）
- lib/core/crypto/        # 加密核心
- lib/core/keychain/      # 密钥存储
- lib/features/privacy/   # PII 检测
- lib/features/skill_sandbox/  # 沙箱安全

## 禁止的代码模式（速查）
1. 不用 print()，用 AppLogger
2. API Key 只存 KeyChain，不存 SharedPreferences
3. SQL 只用参数化，不拼字符串
4. HTTP 必须 HTTPS
5. 不留空 catch 块
6. Skill 沙箱无网络访问

## 测试位置
- test/unit/          单元测试
- test/security/      安全测试（阻断级）
- test/integration/   集成测试
- test/performance/   性能基准
- test/golden/        视觉回归