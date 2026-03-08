import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/keychain/flutter_secure_keychain_service.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const String _databaseName = 'personal_ai_assistant.db';
const String _databaseSecretKeyName = 'storage.sqlcipher.database_key';
const int _databaseVersion = 1;

class SqlCipherDatabase {
  SqlCipherDatabase(this._keychainService);

  final KeychainService _keychainService;
  Database? _database;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    // Force delete existing database to ensure clean start
    final databasePath = await getDatabasesPath();
    final path = '$databasePath/$_databaseName';
    await deleteDatabase(path);

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
        // No migrations - we'll delete and recreate instead
        await db.close();
        final databasePath = await getDatabasesPath();
        final path = '$databasePath/$_databaseName';
        await deleteDatabase(path);
        // The next call to open() will trigger onCreate
      },
    );

    _database = database;
    return database;
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
