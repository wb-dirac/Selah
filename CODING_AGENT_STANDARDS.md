# Coding Agent 编码规范与验证机制

**项目**：跨平台智能个人助理应用  
**文档版本**：v1.0  
**创建日期**：2026-03-02  
**适用对象**：所有参与本项目的 Coding Agent（Claude Code、API Agentic 调用等）  
**关联文档**：PRD v1.1 · UI/UX 规范 v1.0

> **核心原则**：本项目涉及隐私数据、加密存储、沙箱隔离、跨平台兼容四个高风险维度。Coding Agent 在每次生成代码前必须主动识别所属维度并应用对应的约束规则，不得以"完成功能"为由跳过安全检查。

---

## 目录

1. [项目结构规范](#1-项目结构规范)
2. [通用编码规则](#2-通用编码规则)
3. [Flutter / Dart 专项规范](#3-flutter--dart-专项规范)
4. [安全与隐私编码规范](#4-安全与隐私编码规范)
5. [本地数据库操作规范](#5-本地数据库操作规范)
6. [LLM Gateway 编码规范](#6-llm-gateway-编码规范)
7. [Skill 沙箱编码规范](#7-skill-沙箱编码规范)
8. [A2A 协议编码规范](#8-a2a-协议编码规范)
9. [Tool Bridge 编码规范](#9-tool-bridge-编码规范)
10. [后台任务编码规范](#10-后台任务编码规范)
11. [生成式 UI 编码规范](#11-生成式-ui-编码规范)
12. [测试规范](#12-测试规范)
13. [可验证机制：自动检查清单](#13-可验证机制自动检查清单)
14. [可验证机制：CI/CD 流水线](#14-可验证机制cicd-流水线)
15. [可验证机制：代码审查协议](#15-可验证机制代码审查协议)
16. [Coding Agent 行为约束](#16-coding-agent-行为约束)

---

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

## 2. 通用编码规则

### 2.1 Dart 语言规范

#### 2.1.1 类型安全

```dart
// ✅ 正确：始终声明类型，避免动态类型传播
final String apiKey = await keychain.read('openai_key');
final List<Message> messages = [];

// ❌ 错误：使用 var 导致类型不明确（仅在局部变量类型显而易见时可用 var）
var response = await llmClient.complete(prompt);  // response 是什么类型？

// ✅ 正确：显式声明泛型参数
final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;

// ❌ 错误：不加 cast 直接使用
final json = jsonDecode(rawJson);  // 类型为 dynamic，危险
```

#### 2.1.2 空安全

```dart
// ✅ 正确：明确处理 nullable
String? apiKey = await keychain.read('openai_key');
if (apiKey == null) {
  throw const ApiKeyNotFoundException('openai');
}

// ❌ 错误：使用 ! 强制解包，未经验证
String key = apiKey!;  // 若为 null 则崩溃

// ✅ 正确：使用 ?. 和 ?? 做安全访问
final model = config.model?.name ?? 'claude-sonnet-4-6';

// 规则：禁止在非测试代码中使用 ! 操作符，除非有 assert 断言前置保护
assert(apiKey != null, 'API key must be validated before this point');
final key = apiKey!;  // 此处可接受
```

#### 2.1.3 异常处理

```dart
// ✅ 正确：定义具体异常类型，不使用裸 Exception
class LlmRequestException extends AppException {
  const LlmRequestException({
    required super.message,
    required this.provider,
    this.statusCode,
    super.cause,
  });

  final String provider;
  final int? statusCode;
}

// ✅ 正确：使用 Result 类型（Either 模式）处理预期错误
Future<Result<LlmResponse, LlmRequestException>> complete(
  LlmRequest request,
) async {
  try {
    final response = await _client.post(request);
    return Result.success(LlmResponse.fromJson(response));
  } on SocketException catch (e) {
    return Result.failure(LlmRequestException(
      message: 'Network unavailable',
      provider: _providerName,
      cause: e,
    ));
  } on HttpException catch (e, stack) {
    _logger.error('LLM request failed', error: e, stackTrace: stack);
    return Result.failure(LlmRequestException(
      message: e.message,
      provider: _providerName,
      statusCode: e.statusCode,
    ));
  }
}

// ❌ 错误：catch 后吞掉异常，什么都不做
try {
  await sendRequest();
} catch (e) {
  // 空 catch 块——严禁
}

// ❌ 错误：捕获过宽
} catch (e) {
  print(e);  // 不分类型，不上报，不处理
}
```

#### 2.1.4 异步编码

```dart
// ✅ 正确：所有 async 函数都有明确的返回类型
Future<void> deleteConversation(String id) async { ... }
Future<List<Conversation>> getAll() async { ... }
Stream<MessageChunk> streamResponse(LlmRequest request) async* { ... }

// ✅ 正确：使用 unawaited() 显式标记不需要等待的 Future
unawaited(_logger.logEvent('conversation_opened', {'id': id}));

// ❌ 错误：隐式忽略 Future（会导致未捕获异常）
_logger.logEvent('conversation_opened');  // 没有 await，也没有 unawaited()

// ✅ 正确：Stream 订阅必须存储引用以便取消
late StreamSubscription<MessageChunk> _responseSubscription;

_responseSubscription = llmGateway.stream(request).listen(
  (chunk) => _appendChunk(chunk),
  onError: (Object e) => _handleError(e),
  onDone: () => _markComplete(),
);

@override
void dispose() {
  _responseSubscription.cancel();  // 必须取消
  super.dispose();
}
```

### 2.2 注释与文档规范

```dart
/// LLM 请求网关，负责统一管理所有模型提供商的 API 调用。
///
/// 使用示例：
/// ```dart
/// final gateway = LlmGateway(providers: [openaiProvider, claudeProvider]);
/// final result = await gateway.complete(request);
/// ```
///
/// 注意：此类不持有任何 API Key，Key 的读取由 [KeychainService] 负责。
class LlmGateway {
  /// 向当前活跃的 LLM 提供商发起补全请求。
  ///
  /// [request] 包含 prompt、模型参数等。
  /// 返回 [Result] 而非直接抛出异常，调用方必须处理失败情况。
  ///
  /// Throws [NoProviderConfiguredException] 若没有任何提供商被配置。
  Future<Result<LlmResponse, LlmException>> complete(LlmRequest request);
}

// 行内注释规范：
// ✅ 说明「为什么」，而非「做了什么」（代码本身说明做了什么）
// 此处必须先检查 PII，因为 log 会异步上报到分析服务
final sanitized = await _piiDetector.sanitize(userMessage);

// ❌ 无意义的注释（代码已经说清楚了）
// 调用 sanitize 方法
final sanitized = await _piiDetector.sanitize(userMessage);

// TODO 注释格式（必须附带 issue 链接）
// TODO(#142): 实现 Argon2id 参数动态调整（根据设备性能）
```

### 2.3 禁止的代码模式

```dart
// ❌ 1. 禁止在非测试代码中使用 print()
print('debug: $apiKey');       // 可能泄漏密钥到日志

// ❌ 2. 禁止硬编码任何凭据或敏感字符串
const String defaultKey = 'sk-ant-xxx';   // 绝对禁止

// ❌ 3. 禁止直接访问 SharedPreferences 存储敏感数据
SharedPreferences prefs = await SharedPreferences.getInstance();
prefs.setString('api_key', key);  // 明文存储！使用 KeychainService

// ❌ 4. 禁止在内存中长期持有解密后的 API Key
class ProviderConfig {
  final String apiKey;  // 不应以 String 形式长期存储
  // ✅ 改为：仅在使用时从 KeychainService 实时读取
}

// ❌ 5. 禁止 dynamic 类型的数据直接流入 UI
Widget buildCard(dynamic data) { ... }   // data 可能是恶意内容（Skill 返回）

// ❌ 6. 禁止在 UI 层直接调用数据库或网络
// Widget 内部直接查 SQLite 或调 API，必须走 UseCase / ViewModel

// ❌ 7. 禁止跨层引用（data 层不能引用 presentation 层）
import 'package:app/features/conversation/presentation/...';  // 在 data 层中❌

// ❌ 8. 禁止使用 dart:mirrors（反射）——影响 tree-shaking 和安全性
import 'dart:mirrors';
```

---

## 3. Flutter / Dart 专项规范

### 3.1 Widget 设计原则

```dart
// 原则1：Widget 只负责 UI，不包含业务逻辑
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.onCopy,    // 动作回调，不在内部实现
    required this.onRetry,
  });

  final Message message;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  // ✅ 只有 UI 代码
  @override
  Widget build(BuildContext context) { ... }
}

// 原则2：const 构造函数优先（提升重建性能）
// ✅ 凡是可以 const 的地方都加 const
const SizedBox(height: 16),
const Divider(color: AppColors.border),
const EdgeInsets.symmetric(horizontal: 16),

// 原则3：Widget 拆分阈值——单个 build() 方法超过 80 行必须拆分
// 拆分为私有方法或独立 Widget

// 原则4：禁止在 build() 中做耗时操作
@override
Widget build(BuildContext context) {
  // ❌ 错误：build 可能被频繁调用
  final processed = expensiveProcess(message.content);

  // ✅ 正确：在 initState / didUpdateWidget 中预处理，或用 memoize
  return Text(_cachedProcessed);
}
```

### 3.2 状态管理规范

本项目采用 **Riverpod** 作为状态管理方案：

```dart
// Provider 命名规范：功能 + Provider 后缀
final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepositoryImpl(
    localDataSource: ref.watch(conversationLocalDataSourceProvider),
  );
});

// AsyncNotifier 用于异步状态
class ConversationListNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final repo = ref.watch(conversationRepositoryProvider);
    return repo.getAll();
  }

  Future<void> deleteConversation(String id) async {
    // ✅ 正确：先更新 UI，再持久化（乐观更新）
    final previous = state.requireValue;
    state = AsyncData(previous.where((c) => c.id != id).toList());

    try {
      await ref.read(conversationRepositoryProvider).delete(id);
    } catch (e) {
      // 回滚
      state = AsyncData(previous);
      rethrow;
    }
  }
}

// ✅ 正确：Selector 精确订阅，避免不必要重建
final messageCountProvider = Provider.family<int, String>((ref, conversationId) {
  return ref.watch(
    conversationProvider(conversationId).select((c) => c.messages.length),
  );
});
```

### 3.3 Platform Channel 规范

```dart
// 抽象层：所有平台差异必须隐藏在抽象接口后面
abstract class KeychainService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

// 实现层：Platform Channel 调用封装在单独文件
class KeychainServiceImpl implements KeychainService {
  static const _channel = MethodChannel('com.app/keychain');

  @override
  Future<void> write(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('write', {
        'key': key,
        'value': value,
      });
    } on PlatformException catch (e) {
      throw KeychainWriteException(key: key, cause: e);
    }
  }
}

// 测试层：Mock 实现，不依赖真实 KeyChain
class MockKeychainService implements KeychainService {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);
}
```

### 3.4 性能规范

```dart
// 规范1：大型列表必须使用 ListView.builder，禁止 ListView(children: [...])
ListView.builder(
  itemCount: messages.length,
  // ✅ itemExtent 已知时必须设置（提升滚动性能）
  itemExtent: 72.0,
  itemBuilder: (context, index) => MessageBubble(message: messages[index]),
)

// 规范2：图片必须指定尺寸并使用缓存
CachedNetworkImage(
  imageUrl: product.imageUrl,
  width: 60,
  height: 60,
  memCacheWidth: 120,    // 2x for retina
  memCacheHeight: 120,
  placeholder: (_, __) => const SkeletonBox(width: 60, height: 60),
  errorWidget: (_, __, ___) => const ProductImagePlaceholder(),
)

// 规范3：昂贵计算必须标注性能影响，并使用 compute() 放入 isolate
Future<List<SearchResult>> searchMessages(String query) async {
  // 全文搜索在大数据集上耗时，移入 isolate
  return compute(_doSearch, SearchParams(query: query, db: _dbPath));
}

// 规范4：动画必须使用 AnimationController 并在 dispose 中释放
@override
void dispose() {
  _animationController.dispose();
  _scrollController.dispose();
  super.dispose();
}
```

---

## 4. 安全与隐私编码规范

> **这是本项目优先级最高的规范章节。** 所有 Coding Agent 在生成涉及数据存储、网络传输、用户输入处理的代码时，必须先阅读并应用本章规则。

### 4.1 API Key 处理铁律

以下规则**没有例外**：

```dart
// 铁律 1：API Key 只能存在于 OS KeyChain/KeyStore，禁止其他存储方式
// ✅ 唯一合法的写入方式
await keychainService.write('provider.openai.api_key', apiKey);

// ❌ 以下任何方式都是严重违规
SharedPreferences.getInstance().then((p) => p.setString('key', apiKey));
File('keys.txt').writeAsString(apiKey);
Hive.box('config').put('api_key', apiKey);
sqflite.insert('config', {'api_key': apiKey});

// 铁律 2：API Key 不得以明文形式出现在任何日志中
_logger.info('Calling OpenAI with key: $apiKey');  // ❌ 严重违规
_logger.info('Calling OpenAI provider');           // ✅ 不记录 Key

// 铁律 3：API Key 读取后只能在最小必要范围内存活
// ✅ 正确：在请求方法内部读取，用完即丢
Future<LlmResponse> _doRequest(LlmRequest request) async {
  final key = await keychainService.read('provider.${_name}.api_key');
  if (key == null) throw ApiKeyNotFoundException(_name);

  // key 只在此方法作用域内存活
  final response = await _httpClient.post(
    _endpoint,
    headers: {'Authorization': 'Bearer $key'},
    body: request.toJson(),
  );

  // key 在此之后不再被引用，等待 GC
  return LlmResponse.fromJson(response);
}

// ❌ 错误：将 Key 存储为实例变量
class OpenAiProvider {
  late String _apiKey;  // ❌ Key 长期驻留在内存

  Future<void> init() async {
    _apiKey = await keychainService.read('provider.openai.api_key') ?? '';
  }
}

// 铁律 4：API Key 不得出现在网络请求的查询参数中（必须用 Header）
// ❌ 错误
final url = 'https://api.openai.com/v1/complete?api_key=$key';

// ✅ 正确
headers: {'Authorization': 'Bearer $key'}
```

### 4.2 日志脱敏规范

```dart
// 所有日志输出必须经过 SanitizedLogger，不得直接使用 print 或 debugPrint
class SanitizedLogger {
  static final _sensitivePatterns = [
    RegExp(r'sk-[a-zA-Z0-9\-_]{20,}'),           // OpenAI 格式
    RegExp(r'sk-ant-[a-zA-Z0-9\-_]{20,}'),        // Anthropic 格式
    RegExp(r'AIza[0-9A-Za-z\-_]{35}'),             // Google AI 格式
    RegExp(r'\b1[3-9]\d{9}\b'),                    // 中国手机号
    RegExp(r'\b[6-9]\d{15}\b'),                    // 银行卡号
    RegExp(r'\b[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])\d{2}\d{3}[0-9xX]\b'), // 身份证
  ];

  void info(String message, {Map<String, dynamic>? context}) {
    final sanitized = _sanitize(message);
    final sanitizedContext = context?.map(
      (k, v) => MapEntry(k, _sanitize(v.toString())),
    );
    _underlying.info(sanitized, sanitizedContext);
  }

  String _sanitize(String input) {
    var result = input;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAll(pattern, '[REDACTED]');
    }
    return result;
  }
}

// 可验证：日志脱敏单元测试模板
test('logger redacts API keys', () {
  final logger = SanitizedLogger(underlying: MockLogger());
  logger.info('Using key sk-ant-api01-abcdefghijklmnopqrstuvwxyz12345');
  expect(mockLogger.lastMessage, contains('[REDACTED]'));
  expect(mockLogger.lastMessage, isNot(contains('sk-ant-api01')));
});
```

### 4.3 PII 数据处理规范

```dart
// 规范：所有用户输入在发送至云端 LLM 前必须经过 PiiDetector
abstract class PiiDetector {
  /// 返回检测结果，包含原文和脱敏版本
  Future<PiiDetectionResult> detect(String text);
}

class PiiDetectionResult {
  const PiiDetectionResult({
    required this.original,
    required this.sanitized,
    required this.findings,
  });

  final String original;
  final String sanitized;          // 可直接发送的版本
  final List<PiiFindings> findings; // 找到的敏感信息列表

  bool get hasPii => findings.isNotEmpty;
}

// 使用模式：在 LlmGateway 中强制检查
Future<Result<LlmResponse, LlmException>> complete(LlmRequest request) async {
  // 本地模型不需要 PII 检查（数据不离开设备）
  if (request.provider.isLocal) {
    return _doComplete(request);
  }

  // 云端模型必须先做 PII 检测
  final piiResult = await _piiDetector.detect(request.prompt);

  if (piiResult.hasPii && _settings.requireConfirmationBeforeSend) {
    // 抛出需要用户确认的特殊异常，UI 层会处理
    return Result.failure(PiiDetectedNeedsConfirmation(
      original: piiResult.original,
      sanitized: piiResult.sanitized,
      findings: piiResult.findings,
    ));
  }

  // 自动脱敏模式（用户未启用确认模式）
  final safeRequest = piiResult.hasPii
      ? request.copyWith(prompt: piiResult.sanitized)
      : request;

  return _doComplete(safeRequest);
}
```

### 4.4 加密实现规范

```dart
// 使用本项目封装的 CryptoService，禁止直接使用底层加密库
abstract class CryptoService {
  /// 加密数据。nonce 自动生成并附在密文前。
  Future<Uint8List> encrypt(Uint8List plaintext, Uint8List key);

  /// 解密数据。从密文中提取 nonce。
  Future<Uint8List> decrypt(Uint8List ciphertext, Uint8List key);

  /// 从 passphrase 派生密钥（Argon2id）
  Future<Uint8List> deriveKey({
    required String passphrase,
    required Uint8List salt,
    int memoryKib = 65536,   // 64MB，可根据设备调整
    int iterations = 3,
    int parallelism = 4,
    int keyLength = 32,      // AES-256
  });
}

// 实现注意事项（由 core/crypto 层实现，其他层只调用接口）：
// 1. 使用 AES-256-GCM，禁止使用 ECB、CBC（无认证模式）
// 2. nonce 必须每次随机生成，禁止复用
// 3. nonce 长度固定 12 字节（GCM 推荐）
// 4. AAD（附加认证数据）必须包含数据类型标识，防止混用

// 可验证：加密测试
test('encrypted data cannot be decrypted with wrong key', () async {
  final crypto = CryptoServiceImpl();
  final key1 = await crypto.deriveKey(passphrase: 'correct', salt: salt);
  final key2 = await crypto.deriveKey(passphrase: 'wrong', salt: salt);

  final ciphertext = await crypto.encrypt(plaintext, key1);

  expect(
    () async => await crypto.decrypt(ciphertext, key2),
    throwsA(isA<DecryptionException>()),
  );
});

test('nonce is never reused across two encryptions', () async {
  final crypto = CryptoServiceImpl();
  final ct1 = await crypto.encrypt(plaintext, key);
  final ct2 = await crypto.encrypt(plaintext, key);

  // 提取前 12 字节（nonce）
  expect(ct1.sublist(0, 12), isNot(equals(ct2.sublist(0, 12))));
});
```

### 4.5 网络安全规范

```dart
// 规范1：所有外部请求必须使用 HTTPS，禁止 HTTP
// 在 HttpClient 初始化层强制执行
class SecureHttpClient {
  SecureHttpClient() {
    _client = HttpClient()
      ..badCertificateCallback = (_, __, ___) => false  // 禁止接受无效证书
      ..connectionTimeout = const Duration(seconds: 30);
  }

  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (url.scheme != 'https') {
      throw InsecureUrlException(url: url.toString());
    }
    return _client.openUrl(method, url);
  }
}

// 规范2：A2A 通信必须验证 TLS 证书
// 规范3：OAuth Token 存储在 KeyChain，同 API Key 处理规则
// 规范4：所有请求设置超时
const _requestTimeout = Duration(seconds: 30);
const _streamTimeout = Duration(minutes: 5);  // 流式响应宽限

// 规范5：请求头不得包含设备唯一标识（隐私）
// ❌ 错误
headers['X-Device-ID'] = await getDeviceId();

// ✅ 正确：仅传必要信息
headers['Content-Type'] = 'application/json';
headers['Authorization'] = 'Bearer $token';
```

---

## 5. 本地数据库操作规范

### 5.1 SQLCipher 操作规范

```dart
// 规范1：数据库操作只能通过 Repository 接口，禁止在 UI 层或 UseCase 层直接操作 DB
// ✅ 合法调用链：Screen → ViewModel → UseCase → Repository → DataSource → DB

// 规范2：所有写操作必须在事务中执行
Future<void> saveConversationWithMessages(
  Conversation conversation,
  List<Message> messages,
) async {
  await _db.transaction((txn) async {
    await txn.insert(
      'conversations',
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final message in messages) {
      await txn.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  });
}

// 规范3：查询必须使用参数化查询，禁止字符串拼接
// ✅ 正确：参数化
final result = await _db.query(
  'messages',
  where: 'conversation_id = ? AND timestamp > ?',
  whereArgs: [conversationId, since.millisecondsSinceEpoch],
  orderBy: 'timestamp ASC',
  limit: 50,
);

// ❌ 错误：字符串拼接（SQL 注入风险）
final result = await _db.rawQuery(
  "SELECT * FROM messages WHERE id = '$userInput'",
);

// 规范4：数据库 Migration 必须有对应的 down migration
class DatabaseMigration {
  static const List<Migration> migrations = [
    Migration(
      version: 1,
      up: _migration1Up,
      down: _migration1Down,  // 必须实现
    ),
  ];
}

// 规范5：大量数据查询必须分页
Future<List<Message>> getMessages({
  required String conversationId,
  required int page,
  int pageSize = 50,
}) async {
  return _db.query(
    'messages',
    where: 'conversation_id = ?',
    whereArgs: [conversationId],
    orderBy: 'timestamp DESC',
    limit: pageSize,
    offset: page * pageSize,
  );
}
```

### 5.2 数据库 Schema 变更规范

```sql
-- 每次 Schema 变更必须创建 migration 文件
-- 文件命名：migration_v{from}_to_v{to}.sql

-- migration_v1_to_v2.sql（UP）
ALTER TABLE conversations ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_conversations_archived ON conversations(is_archived);

-- migration_v2_to_v1.sql（DOWN）
DROP INDEX IF EXISTS idx_conversations_archived;
-- SQLite 不支持 DROP COLUMN，需重建表
CREATE TABLE conversations_backup AS SELECT id, title, created_at FROM conversations;
DROP TABLE conversations;
ALTER TABLE conversations_backup RENAME TO conversations;
```

### 5.3 向量数据库规范（sqlite-vec）

```dart
// 向量维度必须与嵌入模型输出一致，并在常量文件中定义
class VectorDbConstants {
  static const int embeddingDimension = 384;  // 对应 all-MiniLM-L6-v2
  // 更换嵌入模型时必须同步更新此常量，并重建向量索引
}

// 向量搜索必须设置 top-k 上限，防止返回过多结果
Future<List<MessageSearchResult>> semanticSearch(
  String query, {
  int topK = 10,           // 必须有上限
  double minSimilarity = 0.7,  // 过滤低相关结果
}) async { ... }
```

---

## 6. LLM Gateway 编码规范

### 6.1 Provider 抽象规范

```dart
// 每个 LLM 提供商必须实现此抽象接口，不得绕过
abstract class LlmProvider {
  String get name;
  bool get isLocal;   // 区分本地/云端，用于隐私决策
  List<String> get supportedCapabilities;  // ['text', 'vision', 'realtime']

  Future<Result<LlmResponse, LlmException>> complete(LlmRequest request);
  Stream<LlmChunk> stream(LlmRequest request);

  /// 测试连接是否可用（用于配置 UI 的"测试连接"按钮）
  Future<ProviderHealthResult> healthCheck();
}

// 规范：Provider 实现不得持有 API Key 实例变量（见第4节）
// 规范：Provider 必须实现完整的流式支持
// 规范：Provider 的 name 必须是全局唯一的小写字符串（用作存储 key 前缀）
```

### 6.2 流式响应规范

```dart
// 流式响应必须处理所有中断情况
Stream<LlmChunk> stream(LlmRequest request) async* {
  final key = await _keychainService.read('provider.$name.api_key');
  if (key == null) {
    yield LlmChunk.error(ApiKeyNotFoundException(name));
    return;
  }

  try {
    final sseStream = await _client.streamPost(
      _streamEndpoint,
      headers: _buildHeaders(key),
      body: request.toStreamJson(),
    );

    await for (final event in sseStream) {
      if (event.isDone) break;
      if (event.isError) {
        yield LlmChunk.error(LlmStreamException(event.data));
        return;
      }
      yield LlmChunk.text(_parseChunk(event.data));
    }

    yield LlmChunk.done();
  } on TimeoutException {
    yield LlmChunk.error(LlmTimeoutException(provider: name));
  } on SocketException catch (e) {
    yield LlmChunk.error(NetworkException(cause: e));
  }
}
```

### 6.3 Token 用量追踪规范

```dart
// 每次 LLM 调用完成后必须记录 Token 用量（仅云端提供商）
// 用量数据存储在本地 SQLite，不上报任何服务器
class TokenUsageRecord {
  final String provider;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final DateTime timestamp;

  int get totalTokens => promptTokens + completionTokens;
}

// Token 用量查询接口必须支持按月聚合（用于 UI 展示）
Future<MonthlyUsage> getMonthlyUsage(String provider, DateTime month);
```

---

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

## 8. A2A 协议编码规范

### 8.1 A2A 通信规范

```dart
// 所有 A2A 请求必须经过认证和 TLS 验证
class A2AClient {
  A2AClient({
    required this.agentCard,
    required this.authService,
  }) {
    _httpClient = SecureHttpClient();  // 强制 HTTPS，见第4节
  }

  // 发起 A2A 任务前必须展示操作预览（UI 层负责，此处声明约定）
  // 调用方必须在用户确认后才能调用此方法
  Future<Result<A2ATaskResult, A2AException>> submitTask(A2ATask task) async {
    assert(task.userConfirmed, 'User must confirm before submitting A2A task');

    final token = await authService.getToken(agentCard.url);
    // ... 发送请求
  }
}

// Agent Card 验证：接收到的 Agent Card 必须验证 schema
class AgentCardValidator {
  Result<AgentCard, ValidationException> validate(Map<String, dynamic> json) {
    // 必须有 name, url, capabilities, skills 字段
    // url 必须是 https://
    // skills 列表不能为空
    // capabilities 必须包含已知字段
  }
}

// A2A 响应数据必须在沙箱处理后才能进入 UI
// 外部 Agent 返回的数据视为不可信输入
Future<SafeA2AResult> processA2AResponse(A2ATaskResult raw) async {
  return _sandboxProcessor.process(raw);  // 不直接传递给 UI
}
```

### 8.2 mDNS 发现规范

```dart
// 局域网发现只发现，不自动连接
// 用户必须主动点击"添加"才能建立连接
class MdnsDiscoveryService {
  Stream<DiscoveredAgent> discover() {
    return _mdns.lookup('_a2a._tcp.local')
      .map((record) => DiscoveredAgent.fromMdnsRecord(record))
      // 只暴露发现信息，连接由用户操作触发
      .where((agent) => !_isAlreadyConnected(agent.id));
  }

  // 不提供 autoConnect() 方法——发现和连接必须分离
}
```

---

## 9. Tool Bridge 编码规范

### 9.1 权限检查规范

```dart
// 权限检查必须在工具执行前进行，不可绕过
abstract class NativeTool {
  PermissionLevel get requiredPermissionLevel;
  String get toolName;
  String get toolDescription;

  Future<Result<ToolResult, ToolException>> execute(
    Map<String, dynamic> args,
    PermissionContext context,
  );
}

// 工具执行器：统一执行前检查
class ToolBridge {
  Future<Result<ToolResult, ToolException>> executeTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final tool = _registry.get(toolName);
    if (tool == null) return Result.failure(UnknownToolException(toolName));

    // L0：直接执行
    if (tool.requiredPermissionLevel == PermissionLevel.l0) {
      return tool.execute(args, PermissionContext.granted());
    }

    // L1：检查是否已授权
    final granted = await _permissionStore.isGranted(toolName);
    if (!granted) {
      // 请求授权（UI 层处理弹窗）
      final userDecision = await _permissionRequester.request(tool);
      if (!userDecision.granted) {
        return Result.failure(ToolPermissionDeniedException(toolName));
      }
      if (userDecision.rememberChoice) {
        await _permissionStore.grant(toolName);
      }
    }

    // L2/L3：每次都需要用户确认（通过 UI 层弹窗）
    if (tool.requiredPermissionLevel >= PermissionLevel.l2) {
      final preview = tool.buildPreview(args);
      final confirmed = await _confirmationDialog.show(preview);
      if (!confirmed) {
        return Result.failure(ToolActionCancelledException(toolName));
      }
    }

    return tool.execute(args, PermissionContext.granted());
  }
}
```

### 9.2 工具调用记录规范

```dart
// 每次工具调用必须记录，用于用户审查
class ToolCallRecord {
  final String toolName;
  final Map<String, dynamic> args;    // 脱敏处理后的参数
  final ToolCallStatus status;
  final DateTime timestamp;
  final String conversationId;

  // 注意：不记录工具调用结果（可能包含敏感数据，如联系人信息）
  // 只记录调用本身，结果由用户在对话中查看
}
```

---

## 10. 后台任务编码规范

### 10.1 任务注册规范

```dart
// 后台任务必须使用平台推荐的 API，不得使用自定义 Timer/Isolate 实现持续后台
// iOS: BGTaskScheduler，Android: WorkManager

// 任务标识符必须全局唯一，使用反向域名格式
class ScheduledTaskIds {
  static const String morningBriefing = 'com.app.tasks.morning_briefing';
  static const String locationReminder = 'com.app.tasks.location_reminder';
  // 新增任务时必须在此统一注册
}

// 后台任务执行时间不保证精确，不得依赖精确时间做金融类操作
// 任务执行结果必须记录日志（本地，脱敏）
class TaskExecutionLog {
  final String taskId;
  final DateTime scheduledTime;
  final DateTime actualExecutionTime;
  final TaskExecutionResult result;
  final int inferenceTimeMs;    // 轻量模型推理耗时
  final bool usedLocalModel;    // 必须记录，用于电量分析
}
```

### 10.2 轻量推理规范

```dart
// 后台任务推理必须使用本地轻量模型（< 4B 参数）
// 严禁后台任务向云端发起 LLM 请求（用户不知情时不发云端请求）
class BackgroundInferenceService {
  BackgroundInferenceService({required this.localModelService});

  // 明确类型：只允许本地模型
  final LocalModelService localModelService;

  Future<InferenceResult> decide(TaskContext context) async {
    // 不接受 LlmGateway（可能路由到云端），只接受 LocalModelService
    return localModelService.infer(
      prompt: _buildDecisionPrompt(context),
      maxTokens: 256,    // 后台推理限制输出长度
      timeout: const Duration(seconds: 10),
    );
  }
}
```

---

## 11. 生成式 UI 编码规范

### 11.1 Schema 解析规范

```dart
// 所有生成式 UI 数据来源（LLM 输出或 Skill 输出）都是不可信的
// 必须严格校验 Schema，不得对 dynamic 数据做隐式转换

abstract class UiSchemaParser<T extends UiCard> {
  /// 解析结果必须是 Result，不得抛出异常
  Result<T, SchemaParseException> parse(Map<String, dynamic> raw);
}

class TrainCardParser implements UiSchemaParser<TrainCard> {
  @override
  Result<TrainCard, SchemaParseException> parse(Map<String, dynamic> raw) {
    try {
      // 每个字段都必须显式提取和类型检查
      final departure = raw['departure'] as Map<String, dynamic>?;
      if (departure == null) {
        return Result.failure(MissingFieldException('departure'));
      }

      final departureTime = DateTime.tryParse(
        departure['time'] as String? ?? '',
      );
      if (departureTime == null) {
        return Result.failure(InvalidFieldException('departure.time'));
      }

      // 价格必须是数字，不能直接 as String
      final price = switch (raw['price']) {
        int p => p.toDouble(),
        double p => p,
        String s => double.tryParse(s),
        _ => null,
      };
      if (price == null) {
        return Result.failure(InvalidFieldException('price'));
      }

      return Result.success(TrainCard(
        departureTime: departureTime,
        price: price,
        // ... 其余字段
      ));
    } catch (e) {
      return Result.failure(SchemaParseException(raw: raw, cause: e));
    }
  }
}
```

### 11.2 卡片 Widget 规范

```dart
// 所有生成式 UI 卡片 Widget 必须：
// 1. 是 StatelessWidget（状态由 ViewModel 管理）
// 2. 接受强类型数据模型，不接受 Map<String, dynamic>
// 3. 所有用户操作通过回调传出，不在内部发起网络/数据库操作

class TrainCardWidget extends StatelessWidget {
  const TrainCardWidget({
    super.key,
    required this.card,
    required this.onAddToCalendar,    // ✅ 回调，不在内部实现
    required this.onBookTicket,
  });

  final TrainCard card;              // ✅ 强类型
  final VoidCallback onAddToCalendar;
  final VoidCallback onBookTicket;

  @override
  Widget build(BuildContext context) {
    // 只有 UI 代码
    return AppCard(
      typeLabel: '高铁信息',
      child: Column(
        children: [
          _buildRouteRow(),
          _buildInfoRow(),
          _buildActionRow(),
        ],
      ),
    );
  }
}
```

---

## 12. 测试规范

### 12.1 测试覆盖率要求

| 模块 | 最低行覆盖率 | 最低分支覆盖率 | 备注 |
|------|------------|--------------|------|
| `core/crypto` | **100%** | **100%** | 加密实现零容忍 |
| `core/keychain` | **100%** | **100%** | |
| `features/privacy` | **100%** | 95% | PII 检测 |
| `features/skill_sandbox` | 95% | 90% | |
| `features/llm_gateway` | 90% | 85% | |
| `features/tool_bridge` | 90% | 85% | |
| `features/a2a` | 90% | 85% | |
| `features/conversation` | 85% | 80% | |
| `shared/widgets` | 70% | — | Golden 测试补充 |
| `presentation` 层 | 70% | — | Widget 测试补充 |

### 12.2 单元测试规范

```dart
// 测试文件结构规范
void main() {
  // ✅ 使用 group 组织测试，group 名称 = 被测类/方法名
  group('LlmGateway', () {
    late MockKeychainService mockKeychain;
    late MockOpenAiProvider mockProvider;
    late LlmGateway gateway;

    // setUp 中创建 Mock，不在 test 内部
    setUp(() {
      mockKeychain = MockKeychainService();
      mockProvider = MockOpenAiProvider();
      gateway = LlmGateway(
        providers: [mockProvider],
        keychainService: mockKeychain,
      );
    });

    group('complete()', () {
      test('returns success when provider responds correctly', () async {
        // Arrange
        when(() => mockProvider.complete(any()))
          .thenAnswer((_) async => Result.success(fakeResponse));

        // Act
        final result = await gateway.complete(fakeRequest);

        // Assert
        expect(result, isA<Success<LlmResponse, LlmException>>());
        expect(result.value.content, equals(fakeResponse.content));
      });

      test('returns failure when API key is missing', () async {
        // Arrange
        when(() => mockKeychain.read(any()))
          .thenAnswer((_) async => null);  // Key 不存在

        // Act
        final result = await gateway.complete(fakeRequest);

        // Assert
        expect(result, isA<Failure<LlmResponse, LlmException>>());
        expect(result.failure, isA<ApiKeyNotFoundException>());
      });

      test('sanitizes PII before sending to cloud provider', () async {
        // Arrange
        final requestWithPii = LlmRequest(
          prompt: '我的手机号是 13812345678',
          provider: cloudProvider,
        );
        final capturedRequests = <LlmRequest>[];
        when(() => mockProvider.complete(captureAny()))
          .thenAnswer((inv) {
            capturedRequests.add(inv.positionalArguments[0] as LlmRequest);
            return Future.value(Result.success(fakeResponse));
          });

        // Act
        await gateway.complete(requestWithPii);

        // Assert：发出的请求不含原始手机号
        expect(capturedRequests.single.prompt, isNot(contains('13812345678')));
      });
    });
  });
}

// Mock 命名规范：Mock + 接口名
// 使用 mocktail 生成，不手写 Mock 实现
class MockKeychainService extends Mock implements KeychainService {}
class MockOpenAiProvider extends Mock implements LlmProvider {}
```

### 12.3 集成测试规范

```dart
// 集成测试使用真实的本地数据库（内存模式）和 Mock 网络
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationFlow Integration', () {
    late TestDatabase testDb;
    late MockLlmGateway mockGateway;
    late ProviderContainer container;

    setUp(() async {
      testDb = await TestDatabase.createInMemory();
      mockGateway = MockLlmGateway();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((_) => testDb),
          llmGatewayProvider.overrideWith((_) => mockGateway),
        ],
      );
    });

    tearDown(() async {
      await testDb.close();
      container.dispose();
    });

    testWidgets('sends message and displays response', (tester) async {
      // 构建完整的 Widget 树（不是孤立 Widget）
      await tester.pumpWidget(
        ProviderScope(
          parent: container,
          child: const AppRoot(),
        ),
      );

      // 模拟用户操作
      await tester.enterText(find.byType(MessageInputField), 'Hello');
      await tester.tap(find.byType(SendButton));
      await tester.pump();

      // 验证 loading 状态
      expect(find.byType(MessageLoadingIndicator), findsOneWidget);

      // 等待响应
      await tester.pumpAndSettle();

      // 验证消息显示
      expect(find.text('Hello'), findsOneWidget);  // 用户消息
      expect(find.text(fakeResponse.content), findsOneWidget);  // AI 响应
    });
  });
}
```

### 12.4 安全专项测试规范

```dart
// 安全测试独立放在 test/security/ 目录
// 这些测试必须在 CI 中强制通过，不允许跳过

