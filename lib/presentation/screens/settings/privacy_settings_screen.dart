import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/data_retention_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/privacy_preferences_service.dart';
import 'package:personal_ai_assistant/features/privacy/presentation/widgets/clear_all_data_dialog.dart';

final privacyRetentionDaysProvider = FutureProvider<int>((ref) {
  return ref.watch(dataRetentionServiceProvider).getRetentionDays();
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(privacyPreferencesProvider);
    final retentionAsync = ref.watch(privacyRetentionDaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('隐私与安全')),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载隐私设置失败：$error')),
        data: (preferences) {
          final retentionDays = retentionAsync.asData?.value ?? 90;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('本地存储已加密'),
                  subtitle: const Text('SQLCipher · KeyChain / KeyStore'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('图片处理方式'),
                      subtitle: Text(preferences.imageProcessingMode.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changeImageMode(context, ref, preferences),
                    ),
                    SwitchListTile(
                      value: preferences.piiDetectionEnabled,
                      title: const Text('PII 检测'),
                      subtitle: const Text('识别手机号、身份证号、银行卡号'),
                      onChanged: (value) => _savePreferences(
                        ref,
                        preferences.copyWith(piiDetectionEnabled: value),
                      ),
                    ),
                    SwitchListTile(
                      value: preferences.sendBeforeConfirmEnabled,
                      title: const Text('发送前确认模式'),
                      subtitle: const Text('发送前预览 Prompt 与脱敏版本'),
                      onChanged: (value) => _savePreferences(
                        ref,
                        preferences.copyWith(sendBeforeConfirmEnabled: value),
                      ),
                    ),
                    SwitchListTile(
                      value: preferences.replaceContactNamesEnabled,
                      title: const Text('联系人姓名代号替换'),
                      subtitle: const Text('会话内保持一致的联系人代号'),
                      onChanged: (value) => _savePreferences(
                        ref,
                        preferences.copyWith(replaceContactNamesEnabled: value),
                      ),
                    ),
                    SwitchListTile(
                      value: preferences.imageCloudConfirmationEnabled,
                      title: const Text('图片云端发送前确认'),
                      subtitle: const Text('发送图片到云端多模态模型前弹窗确认'),
                      onChanged: (value) => _savePreferences(
                        ref,
                        preferences.copyWith(imageCloudConfirmationEnabled: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('对话历史保留时间'),
                      subtitle: Text('$retentionDays 天'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _changeRetentionDays(context, ref),
                    ),
                    ListTile(
                      title: const Text('一键清除所有本地数据'),
                      subtitle: const Text('删除对话、索引、偏好与本地缓存'),
                      trailing: const Icon(Icons.delete_outline, color: Colors.red),
                      onTap: () => ClearAllDataDialog.show(context, ref),
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

  Future<void> _savePreferences(
    WidgetRef ref,
    PrivacyPreferences next,
  ) async {
    await ref.read(privacyPreferencesServiceProvider).save(next);
    ref.invalidate(privacyPreferencesProvider);
  }

  Future<void> _changeImageMode(
    BuildContext context,
    WidgetRef ref,
    PrivacyPreferences current,
  ) async {
    final mode = await showModalBottomSheet<ImageProcessingMode>(
      context: context,
      builder: (dialogContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageProcessingMode.values
                .map(
                  (mode) => ListTile(
                    title: Text(mode.label),
                    trailing: mode == current.imageProcessingMode
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(dialogContext).pop(mode),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (mode == null) {
      return;
    }
    await _savePreferences(ref, current.copyWith(imageProcessingMode: mode));
  }

  Future<void> _changeRetentionDays(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (dialogContext) {
        const options = <int>[30, 90, 180, 365];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (days) => ListTile(
                    title: Text('$days 天'),
                    onTap: () => Navigator.of(dialogContext).pop(days),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    await ref.read(dataRetentionServiceProvider).setRetentionDays(result);
    ref.invalidate(privacyRetentionDaysProvider);
  }
}
