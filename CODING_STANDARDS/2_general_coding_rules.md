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

