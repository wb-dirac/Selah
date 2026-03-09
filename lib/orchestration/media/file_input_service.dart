import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/knowledge/data/parsers/document_parser_service.dart';
import 'package:personal_ai_assistant/features/knowledge/domain/knowledge_retrieval_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';

class PickedDocument {
  const PickedDocument({
    required this.name,
    required this.filePath,
    required this.extension,
    required this.sizeBytes,
    required this.extractedText,
    required this.indexedChunkCount,
  });

  final String name;
  final String filePath;
  final String extension;
  final int sizeBytes;
  final String extractedText;
  final int indexedChunkCount;
}

class FileInputService {
  FileInputService({
    required DocumentParserService parserService,
    required KnowledgeRetrievalService retrievalService,
    FilePicker? filePicker,
  }) : _parserService = parserService,
       _retrievalService = retrievalService,
       _filePicker = filePicker ?? FilePicker.platform;

  final DocumentParserService _parserService;
  final KnowledgeRetrievalService _retrievalService;
  final FilePicker _filePicker;

  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  Future<PickedDocument?> pickAndIndex(LlmGateway? gateway) async {
    final result = await _filePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentParserService.supportedExtensions.toList(),
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.path == null) return null;
    if (file.size > maxFileSizeBytes) {
      throw FileTooLargeException(file.name, file.size);
    }

    final text = await _parserService.extractText(file.path!);
    if (text == null || text.trim().isEmpty) return null;

    int chunks = 0;
    if (gateway != null) {
      chunks = await _retrievalService.indexPlainText(
        sourceId: 'file:${file.name}',
        content: text,
        gateway: gateway,
      );
    }

    return PickedDocument(
      name: file.name,
      filePath: file.path!,
      extension: file.extension ?? '',
      sizeBytes: file.size,
      extractedText: text,
      indexedChunkCount: chunks,
    );
  }
}

class FileTooLargeException implements Exception {
  const FileTooLargeException(this.fileName, this.sizeBytes);

  final String fileName;
  final int sizeBytes;

  @override
  String toString() =>
      'FileTooLargeException: $fileName (${sizeBytes ~/ 1024}KB) exceeds '
      '${FileInputService.maxFileSizeBytes ~/ 1024 ~/ 1024}MB limit';
}

final documentParserServiceProvider = Provider<DocumentParserService>((ref) {
  return const DocumentParserService();
});

final fileInputServiceProvider = Provider<FileInputService>((ref) {
  return FileInputService(
    parserService: ref.watch(documentParserServiceProvider),
    retrievalService: ref.watch(knowledgeRetrievalServiceProvider),
  );
});