void main() {
  group('Security Tests', () {

    group('API Key Isolation', () {
      test('API key never appears in application logs', () async {
        final logCapture = LogCaptureService();
        final keychain = MockKeychainService();
        when(() => keychain.read(any())).thenReturn(Future.value('sk-test-key-12345'));

        final gateway = LlmGateway(keychainService: keychain, ...);
        await gateway.complete(request);

        for (final logEntry in logCapture.entries) {
          expect(logEntry.message, isNot(contains('sk-test-key-12345')));
        }
      });

      test('API key is not stored in SharedPreferences', () async {
        final fakePrefs = FakeSharedPreferences();
        // 配置保存流程
        await configService.saveProvider(providerConfig);
        // 验证 SharedPreferences 中没有 Key
        for (final key in fakePrefs.keys) {
          expect(fakePrefs.getString(key), isNot(contains('sk-')));
        }
      });
    });

    group('Sandbox Isolation', () {
      test('skill cannot read files outside sandbox directory', () async {
        final sandbox = await createTestSandbox();
        final result = await sandbox.execute(
          scriptPath: 'escape_attempt.py',
          args: {'target': '/etc/hosts'},
        );
        expect(result.isFailure, isTrue);
        expect(result.failure, isA<SandboxSecurityException>());
      });

      test('skill execution is terminated after timeout', () async {
        final sandbox = await createTestSandbox();
        final stopwatch = Stopwatch()..start();
        await sandbox.execute(
          scriptPath: 'infinite_loop.py',
          args: {},
          timeout: const Duration(seconds: 3),
        );
        stopwatch.stop();
        // 允许 500ms 误差
        expect(stopwatch.elapsedMilliseconds, lessThan(3500));
      });
    });

    group('Encryption Correctness', () {
      test('decryption with wrong key fails with exception, not garbage data', () async {
        final crypto = CryptoServiceImpl();
        final ct = await crypto.encrypt(Uint8List.fromList([1,2,3]), correctKey);
        expect(
          () async => await crypto.decrypt(ct, wrongKey),
          throwsA(isA<DecryptionException>()),
        );
      });

      test('nonce is unique across 1000 encryptions', () async {
        final crypto = CryptoServiceImpl();
        final nonces = <String>{};
        for (int i = 0; i < 1000; i++) {
          final ct = await crypto.encrypt(plaintext, key);
          final nonce = base64.encode(ct.sublist(0, 12));
          expect(nonces.add(nonce), isTrue, reason: 'Nonce collision at $i');
        }
      });
    });

    group('PII Detection', () {
      test('detects Chinese phone numbers', () async {
        final detector = PiiDetector();
        final result = await detector.detect('联系我 13812345678');
        expect(result.hasPii, isTrue);
        expect(result.sanitized, isNot(contains('13812345678')));
      });

      test('detects API keys in user input', () async {
        final detector = PiiDetector();
        final result = await detector.detect('我的 key 是 sk-ant-api01-abcdef');
        expect(result.hasPii, isTrue);
      });
    });
  });
}
```

### 12.5 性能基准测试规范

```dart
// 性能基准测试放在 test/performance/
// 基准值来源：PRD 5.1 性能要求

