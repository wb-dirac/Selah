import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ConversationDao {
	ConversationDao(this._database);

	final SqlCipherDatabase _database;

	/// Upserts a conversation row without triggering CASCADE DELETE.
	///
	/// Using `INSERT OR REPLACE` (ConflictAlgorithm.replace) physically DELETEs
	/// the old row before re-inserting, which fires `ON DELETE CASCADE` and wipes
	/// all messages for that conversation.  Instead, we try an UPDATE first and
	/// fall back to a plain INSERT for truly new rows.
	Future<void> upsert(ConversationEntity entity) async {
		final db = await _database.open();
		final affected = await db.update(
			'conversations',
			entity.toMap(),
			where: 'id = ?',
			whereArgs: [entity.id],
		);
		if (affected == 0) {
			// Row does not exist yet — insert it.
			await db.insert(
				'conversations',
				entity.toMap(),
				conflictAlgorithm: ConflictAlgorithm.ignore,
			);
		}
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