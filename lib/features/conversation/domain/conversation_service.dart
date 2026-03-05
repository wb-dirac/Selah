import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/attachment_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/conversation_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/datasources/message_local_datasource.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/attachment_model.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/conversation_model.dart';
import 'package:personal_ai_assistant/features/conversation/data/models/message_model.dart';
import 'package:uuid/uuid.dart';

class ConversationService {
  ConversationService({
    required ConversationDao conversationDao,
    required MessageDao messageDao,
    required AttachmentDao attachmentDao,
    required SqlCipherDatabase database,
  }) : _conversationDao = conversationDao,
       _messageDao = messageDao,
       _attachmentDao = attachmentDao,
       _database = database;

  final ConversationDao _conversationDao;
  final MessageDao _messageDao;
  final AttachmentDao _attachmentDao;
  final SqlCipherDatabase _database;
  static const _uuid = Uuid();

  Future<ConversationEntity> createConversation({String? title}) async {
    final now = DateTime.now();
    final entity = ConversationEntity(
      id: _uuid.v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    await _conversationDao.upsert(entity);
    return entity;
  }

  Future<ConversationEntity> getOrCreateActiveConversation() async {
    final list = await _conversationDao.list(page: 0, pageSize: 1);
    if (list.isNotEmpty) {
      return list.first;
    }
    final now = DateTime.now();
    final entity = ConversationEntity(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
    );
    await _conversationDao.upsert(entity);
    return entity;
  }

  Future<ConversationEntity?> getConversationById(String id) {
    return _conversationDao.findById(id);
  }

  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int page = 0,
  }) async {
    return _messageDao.listByConversation(conversationId, page: page);
  }

  /// Returns all messages in a conversation (all branches), ordered
  /// chronologically (oldest first).
  Future<List<MessageEntity>> getAllMessages(String conversationId) async {
    return _messageDao.listAllByConversation(conversationId);
  }

  Future<MessageEntity> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? parentMessageId,
  }) async {
    final now = DateTime.now();
    final entity = MessageEntity(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: now,
      parentMessageId: parentMessageId,
    );
    await _messageDao.upsert(entity);
    // bump conversation updated_at
    final conv = await _conversationDao.findById(conversationId);
    if (conv != null) {
      await _conversationDao.upsert(
        ConversationEntity(
          id: conv.id,
          title: conv.title,
          createdAt: conv.createdAt,
          updatedAt: now,
          deletedAt: conv.deletedAt,
        ),
      );
    }
    return entity;
  }

  /// Returns all sibling assistant messages that were generated as responses
  /// to the same user message ([parentMessageId]).
  Future<List<MessageEntity>> getSiblings(String parentMessageId) async {
    return _messageDao.listSiblings(parentMessageId);
  }

  Future<MessageEntity?> getMessageById(String id) async {
    return _messageDao.findById(id);
  }

  /// Saves an attachment record linked to a message.
  Future<AttachmentEntity> addAttachment({
    required String messageId,
    required String type,
    required String filePath,
    String? mimeType,
    int? width,
    int? height,
    int? sizeBytes,
  }) async {
    final entity = AttachmentEntity(
      id: _uuid.v4(),
      messageId: messageId,
      type: type,
      filePath: filePath,
      createdAt: DateTime.now(),
      mimeType: mimeType,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
    );
    await _attachmentDao.upsert(entity);
    return entity;
  }

  /// Batch-loads attachments for a list of message IDs.
  /// Returns a map of messageId → list of attachments.
  Future<Map<String, List<AttachmentEntity>>> getAttachmentsForMessages(
    List<String> messageIds,
  ) async {
    return _attachmentDao.listByMessages(messageIds);
  }

  Future<void> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    final conv = await _conversationDao.findById(conversationId);
    if (conv == null) return;
    await _conversationDao.upsert(
      ConversationEntity(
        id: conv.id,
        title: title,
        createdAt: conv.createdAt,
        updatedAt: DateTime.now(),
        deletedAt: conv.deletedAt,
      ),
    );
  }

  Future<List<ConversationEntity>> listConversations({
    int page = 0,
    int pageSize = 20,
  }) async {
    return _conversationDao.list(page: page, pageSize: pageSize);
  }

  Future<List<ConversationEntity>> searchConversations(
    String query, {
    int page = 0,
    int pageSize = 20,
  }) async {
    final db = await _database.open();
    // Escape LIKE special characters before wrapping in wildcards
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    final offset = page * pageSize;
    final rows = await db.rawQuery(
      'SELECT DISTINCT c.* FROM conversations c '
      'LEFT JOIN messages m ON m.conversation_id = c.id '
      "WHERE (c.title LIKE ? ESCAPE '\\' OR m.content LIKE ? ESCAPE '\\') "
      'AND c.deleted_at IS NULL '
      'ORDER BY c.updated_at DESC '
      'LIMIT ? OFFSET ?',
      [pattern, pattern, pageSize, offset],
    );
    return rows.map(ConversationEntity.fromMap).toList();
  }
}

final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService(
    conversationDao: ref.watch(conversationDaoProvider),
    messageDao: ref.watch(messageDaoProvider),
    attachmentDao: ref.watch(attachmentDaoProvider),
    database: ref.watch(sqlCipherDatabaseProvider),
  );
});