void main() {
  group('Performance Benchmarks', () {
    test('app cold start completes within 2 seconds', () async {
      final stopwatch = Stopwatch()..start();
      await AppInitializer().initialize();
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
        reason: 'Cold start exceeded 2s SLA');
    });

    test('SQLite conversation list query under 100ms for 1000 records', () async {
      await _seedDatabase(1000);
      final stopwatch = Stopwatch()..start();
      await conversationRepository.getAll(limit: 50);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('local OCR completes within 1 second for standard image', () async {
      final testImage = await _loadTestImage('menu_photo.jpg');
      final stopwatch = Stopwatch()..start();
      await ocrService.extract(testImage);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
        reason: 'OCR exceeded 1s SLA');
    });
  });
}
```

### 12.6 Golden 测试规范

```dart
// 生成式 UI 卡片必须有 Golden 测试，防止视觉回归
void main() {
  testWidgets('TrainCardWidget golden test - standard state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TrainCardWidget(
            card: TrainCard.testFixture(),
            onAddToCalendar: () {},
            onBookTicket: () {},
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TrainCardWidget),
      matchesGoldenFile('golden/train_card_standard.png'),
    );
  });

  testWidgets('TrainCardWidget golden test - delayed state', (tester) async {
    // 延误态的视觉必须经过 Golden 验证
    await tester.pumpWidget(/* ... delayed train ... */);
    await expectLater(
      find.byType(TrainCardWidget),
      matchesGoldenFile('golden/train_card_delayed.png'),
    );
  });
}
```

---

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

## 15. 可验证机制：代码审查协议

### 15.1 Coding Agent 自检清单

**每次生成代码后，Coding Agent 必须按以下清单自检，并在 PR 描述中附上自检结果：**

```markdown
## Coding Agent 自检报告

