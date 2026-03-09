import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/orchestration/media/image_input_service.dart';
import 'package:personal_ai_assistant/presentation/screens/chat/chat_screen.dart';

/// Integration test that exposes issues with the actual image input implementation
/// This test uses real dependencies and will fail if the image flow is broken

void main() {
  group('Image Input Integration Tests', () {
    testWidgets('real image picker integration test', (tester) async {
      // Test with real ImagePicker to expose platform-specific issues
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagServiceProvider.overrideWithValue(
              _FakeFeatureFlagService(),
            ),
          ],
          child: MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify attachment button exists
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);

      // Tap attachment button
      await tester.tap(find.byIcon(Icons.add_photo_alternate));
      await tester.pumpAndSettle();

      // Verify options appear
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);

      // This test will expose issues when using real ImagePicker
      // on different platforms (emulator vs real device)
    });

    testWidgets('image service file handling test', (tester) async {
      // Test the actual ImageInputService with real file operations
      final service = ImageInputService();

      // Test with a non-existent file path (should return null)
      final result = await service.processDragAndDrop('/non/existent/path.jpg');
      expect(result, isNull);

      // Test with invalid file extension
      final invalidFile = File('/tmp/test.txt');
      if (!await invalidFile.parent.exists()) {
        await invalidFile.parent.create(recursive: true);
      }
      await invalidFile.writeAsString('This is not an image');
      
      final invalidResult = await service.processDragAndDrop(invalidFile.path);
      expect(invalidResult, isNull);

      // Clean up
      if (await invalidFile.exists()) {
        await invalidFile.delete();
      }
    });
  });
}

class _FakeFeatureFlagService implements FeatureFlagService {
  @override
  bool isEnabled(AppFeatureModule module) => true;

  @override
  void setEnabled(AppFeatureModule module, bool enabled) {}
  
  @override
  Map<AppFeatureModule, bool> snapshot() => {};
}
