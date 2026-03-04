import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/presentation/screens/widgets/feature_disabled_view.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagServiceProvider);
    if (!flags.isEnabled(AppFeatureModule.backgroundTasks)) {
      return const FeatureDisabledView(
        title: '后台任务模块未启用',
        message: '当前版本默认关闭 backgroundTasks，可在后续阶段开启。',
      );
    }

    return const Scaffold(
      body: Center(child: Text('Tasks Workspace')),
    );
  }
}
