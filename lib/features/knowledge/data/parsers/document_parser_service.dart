import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class DocumentParserService {
  const DocumentParserService();

  static const Set<String> supportedExtensions = {
    'txt',
    'csv',
    'md',
    'markdown',
    'pdf',
    'docx',
    'xlsx',
  };

  Future<String?> extractText(String filePath) async {
    final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'txt' || 'csv' || 'md' || 'markdown' => _readPlainText(filePath),
      'pdf' => _readPdf(filePath),
      'docx' => _readDocx(filePath),
      'xlsx' => _readXlsx(filePath),
      _ => null,
    };
  }

  Future<String> _readPlainText(String filePath) {
    return File(filePath).readAsString();
  }

  Future<String?> _readPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return text.trim().isEmpty ? null : text;
    } finally {
      document.dispose();
    }
  }

  Future<String?> _readDocx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final contentEntry = archive.findFile('word/document.xml');
    if (contentEntry == null) return null;

    final xmlString = String.fromCharCodes(
      contentEntry.content as List<int>,
    );
    final document = XmlDocument.parse(xmlString);
    final texts = document
        .findAllElements('w:t')
        .map((e) => e.innerText)
        .where((t) => t.isNotEmpty);
    final result = texts.join(' ').trim();
    return result.isEmpty ? null : result;
  }

  Future<String?> _readXlsx(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final workbook = Excel.decodeBytes(bytes);
    final buffer = StringBuffer();
    for (final table in workbook.tables.keys) {
      for (final row in workbook.tables[table]!.rows) {
        final cells = row
            .where((cell) => cell != null && cell.value != null)
            .map((cell) => cell!.value.toString());
        if (cells.isNotEmpty) {
          buffer.writeln(cells.join('\t'));
        }
      }
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }
}
