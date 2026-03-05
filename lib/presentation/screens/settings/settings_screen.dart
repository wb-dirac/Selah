import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('LLM 提供商管理'),
            subtitle: const Text('列表 / 添加 / 编辑 / 删除 / 可用性测试'),
            onTap: () => context.push('/settings/providers'),
          ),
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('模型路由规则'),
            subtitle: const Text('按复杂度/模态设置目标与 Fallback'),
            onTap: () => context.push('/settings/routing'),
          ),
          ListTile(
            leading: const Icon(Icons.cable_outlined),
            title: const Text('网络代理'),
            subtitle: const Text('系统代理（有则使用）/ 自定义 HTTP、SOCKS5'),
            onTap: () => context.push('/settings/proxy'),
          ),
          const Divider(height: 1),
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
