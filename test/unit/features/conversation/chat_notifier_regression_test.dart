import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/attachment_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/conversation_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/message_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/attachment_model.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/message_model.dart';
import 'package:personal_ai_assistant/features/conversation/domain/conversation_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/storage/config/app_preferences_store.dart';

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

class _InMemoryPreferencesStore implements AppPreferencesStore {
  final Map<String, String> _store = {};

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  @override
  Future<String?> readString(String key) async {
    return _store[key];
  }

  @override
  Future<void> saveString(String key, String value) async {
    _store[key] = value;
  }
}

SqlCipherDatabase _fakeDb() => SqlCipherDatabase(_NullKeychain());

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
  Future<List<ConversationEntity>> list({int page = 0, int pageSize = 20}) async {
    final all = _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (all.isEmpty) return [];
    return [all.first];
  }
}

class _FakeMessageDao extends MessageDao {
  _FakeMessageDao() : super(_fakeDb());

  final List<MessageEntity> _messages = [];

  @override
  Future<void> upsert(MessageEntity entity) async {
    _messages.add(entity);
  }

  @override
  Future<MessageEntity?> findById(String id) async {
    for (final message in _messages) {
      if (message.id == id && message.deletedAt == null) {
        return message;
      }
    }
    return null;
  }

  @override
  Future<List<MessageEntity>> listByConversation(
    String conversationId, {
    int page = 0,
    int pageSize = 50,
  }) async {
    return _messages.where((m) => m.conversationId == conversationId).toList();
  }

  @override
  Future<List<MessageEntity>> listAllByConversation(String conversationId) async {
    return const [];
  }

  @override
  Future<List<MessageEntity>> listSiblings(String parentMessageId) async {
    return _messages.where((m) => m.parentMessageId == parentMessageId).toList();
  }
}

class _FakeAttachmentDao extends AttachmentDao {
  _FakeAttachmentDao() : super(_fakeDb());

  @override
  Future<void> upsert(AttachmentEntity entity) async {}

  @override
  Future<Map<String, List<AttachmentEntity>>> listByMessages(
    List<String> messageIds,
  ) async {
    return {};
  }
}

class _FakeGateway implements LlmGateway {
  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    yield const ChatChunk(textDelta: '部分');
    yield const ChatChunk(textDelta: '回复');
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(String text, {String? model}) {
    throw UnimplementedError();
  }

  @override
  Future<List<LlmModelInfo>> listModels() async => const [];
}

class _NoTitleTagGateway implements LlmGateway {
  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    yield const ChatChunk(textDelta: '这是不带标题标签的回答内容。');
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(String text, {String? model}) {
    throw UnimplementedError();
  }

  @override
  Future<List<LlmModelInfo>> listModels() async => const [];
}

class _TitleGateway implements LlmGateway {
  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {
    yield const ChatChunk(
      textDelta: '[TITLE]高铁出行建议[/TITLE]\n给你整理了明天班次。',
    );
    yield const ChatChunk(textDelta: '', isDone: true);
  }

  @override
  Future<EmbeddingVector> embed(String text, {String? model}) {
    throw UnimplementedError();
  }

  @override
  Future<List<LlmModelInfo>> listModels() async => const [];
}

void main() {
  test('regression: do not clear messages when DB rebuild returns empty', () async {
    final service = ConversationService(
      conversationDao: _FakeConversationDao(),
      messageDao: _FakeMessageDao(),
      attachmentDao: _FakeAttachmentDao(),
      database: _fakeDb(),
      preferencesStore: _InMemoryPreferencesStore(),
    );

    final container = ProviderContainer(
      overrides: [
        conversationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatNotifierProvider.notifier);
    await notifier.initialize();

    await notifier.sendMessage('你好', _FakeGateway());

    final state = container.read(chatNotifierProvider).value!;
    final assistant = state.messages.where((m) => m.role == ChatRole.assistant).toList();

    expect(assistant, isNotEmpty);
    expect(assistant.last.content, contains('部分回复'));
    expect(state.messages, isNotEmpty);
  });

  test('first reply title tag is parsed and not shown in chat content', () async {
    final service = ConversationService(
      conversationDao: _FakeConversationDao(),
      messageDao: _FakeMessageDao(),
      attachmentDao: _FakeAttachmentDao(),
      database: _fakeDb(),
      preferencesStore: _InMemoryPreferencesStore(),
    );

    final container = ProviderContainer(
      overrides: [
        conversationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatNotifierProvider.notifier);
    await notifier.initialize();
    await notifier.sendMessage('帮我查明天高铁', _TitleGateway());

    final state = container.read(chatNotifierProvider).value!;
    final assistant = state.messages.where((m) => m.role == ChatRole.assistant).toList();
    expect(assistant, isNotEmpty);
    expect(assistant.last.content.contains('[TITLE]'), isFalse);
    expect(assistant.last.content, contains('给你整理了明天班次'));

    final conversationId = state.conversationId!;
    final conversation = await service.getConversationById(conversationId);
    expect(conversation, isNotNull);
    expect(conversation!.title, equals('高铁出行建议'));
  });

  test('first reply without TITLE tag still auto-generates fallback title', () async {
    final service = ConversationService(
      conversationDao: _FakeConversationDao(),
      messageDao: _FakeMessageDao(),
      attachmentDao: _FakeAttachmentDao(),
      database: _fakeDb(),
      preferencesStore: _InMemoryPreferencesStore(),
    );

    final container = ProviderContainer(
      overrides: [
        conversationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatNotifierProvider.notifier);
    await notifier.initialize();
    await notifier.sendMessage('请帮我规划一个两天北京行程', _NoTitleTagGateway());

    final state = container.read(chatNotifierProvider).value!;
    final conversation = await service.getConversationById(state.conversationId!);
    expect(conversation, isNotNull);
    expect(conversation!.title, equals('请帮我规划一个两天北京行程'));
  });

  test('renameConversationTitle updates state and persistence', () async {
    final service = ConversationService(
      conversationDao: _FakeConversationDao(),
      messageDao: _FakeMessageDao(),
      attachmentDao: _FakeAttachmentDao(),
      database: _fakeDb(),
      preferencesStore: _InMemoryPreferencesStore(),
    );

    final container = ProviderContainer(
      overrides: [
        conversationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatNotifierProvider.notifier);
    await notifier.initialize();
    await notifier.renameConversationTitle('  我的差旅计划  ');

    final state = container.read(chatNotifierProvider).value!;
    expect(state.conversationTitle, equals('我的差旅计划'));

    final conversation = await service.getConversationById(state.conversationId!);
    expect(conversation, isNotNull);
    expect(conversation!.title, equals('我的差旅计划'));
  });
}