### 基本检查
- [ ] 已运行 `dart tool/verify.dart`，全部通过
- [ ] 新增代码有对应的单元测试
- [ ] 新增功能有对应的 API 文档注释

### 安全检查（高风险模块必填）
- [ ] 无硬编码 API Key 或密码
- [ ] API Key 操作通过 KeychainService（如涉及）
- [ ] 所有日志经过脱敏处理（如涉及新增日志）
- [ ] 用户输入已做 PII 检测（如涉及发云端 LLM）
- [ ] SQL 查询使用参数化（如涉及数据库查询）
- [ ] 所有 HTTP 请求使用 HTTPS（如涉及网络请求）
- [ ] Skill 沙箱已设置资源上限（如涉及 Skill 执行）

### 隐私检查
- [ ] 位置数据仅在内存中使用，未持久化（如涉及位置）
- [ ] 联系人数据发云端前已脱敏（如涉及联系人）
- [ ] 本地数据走加密存储（如涉及新增持久化字段）

### 性能检查
- [ ] 大列表使用 ListView.builder
- [ ] 耗时操作移入 isolate（> 16ms 的同步操作）
- [ ] 已设置新增网络请求的超时时间

### 跨平台检查
- [ ] 代码在 iOS/Android/macOS/Windows 均可编译
- [ ] Platform-specific 代码通过抽象接口隔离
- [ ] 已在最低系统版本（iOS 16, Android 10）上验证 API 可用性
```

### 15.2 必须触发人工审查的场景

以下任何改动，必须在 CI 通过后附加人工代码审查，不得仅凭 Coding Agent 生成后直接合并：

| 改动类型 | 审查重点 |
|----------|----------|
| `core/crypto/` 任何修改 | 加密算法正确性、nonce 唯一性、AAD 正确使用 |
| `core/keychain/` 任何修改 | 是否真正使用 OS 安全存储，无降级路径 |
| Skill 沙箱核心逻辑修改 | 沙箱逃逸可能性、资源限制完整性 |
| A2A 认证逻辑修改 | TLS 验证未被绕过、OAuth 流程正确 |
| 数据库 Schema 变更 | Migration up/down 完整性、无数据丢失风险 |
| Tool Bridge 权限逻辑修改 | 权限级别分类正确、无权限绕过路径 |
| GitHub Gist 同步加密逻辑 | 端对端加密未被破坏、passphrase 不上传 |
| 新增外部网络请求目标 | 是否符合隐私承诺、是否需要用户知情 |

### 15.3 PR 描述模板

```markdown
## 变更描述
<!-- 一句话说明这个 PR 做了什么 -->

