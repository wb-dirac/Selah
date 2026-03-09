import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/sync_settings_service.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(syncSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('跨设备同步')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载同步配置失败：$error')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: Text(settings.connected ? 'GitHub Gist 已连接' : 'GitHub Gist 未连接'),
                  subtitle: Text(
                    settings.connected
                        ? '${settings.githubUsername ?? '未知账号'}\n上次同步: ${settings.lastSyncAt?.toLocal() ?? '尚未同步'} · ${settings.lastSyncStatus.label}'
                        : '配置 GitHub 用户名、同步项和同步密码',
                  ),
                  isThreeLine: settings.connected,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.syncProviderConfigs,
                      title: const Text('LLM 配置（不含 Key）'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(syncProviderConfigs: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.syncTaskDefinitions,
                      title: const Text('定时任务定义'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(syncTaskDefinitions: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.syncPreferences,
                      title: const Text('用户偏好设置'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(syncPreferences: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.syncInstalledSkills,
                      title: const Text('已安装 Skill 列表'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(syncInstalledSkills: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.syncConversationHistory,
                      title: const Text('对话历史'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(syncConversationHistory: value),
                      ),
                    ),
                    const ListTile(
                      title: Text('API Key'),
                      subtitle: Text('永不同步'),
                      trailing: Icon(Icons.lock_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('同步密码'),
                      subtitle: Text(settings.passphraseConfigured ? '已设置' : '未设置'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editPassphrase(context, ref),
                    ),
                    ListTile(
                      title: Text(settings.connected ? '断开 GitHub 连接' : '连接 GitHub 账号'),
                      trailing: Icon(
                        settings.connected ? Icons.link_off : Icons.link,
                      ),
                      onTap: () => settings.connected
                          ? _disconnect(ref)
                          : _connect(context, ref),
                    ),
                    ListTile(
                      title: const Text('立即同步'),
                      trailing: const Icon(Icons.sync),
                      onTap: settings.connected ? () => _manualSync(ref) : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(WidgetRef ref, SyncSettings settings) async {
    await ref.read(syncSettingsServiceProvider).save(settings);
    ref.invalidate(syncSettingsProvider);
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('连接 GitHub'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'GitHub 用户名'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    await ref.read(syncSettingsServiceProvider).connect(result);
    ref.invalidate(syncSettingsProvider);
  }

  Future<void> _disconnect(WidgetRef ref) async {
    await ref.read(syncSettingsServiceProvider).disconnect();
    ref.invalidate(syncSettingsProvider);
  }

  Future<void> _editPassphrase(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('设置同步密码'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    await ref.read(syncSettingsServiceProvider).setPassphrase(result);
    ref.invalidate(syncSettingsProvider);
  }

  Future<void> _manualSync(WidgetRef ref) async {
    await ref.read(syncSettingsServiceProvider).markManualSync(success: true);
    ref.invalidate(syncSettingsProvider);
  }
}
