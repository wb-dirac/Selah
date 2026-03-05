import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/ocr/data/providers/mlkit_ocr_provider.dart';
import 'package:personal_ai_assistant/features/ocr/data/providers/platform_ocr_provider.dart';
import 'package:personal_ai_assistant/features/ocr/domain/ocr_service.dart';

/// Platform-aware factory that returns the appropriate [OcrService]
/// implementation based on the current OS.
///
/// - iOS / Android → [MlKitOcrProvider] (Google ML Kit)
/// - macOS / Windows → [PlatformOcrProvider] (native Vision / WinRT)
/// - Linux → throws [UnsupportedError]
OcrService createPlatformOcrService() {
  if (Platform.isIOS || Platform.isAndroid) {
    return MlKitOcrProvider();
  } else if (Platform.isMacOS || Platform.isWindows) {
    return PlatformOcrProvider();
  } else {
    throw UnsupportedError(
      'OCR is not supported on ${Platform.operatingSystem}',
    );
  }
}

/// Auto-configured provider that selects the right OCR engine for the
/// current platform. Disposes native resources on provider teardown.
final platformAwareOcrServiceProvider = Provider<OcrService>((ref) {
  final service = createPlatformOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
