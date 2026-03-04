import 'dart:convert';

class DocumentFragment {
	const DocumentFragment({
		required this.id,
		required this.sourceId,
		required this.chunkIndex,
		required this.content,
		required this.createdAt,
		this.embedding,
	});

	final String id;
	final String sourceId;
	final int chunkIndex;
	final String content;
	final List<double>? embedding;
	final DateTime createdAt;

	Map<String, Object?> toMap() {
		return {
			'id': id,
			'source_id': sourceId,
			'chunk_index': chunkIndex,
			'content': content,
			'embedding': embedding != null ? jsonEncode(embedding) : null,
			'created_at': createdAt.millisecondsSinceEpoch,
		};
	}

	factory DocumentFragment.fromMap(Map<String, Object?> map) {
		final embeddingRaw = map['embedding'] as String?;
		List<double>? embedding;
		if (embeddingRaw != null) {
			final decoded = jsonDecode(embeddingRaw) as List<dynamic>;
			embedding = decoded.map((e) => (e as num).toDouble()).toList();
		}
		return DocumentFragment(
			id: map['id']! as String,
			sourceId: map['source_id']! as String,
			chunkIndex: map['chunk_index']! as int,
			content: map['content']! as String,
			embedding: embedding,
			createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
		);
	}
}
