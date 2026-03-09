import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/orchestration/media/image_input_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageInputService Mock Tests', () {
    late ImageInputService service;

    setUp(() {
      service = ImageInputService(
        attachmentDirectoryProvider: () async => Directory.systemTemp,
      );
    });

    group('processDragAndDrop', () {
      test('should return null for non-existent file', () async {
        final result = await service.processDragAndDrop('/non/existent/path.jpg');
        expect(result, isNull);
      });

      test('should return null for invalid file extension', () async {
        final tempFile = File('${Directory.systemTemp.path}/test.txt');
        await tempFile.writeAsString('This is not an image');

        try {
          final result = await service.processDragAndDrop(tempFile.path);
          expect(result, isNull);
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      });

      test('should return PickedImage for valid image file', () async {
        // Create a minimal JPEG file
        final jpegBytes = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
          0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
          0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43
        ]);
        
        final tempFile = File('${Directory.systemTemp.path}/test.jpg');
        await tempFile.writeAsBytes(jpegBytes);

        try {
          final result = await service.processDragAndDrop(tempFile.path);
          expect(result, isNotNull);
          expect(result!.source, equals(ImageInputSource.dragAndDrop));
          expect(result.mimeType, equals('image/jpeg'));
          expect(result.sizeBytes, equals(jpegBytes.length));
          expect(await File(result.filePath).exists(), isTrue);
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          // Clean up the copied file
          final copiedFile = File('${Directory.systemTemp.path}/attachments/test.jpg');
          if (await copiedFile.exists()) {
            await copiedFile.delete();
          }
        }
      });
    });

    group('processClipboardImage', () {
      test('should return null for empty bytes', () async {
        final result = await service.processClipboardImage(Uint8List(0));
        expect(result, isNull);
      });

      test('should return PickedImage for valid image bytes', () async {
        final imageBytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        ]);

        final result = await service.processClipboardImage(imageBytes);
        expect(result, isNotNull);
        expect(result!.source, equals(ImageInputSource.clipboard));
        expect(result.mimeType, equals('image/png'));
        expect(result.sizeBytes, equals(imageBytes.length));
        expect(await File(result.filePath).exists(), isTrue);
      });
    });

    group('image extension validation', () {
      test('should validate common image extensions', () async {
        final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
        
        for (final ext in validExtensions) {
          final tempFile = File('${Directory.systemTemp.path}/test$ext');
          await tempFile.writeAsBytes([0x00]); // Minimal content

          try {
            final result = await service.processDragAndDrop(tempFile.path);
            expect(result, isNotNull, reason: 'Extension $ext should be valid');
          } finally {
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      });

      test('should reject invalid extensions', () async {
        final invalidExtensions = ['.txt', '.pdf', '.doc', '.mp4', '.zip'];
        
        for (final ext in invalidExtensions) {
          final tempFile = File('${Directory.systemTemp.path}/test$ext');
          await tempFile.writeAsString('Not an image');

          try {
            final result = await service.processDragAndDrop(tempFile.path);
            expect(result, isNull, reason: 'Extension $ext should be invalid');
          } finally {
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
        }
      });
    });

    group('file copying and storage', () {
      test('should copy file to attachments directory', () async {
        final originalBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        final tempFile = File('${Directory.systemTemp.path}/original.jpg');
        await tempFile.writeAsBytes(originalBytes);

        PickedImage? result;
        try {
          result = await service.processDragAndDrop(tempFile.path);
          expect(result, isNotNull);
          
          // Verify the file was copied to a new location
          expect(result!.filePath, isNot(equals(tempFile.path)));
          expect(await File(result.filePath).exists(), isTrue);
          
          // Verify the content is the same
          final copiedBytes = await File(result.filePath).readAsBytes();
          expect(copiedBytes, equals(originalBytes));
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          // Clean up the copied file
          if (result != null && await File(result.filePath).exists()) {
            await File(result.filePath).delete();
          }
        }
      });
    });
  });
}
