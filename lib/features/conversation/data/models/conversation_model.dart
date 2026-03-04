class ConversationEntity {
	const ConversationEntity({
		required this.id,
		required this.createdAt,
		required this.updatedAt,
		this.title,
		this.deletedAt,
	});

	final String id;
	final String? title;
	final DateTime createdAt;
	final DateTime updatedAt;
	final DateTime? deletedAt;

	Map<String, Object?> toMap() {
		return {
			'id': id,
			'title': title,
			'created_at': createdAt.millisecondsSinceEpoch,
			'updated_at': updatedAt.millisecondsSinceEpoch,
			'deleted_at': deletedAt?.millisecondsSinceEpoch,
		};
	}

	factory ConversationEntity.fromMap(Map<String, Object?> map) {
		return ConversationEntity(
			id: map['id']! as String,
			title: map['title'] as String?,
			createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
			updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
			deletedAt: map['deleted_at'] == null
					? null
					: DateTime.fromMillisecondsSinceEpoch(map['deleted_at']! as int),
		);
	}
}