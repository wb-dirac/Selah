import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

sealed class VoiceLiveChunk {
  const VoiceLiveChunk();
}

class VoiceLiveText extends VoiceLiveChunk {
  VoiceLiveText(this.text, {this.isUser = false});
  final String text;
  final bool isUser;
}

class VoiceLiveAudio extends VoiceLiveChunk {
  VoiceLiveAudio(this.bytes);
  final Uint8List bytes;
}

class VoiceLiveDone extends VoiceLiveChunk {
  const VoiceLiveDone();
}

class VoiceLiveError extends VoiceLiveChunk {
  VoiceLiveError(this.message);
  final String message;
}

class GoogleLiveVoiceService {
  static const _kWsUrl =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent';

  WebSocket? _ws;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<dynamic>? _wsSub;
  final StreamController<VoiceLiveChunk> _outController =
      StreamController<VoiceLiveChunk>.broadcast();
  bool _isConnected = false;

  Stream<VoiceLiveChunk> get chunks => _outController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect({required String apiKey, String? systemPrompt}) async {
    final uri = Uri.parse('$_kWsUrl?key=$apiKey');
    _ws = await WebSocket.connect(uri.toString());
    _isConnected = true;

    final setup = {
      'setup': {
        'model': 'models/gemini-2.0-flash-live-001',
        'generation_config': {
          'response_modalities': ['AUDIO', 'TEXT'],
        },
        if (systemPrompt != null)
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
      },
    };
    _ws!.add(jsonEncode(setup));

    _wsSub = _ws!.listen(
      _onMessage,
      onError: (Object e) {
        _outController.add(VoiceLiveError(e.toString()));
      },
      onDone: () {
        _isConnected = false;
        _outController.add(const VoiceLiveDone());
      },
    );
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg =
        jsonDecode(raw as String) as Map<String, dynamic>;

    final serverContent = msg['serverContent'] as Map<String, dynamic>?;
    if (serverContent == null) return;

    final parts =
        (serverContent['modelTurn']?['parts'] as List<dynamic>?) ?? [];
    for (final part in parts) {
      final p = part as Map<String, dynamic>;
      if (p.containsKey('text')) {
        _outController.add(VoiceLiveText(p['text'] as String));
      } else if (p.containsKey('inlineData')) {
        final data = p['inlineData'] as Map<String, dynamic>;
        final bytes =
            base64Decode(data['data'] as String);
        _outController.add(VoiceLiveAudio(bytes));
      }
    }

    if ((serverContent['turnComplete'] as bool?) == true) {
      _outController.add(const VoiceLiveDone());
    }
  }

  Future<void> startMicStreaming() async {
    if (_ws == null || !_isConnected) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final tmpPath = '/dev/null';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: tmpPath,
    );
  }

  void sendTextTurn(String text) {
    if (_ws == null || !_isConnected) return;
    final msg = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    };
    _ws!.add(jsonEncode(msg));
  }

  void sendBargeIn() {
    if (_ws == null || !_isConnected) return;
    _ws!.add(jsonEncode({'realtimeInput': {'activityEnd': {}}}));
  }

  Future<void> disconnect() async {
    _isConnected = false;
    await _wsSub?.cancel();
    await _recorder.stop();
    await _ws?.close();
    _ws = null;
  }

  void dispose() {
    disconnect();
    _outController.close();
    _recorder.dispose();
  }
}

final googleLiveVoiceServiceProvider = Provider<GoogleLiveVoiceService>((ref) {
  final service = GoogleLiveVoiceService();
  ref.onDispose(service.dispose);
  return service;
});
