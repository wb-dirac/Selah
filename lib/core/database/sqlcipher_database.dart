import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/keychain/flutter_secure_keychain_service.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const String _databaseName = 'personal_ai_assistant.db';
const String _databaseSecretKeyName = 'storage.sqlcipher.database_key';
const int _databaseVersion = 6;

class SqlCipherDatabase {
  SqlCipherDatabase(this._keychainService);

  final KeychainService _keychainService;
  Database? _database;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = '$databasePath/$_databaseName';
    final password = await _getOrCreateDatabasePassword();

    final database = await openDatabase(
      path,
      password: password,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
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
	parent_message_id TEXT,
	FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);
''');

        await db.execute(
          'CREATE INDEX idx_conversations_updated_at ON conversations(updated_at);',
        );
        await db.execute(
          'CREATE INDEX idx_messages_conversation_created_at ON messages(conversation_id, created_at);',
        );
        await db.execute(
          'CREATE INDEX idx_messages_parent_message_id ON messages(parent_message_id);',
        );

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
        await db.execute(
          'CREATE INDEX idx_token_usage_provider_created_at ON token_usage_records(provider_id, created_at);',
        );

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
        await db.execute(
          'CREATE INDEX idx_document_fragments_source_id ON document_fragments(source_id);',
        );

        await db.execute('''
CREATE TABLE message_attachments (
	id TEXT PRIMARY KEY,
	message_id TEXT NOT NULL,
	type TEXT NOT NULL,
	file_path TEXT NOT NULL,
	mime_type TEXT,
	thumbnail_path TEXT,
	width INTEGER,
	height INTEGER,
	size_bytes INTEGER,
	created_at INTEGER NOT NULL,
	FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
);
''');
        await db.execute(
          'CREATE INDEX idx_message_attachments_message_id ON message_attachments(message_id);',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS token_usage_records (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	provider_id TEXT NOT NULL,
	model_id TEXT NOT NULL,
	prompt_tokens INTEGER NOT NULL,
	completion_tokens INTEGER NOT NULL,
	created_at INTEGER NOT NULL
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_token_usage_provider_created_at ON token_usage_records(provider_id, created_at);',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS document_fragments (
	id TEXT PRIMARY KEY,
	source_id TEXT NOT NULL,
	chunk_index INTEGER NOT NULL,
	content TEXT NOT NULL,
	embedding TEXT,
	created_at INTEGER NOT NULL
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_document_fragments_source_id ON document_fragments(source_id);',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN parent_message_id TEXT;',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_parent_message_id ON messages(parent_message_id);',
          );
        }
        if (oldVersion < 5) {
          await db.execute('''
CREATE TABLE IF NOT EXISTS message_attachments (
	id TEXT PRIMARY KEY,
	message_id TEXT NOT NULL,
	type TEXT NOT NULL,
	file_path TEXT NOT NULL,
	mime_type TEXT,
	thumbnail_path TEXT,
	width INTEGER,
	height INTEGER,
	size_bytes INTEGER,
	created_at INTEGER NOT NULL,
	FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
);
''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_message_attachments_message_id ON message_attachments(message_id);',
          );
        }
        if (oldVersion < 6) {
          // Rebuild messages table to remove any legacy unexpected constraints
          // (for example, accidental uniqueness on conversation_id) that can
          // silently collapse history to one row when using inserts.
          await db.execute('PRAGMA foreign_keys = OFF;');
          await db.transaction((txn) async {
            await txn.execute('ALTER TABLE messages RENAME TO messages_old;');
            await txn.execute('''
CREATE TABLE messages (
	id TEXT PRIMARY KEY,
	conversation_id TEXT NOT NULL,
	role TEXT NOT NULL,
	content TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	deleted_at INTEGER,
	parent_message_id TEXT,
	FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);
''');
            await txn.execute('''
INSERT INTO messages (
	id,
	conversation_id,
	role,
	content,
	created_at,
	deleted_at,
	parent_message_id
)
SELECT
	id,
	conversation_id,
	role,
	content,
	created_at,
	deleted_at,
	parent_message_id
FROM messages_old;
''');
            await txn.execute('DROP TABLE messages_old;');
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at ON messages(conversation_id, created_at);',
            );
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_messages_parent_message_id ON messages(parent_message_id);',
            );
          });
          await db.execute('PRAGMA foreign_keys = ON;');
        }
      },
    );

    await _ensureMessagesSchemaHealthy(database);

    _database = database;
    return database;
  }

  Future<void> _ensureMessagesSchemaHealthy(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(messages);');
    if (tableInfo.isEmpty) {
      return;
    }

    final hasIdPrimaryKey = tableInfo.any(
      (row) => row['name'] == 'id' && (row['pk'] as int? ?? 0) == 1,
    );
    final hasConversationId = tableInfo.any(
      (row) => row['name'] == 'conversation_id',
    );
    final hasUnexpectedPrimaryKey = tableInfo.any(
      (row) => (row['pk'] as int? ?? 0) > 0 && row['name'] != 'id',
    );

    final indexList = await db.rawQuery('PRAGMA index_list(messages);');
    var hasUniqueConversationIndex = false;
    for (final index in indexList) {
      final isUnique = (index['unique'] as int? ?? 0) == 1;
      if (!isUnique) continue;
      final indexName = (index['name'] ?? '').toString();
      if (indexName.isEmpty) continue;
      final indexInfo = await db.rawQuery('PRAGMA index_info($indexName);');
      final includesConversationId = indexInfo.any(
        (row) => row['name'] == 'conversation_id',
      );
      if (includesConversationId) {
        hasUniqueConversationIndex = true;
        break;
      }
    }

    final healthy =
        hasIdPrimaryKey &&
        hasConversationId &&
        !hasUnexpectedPrimaryKey &&
        !hasUniqueConversationIndex;

    if (healthy) {
      return;
    }

    developer.log(
      '[SqlCipherDatabase] messages schema unhealthy; rebuilding. '
      'hasIdPrimaryKey=$hasIdPrimaryKey, hasConversationId=$hasConversationId, '
      'hasUnexpectedPrimaryKey=$hasUnexpectedPrimaryKey, '
      'hasUniqueConversationIndex=$hasUniqueConversationIndex',
      name: 'SqlCipherDatabase',
    );

    await db.execute('PRAGMA foreign_keys = OFF;');
    try {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE messages RENAME TO messages_broken;');
        await txn.execute('''
CREATE TABLE messages (
	id TEXT PRIMARY KEY,
	conversation_id TEXT NOT NULL,
	role TEXT NOT NULL,
	content TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	deleted_at INTEGER,
	parent_message_id TEXT,
	FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);
''');
        await txn.execute('''
INSERT INTO messages (
	id,
	conversation_id,
	role,
	content,
	created_at,
	deleted_at,
	parent_message_id
)
SELECT
	id,
	conversation_id,
	role,
	content,
	created_at,
	deleted_at,
	parent_message_id
FROM messages_broken;
''');
        await txn.execute('DROP TABLE messages_broken;');
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at ON messages(conversation_id, created_at);',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_messages_parent_message_id ON messages(parent_message_id);',
        );
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) {
      return;
    }
    await database.close();
    _database = null;
  }

  Future<String> _getOrCreateDatabasePassword() async {
    final existing = await _keychainService.read(key: _databaseSecretKeyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _generateSecret();
    await _keychainService.write(key: _databaseSecretKeyName, value: created);
    return created;
  }

  String _generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

final sqlCipherDatabaseProvider = Provider<SqlCipherDatabase>((ref) {
  final keychainService = ref.watch(keychainServiceProvider);
  return SqlCipherDatabase(keychainService);
});
