import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/voice/data/voice_session_notifier.dart';
import 'package:personal_ai_assistant/features/voice/domain/voice_state.dart';
import 'package:personal_ai_assistant/features/voice/presentation/screens/voice_summary_screen.dart';

class VoiceScreen extends ConsumerStatefulWidget {
  const VoiceScreen({super.key});

  @override
  ConsumerState<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends ConsumerState<VoiceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _subtitlesVisible = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    Future.microtask(
      () => ref.read(voiceSessionProvider.notifier).startLocalSession(),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _endSession() async {
    final summary =
        await ref.read(voiceSessionProvider.notifier).endSession();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VoiceSummaryScreen(summary: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(voiceSessionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0D1B2A), Color(0xFF1B2838)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: '结束',
                  onPressed: _endSession,
                ),
              ),
              Column(
                children: <Widget>[
                  const SizedBox(height: 48),
                  _WaveformAnimator(
                    controller: _animController,
                    status: session.status,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusLabel(session.status),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_subtitlesVisible)
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _subtitlesVisible = false),
                        child: _SubtitleArea(subtitles: session.subtitles),
                      ),
                    )
                  else
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _subtitlesVisible = true),
                        child: const Center(
                          child: Text(
                            '点击显示字幕',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                  _BottomControls(
                    isMuted: session.isMuted,
                    onMute: () =>
                        ref.read(voiceSessionProvider.notifier).toggleMute(),
                    onPause: _endSession,
                    modeName: session.mode == VoiceMode.googleLive
                        ? 'Gemini Live'
                        : 'Whisper.cpp',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(VoiceSessionStatus status) {
    switch (status) {
      case VoiceSessionStatus.idle:
        return '待机';
      case VoiceSessionStatus.listening:
        return '正在聆听...';
      case VoiceSessionStatus.processing:
        return '处理中...';
      case VoiceSessionStatus.speaking:
        return 'AI 正在说话';
      case VoiceSessionStatus.bargeIn:
        return '打断中...';
    }
  }
}

class _WaveformAnimator extends AnimatedWidget {
  const _WaveformAnimator({
    required AnimationController controller,
    required this.status,
  }) : super(listenable: controller);

  final VoiceSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _WaveformPainter(t: t, status: status),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.t, required this.status});

  final double t;
  final VoiceSessionStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.3;

    switch (status) {
      case VoiceSessionStatus.idle:
      case VoiceSessionStatus.bargeIn:
        _drawRipple(canvas, center, baseRadius * 0.6, Colors.blueGrey, t);
      case VoiceSessionStatus.listening:
        _drawBars(canvas, center, baseRadius, Colors.white, t);
      case VoiceSessionStatus.processing:
        _drawDots(canvas, center, baseRadius, const Color(0xFF4A90E2), t);
      case VoiceSessionStatus.speaking:
        _drawBars(canvas, center, baseRadius, const Color(0xFF2979FF), t);
    }
  }

  void _drawRipple(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double t,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 - t * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius + t * 8, paint);
    paint.color = color.withValues(alpha: 0.7);
    canvas.drawCircle(center, radius, paint);
  }

  void _drawBars(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double t,
  ) {
    const barCount = 5;
    const barWidth = 6.0;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (int i = 0; i < barCount; i++) {
      final x = center.dx - (barCount / 2 - i) * (barWidth + 6);
      final heightFactor =
          0.3 + 0.7 * math.sin((t + i / barCount) * math.pi).abs();
      final h = radius * heightFactor;
      canvas.drawLine(
        Offset(x, center.dy - h / 2),
        Offset(x, center.dy + h / 2),
        paint,
      );
    }
  }

  void _drawDots(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double t,
  ) {
    const dotCount = 8;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount + t * 0.5) * 2 * math.pi;
      final dotPos = Offset(
        center.dx + radius * 0.7 * math.cos(angle),
        center.dy + radius * 0.7 * math.sin(angle),
      );
      final alpha = 0.4 + 0.6 * ((math.sin(t * math.pi * 2 + i) + 1) / 2);
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(dotPos, 5, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.t != t || old.status != status;
}

class _SubtitleArea extends StatelessWidget {
  const _SubtitleArea({required this.subtitles});

  final List<VoiceSubtitle> subtitles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          padding: const EdgeInsets.all(12),
          child: subtitles.isEmpty
              ? const Center(
                  child: Text(
                    '',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: subtitles.length,
                  itemBuilder: (context, index) {
                    final sub = subtitles[subtitles.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        sub.text,
                        style: TextStyle(
                          color: sub.isUser ? Colors.white70 : Colors.white,
                          fontSize: sub.isUser ? 14 : 16,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isMuted,
    required this.onMute,
    required this.onPause,
    required this.modeName,
  });

  final bool isMuted;
  final VoidCallback onMute;
  final VoidCallback onPause;
  final String modeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: '静音',
            onTap: onMute,
            active: isMuted,
          ),
          _ControlButton(
            icon: Icons.pause,
            label: '暂停',
            onTap: onPause,
          ),
          _ControlButton(
            icon: Icons.cloud_outlined,
            label: modeName,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.red : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
