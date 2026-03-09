import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/knowledge/data/parsers/document_parser_service.dart';

void main() {
  const service = DocumentParserService();

  group('DocumentParserService', () {
    test('returns null for unsupported extension', () async {
      final tmpFile = await _writeTmp('test.xyz', 'hello');
      addTearDown(tmpFile.deleteSync);

      final result = await service.extractText(tmpFile.path);
      expect(result, isNull);
    });

    test('extracts text from .txt file', () async {
      const content = 'Hello, world!\nSecond line.';
      final tmpFile = await _writeTmp('test.txt', content);
      addTearDown(tmpFile.deleteSync);

      final result = await service.extractText(tmpFile.path);
      expect(result, equals(content));
    });

    test('extracts text from .csv file', () async {
      const content = 'name,age\nAlice,30\nBob,25';
      final tmpFile = await _writeTmp('test.csv', content);
      addTearDown(tmpFile.deleteSync);

      final result = await service.extractText(tmpFile.path);
      expect(result, equals(content));
    });

    test('extracts text from .md file', () async {
      const content = '# Title\n\nSome paragraph.';
      final tmpFile = await _writeTmp('test.md', content);
      addTearDown(tmpFile.deleteSync);

      final result = await service.extractText(tmpFile.path);
      expect(result, equals(content));
    });

    test('extracts text from .markdown file', () async {
      const content = '## Heading\n\nParagraph text.';
      final tmpFile = await _writeTmp('test.markdown', content);
      addTearDown(tmpFile.deleteSync);

      final result = await service.extractText(tmpFile.path);
      expect(result, equals(content));
    });

    test('supportedExtensions contains expected formats', () {
      expect(
        DocumentParserService.supportedExtensions,
        containsAll(<String>['txt', 'csv', 'md', 'markdown', 'pdf', 'docx', 'xlsx']),
      );
    });
  });
}

Future<File> _writeTmp(String name, String content) async {
  final tmpDir = Directory.systemTemp;
  final file = File('${tmpDir.path}/$name');
  await file.writeAsString(content);
  return file;
}
