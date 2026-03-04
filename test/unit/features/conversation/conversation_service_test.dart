import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/conversation_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/message_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/message_model.dart';
import 'package:personal_ai_assistant/features/conversation/domain/conversation_service.dart';

// ---------------------------------------------------------------------------
// Minimal stubs
// ---------------------------------------------------------------------------

class _NullKeychain implements KeychainService {
	@override
	Future<void> delete({required String key}) async {}
	@override
	Future<void> deleteAll() async {}
	@override
	Future<String?> read({required String key}) async => null;
	@override
	Future<void> write({required String key, required String value}) async {}
}

SqlCipherDatabase _fakeDb() => SqlCipherDatabase(_NullKeychain());

// ---------------------------------------------------------------------------

class _FakeConversationDao extends ConversationDao {
	_FakeConversationDao() : super(_fakeDb());

	final Map<String, ConversationEntity> _store = {};

	@override
	Future<void> upsert(ConversationEntity entity) async {
		_store[entity.id] = entity;
	}

	@override
	Future<ConversationEntity?> findById(String id) async => _store[id];

	@override
	Future<List<ConversationEntity>> list({
		int page = 0,
		int pageSize = 20,
	}) async {
		final all = _store.values
				.where((c) => c.deletedAt == null)
				.toList()
			..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
		final offset = page * pageSize;
		if (offset >= all.length) return [];
		return all.sublist(offset, (offset + pageSize).clamp(0, all.length));
	}
}

class _FakeMessageDao extends MessageDao {
	_FakeMessageDao() : super(_fakeDb());

	final Map<String, List<MessageEntity>> _store = {};

	@override
	Future<void> upsert(MessageEntity entity) async {
		_store.putIfAbsent(entity.conversationId, () => []).add(entity);
	}

	@override
	Future<List<MessageEntity>> listByConversation(
		String conversationId, {
		int page = 0,
		int pageSize = 50,
	}) async {
		final all = (_store[conversationId] ?? [])
				.where((m) => m.deletedAt == null)
				.toList()
			..sort((a, b) => b.createdAt.compareTo(a.createdAt));
		final offset = page * pageSize;
		if (offset >= all.length) return [];
		return all.sublist(offset, (offset + pageSize).clamp(0, all.length));
	}
}

// ---------------------------------------------------------------------------

ConversationService _makeService() {
	return ConversationService(
		conversationDao: _FakeConversationDao(),
		messageDao: _FakeMessageDao(),
		database: _fakeDb(),
	);
}

void main() {
	group('ConversationService', () {
		test('getOrCreateActiveConversation creates one when none exist', () async {
			final svc = _makeService();
			final conv = await svc.getOrCreateActiveConversation();
			expect(conv.id, isNotEmpty);
			expect(conv.title, isNull);
		});

		test('getOrCreateActiveConversation returns existing conversation', () async {
			final svc = _makeService();
			final first = await svc.getOrCreateActiveConversation();
			final second = await svc.getOrCreateActiveConversation();
			expect(second.id, equals(first.id));
		});

		test('listConversations pagination returns correct page', () async {
			final svc = _makeService();
			// Add a message to bump conversation, creating a total of one conversation
			final conv = await svc.getOrCreateActiveConversation();
			await svc.addMessage(
				conversationId: conv.id,
				role: 'user',
				content: 'msg',
			);

			final page0 = await svc.listConversations(page: 0, pageSize: 1);
			expect(page0.length, equals(1));

			final page1 = await svc.listConversations(page: 1, pageSize: 1);
			expect(page1, isEmpty);
		});

		test('addMessage persists message under correct conversation', () async {
			final svc = _makeService();
			final conv = await svc.getOrCreateActiveConversation();
			final msg = await svc.addMessage(
				conversationId: conv.id,
				role: 'user',
				content: 'Hello',
			);
			expect(msg.conversationId, equals(conv.id));
			expect(msg.content, equals('Hello'));
			expect(msg.role, equals('user'));

			final messages = await svc.getMessages(conv.id);
			expect(messages, isNotEmpty);
			expect(messages.first.content, equals('Hello'));
		});

		test('updateConversationTitle updates the title', () async {
			final svc = _makeService();
			final conv = await svc.getOrCreateActiveConversation();
			await svc.updateConversationTitle(conv.id, '新对话标题');
			final updated = await svc.listConversations();
			expect(updated.first.title, equals('新对话标题'));
		});
	});
}

