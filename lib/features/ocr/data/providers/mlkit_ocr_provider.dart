import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:personal_ai_assistant/features/ocr/domain/ocr_service.dart';

/// [OcrService] implementation using Google ML Kit Text Recognition.
///
/// Supports iOS and Android. On iOS, ML Kit delegates to Apple's
/// on-device ML engine. On Android, it uses Google's ML Kit.
///
/// All processing is performed on-device with zero network calls.
class MlKitOcrProvider implements OcrService {
  MlKitOcrProvider({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? _createDefaultRecognizer();

  final TextRecognizer _recognizer;

  static TextRecognizer _createDefaultRecognizer() {
    try {
      return TextRecognizer();
    } catch (e) {
      // If ML Kit fails to initialize, return a dummy recognizer
      // that will always throw OcrException when used
      return _DummyTextRecognizer();
    }
  }

  @override
  Future<OcrResult> recognizeText(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw OcrException('Image file not found: $imagePath');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(inputImage);
      stopwatch.stop();

      if (recognized.text.isEmpty) {
        return OcrResult(
          fullText: '',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      final blocks = recognized.blocks.map((block) {
        // Determine the primary language of this block
        final languages = block.recognizedLanguages;
        final langCode = languages.isNotEmpty
          ? languages.first
            : null;

        // Average confidence across block elements
        double? avgConfidence;
        final confidences = block.lines
            .expand((line) => line.elements)
            .where((el) => el.confidence != null)
            .map((el) => el.confidence!)
            .toList();
        if (confidences.isNotEmpty) {
          avgConfidence =
              confidences.reduce((a, b) => a + b) / confidences.length;
        }

        return OcrTextBlock(
          text: block.text,
          confidence: avgConfidence,
          languageCode: langCode,
        );
      }).toList();

      // Determine overall language from the first block with a language code
      final primaryLang = blocks
          .where((b) => b.languageCode != null)
          .map((b) => b.languageCode)
          .firstOrNull;

      return OcrResult(
        fullText: recognized.text,
        blocks: blocks,
        languageCode: primaryLang,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      if (e is OcrException) rethrow;
      throw OcrException('ML Kit text recognition failed', cause: e);
    }
  }

  @override
  Future<bool> isAvailable() async {
    // ML Kit is available on iOS and Android only
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}

/// Dummy TextRecognizer used when ML Kit fails to initialize
class _DummyTextRecognizer implements TextRecognizer {
  @override
  String get id => 'dummy';

  @override
  TextRecognitionScript get script => TextRecognitionScript.latin;

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    throw OcrException('ML Kit is not available on this device');
  }

  @override
  Future<void> close() async {
    // No-op
  }
}

final mlKitOcrProvider = Provider<MlKitOcrProvider>((ref) {
  final provider = MlKitOcrProvider();
  ref.onDispose(() {
    provider.dispose(); // Don't wait for disposal
  });
  return provider;
});
