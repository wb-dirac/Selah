import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_ocr/platform_ocr.dart';
import 'package:personal_ai_assistant/features/ocr/domain/ocr_service.dart';

/// [OcrService] implementation using platform-native OCR APIs.
///
/// - macOS: Apple Vision.framework
/// - Windows: Windows.Media.Ocr (WinRT)
///
/// All processing is performed on-device with zero network calls.
class PlatformOcrProvider implements OcrService {
  PlatformOcrProvider({PlatformOcr? ocr}) : _ocr = ocr ?? PlatformOcr();

  final PlatformOcr _ocr;

  @override
  Future<OcrResult> recognizeText(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw OcrException('Image file not found: $imagePath');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final result = await _ocr.recognizeText(OcrSource.file(imagePath));
      stopwatch.stop();

      if (result.text.isEmpty) {
        return OcrResult(
          fullText: '',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      // platform_ocr returns a single text result without block-level details,
      // so we wrap the entire result as a single block.
      final blocks = [OcrTextBlock(text: result.text)];

      return OcrResult(
        fullText: result.text,
        blocks: blocks,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      if (e is OcrException) rethrow;
      throw OcrException('Platform OCR recognition failed', cause: e);
    }
  }

  @override
  Future<bool> isAvailable() async {
    return Platform.isMacOS || Platform.isWindows;
  }

  @override
  Future<void> dispose() async {
    // platform_ocr does not hold persistent native resources
  }
}

final platformOcrProvider = Provider<PlatformOcrProvider>((ref) {
  return PlatformOcrProvider();
});
