import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/ocr/ocr_service.dart';
import 'package:personal_ai_assistant/features/ocr/data/ocr_service_factory.dart';
import 'package:personal_ai_assistant/presentation/app/personal_assistant_app.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        ocrServiceProvider.overrideWith((ref) => createPlatformOcrService()),
      ],
      child: PersonalAssistantApp(),
    ),
  );
}
