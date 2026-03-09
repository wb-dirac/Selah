import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/text_chunking_service.dart';

void main() {
  group('TextChunkingService', () {
    const service = TextChunkingService();

    test('splits text by paragraphs within max size', () {
      final chunks = service.chunk(
        '第一段内容。\n\n第二段内容。\n\n第三段内容。',
        maxChars: 12,
        overlapChars: 2,
      );

      expect(chunks, hasLength(3));
      expect(chunks.first, contains('第一段内容'));
      expect(chunks.last, contains('第三段内容'));
    });

    test('splits long paragraph with overlap', () {
      final chunks = service.chunk(
        'abcdefghijklmnopqrstuvwxyz',
        maxChars: 10,
        overlapChars: 3,
      );

      expect(chunks.length, greaterThan(2));
      expect(chunks.first, equals('abcdefghij'));
      expect(chunks[1], startsWith('hij'));
    });
  });
}
