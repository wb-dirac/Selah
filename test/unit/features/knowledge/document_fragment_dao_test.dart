import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/knowledge/data/models/document_fragment.dart';

/// Local reimplementation of cosine similarity matching DocumentFragmentDao logic.
double _cosineSimilarity(List<double> a, List<double> b) {
	if (a.length != b.length || a.isEmpty) return 0.0;
	double dot = 0.0;
	double normA = 0.0;
	double normB = 0.0;
	for (var i = 0; i < a.length; i++) {
		dot += a[i] * b[i];
		normA += a[i] * a[i];
		normB += b[i] * b[i];
	}
	final denom = sqrt(normA) * sqrt(normB);
	if (denom == 0.0) return 0.0;
	return dot / denom;
}

void main() {
	group('DocumentFragment toMap/fromMap', () {
		test('round-trips without embedding', () {
			final fragment = DocumentFragment(
				id: 'frag-1',
				sourceId: 'src-1',
				chunkIndex: 0,
				content: 'Hello world',
				createdAt: DateTime.fromMillisecondsSinceEpoch(1000000),
			);
			final restored = DocumentFragment.fromMap(fragment.toMap());
			expect(restored.id, fragment.id);
			expect(restored.sourceId, fragment.sourceId);
			expect(restored.chunkIndex, fragment.chunkIndex);
			expect(restored.content, fragment.content);
			expect(restored.embedding, isNull);
			expect(restored.createdAt, fragment.createdAt);
		});

		test('round-trips with embedding', () {
			final fragment = DocumentFragment(
				id: 'frag-2',
				sourceId: 'src-1',
				chunkIndex: 1,
				content: 'Another chunk',
				embedding: [0.1, 0.2, 0.3],
				createdAt: DateTime.fromMillisecondsSinceEpoch(2000000),
			);
			final restored = DocumentFragment.fromMap(fragment.toMap());
			expect(restored.embedding, isNotNull);
			expect(restored.embedding!.length, 3);
			expect(restored.embedding![0], closeTo(0.1, 1e-10));
			expect(restored.embedding![1], closeTo(0.2, 1e-10));
			expect(restored.embedding![2], closeTo(0.3, 1e-10));
		});
	});

	group('cosine similarity', () {
		test('identical vectors have similarity 1.0', () {
			const v = [1.0, 0.0, 0.0];
			expect(_cosineSimilarity(v, v), closeTo(1.0, 1e-10));
		});

		test('orthogonal vectors have similarity 0.0', () {
			expect(
				_cosineSimilarity([1.0, 0.0], [0.0, 1.0]),
				closeTo(0.0, 1e-10),
			);
		});

		test('opposite vectors have similarity -1.0', () {
			expect(
				_cosineSimilarity([1.0, 0.0], [-1.0, 0.0]),
				closeTo(-1.0, 1e-10),
			);
		});

		test('zero vector returns 0.0', () {
			expect(_cosineSimilarity([0.0, 0.0], [1.0, 0.0]), equals(0.0));
		});

		test('partial overlap returns value between 0 and 1', () {
			final score = _cosineSimilarity([1.0, 0.0, 0.0], [0.707, 0.707, 0.0]);
			expect(score, greaterThan(0.0));
			expect(score, lessThan(1.0));
		});
	});

	group('findSimilar ordering (mock)', () {
		test('scores are ordered descending', () {
			final query = [1.0, 0.0, 0.0];
			final embeddings = <List<double>>[
				[0.0, 1.0, 0.0],     // orthogonal ≈ 0.0
				[1.0, 0.0, 0.0],     // identical  = 1.0
				[0.707, 0.707, 0.0], // partial    ≈ 0.707
			];

			final scored = embeddings
					.map((e) => _cosineSimilarity(query, e))
					.toList()
				..sort((a, b) => b.compareTo(a));

			expect(scored[0], closeTo(1.0, 1e-3));
			expect(scored[1], closeTo(0.707, 1e-3));
			expect(scored[2], closeTo(0.0, 1e-3));
		});

		test('topK limits result count', () {
			final query = [1.0, 0.0];
			final embeddings = List.generate(
				10,
				(i) => [i.toDouble(), 0.0],
			);
			final scored = embeddings
					.map((e) => _cosineSimilarity(query, e))
					.toList()
				..sort((a, b) => b.compareTo(a));
			const topK = 3;
			final top = scored.take(topK).toList();
			expect(top.length, topK);
		});
	});
}
