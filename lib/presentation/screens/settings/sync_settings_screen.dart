import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/github_gist_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/sync_settings_service.dart';
import 'package:personal_ai_assistant/features/privacy/presentation/widgets/sync_conflict_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  title: Text(
                    settings.connected
                        ? 'GitHub Gist 已连接'
                        : 'GitHub Gist 未连接',
                  ),
                  subtitle: Text(
                    settings.connected
                        ? '${settings.githubUsername ?? '未知账号'}\n上次同步: ${settings.lastSyncAt?.toLocal() ?? '尚未同步'} · ${settings.lastSyncStatus.label}'
                        : '通过 GitHub Device Flow 授权，同步加密设置',
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
                      subtitle: Text(
                        settings.passphraseConfigured
                            ? ref
                                    .read(syncSettingsServiceProvider)
                                    .hasSessionPassphrase
                                ? '已设置（本次会话有效）'
                                : '已配置（需重新输入）'
                            : '未设置',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editPassphrase(context, ref),
                    ),
                    ListTile(
                      title: Text(
                        settings.connected ? '断开 GitHub 连接' : '连接 GitHub 账号',
                      ),
                      trailing: Icon(
                        settings.connected ? Icons.link_off : Icons.link,
                      ),
                      onTap: () => settings.connected
                          ? _disconnect(context, ref)
                          : _connect(context, ref),
                    ),
                    ListTile(
                      title: const Text('立即同步'),
                      trailing: const Icon(Icons.sync),
                      onTap: settings.connected
                          ? () => _manualSync(context, ref)
                          : null,
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
    final service = ref.read(syncSettingsServiceProvider);

    GitHubDeviceCodeResponse deviceCodeResponse;
    try {
      deviceCodeResponse = await service.initiateDeviceFlow();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法启动 GitHub 授权：$e')),
      );
      return;
    }

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (sheetContext) => _OAuthBottomSheet(
        deviceCodeResponse: deviceCodeResponse,
        service: service,
      ),
    );

    if (result == true) {
      ref.invalidate(syncSettingsProvider);
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('断开 GitHub 连接'),
        content: const Text('确认断开连接？本地同步记录将被清除，已加密的 Gist 数据不受影响。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('断开'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Passphrase',
              helperText: '密码仅保存在本次会话中，不会写入磁盘',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    ref.read(syncSettingsServiceProvider).setPassphrase(result);
    ref.invalidate(syncSettingsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步密码已设置（仅本次会话有效）')),
    );
  }

  Future<void> _manualSync(BuildContext context, WidgetRef ref) async {
    final service = ref.read(syncSettingsServiceProvider);

    if (!service.hasSessionPassphrase) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先设置同步密码后再进行同步'),
          action: SnackBarAction(label: '设置', onPressed: _noOp),
        ),
      );
      await _editPassphrase(context, ref);
      if (!service.hasSessionPassphrase) return;
    }

    if (!context.mounted) return;

    final progressKey = GlobalKey<State>();
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: progressKey,
        content: const Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在同步...'),
          ],
        ),
      ),
    );
    unawaited(dialogFuture);

    final result = await service.performSync();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    switch (result) {
      case SyncSuccess():
        ref.invalidate(syncSettingsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步成功')),
        );

      case SyncConflict(:final localPayload,
          :final remotePayload,
          :final localTimestamp,
          :final remoteTimestamp):
        if (!context.mounted) return;
        final choice = await showSyncConflictDialog(
          context: context,
          localPayload: localPayload,
          remotePayload: remotePayload,
          localTimestamp: localTimestamp,
          remoteTimestamp: remoteTimestamp,
        );

        if (choice == null || !context.mounted) return;

        try {
          if (choice == SyncConflictChoice.keepLocal) {
            await service.pushLocalPayload(result);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已保留本地版本并推送至远端')),
            );
          } else {
            await service.applyRemotePayload(result);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已应用远端版本')),
            );
          }
          ref.invalidate(syncSettingsProvider);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('冲突处理失败：$e')),
          );
        }

      case SyncError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  static void _noOp() {}
}

class _OAuthBottomSheet extends StatefulWidget {
  const _OAuthBottomSheet({
    required this.deviceCodeResponse,
    required this.service,
  });

  final GitHubDeviceCodeResponse deviceCodeResponse;
  final SyncSettingsService service;

  @override
  State<_OAuthBottomSheet> createState() => _OAuthBottomSheetState();
}

class _OAuthBottomSheetState extends State<_OAuthBottomSheet> {
  StreamSubscription<GitHubTokenResult>? _subscription;
  bool _isPolling = true;
  String? _errorMessage;
  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _subscription = widget.service
        .connectWithOAuth(
          deviceCode: widget.deviceCodeResponse.deviceCode,
          intervalSeconds: widget.deviceCodeResponse.interval,
        )
        .listen(
          _onTokenResult,
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _isPolling = false;
                _errorMessage = '授权过程中出现错误：$e';
              });
            }
          },
        );
  }

  void _onTokenResult(GitHubTokenResult result) {
    if (!mounted) return;

    switch (result) {
      case GitHubTokenSuccess():
        Navigator.of(context).pop(true);
      case GitHubTokenPending():
        if (!_isPolling) {
          setState(() => _isPolling = true);
        }
      case GitHubTokenError(:final message):
        setState(() {
          _isPolling = false;
          _errorMessage = message;
        });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openVerificationUrl() async {
    final uri = Uri.tryParse(widget.deviceCodeResponse.verificationUri);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: widget.deviceCodeResponse.userCode),
    );
    if (mounted) {
      setState(() => _codeCopied = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _codeCopied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + mediaQuery.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.key_outlined),
              const SizedBox(width: 8),
              Text(
                '步骤 1/2：设备授权',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: '取消',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '请在浏览器中访问以下网址并输入授权码：',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openVerificationUrl,
            child: Text(
              widget.deviceCodeResponse.verificationUri,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      widget.deviceCodeResponse.userCode,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _codeCopied ? '已复制' : '点击复制',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonal(
                onPressed: () {
                  _subscription?.cancel();
                  setState(() {
                    _isPolling = true;
                    _errorMessage = null;
                  });
                  _startPolling();
                },
                child: const Text('重试'),
              ),
            ),
          ] else if (_isPolling) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '正在等待授权...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
