import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/features/voice/data/sherpa_onnx_model_download_service.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class SherpaOnnxLocalSpeechService {
  const SherpaOnnxLocalSpeechService({required this.modelDownloadService});

  final SherpaOnnxModelDownloadService modelDownloadService;

  static bool _bindingsInitialized = false;

  String get backendStatusDescription {
    return '当前使用 sherpa_onnx 官方 Flutter 插件加载本地动态库并执行离线 STT/TTS。';
  }

  Future<bool> isLocalTtsReady() async {
    if (!await modelDownloadService.isModelReady(SherpaModelKind.tts)) {
      return false;
    }
    return _ensureBindingsInitialized();
  }

  Future<bool> isLocalSttReady() async {
    if (!await modelDownloadService.isModelReady(SherpaModelKind.stt)) {
      return false;
    }
    return _ensureBindingsInitialized();
  }

  Future<String?> transcribeFile(String audioPath) async {
    if (!await isLocalSttReady()) {
      return null;
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      return null;
    }

    final modelDir = await modelDownloadService.getModelDirectory(SherpaModelKind.stt);
    final modelPath = await _resolveFirstExisting(
      modelDir,
      const <String>['model.int8.onnx', 'model.onnx'],
    );
    final tokensPath = await _resolveFirstExisting(
      modelDir,
      const <String>['tokens.txt'],
    );
    if (modelPath == null || tokensPath == null) {
      return null;
    }

    sherpa_onnx.OfflineRecognizer? recognizer;
    sherpa_onnx.OfflineStream? stream;
    try {
      final waveData = sherpa_onnx.readWave(audioPath);
      if (waveData.sampleRate <= 0 || waveData.samples.isEmpty) {
        return null;
      }

      final config = sherpa_onnx.OfflineRecognizerConfig(
        feat: const sherpa_onnx.FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: sherpa_onnx.OfflineModelConfig(
          senseVoice: sherpa_onnx.OfflineSenseVoiceModelConfig(
            model: modelPath,
            language: '',
            useInverseTextNormalization: true,
          ),
          tokens: tokensPath,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      );
      recognizer = sherpa_onnx.OfflineRecognizer(config);
      stream = recognizer.createStream();
      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      stream?.free();
      recognizer?.free();
    }
  }

  Future<File?> synthesizeToFile(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    if (!await isLocalTtsReady()) {
      return null;
    }

    final modelDir = await modelDownloadService.getModelDirectory(SherpaModelKind.tts);
    final modelPath = await _resolveFirstExisting(
      modelDir,
      const <String>['model.onnx', 'model.int8.onnx'],
    );
    final lexiconPath = await _resolveFirstExisting(
      modelDir,
      const <String>['lexicon.txt'],
    );
    final tokensPath = await _resolveFirstExisting(
      modelDir,
      const <String>['tokens.txt'],
    );
    if (modelPath == null || lexiconPath == null || tokensPath == null) {
      return null;
    }

    final tmpDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tmpDir.path,
      'sherpa_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    sherpa_onnx.OfflineTts? tts;
    try {
      final config = sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: lexiconPath,
            tokens: tokensPath,
            dataDir: modelDir.path,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      );
      tts = sherpa_onnx.OfflineTts(config);
      final audio = tts.generate(text: normalized, speed: 1.0);
      final ok = sherpa_onnx.writeWave(
        filename: outputPath,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      if (!ok) {
        return null;
      }

      final outFile = File(outputPath);
      if (!await outFile.exists()) {
        return null;
      }

      return outFile;
    } catch (_) {
      return null;
    } finally {
      tts?.free();
    }
  }

  bool _ensureBindingsInitialized() {
    if (_bindingsInitialized) {
      return true;
    }
    try {
      sherpa_onnx.initBindings();
      _bindingsInitialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveFirstExisting(
    Directory dir,
    List<String> fileNames,
  ) async {
    for (final name in fileNames) {
      final file = File(p.join(dir.path, name));
      if (await file.exists()) {
        return file.path;
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
