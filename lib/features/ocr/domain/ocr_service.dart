import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single recognized text block with its bounding region.
class OcrTextBlock {
  const OcrTextBlock({required this.text, this.confidence, this.languageCode});

  /// The recognized text content of this block.
  final String text;

  /// Recognition confidence score (0.0–1.0), if provided by the engine.
  final double? confidence;

  /// BCP-47 language code detected for this block (e.g. 'zh', 'en').
  final String? languageCode;
}

/// Result of an OCR recognition operation.
class OcrResult {
  const OcrResult({
    required this.fullText,
    this.blocks = const [],
    this.languageCode,
    this.durationMs,
  });

  /// Concatenated plain text of all recognized blocks.
  final String fullText;

  /// Individual text blocks with optional confidence and language info.
  final List<OcrTextBlock> blocks;

  /// Primary detected language code, if available.
  final String? languageCode;

  /// Processing duration in milliseconds for performance monitoring.
  final int? durationMs;

  /// Whether any text was actually recognized.
  bool get hasText => fullText.trim().isNotEmpty;

  /// Empty result for when OCR finds nothing.
  static const empty = OcrResult(fullText: '');
}

/// Abstract interface for local OCR text recognition.
///
/// Platform implementations:
/// - iOS / Android: Google ML Kit Text Recognition
/// - Other platforms: currently unsupported in this app
///
/// All processing is done on-device — no network calls.
abstract class OcrService {
  /// Recognizes text in the image at [imagePath].
  ///
  /// Returns [OcrResult] with the extracted text and block-level details.
  /// Returns [OcrResult.empty] if no text is detected.
  ///
  /// Throws [OcrException] if the image cannot be read or processing fails.
  Future<OcrResult> recognizeText(String imagePath);

  /// Whether this OCR engine is available on the current platform.
  Future<bool> isAvailable();

  /// Releases any native resources held by the OCR engine.
  Future<void> dispose();
}

/// Exception thrown when OCR processing fails.
class OcrException implements Exception {
  const OcrException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'OcrException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Provider for the platform-appropriate [OcrService] implementation.
///
/// Override in main app bootstrap with the concrete platform provider.
final ocrServiceProvider = Provider<OcrService>((ref) {
  throw UnimplementedError(
    'ocrServiceProvider must be overridden with a platform-specific implementation',
  );
});
