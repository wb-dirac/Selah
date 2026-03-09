import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextChunkingService {
  const TextChunkingService();

  List<String> chunk(
    String text, {
    int maxChars = 800,
    int overlapChars = 120,
  }) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final paragraphs = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final chunks = <String>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) {
        chunks.add(value);
      }
      buffer.clear();
    }

    for (final paragraph in paragraphs) {
      if (paragraph.length > maxChars) {
        if (buffer.isNotEmpty) {
          flushBuffer();
        }
        chunks.addAll(
          _splitLongParagraph(
            paragraph,
            maxChars: maxChars,
            overlapChars: overlapChars,
          ),
        );
        continue;
      }

      final candidate = buffer.isEmpty
          ? paragraph
          : '${buffer.toString().trim()}\n\n$paragraph';
      if (candidate.length > maxChars && buffer.isNotEmpty) {
        flushBuffer();
        buffer.write(paragraph);
      } else {
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(paragraph);
      }
    }

    if (buffer.isNotEmpty) {
      flushBuffer();
    }

    return chunks;
  }

  List<String> _splitLongParagraph(
    String paragraph, {
    required int maxChars,
    required int overlapChars,
  }) {
    final chunks = <String>[];
    var start = 0;
    while (start < paragraph.length) {
      final end = (start + maxChars).clamp(0, paragraph.length);
      final slice = paragraph.substring(start, end).trim();
      if (slice.isNotEmpty) {
        chunks.add(slice);
      }
      if (end >= paragraph.length) {
        break;
      }
      start = (end - overlapChars).clamp(0, paragraph.length);
      if (start == end) {
        break;
      }
    }
    return chunks;
  }
}

final textChunkingServiceProvider = Provider<TextChunkingService>((ref) {
  return const TextChunkingService();
});
