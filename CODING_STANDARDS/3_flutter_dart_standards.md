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

