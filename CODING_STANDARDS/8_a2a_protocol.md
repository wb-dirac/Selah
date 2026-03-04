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

