import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ConversationDao {
	ConversationDao(this._database);

	final SqlCipherDatabase _database;

	Future<void> upsert(ConversationEntity entity) async {
		final db = await _database.open();
		await db.insert(
			'conversations',
			entity.toMap(),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<ConversationEntity?> findById(String id) async {
		final db = await _database.open();
		final rows = await db.query(
			'conversations',
			where: 'id = ? AND deleted_at IS NULL',
			whereArgs: [id],
			limit: 1,
		);
		if (rows.isEmpty) {
			return null;
		}
		return ConversationEntity.fromMap(rows.first);
	}

	Future<List<ConversationEntity>> list({
		int page = 0,
		int pageSize = 20,
	}) async {
		final db = await _database.open();
		final rows = await db.query(
			'conversations',
			where: 'deleted_at IS NULL',
			orderBy: 'updated_at DESC',
			limit: pageSize,
			offset: page * pageSize,
		);

		return rows.map(ConversationEntity.fromMap).toList();
	}

	Future<void> softDelete(String id, {DateTime? deletedAt}) async {
		final db = await _database.open();
		final now = (deletedAt ?? DateTime.now()).millisecondsSinceEpoch;
		await db.update(
			'conversations',
			{
				'deleted_at': now,
				'updated_at': now,
			},
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	Future<void> hardDelete(String id) async {
		final db = await _database.open();
		await db.delete(
			'conversations',
			where: 'id = ?',
			whereArgs: [id],
		);
	}
}

final conversationDaoProvider = Provider<ConversationDao>((ref) {
	final db = ref.watch(sqlCipherDatabaseProvider);
	return ConversationDao(db);
});