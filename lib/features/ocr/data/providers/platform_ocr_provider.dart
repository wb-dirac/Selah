import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/ocr/domain/ocr_service.dart';

/// [OcrService] implementation using platform-native OCR APIs.
///
/// Desktop OCR is currently disabled in this app build.
class PlatformOcrProvider implements OcrService {
  PlatformOcrProvider();

  @override
  Future<OcrResult> recognizeText(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw OcrException('Image file not found: $imagePath');
    }
    throw const OcrException('OCR is currently unsupported on desktop');
  }

  @override
  Future<bool> isAvailable() async {
    return false;
  }

  @override
  Future<void> dispose() async {
    // no-op
  }
}

final platformOcrProvider = Provider<PlatformOcrProvider>((ref) {
  return PlatformOcrProvider();
});
