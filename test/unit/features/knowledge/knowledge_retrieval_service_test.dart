import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/knowledge/data/datasources/document_fragment_dao.dart';
import 'package:personal_ai_assistant/features/knowledge/data/models/document_fragment.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/knowledge_retrieval_service.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/text_chunking_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/embedding_vector.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_chat_options.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/llm_model_info.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

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

class _FakeDocumentFragmentDao extends DocumentFragmentDao {
  _FakeDocumentFragmentDao() : super(_fakeDb());

  final List<DocumentFragment> saved = <DocumentFragment>[];
  List<ScoredFragment> nextResult = const <ScoredFragment>[];

  @override
  Future<void> upsert(DocumentFragment fragment) async {
    saved.removeWhere((item) => item.id == fragment.id);
    saved.add(fragment);
  }

  @override
  Future<void> deleteBySource(String sourceId) async {
    saved.removeWhere((item) => item.sourceId == sourceId);
  }

  @override
  Future<List<ScoredFragment>> findSimilar(
    List<double> queryEmbedding, {
    int topK = 5,
    String? filterSourceId,
  }) async {
    return nextResult.take(topK).toList(growable: false);
  }
}

class _EmbeddingGateway implements LlmGateway {
  @override
  Stream<ChatChunk> chat(
    List<ChatMessage> messages, {
    LlmChatOptions options = const LlmChatOptions(),
  }) async* {}

  @override
  Future<EmbeddingVector> embed(String text, {String? model}) async {
    return EmbeddingVector(
      values: <double>[text.length.toDouble(), 1, 0.5],
      model: model,
    );
  }

  @override
  Future<List<LlmModelInfo>> listModels() async => const <LlmModelInfo>[];
}

void main() {
  group('KnowledgeRetrievalService', () {
    late _FakeDocumentFragmentDao dao;
    late KnowledgeRetrievalService service;

    setUp(() {
      dao = _FakeDocumentFragmentDao();
      service = KnowledgeRetrievalService(
        documentFragmentDao: dao,
        textChunkingService: const TextChunkingService(),
      );
    });

    test('indexes plain text into document fragments', () async {
      final firstParagraph = List<String>.filled(450, '北京').join();
      final secondParagraph = List<String>.filled(450, '上海').join();
      final count = await service.indexPlainText(
        sourceId: 'doc-1',
        content: '$firstParagraph\n\n$secondParagraph',
        gateway: _EmbeddingGateway(),
      );

      expect(count, greaterThanOrEqualTo(2));
      expect(dao.saved.length, equals(count));
      expect(dao.saved.first.sourceId, equals('doc-1'));
      expect(dao.saved.first.embedding, isNotNull);
    });

    test('builds prompt context from scored fragments', () async {
      dao.nextResult = <ScoredFragment>[
        ScoredFragment(
          fragment: DocumentFragment(
            id: 'f1',
            sourceId: 'doc-a',
            chunkIndex: 0,
            content: '北京两日行程建议先去故宫。',
            createdAt: DateTime.now(),
            embedding: const <double>[1, 2, 3],
          ),
          score: 0.92,
        ),
      ];

      final context = await service.buildPromptContext(
        query: '北京两日游怎么安排',
        gateway: _EmbeddingGateway(),
      );

      expect(context, isNotNull);
      expect(context, contains('doc-a'));
      expect(context, contains('故宫'));
    });
  });
}
