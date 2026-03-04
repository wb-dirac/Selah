import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagServiceProvider).snapshot();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const ListTile(title: Text('Feature Flags')),
          ...flags.entries.map(
            (entry) => SwitchListTile(
              value: entry.value,
              onChanged: null,
              title: Text(entry.key.name),
              subtitle: const Text('当前为基础只读模式，后续接入持久化开关'),
            ),
          ),
        ],
      ),
    );
  }
}
