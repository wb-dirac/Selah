import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum SherpaModelKind { tts, stt }

/// Metadata that describes a specific bundled model release.
class _SherpaModelSpec {
  const _SherpaModelSpec({
    required this.archiveName,
    required this.downloadUrl,
    required this.extractedDirName,
    required this.requiredFiles,
    required this.displayName,
  });

  /// File name of the archive (e.g. `vits-melo-tts-zh_en.tar.bz2`).
  final String archiveName;

  /// Direct HTTPS link to the GitHub release asset.
  final String downloadUrl;

  /// Top-level directory name that the archive extracts into.
  final String extractedDirName;

  /// Files that must exist inside [extractedDirName] to consider the model ready.
  final List<String> requiredFiles;

  /// Human-readable label shown in the settings UI.
  final String displayName;
}

/// Service that manages downloading and extracting Sherpa-ONNX model archives.
class SherpaOnnxModelDownloadService {
  SherpaOnnxModelDownloadService({http.Client? client}) : _client = client;

  final http.Client? _client;

  // ---------------------------------------------------------------------------
  // Bundled model definitions
  // ---------------------------------------------------------------------------

  /// vits-melo-tts-zh_en: bilingual (Mandarin + English) VITS TTS.
  /// Compressed size: ~56 MB. Extracted into `vits-melo-tts-zh_en/`.
  static const _ttsSpec = _SherpaModelSpec(
    archiveName: 'vits-melo-tts-zh_en.tar.bz2',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
    extractedDirName: 'vits-melo-tts-zh_en',
    requiredFiles: ['model.onnx', 'lexicon.txt', 'tokens.txt'],
    displayName: 'vits-melo-tts-zh_en（中英文 TTS，约 56 MB）',
  );

  /// SenseVoice zh/en/ja/ko/yue int8: highly accurate multilingual ASR.
  /// Compressed size: ~105 MB. Extracted into the model name directory.
  static const _sttSpec = _SherpaModelSpec(
    archiveName:
        'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17-int8.tar.bz2',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17-int8.tar.bz2',
    extractedDirName:
        'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17-int8',
    requiredFiles: ['tokens.txt'],
    displayName: 'SenseVoice zh/en/ja/ko int8（语音识别，约 105 MB）',
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the human-readable label for [kind].
  String displayName(SherpaModelKind kind) => _spec(kind).displayName;

  /// Returns the on-disk directory that contains the extracted model files.
  Future<Directory> getModelDirectory(SherpaModelKind kind) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(root.path, 'sherpa_onnx', _spec(kind).extractedDirName),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns `true` when all required model files are present on disk.
  Future<bool> isModelReady(SherpaModelKind kind) async {
    final dir = await getModelDirectory(kind);
    final requiredFiles = _spec(kind).requiredFiles;
    for (final fileName in requiredFiles) {
      if (!await File(p.join(dir.path, fileName)).exists()) return false;
    }
    if (kind == SherpaModelKind.stt) {
      final modelOnnx = File(p.join(dir.path, 'model.onnx'));
      final modelInt8Onnx = File(p.join(dir.path, 'model.int8.onnx'));
      if (!await modelOnnx.exists() && !await modelInt8Onnx.exists()) {
        return false;
      }
    }
    return true;
  }

  /// Downloads and extracts the model archive.
  ///
  /// [onProgress] is called with (bytesDownloaded, totalBytes) as each chunk
  /// arrives. `totalBytes` is `-1` when the server omits `Content-Length`.
  Future<void> downloadModel(
    SherpaModelKind kind, {
    void Function(int downloaded, int total)? onProgress,
  }) async {
    final spec = _spec(kind);
    final uri = Uri.parse(spec.downloadUrl);
    if (uri.scheme != 'https') {
      throw StateError('Sherpa model URL must use HTTPS: ${spec.downloadUrl}');
    }

    final root = await getApplicationSupportDirectory();
    final sherpaDir = Directory(p.join(root.path, 'sherpa_onnx'));
    if (!await sherpaDir.exists()) await sherpaDir.create(recursive: true);

    final archivePath = p.join(sherpaDir.path, spec.archiveName);
    final client = _client ?? http.Client();

    try {
      // ── Step 1: stream the archive to disk ─────────────────────────────────
      final request = http.Request('GET', uri);
      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw StateError(
          'HTTP ${streamedResponse.statusCode} while downloading '
          '${spec.archiveName}',
        );
      }

      final total = streamedResponse.contentLength ?? -1;
      int downloaded = 0;
      final sink = File(archivePath).openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded, total);
      }
      await sink.flush();
      await sink.close();

      // ── Step 2: decompress and extract tar.bz2 in place ────────────────────
      await _extractTarBzip2(archivePath, sherpaDir.path);
    } finally {
      // Remove the temporary archive file regardless of success or failure.
      final archiveFile = File(archivePath);
      if (await archiveFile.exists()) await archiveFile.delete();
      if (_client == null) client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  _SherpaModelSpec _spec(SherpaModelKind kind) =>
      kind == SherpaModelKind.tts ? _ttsSpec : _sttSpec;

  /// Decompresses a `.tar.bz2` archive and writes all extracted entries under
  /// [destDir], preserving the directory structure inside the archive.
  Future<void> _extractTarBzip2(String archivePath, String destDir) async {
    final bytes = await File(archivePath).readAsBytes();
    // Decompress bzip2 → raw tar bytes, then decode the tar container.
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final entry in archive) {
      final entryPath = p.join(destDir, entry.name);
      if (entry.isFile) {
        final content = entry.content;
        final outFile = File(entryPath);
        await outFile.create(recursive: true);
        if (content != null) {
          await outFile.writeAsBytes(content as List<int>, flush: true);
        }
      } else {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }
}

final sherpaOnnxModelDownloadServiceProvider =
    Provider<SherpaOnnxModelDownloadService>((ref) {
  return SherpaOnnxModelDownloadService();
});
