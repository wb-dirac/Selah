import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/features/voice/data/sherpa_onnx_model_download_service.dart';

class SherpaOnnxLocalSpeechService {
  const SherpaOnnxLocalSpeechService({required this.modelDownloadService});

  final SherpaOnnxModelDownloadService modelDownloadService;

  Future<bool> isLocalTtsReady() {
    return modelDownloadService.isModelReady(SherpaModelKind.tts);
  }

  Future<bool> isLocalSttReady() {
    return modelDownloadService.isModelReady(SherpaModelKind.stt);
  }

  Future<String?> transcribeFile(String audioPath) async {
    if (!await isLocalSttReady()) {
      return null;
    }

    final bin = await _resolveExecutable('sherpa-onnx-offline', fallback: 'sherpa-onnx');
    if (bin == null) {
      return null;
    }

    final modelDir = await modelDownloadService.getModelDirectory(SherpaModelKind.stt);
    final result = await Process.run(
      bin.path,
      <String>[
        '--model-dir',
        modelDir.path,
        '--input',
        audioPath,
      ],
    );

    if (result.exitCode != 0) {
      return null;
    }

    final output = '${result.stdout}'.trim();
    if (output.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(output) as Map<String, dynamic>;
      return (json['text'] as String?)?.trim();
    } catch (_) {
      return output;
    }
  }

  Future<File?> synthesizeToFile(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    if (!await isLocalTtsReady()) {
      return null;
    }

    final bin = await _resolveExecutable('sherpa-onnx-tts');
    if (bin == null) {
      return null;
    }

    final modelDir = await modelDownloadService.getModelDirectory(SherpaModelKind.tts);
    final tmpDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tmpDir.path,
      'sherpa_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final result = await Process.run(
      bin.path,
      <String>[
        '--model-dir',
        modelDir.path,
        '--text',
        normalized,
        '--output',
        outputPath,
      ],
    );

    if (result.exitCode != 0) {
      return null;
    }

    final outFile = File(outputPath);
    if (!await outFile.exists()) {
      return null;
    }

    return outFile;
  }

  Future<File?> _resolveExecutable(String baseName, {String? fallback}) async {
    final root = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(root.path, 'sherpa_onnx', 'bin'));
    if (!await binDir.exists()) {
      return null;
    }

    final candidates = <String>[
      if (Platform.isWindows) '$baseName.exe' else baseName,
      if (fallback != null && Platform.isWindows) '$fallback.exe',
      if (fallback != null && !Platform.isWindows) fallback,
    ];

    for (final name in candidates) {
      final file = File(p.join(binDir.path, name));
      if (await file.exists()) {
        return file;
      }
    }

    return null;
  }
}

final sherpaOnnxLocalSpeechServiceProvider =
    Provider<SherpaOnnxLocalSpeechService>((ref) {
      return SherpaOnnxLocalSpeechService(
        modelDownloadService: ref.watch(sherpaOnnxModelDownloadServiceProvider),
      );
    });
