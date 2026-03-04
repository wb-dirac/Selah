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

