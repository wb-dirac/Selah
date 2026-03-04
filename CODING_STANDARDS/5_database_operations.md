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

