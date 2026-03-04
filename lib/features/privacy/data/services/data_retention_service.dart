import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/storage/config/app_preferences_store.dart';

class DataRetentionResult {
	const DataRetentionResult({
		required this.deletedConversations,
		required this.deletedMessages,
	});

	final int deletedConversations;
	final int deletedMessages;
}

class DataRetentionService {
	DataRetentionService({
		required SqlCipherDatabase database,
		required AppPreferencesStore preferencesStore,
		AppLogger? logger,
	})	: _database = database,
		_preferencesStore = preferencesStore,
		_logger = logger;

	static const String retentionDaysKey = 'privacy.retention_days';
	static const int defaultRetentionDays = 90;

	final SqlCipherDatabase _database;
	final AppPreferencesStore _preferencesStore;
	final AppLogger? _logger;

	Future<int> getRetentionDays() async {
		final raw = await _preferencesStore.readString(retentionDaysKey);
		if (raw == null) return defaultRetentionDays;
		return int.tryParse(raw) ?? defaultRetentionDays;
	}

	Future<void> setRetentionDays(int days) async {
		await _preferencesStore.saveString(retentionDaysKey, days.toString());
	}

	Future<DataRetentionResult> runCleanup() async {
		final days = await getRetentionDays();
		final cutoff =
				DateTime.now().millisecondsSinceEpoch - days * 86400000;

		final db = await _database.open();

		// Count conversations to be deleted for reporting.
		final countResult = await db.rawQuery(
			'SELECT COUNT(*) AS cnt FROM conversations WHERE updated_at < ?',
			[cutoff],
		);
		final deletedConversations =
				(countResult.first['cnt'] as int?) ?? 0;

		// Count messages in those conversations before cascade-deleting.
		final msgCountResult = await db.rawQuery(
			'SELECT COUNT(*) AS cnt FROM messages WHERE conversation_id IN '
			'(SELECT id FROM conversations WHERE updated_at < ?)',
			[cutoff],
		);
		final deletedMessages = (msgCountResult.first['cnt'] as int?) ?? 0;

		// Hard-delete; messages cascade via foreign key.
		await db.delete(
			'conversations',
			where: 'updated_at < ?',
			whereArgs: [cutoff],
		);

		_logger?.info(
			'Data retention cleanup complete',
			context: {
				'retentionDays': days,
				'deletedConversations': deletedConversations,
				'deletedMessages': deletedMessages,
			},
		);

		return DataRetentionResult(
			deletedConversations: deletedConversations,
			deletedMessages: deletedMessages,
		);
	}
}

final dataRetentionServiceProvider = Provider<DataRetentionService>((ref) {
	throw UnimplementedError(
		'dataRetentionServiceProvider requires AppPreferencesStore — '
		'override this provider in the app ProviderScope.',
	);
});
