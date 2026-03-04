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

