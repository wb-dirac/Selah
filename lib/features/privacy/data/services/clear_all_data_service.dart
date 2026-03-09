import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';
import 'package:personal_ai_assistant/storage/config/app_preferences_store.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class ClearAllDataService {
	ClearAllDataService({
		required SqlCipherDatabase database,
		required AppPreferencesStore preferencesStore,
		AppLogger? logger,
	})	: _database = database,
		_preferencesStore = preferencesStore,
		_logger = logger;

	final SqlCipherDatabase _database;
	final AppPreferencesStore _preferencesStore;
	final AppLogger? _logger;

	Future<void> clearAll() async {
		final db = await _database.open();

		await db.delete('messages');
		await db.delete('conversations');
		await db.delete('token_usage_records');
		await db.delete('document_fragments');

		await _preferencesStore.clearAll();

		_logger?.info('All local data cleared');
	}
}

final clearAllDataServiceProvider = Provider<ClearAllDataService>((ref) {
	return ClearAllDataService(
		database: ref.watch(sqlCipherDatabaseProvider),
		preferencesStore: ref.watch(keychainPreferencesStoreProvider),
		logger: ref.watch(sanitizedLoggerProvider),
	);
});
