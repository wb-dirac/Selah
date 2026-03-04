## 1. 项目结构规范

### 1.1 标准目录结构

```
assistant_app/
├── lib/
│   ├── core/                        # 核心基础设施，无业务逻辑
│   │   ├── crypto/                  # 加密工具（AES-GCM, Argon2）
│   │   ├── database/                # SQLCipher 初始化与 migration
│   │   ├── keychain/                # OS KeyChain/KeyStore 抽象
│   │   ├── logger/                  # 结构化日志（含脱敏层）
│   │   ├── network/                 # HTTP 客户端基础配置
│   │   └── error/                   # 统一错误类型定义
│   │
│   ├── features/                    # 按功能模块划分
│   │   ├── conversation/            # 对话功能
│   │   │   ├── data/                # Repository 实现 + 数据模型
│   │   │   ├── domain/              # Use Case + 领域模型
│   │   │   └── presentation/        # Widget + ViewModel
│   │   ├── llm_gateway/             # LLM 接入层
│   │   ├── skill_sandbox/           # Skill 加载与沙箱执行
│   │   ├── tool_bridge/             # 原生能力调用
│   │   ├── generative_ui/           # 生成式 UI 卡片渲染
│   │   ├── scheduled_tasks/         # 后台定时任务
│   │   ├── a2a/                     # A2A 协议实现
│   │   ├── privacy/                 # PII 检测、数据脱敏
│   │   ├── sync/                    # GitHub Gist 同步
│   │   └── settings/                # 用户配置管理
│   │
│   ├── shared/                      # 跨功能共用组件
│   │   ├── widgets/                 # 通用 UI 组件
│   │   ├── theme/                   # 设计系统 Token
│   │   ├── extensions/              # Dart 扩展方法
│   │   └── constants/               # 应用常量
│   │
│   └── main.dart                    # 入口，仅做 DI 初始化
│
├── test/
│   ├── unit/                        # 单元测试（镜像 lib/ 结构）
│   ├── integration/                 # 集成测试
│   ├── security/                    # 安全专项测试
│   ├── performance/                 # 性能基准测试
│   └── golden/                      # Golden 截图测试
│
├── native/
│   ├── ios/                         # iOS Platform Channel 实现
│   ├── android/                     # Android Platform Channel 实现
│   ├── macos/                       # macOS 原生实现
│   └── windows/                     # Windows 原生实现
│
├── tool/
│   ├── verify.dart                  # 本地验证脚本（见第13节）
│   ├── check_secrets.sh             # 密钥泄漏扫描
│   └── codegen/                     # 代码生成工具
│
├── analysis_options.yaml            # Dart 静态分析规则
├── pubspec.yaml
└── AGENTS.md                        # Coding Agent 工作说明（本文档入口）
```

### 1.2 文件命名规范

```
# Dart 文件：snake_case
llm_gateway.dart
openai_provider.dart
conversation_view_model.dart

# 测试文件：被测文件名 + _test.dart
llm_gateway_test.dart
openai_provider_test.dart

# 常量文件：以 _constants.dart 结尾
api_constants.dart
route_constants.dart

# 禁止的命名模式
utils.dart          ❌  （过于宽泛，必须具体命名）
helpers.dart        ❌
common.dart         ❌
MyClass.dart        ❌  （不用驼峰，用 snake_case）
```

### 1.3 功能模块内部结构（以 conversation 为例）

```
features/conversation/
├── data/
│   ├── models/
│   │   ├── conversation_model.dart        # 数据层模型（含 JSON 序列化）
│   │   └── message_model.dart
│   ├── datasources/
│   │   ├── conversation_local_datasource.dart   # SQLite 操作
│   │   └── conversation_local_datasource_impl.dart
│   └── repositories/
│       ├── conversation_repository_impl.dart
│       └── conversation_repository_impl_test.dart  # 就近测试
├── domain/
│   ├── entities/
│   │   ├── conversation.dart              # 领域实体（纯 Dart 对象）
│   │   └── message.dart
│   ├── repositories/
│   │   └── conversation_repository.dart   # 抽象接口
│   └── usecases/
│       ├── send_message_usecase.dart
│       └── send_message_usecase_test.dart
└── presentation/
    ├── viewmodels/
    │   └── conversation_view_model.dart
    ├── widgets/
    │   ├── message_bubble.dart
    │   └── tool_call_card.dart
    └── screens/
        └── conversation_screen.dart
```

---

