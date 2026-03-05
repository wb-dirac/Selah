class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.deletedAt,
    this.parentMessageId,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final DateTime? deletedAt;

  /// The ID of the user message that this assistant message is a response to.
  /// Used for branching: multiple assistant messages can share the same
  /// [parentMessageId], representing alternative regenerations.
  /// Null for user messages and legacy messages without branching.
  final String? parentMessageId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'parent_message_id': parentMessageId,
    };
  }

  factory MessageEntity.fromMap(Map<String, Object?> map) {
    return MessageEntity(
      id: map['id']! as String,
      conversationId: map['conversation_id']! as String,
      role: map['role']! as String,
      content: map['content']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['deleted_at']! as int),
      parentMessageId: map['parent_message_id'] as String?,
    );
  }

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    DateTime? createdAt,
    DateTime? deletedAt,
    String? parentMessageId,
    bool clearParentMessageId = false,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      parentMessageId: clearParentMessageId
          ? null
          : (parentMessageId ?? this.parentMessageId),
    );
  }
}
