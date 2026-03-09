import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/knowledge/data/datasources/document_fragment_dao.dart';
import 'package:personal_ai_assistant/features/knowledge/data/models/document_fragment.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/text_chunking_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:uuid/uuid.dart';

class KnowledgeRetrievalService {
  KnowledgeRetrievalService({
    required DocumentFragmentDao documentFragmentDao,
    required TextChunkingService textChunkingService,
  }) : _documentFragmentDao = documentFragmentDao,
       _textChunkingService = textChunkingService;

  static const _uuid = Uuid();

  final DocumentFragmentDao _documentFragmentDao;
  final TextChunkingService _textChunkingService;

  Future<int> indexPlainText({
    required String sourceId,
    required String content,
    required LlmGateway gateway,
  }) async {
    final chunks = _textChunkingService.chunk(content);
    await _documentFragmentDao.deleteBySource(sourceId);

    for (var index = 0; index < chunks.length; index += 1) {
      final chunk = chunks[index];
      List<double>? embedding;
      try {
        embedding = (await gateway.embed(chunk)).values;
      } catch (_) {
        embedding = null;
      }
      await _documentFragmentDao.upsert(
        DocumentFragment(
          id: _uuid.v4(),
          sourceId: sourceId,
          chunkIndex: index,
          content: chunk,
          embedding: embedding,
          createdAt: DateTime.now(),
        ),
      );
    }

    return chunks.length;
  }

  Future<List<ScoredFragment>> retrieveRelevantFragments({
    required String query,
    required LlmGateway gateway,
    int topK = 3,
    String? filterSourceId,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <ScoredFragment>[];
    }

    try {
      final queryEmbedding = await gateway.embed(normalized);
      return _documentFragmentDao.findSimilar(
        queryEmbedding.values,
        topK: topK,
        filterSourceId: filterSourceId,
      );
    } catch (_) {
      return const <ScoredFragment>[];
    }
  }

  Future<String?> buildPromptContext({
    required String query,
    required LlmGateway gateway,
    int topK = 3,
  }) async {
    final scored = await retrieveRelevantFragments(
      query: query,
      gateway: gateway,
      topK: topK,
    );
    if (scored.isEmpty) {
      return null;
    }

    final filtered = scored.where((item) => item.score > 0.15).toList(growable: false);
    if (filtered.isEmpty) {
      return null;
    }

    final buffer = StringBuffer('以下是与当前问题相关的本地知识片段，可作为补充上下文：\n');
    for (final item in filtered) {
      buffer.writeln(
        '- [来源 ${item.fragment.sourceId} · 片段 ${item.fragment.chunkIndex + 1} · 相似度 ${item.score.toStringAsFixed(2)}] ${item.fragment.content}',
      );
    }
    return buffer.toString().trim();
  }
}

final knowledgeRetrievalServiceProvider = Provider<KnowledgeRetrievalService>((ref) {
  return KnowledgeRetrievalService(
    documentFragmentDao: ref.watch(documentFragmentDaoProvider),
    textChunkingService: ref.watch(textChunkingServiceProvider),
  );
});
