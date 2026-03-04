import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/message_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MessageDao {
	MessageDao(this._database);

	final SqlCipherDatabase _database;

	Future<void> upsert(MessageEntity entity) async {
		final db = await _database.open();
		await db.insert(
			'messages',
			entity.toMap(),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<MessageEntity?> findById(String id) async {
		final db = await _database.open();
		final rows = await db.query(
			'messages',
			where: 'id = ? AND deleted_at IS NULL',
			whereArgs: [id],
			limit: 1,
		);
		if (rows.isEmpty) {
			return null;
		}
		return MessageEntity.fromMap(rows.first);
	}

	Future<List<MessageEntity>> listByConversation(
		String conversationId, {
		int page = 0,
		int pageSize = 50,
	}) async {
		final db = await _database.open();
		final rows = await db.query(
			'messages',
			where: 'conversation_id = ? AND deleted_at IS NULL',
			whereArgs: [conversationId],
			orderBy: 'created_at DESC',
			limit: pageSize,
			offset: page * pageSize,
		);

		return rows.map(MessageEntity.fromMap).toList();
	}

	Future<void> softDelete(String id, {DateTime? deletedAt}) async {
		final db = await _database.open();
		final now = (deletedAt ?? DateTime.now()).millisecondsSinceEpoch;
		await db.update(
			'messages',
			{
				'deleted_at': now,
			},
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	Future<void> hardDelete(String id) async {
		final db = await _database.open();
		await db.delete(
			'messages',
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	Future<void> deleteByConversation(String conversationId) async {
		final db = await _database.open();
		await db.delete(
			'messages',
			where: 'conversation_id = ?',
			whereArgs: [conversationId],
		);
	}
}

final messageDaoProvider = Provider<MessageDao>((ref) {
	final db = ref.watch(sqlCipherDatabaseProvider);
	return MessageDao(db);
});