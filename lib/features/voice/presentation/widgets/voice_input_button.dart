import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.mic_outlined),
      tooltip: '语音对话',
      onPressed: enabled ? () => context.push('/chat/voice') : null,
    );
  }
}
