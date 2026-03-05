import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Represents a picked image from any input source.
class PickedImage {
  const PickedImage({
    required this.filePath,
    required this.source,
    this.mimeType,
    this.width,
    this.height,
    this.sizeBytes,
  });

  /// Absolute path to the image file (already copied to app storage).
  final String filePath;

  /// How the image was obtained.
  final ImageInputSource source;

  /// MIME type, e.g. 'image/jpeg', 'image/png'.
  final String? mimeType;

  /// Image dimensions, if known.
  final int? width;
  final int? height;

  /// File size in bytes.
  final int? sizeBytes;
}

/// The source of an image input.
enum ImageInputSource { camera, gallery, clipboard, dragAndDrop }

/// Orchestration-layer service that handles all image input methods:
/// - Camera capture (mobile)
/// - Gallery/photo library selection (mobile + desktop)
/// - Clipboard paste (all platforms)
/// - Drag-and-drop (desktop)
///
/// Images are copied to a private app directory so the original
/// can safely be deleted without affecting stored attachments.
class ImageInputService {
  ImageInputService({ImagePicker? imagePicker})
    : _picker = imagePicker ?? ImagePicker();

  final ImagePicker _picker;
  static const _uuid = Uuid();

  /// Directory name under the app's documents path for attachment storage.
  static const _attachmentDir = 'attachments';

  /// Opens the device camera and captures a photo.
  /// Returns `null` if the user cancelled.
  Future<PickedImage?> pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xFile == null) return null;
    return _processXFile(xFile, ImageInputSource.camera);
  }

  /// Opens the gallery/photo library to pick an image.
  /// Returns `null` if the user cancelled.
  Future<PickedImage?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return null;
    return _processXFile(xFile, ImageInputSource.gallery);
  }

  /// Picks multiple images from the gallery at once.
  Future<List<PickedImage>> pickMultipleFromGallery() async {
    final xFiles = await _picker.pickMultiImage(imageQuality: 90);
    final results = <PickedImage>[];
    for (final xFile in xFiles) {
      final picked = await _processXFile(xFile, ImageInputSource.gallery);
      results.add(picked);
    }
    return results;
  }

  /// Processes raw image bytes from the clipboard.
  /// Saves the bytes to app storage and returns a [PickedImage].
  Future<PickedImage?> processClipboardImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) return null;

    final dir = await _getAttachmentDirectory();
    final fileName = '${_uuid.v4()}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(imageBytes);

    return PickedImage(
      filePath: file.path,
      source: ImageInputSource.clipboard,
      mimeType: 'image/png',
      sizeBytes: imageBytes.length,
    );
  }

  /// Processes a file path from a desktop drag-and-drop event.
  /// Copies the file to app storage.
  /// Returns `null` if the file doesn't exist or isn't an image.
  Future<PickedImage?> processDragAndDrop(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final ext = p.extension(sourcePath).toLowerCase();
    if (!_isImageExtension(ext)) return null;

    final dir = await _getAttachmentDirectory();
    final fileName = '${_uuid.v4()}$ext';
    final destFile = File(p.join(dir.path, fileName));
    await sourceFile.copy(destFile.path);

    final stat = await destFile.stat();

    return PickedImage(
      filePath: destFile.path,
      source: ImageInputSource.dragAndDrop,
      mimeType: _mimeFromExtension(ext),
      sizeBytes: stat.size,
    );
  }

  // ─── Private helpers ─────────────────────────────────────────────

  Future<PickedImage> _processXFile(
    XFile xFile,
    ImageInputSource source,
  ) async {
    final dir = await _getAttachmentDirectory();
    final ext = p.extension(xFile.path).toLowerCase();
    final fileName = '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}';
    final destPath = p.join(dir.path, fileName);

    // Copy file to app-private storage
    final bytes = await xFile.readAsBytes();
    final destFile = File(destPath);
    await destFile.writeAsBytes(bytes);

    return PickedImage(
      filePath: destPath,
      source: source,
      mimeType: xFile.mimeType ?? _mimeFromExtension(ext),
      sizeBytes: bytes.length,
    );
  }

  Future<Directory> _getAttachmentDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final attachDir = Directory(p.join(appDir.path, _attachmentDir));
    if (!await attachDir.exists()) {
      await attachDir.create(recursive: true);
    }
    return attachDir;
  }

  bool _isImageExtension(String ext) {
    return const {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
      '.heif',
    }.contains(ext);
  }

  String? _mimeFromExtension(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return null;
    }
  }
}

final imageInputServiceProvider = Provider<ImageInputService>((ref) {
  return ImageInputService();
});
