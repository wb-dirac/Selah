import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/presentation/screens/widgets/feature_disabled_view.dart';

class AgentScreen extends ConsumerWidget {
  const AgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagServiceProvider);
    if (!flags.isEnabled(AppFeatureModule.a2aProtocol)) {
      return const FeatureDisabledView(
        title: 'A2A 模块未启用',
        message: '当前版本默认关闭 a2aProtocol，可在阶段性发布中开启。',
      );
    }

    return const Scaffold(
      body: Center(child: Text('Agent Workspace')),
    );
  }
}
