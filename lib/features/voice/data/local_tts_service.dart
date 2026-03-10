import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

const _kTtsBaseUrl = 'http://localhost:8880';

class LocalTtsService {
  LocalTtsService() : _player = AudioPlayer();

  final AudioPlayer _player;
  int _fileIndex = 0;

  Future<bool> isAvailable() async {
    try {
      final resp = await http
          .get(Uri.parse('$_kTtsBaseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Stream<String> speakStream(String text) async* {
    final sentences = _splitSentences(text);
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      final audioPath = await _synthesize(sentence);
      if (audioPath != null) {
        await _player.setFilePath(audioPath);
        await _player.play();
        await _player.processingStateStream
            .firstWhere((s) => s == ProcessingState.completed);
        yield sentence;
        final f = File(audioPath);
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  Future<String?> _synthesize(String text) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_kTtsBaseUrl/v1/audio/speech'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': text, 'voice': 'af_sky', 'speed': 1.0}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      final tmpDir = await getTemporaryDirectory();
      final path = '${tmpDir.path}/tts_${_fileIndex++}.wav';
      await File(path).writeAsBytes(resp.bodyBytes);
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  List<String> _splitSentences(String text) {
    return text
        .split(RegExp(r'(?<=[。！？!?.])'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  void dispose() {
    _player.dispose();
  }
}

final localTtsServiceProvider = Provider<LocalTtsService>((ref) {
  final service = LocalTtsService();
  ref.onDispose(service.dispose);
  return service;
});
