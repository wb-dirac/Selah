import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/accessibility/data/accessibility_settings_service.dart';

class AccessibilitySettingsScreen extends ConsumerWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(accessibilitySettingsProvider);
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('无障碍')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载无障碍设置失败：$error')),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: const Text('系统无障碍状态'),
                  subtitle: Text(
                    '高对比度: ${mediaQuery.highContrast ? '开启' : '关闭'}\n'
                    '减少动效: ${mediaQuery.disableAnimations ? '开启' : '关闭'}\n'
                    '字体缩放: ${mediaQuery.textScaler.scale(1).toStringAsFixed(2)}x',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings.forceHighContrast,
                      title: const Text('增强高对比度'),
                      subtitle: const Text('为主要界面启用更强的对比度与边界显示'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(forceHighContrast: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.reduceMotion,
                      title: const Text('减少动态效果'),
                      subtitle: const Text('减少主题切换与界面动画'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(reduceMotion: value),
                      ),
                    ),
                    SwitchListTile(
                      value: settings.respectSystemTextScale,
                      title: const Text('跟随系统字体大小'),
                      subtitle: const Text('按系统字体缩放显示文本'),
                      onChanged: (value) => _save(
                        ref,
                        settings.copyWith(respectSystemTextScale: value),
                      ),
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

  Future<void> _save(WidgetRef ref, AccessibilitySettings settings) async {
    await ref.read(accessibilitySettingsServiceProvider).save(settings);
    ref.invalidate(accessibilitySettingsProvider);
  }
}
