import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/presentation/app/personal_assistant_app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: PersonalAssistantApp(),
    ),
  );
}
