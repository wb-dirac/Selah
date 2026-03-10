import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const _kWhisperBaseUrl = 'http://localhost:8880';
const _kSilenceThresholdMs = 1200;

class WhisperSttService {
  WhisperSttService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _lastSoundAt;
  Timer? _silenceTimer;

  Future<bool> isAvailable() async {
    try {
      final resp = await http
          .get(Uri.parse('$_kWhisperBaseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> transcribeFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_kWhisperBaseUrl/inference'),
      )
        ..fields['language'] = 'auto'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['text'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Stream<String> startListeningStream() async* {
    final tmpDir = await getTemporaryDirectory();
    final path = '${tmpDir.path}/vad_chunk.m4a';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: path,
    );
    _lastSoundAt = DateTime.now();

    final controller = StreamController<String>();
    _silenceTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) async {
        final amplitude = await _recorder.getAmplitude();
        final db = amplitude.current;
        if (db > -40) {
          _lastSoundAt = DateTime.now();
        }
        final silent = _lastSoundAt != null &&
            DateTime.now().difference(_lastSoundAt!).inMilliseconds >
                _kSilenceThresholdMs;
        if (silent && await _recorder.isRecording()) {
          await _recorder.stop();
          _silenceTimer?.cancel();
          final text = await transcribeFile(path);
          if (text != null && text.isNotEmpty) {
            controller.add(text);
          }
          unawaited(controller.close());
        }
      },
    );

    yield* controller.stream;
  }

  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  void dispose() {
    _silenceTimer?.cancel();
    _recorder.dispose();
  }
}

final whisperSttServiceProvider = Provider<WhisperSttService>((ref) {
  final service = WhisperSttService();
  ref.onDispose(service.dispose);
  return service;
});
