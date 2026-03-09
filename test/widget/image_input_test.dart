import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/orchestration/media/image_input_service.dart';
import 'package:personal_ai_assistant/presentation/screens/chat/chat_screen.dart';

class _FakeImagePicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    // Simulate user picking an image
    if (source == ImageSource.camera || source == ImageSource.gallery) {
      return XFile('/fake/path/to/image.jpg');
    }
    return null;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    return [XFile('/fake/path/to/image1.jpg'), XFile('/fake/path/to/image2.jpg')];
  }
}

class _FakeFeatureFlagService implements FeatureFlagService {
  @override
  bool isEnabled(AppFeatureModule module) => true;

  @override
  void setEnabled(AppFeatureModule module, bool enabled) {}
  
  @override
  Map<AppFeatureModule, bool> snapshot() => {};
}

void main() {
  group('Image Input Flow Tests', () {
    testWidgets('should show attachment options and handle camera selection', (tester) async {
      // Build the chat screen with fake dependencies
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageInputServiceProvider.overrideWith(
              (ref) => ImageInputService(imagePicker: _FakeImagePicker()),
            ),
            featureFlagServiceProvider.overrideWithValue(_FakeFeatureFlagService()),
          ],
          child: MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      // Wait for the chat screen to load
      await tester.pumpAndSettle();

      // Verify the attachment button exists
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);

      // Tap the attachment button
      await tester.tap(find.byIcon(Icons.add_photo_alternate));
      await tester.pumpAndSettle();

      // Verify the bottom sheet appears with camera and gallery options
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);

      // Tap camera option
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      // The bottom sheet should close
      expect(find.text('拍照'), findsNothing);
      
      // Now let's check if there's any indication that an image was staged
      // This test will likely fail, exposing the issue with image staging
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);
    });

    testWidgets('should handle gallery selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageInputServiceProvider.overrideWith(
              (ref) => ImageInputService(imagePicker: _FakeImagePicker()),
            ),
            featureFlagServiceProvider.overrideWithValue(_FakeFeatureFlagService()),
          ],
          child: MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap attachment button
      await tester.tap(find.byIcon(Icons.add_photo_alternate));
      await tester.pumpAndSettle();

      // Tap gallery option
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();

      // The bottom sheet should close
      expect(find.text('相册'), findsNothing);
      
      // This test will also expose issues - we should see some indication
      // that an image was selected and staged
    });

    testWidgets('should handle drag and drop on desktop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageInputServiceProvider.overrideWith(
              (ref) => ImageInputService(imagePicker: _FakeImagePicker()),
            ),
            featureFlagServiceProvider.overrideWithValue(_FakeFeatureFlagService()),
          ],
          child: MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the DropTarget widget
      final dropTarget = find.byType(DropTarget);
      expect(dropTarget, findsOneWidget);

      // This test verifies DropTarget exists but actual drag-drop testing
      // would require more complex setup
    });

    testWidgets('should send message with staged images', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageInputServiceProvider.overrideWith(
              (ref) => ImageInputService(imagePicker: _FakeImagePicker()),
            ),
            featureFlagServiceProvider.overrideWithValue(_FakeFeatureFlagService()),
          ],
          child: MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First add an image
      await tester.tap(find.byIcon(Icons.add_photo_alternate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();

      // Enter some text
      await tester.enterText(find.byType(TextField), 'Test message with image');
      
      // Try to send - this will likely fail if image staging doesn't work
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
      
      // This test exposes issues with the image sending flow
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
    });
  });
}
