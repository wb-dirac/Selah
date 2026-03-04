import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/presentation/screens/widgets/feature_disabled_view.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagServiceProvider);
    if (!flags.isEnabled(AppFeatureModule.multimodalChat)) {
      return const FeatureDisabledView(
        title: '多模态对话已关闭',
        message: '请在 Feature Flag 中启用 multimodalChat 模块。',
      );
    }

    return const Scaffold(
      body: Center(child: Text('Chat Workspace')),
    );
  }
}
