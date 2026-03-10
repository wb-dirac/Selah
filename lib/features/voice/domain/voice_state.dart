enum VoiceMode { local, googleLive }

enum VoiceSessionStatus { idle, listening, processing, speaking, bargeIn }

class VoiceSubtitle {
  const VoiceSubtitle({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class VoiceSession {
  const VoiceSession({
    this.status = VoiceSessionStatus.idle,
    this.mode = VoiceMode.local,
    this.subtitles = const <VoiceSubtitle>[],
    this.isMuted = false,
    this.durationSeconds = 0,
    this.completedActions = const <String>[],
    this.summary,
  });

  final VoiceSessionStatus status;
  final VoiceMode mode;
  final List<VoiceSubtitle> subtitles;
  final bool isMuted;
  final int durationSeconds;
  final List<String> completedActions;
  final String? summary;

  VoiceSession copyWith({
    VoiceSessionStatus? status,
    VoiceMode? mode,
    List<VoiceSubtitle>? subtitles,
    bool? isMuted,
    int? durationSeconds,
    List<String>? completedActions,
    String? summary,
  }) {
    return VoiceSession(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      subtitles: subtitles ?? this.subtitles,
      isMuted: isMuted ?? this.isMuted,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completedActions: completedActions ?? this.completedActions,
      summary: summary ?? this.summary,
    );
  }
}