## 关联 PRD 章节
<!-- 例如：PRD 4.5.3 沙箱运行环境 -->

## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 安全加固
- [ ] 性能优化
- [ ] 重构
- [ ] 测试

## 涉及的高风险维度
- [ ] 加密/密钥管理
- [ ] 隐私数据处理
- [ ] 沙箱安全
- [ ] 跨平台兼容

## Coding Agent 自检报告
<!-- 粘贴第15.1节自检清单结果 -->

## 测试说明
<!-- 新增了哪些测试，如何在本地验证 -->

## 截图/录屏（如涉及 UI 变更）
```

---

## 16. Coding Agent 行为约束

### 16.1 强制性行为规则

以下规则对 Coding Agent 无条件适用，不接受"功能紧急"等理由豁免：

**规则 1：安全检查先于功能实现**
在实现任何涉及数据存储、网络请求、用户输入的功能时，必须先确认安全方案，再写功能代码。顺序不可颠倒。

**规则 2：不生成测试无法覆盖的代码**
所有新增代码必须是可测试的。如果发现某段逻辑难以单元测试，说明设计有问题（通常是职责不清晰），必须先重构再实现。

**规则 3：不使用未在 analysis_options.yaml 豁免的 lint 规则**
如需豁免某条 lint 规则，必须在代码旁用注释说明原因，并同步更新 `analysis_options.yaml`：

```dart
// ignore: avoid_dynamic_calls
// 原因：此处处理来自 QuickJS 沙箱的动态返回值，
// 已在上层做了类型校验（见 SkillResultParser）
final value = result[key];
```

**规则 4：不跨层直接调用**
Coding Agent 在生成代码时，必须维护 presentation → domain → data 的调用方向，发现需要跨层时，先定义中间接口，再实现。

**规则 5：变更加密相关代码必须同时更新对应测试**
加密、密钥、沙箱相关代码的测试是项目的安全底线，不允许"先改代码，后补测试"。必须同一个 commit 包含代码和测试。

**规则 6：不自行决定降低安全级别**
如 PRD 要求"云端处理前必须 PII 检测"，Coding Agent 不得以"开发阶段先跳过"为由省略此步骤。如有争议，通过 Issue 讨论，不在代码中偷偷绕过。

**规则 7：发现规范冲突时暂停并上报**
如果在实现过程中发现本规范与 PRD 或 UI/UX 规范存在矛盾，Coding Agent 应停止实现，在当前 PR 或 Issue 中记录冲突，等待人工决策，不得自行解决矛盾。

### 16.2 Coding Agent 工作流程

```
收到任务
    │
    ▼
1. 识别任务所属模块和风险维度
   （对照第4-11章确认适用规范）
    │
    ▼
2. 确认测试策略
   （先想好怎么测，再写实现）
    │
    ▼
3. 实现代码
   （遵循本规范）
    │
    ▼
4. 编写配套测试
   （同一 commit）
    │
    ▼
5. 运行本地验证
   dart tool/verify.dart
    │
    ├── 失败 → 修复问题，回到步骤3
    │
    └── 通过 ▼
    │
6. 填写 PR 自检清单（第15.1节）
    │
    ▼
7. 提交 PR，等待 CI
    │
    ├── CI 失败 → 查看失败原因，回到步骤3
    │
    └── CI 通过 ▼
    │
8. 判断是否需要人工审查（第15.2节）
    │
    ├── 需要 → 等待审查
    └── 不需要 → 可合并
```

---

*本规范随项目迭代持续更新。所有规范变更需在 PR 中同步更新 `AGENTS.md` 的受影响章节摘要。*

*当前版本覆盖 PRD Phase 1 + Phase 2 所需的全部技术模块。*
