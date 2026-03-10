import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/voice/data/google_live_voice_service.dart';
import 'package:personal_ai_assistant/features/voice/data/local_tts_service.dart';
import 'package:personal_ai_assistant/features/voice/data/whisper_stt_service.dart';
import 'package:personal_ai_assistant/features/voice/domain/voice_state.dart';

class VoiceSessionNotifier extends Notifier<VoiceSession> {
  Timer? _durationTimer;
  StreamSubscription<dynamic>? _sttSub;
  StreamSubscription<dynamic>? _liveChunkSub;

  @override
  VoiceSession build() => const VoiceSession();

  Future<void> startLocalSession() async {
    state = const VoiceSession(
      status: VoiceSessionStatus.listening,
      mode: VoiceMode.local,
    );
    _startDurationTimer();
    await _listenLocal();
  }

  Future<void> _listenLocal() async {
    final stt = ref.read(whisperSttServiceProvider);
    _sttSub = stt.startListeningStream().listen(
      (text) async {
        _addSubtitle(text, isUser: true);
        state = state.copyWith(status: VoiceSessionStatus.processing);
        state = state.copyWith(status: VoiceSessionStatus.speaking);
        final tts = ref.read(localTtsServiceProvider);
        await for (final _ in tts.speakStream(text)) {}
        state = state.copyWith(status: VoiceSessionStatus.listening);
        await _listenLocal();
      },
      onDone: () {
        state = state.copyWith(status: VoiceSessionStatus.idle);
      },
    );
  }

  Future<void> startGoogleLiveSession({required String apiKey}) async {
    state = const VoiceSession(
      status: VoiceSessionStatus.listening,
      mode: VoiceMode.googleLive,
    );
    _startDurationTimer();

    final liveService = ref.read(googleLiveVoiceServiceProvider);
    await liveService.connect(apiKey: apiKey);
    await liveService.startMicStreaming();

    _liveChunkSub = liveService.chunks.listen((chunk) {
      switch (chunk) {
        case VoiceLiveText(:final text, :final isUser):
          _addSubtitle(text, isUser: isUser);
          if (!isUser) {
            state = state.copyWith(status: VoiceSessionStatus.speaking);
          }
        case VoiceLiveAudio():
          break;
        case VoiceLiveDone():
          state = state.copyWith(status: VoiceSessionStatus.listening);
        case VoiceLiveError(:final message):
          _addSubtitle('错误: $message', isUser: false);
          state = state.copyWith(status: VoiceSessionStatus.idle);
      }
    });
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void bargeIn() {
    if (state.mode == VoiceMode.googleLive) {
      ref.read(googleLiveVoiceServiceProvider).sendBargeIn();
    }
    state = state.copyWith(status: VoiceSessionStatus.bargeIn);
  }

  Future<String?> endSession() async {
    _durationTimer?.cancel();
    await _sttSub?.cancel();
    await _liveChunkSub?.cancel();

    await ref.read(whisperSttServiceProvider).stopListening();
    await ref.read(localTtsServiceProvider).stop();
    await ref.read(googleLiveVoiceServiceProvider).disconnect();

    final summary = _buildSummary();
    state = state.copyWith(status: VoiceSessionStatus.idle, summary: summary);
    return summary;
  }

  void _addSubtitle(String text, {required bool isUser}) {
    final updated = List<VoiceSubtitle>.from(state.subtitles)
      ..add(VoiceSubtitle(text: text, isUser: isUser));
    state = state.copyWith(subtitles: updated);
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });
  }

  String _buildSummary() {
    if (state.subtitles.isEmpty) return '本次对话无内容';
    final lines = state.subtitles
        .where((s) => !s.isUser)
        .take(3)
        .map((s) => s.text)
        .join(' ');
    return lines.isEmpty ? '本次对话完成' : lines;
  }
}

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, VoiceSession>(
  VoiceSessionNotifier.new,
);
