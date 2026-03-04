import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/data_retention_service.dart';
import 'package:personal_ai_assistant/storage/config/app_preferences_store.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// In-memory KeychainService that returns a fixed password.
class _FakeKeychainService implements KeychainService {
	final Map<String, String> _keychainStore = {};

	@override
	Future<void> write({required String key, required String value}) async {
		_keychainStore[key] = value;
	}

	@override
	Future<String?> read({required String key}) async => _keychainStore[key];

	@override
	Future<void> delete({required String key}) async => _keychainStore.remove(key);

	@override
	Future<void> deleteAll() async => _keychainStore.clear();
}

/// SqlCipherDatabase backed by an in-memory sqflite database.
class _InMemorySqlCipherDatabase extends SqlCipherDatabase {
	_InMemorySqlCipherDatabase() : super(_FakeKeychainService());

	Database? _memDb;

	@override
	Future<Database> open() async {
		if (_memDb != null) return _memDb!;
		_memDb = await openDatabase(
			':memory:',
			version: 3,
			onCreate: (db, _) async {
				await db.execute('''
CREATE TABLE conversations (
	id TEXT PRIMARY KEY,
	title TEXT,
	created_at INTEGER NOT NULL,
	updated_at INTEGER NOT NULL,
	deleted_at INTEGER
);
''');
				await db.execute('''
CREATE TABLE messages (
	id TEXT PRIMARY KEY,
	conversation_id TEXT NOT NULL,
	role TEXT NOT NULL,
	content TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	deleted_at INTEGER,
	FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);
''');
				await db.execute('''
CREATE TABLE token_usage_records (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	provider_id TEXT NOT NULL,
	model_id TEXT NOT NULL,
	prompt_tokens INTEGER NOT NULL,
	completion_tokens INTEGER NOT NULL,
	created_at INTEGER NOT NULL
);
''');
				await db.execute('''
CREATE TABLE document_fragments (
	id TEXT PRIMARY KEY,
	source_id TEXT NOT NULL,
	chunk_index INTEGER NOT NULL,
	content TEXT NOT NULL,
	embedding TEXT,
	created_at INTEGER NOT NULL
);
''');
			},
		);
		return _memDb!;
	}

	@override
	Future<void> close() async {
		await _memDb?.close();
		_memDb = null;
	}
}

class _FakePreferencesStore implements AppPreferencesStore {
	final Map<String, String> _preferences = {};

	@override
	Future<void> saveString(String key, String value) async {
		_preferences[key] = value;
	}

	@override
	Future<String?> readString(String key) async => _preferences[key];

	@override
	Future<void> clearAll() async => _preferences.clear();
}

const _msPerDay = 86400000;

void main() {
	late _InMemorySqlCipherDatabase db;
	late _FakePreferencesStore prefs;
	late DataRetentionService service;

	setUp(() async {
		db = _InMemorySqlCipherDatabase();
		prefs = _FakePreferencesStore();
		service = DataRetentionService(database: db, preferencesStore: prefs);
		// Seed with foreign-key pragma support enabled.
		final conn = await db.open();
		await conn.execute('PRAGMA foreign_keys = ON;');
	});

	tearDown(() async {
		await db.close();
	});

	test('default retention days is 90', () async {
		expect(await service.getRetentionDays(), equals(90));
	});

	test('setRetentionDays persists value', () async {
		await service.setRetentionDays(30);
		expect(await service.getRetentionDays(), equals(30));
	});

	test('runCleanup deletes conversations older than retention period', () async {
		final conn = await db.open();
		final now = DateTime.now().millisecondsSinceEpoch;
		final ninetyOneDaysAgo = now - 91 * _msPerDay;
		final oneDayAgo = now - _msPerDay;

		await conn.insert('conversations', {
			'id': 'old-conv',
			'title': 'Old',
			'created_at': ninetyOneDaysAgo,
			'updated_at': ninetyOneDaysAgo,
		});
		await conn.insert('conversations', {
			'id': 'new-conv',
			'title': 'New',
			'created_at': oneDayAgo,
			'updated_at': oneDayAgo,
		});

		final result = await service.runCleanup();

		expect(result.deletedConversations, equals(1));

		final remaining = await conn.query('conversations');
		expect(remaining.length, equals(1));
		expect(remaining.first['id'], equals('new-conv'));
	});

	test('runCleanup cascades to messages', () async {
		final conn = await db.open();
		final now = DateTime.now().millisecondsSinceEpoch;
		final oldTs = now - 100 * _msPerDay;

		await conn.insert('conversations', {
			'id': 'old-conv',
			'title': 'Old',
			'created_at': oldTs,
			'updated_at': oldTs,
		});
		await conn.insert('messages', {
			'id': 'msg-1',
			'conversation_id': 'old-conv',
			'role': 'user',
			'content': 'hi',
			'created_at': oldTs,
		});

		final result = await service.runCleanup();

		expect(result.deletedMessages, equals(1));
		final msgs = await conn.query('messages');
		expect(msgs, isEmpty);
	});

	test('runCleanup respects custom retention days', () async {
		await service.setRetentionDays(30);
		final conn = await db.open();
		final now = DateTime.now().millisecondsSinceEpoch;
		final thirtyOneDaysAgo = now - 31 * _msPerDay;
		final twentyDaysAgo = now - 20 * _msPerDay;

		await conn.insert('conversations', {
			'id': 'old-conv',
			'title': 'Old',
			'created_at': thirtyOneDaysAgo,
			'updated_at': thirtyOneDaysAgo,
		});
		await conn.insert('conversations', {
			'id': 'new-conv',
			'title': 'New',
			'created_at': twentyDaysAgo,
			'updated_at': twentyDaysAgo,
		});

		final result = await service.runCleanup();

		expect(result.deletedConversations, equals(1));
		final remaining = await conn.query('conversations');
		expect(remaining.first['id'], equals('new-conv'));
	});

	test('runCleanup returns zero counts when nothing to delete', () async {
		final result = await service.runCleanup();
		expect(result.deletedConversations, equals(0));
		expect(result.deletedMessages, equals(0));
	});
}
