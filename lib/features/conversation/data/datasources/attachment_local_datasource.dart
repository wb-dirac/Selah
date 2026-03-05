import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/attachment_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class AttachmentDao {
  AttachmentDao(this._database);

  final SqlCipherDatabase _database;

  Future<void> upsert(AttachmentEntity entity) async {
    final db = await _database.open();
    await db.insert(
      'message_attachments',
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AttachmentEntity?> findById(String id) async {
    final db = await _database.open();
    final rows = await db.query(
      'message_attachments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttachmentEntity.fromMap(rows.first);
  }

  /// Returns all attachments for a given message, ordered by creation time.
  Future<List<AttachmentEntity>> listByMessage(String messageId) async {
    final db = await _database.open();
    final rows = await db.query(
      'message_attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'created_at ASC',
    );
    return rows.map(AttachmentEntity.fromMap).toList();
  }

  /// Returns all attachments for multiple messages in a single query.
  /// Useful for batch-loading attachments when displaying a conversation.
  Future<Map<String, List<AttachmentEntity>>> listByMessages(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};

    final db = await _database.open();
    final placeholders = List.filled(messageIds.length, '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT * FROM message_attachments '
      'WHERE message_id IN ($placeholders) '
      'ORDER BY created_at ASC',
      messageIds,
    );

    final result = <String, List<AttachmentEntity>>{};
    for (final row in rows) {
      final entity = AttachmentEntity.fromMap(row);
      result.putIfAbsent(entity.messageId, () => []);
      result[entity.messageId]!.add(entity);
    }
    return result;
  }

  Future<void> delete(String id) async {
    final db = await _database.open();
    await db.delete('message_attachments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByMessage(String messageId) async {
    final db = await _database.open();
    await db.delete(
      'message_attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }
}

final attachmentDaoProvider = Provider<AttachmentDao>((ref) {
  final db = ref.watch(sqlCipherDatabaseProvider);
  return AttachmentDao(db);
});
