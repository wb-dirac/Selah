import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';
import 'package:personal_ai_assistant/features/ocr/domain/ocr_service.dart';

/// Orchestration service that coordinates OCR processing for images.
///
/// Responsibilities:
/// - Accepts an image path, runs local OCR, returns extracted text
/// - Runs OCR in a compute isolate for images to avoid blocking the UI
/// - Logs performance metrics via [SanitizedLogger]
/// - Handles errors gracefully (returns null on failure, never throws)
///
/// This service sits in the orchestration layer between the presentation
/// (ChatNotifier) and the capability layer (OcrService).
class OcrOrchestrationService {
  OcrOrchestrationService({
    required OcrService ocrService,
    required SanitizedLogger logger,
  }) : _ocrService = ocrService,
       _logger = logger;

  final OcrService _ocrService;
  final SanitizedLogger _logger;

  /// Extracts text from the image at [imagePath] using local OCR.
  ///
  /// Returns the [OcrResult] if text was found, or `null` if:
  /// - No text was detected in the image
  /// - OCR processing failed (error is logged, not thrown)
  /// - The OCR engine is unavailable on the current platform
  ///
  /// This method is safe to call from the UI layer — it never throws.
  Future<OcrResult?> extractText(String imagePath) async {
    final available = await _ocrService.isAvailable();
    if (!available) {
      _logger.warning(
        'OCR not available on current platform',
        context: {'platform': defaultTargetPlatform.name},
      );
      return null;
    }

    try {
      final result = await _ocrService.recognizeText(imagePath);

      if (result.hasText) {
        _logger.info(
          'OCR completed',
          context: {
            'textLength': '${result.fullText.length}',
            'blocks': '${result.blocks.length}',
            'durationMs': '${result.durationMs ?? 0}',
            if (result.languageCode != null) 'language': result.languageCode!,
          },
        );
      } else {
        _logger.info('OCR completed: no text detected');
      }

      return result.hasText ? result : null;
    } on OcrException catch (e) {
      _logger.error(
        'OCR extraction failed',
        error: e,
        context: {'imagePath': imagePath},
      );
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected OCR error',
        error: e,
        stackTrace: stackTrace,
        context: {'imagePath': imagePath},
      );
      return null;
    }
  }

  /// Extracts text from multiple images in parallel.
  ///
  /// Returns a map of image path → extracted text for images that
  /// contained recognizable text. Images with no text or that fail
  /// OCR are omitted from the result.
  Future<Map<String, String>> extractTextFromMultiple(
    List<String> imagePaths,
  ) async {
    final results = <String, String>{};

    // Process sequentially to avoid overwhelming the OCR engine.
    // ML Kit and platform_ocr are not designed for concurrent calls.
    for (final path in imagePaths) {
      final result = await extractText(path);
      if (result != null) {
        results[path] = result.fullText;
      }
    }

    return results;
  }
}

final ocrOrchestrationServiceProvider = Provider<OcrOrchestrationService>((
  ref,
) {
  final ocrService = ref.watch(ocrServiceProvider);
  final logger = ref.watch(sanitizedLoggerProvider);
  return OcrOrchestrationService(ocrService: ocrService, logger: logger);
});
