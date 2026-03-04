import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/knowledge/data/models/document_fragment.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ScoredFragment {
	const ScoredFragment({required this.fragment, required this.score});

	final DocumentFragment fragment;
	final double score;
}

class DocumentFragmentDao {
	DocumentFragmentDao(this._database);

	final SqlCipherDatabase _database;

	Future<void> upsert(DocumentFragment fragment) async {
		final db = await _database.open();
		await db.insert(
			'document_fragments',
			fragment.toMap(),
			conflictAlgorithm: ConflictAlgorithm.replace,
		);
	}

	Future<List<DocumentFragment>> listBySource(String sourceId) async {
		final db = await _database.open();
		final rows = await db.query(
			'document_fragments',
			where: 'source_id = ?',
			whereArgs: [sourceId],
			orderBy: 'chunk_index ASC',
		);
		return rows.map(DocumentFragment.fromMap).toList();
	}

	Future<void> deleteBySource(String sourceId) async {
		final db = await _database.open();
		await db.delete(
			'document_fragments',
			where: 'source_id = ?',
			whereArgs: [sourceId],
		);
	}

	Future<List<ScoredFragment>> findSimilar(
		List<double> queryEmbedding, {
		int topK = 5,
		String? filterSourceId,
	}) async {
		final db = await _database.open();
		final rows = filterSourceId != null
				? await db.query(
						'document_fragments',
						where: 'source_id = ? AND embedding IS NOT NULL',
						whereArgs: [filterSourceId],
					)
				: await db.query(
						'document_fragments',
						where: 'embedding IS NOT NULL',
					);

		final fragments = rows.map(DocumentFragment.fromMap).toList();
		final scored = <ScoredFragment>[];

		for (final fragment in fragments) {
			final emb = fragment.embedding;
			if (emb == null || emb.isEmpty) continue;
			final score = _cosineSimilarity(queryEmbedding, emb);
			scored.add(ScoredFragment(fragment: fragment, score: score));
		}

		scored.sort((a, b) => b.score.compareTo(a.score));
		return scored.take(topK).toList();
	}

	static double _cosineSimilarity(List<double> a, List<double> b) {
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
}

final documentFragmentDaoProvider = Provider<DocumentFragmentDao>((ref) {
	final db = ref.watch(sqlCipherDatabaseProvider);
	return DocumentFragmentDao(db);
});
