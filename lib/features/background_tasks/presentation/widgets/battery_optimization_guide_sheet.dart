import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/background_task_scheduler_service.dart';

// Android-only bottom sheet that guides the user to exempt this app from
// battery optimisation. Shown when the first background task is created.
// Status is re-checked each time the user returns from system settings.

class BatteryOptimizationGuideSheet extends ConsumerStatefulWidget {
  const BatteryOptimizationGuideSheet({super.key});

  @override
  ConsumerState<BatteryOptimizationGuideSheet> createState() =>
      _BatteryOptimizationGuideSheetState();
}

class _BatteryOptimizationGuideSheetState
    extends ConsumerState<BatteryOptimizationGuideSheet>
    with WidgetsBindingObserver {
  bool _isBypassed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check after returning from system settings.
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    try {
      final scheduler = ref.read(backgroundTaskSchedulerServiceProvider);
      final bypassed = await scheduler.isBatteryOptimizationBypassed();
      if (mounted) {
        setState(() {
          _isBypassed = bypassed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_isBypassed)
              _BypassedContent(onClose: () => Navigator.pop(context))
            else
              _GuideContent(
                onOpenSettings: () async {
                  await ref
                      .read(backgroundTaskSchedulerServiceProvider)
                      .openBatteryOptimizationSettings();
                },
                onDismiss: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _BypassedContent extends StatelessWidget {
  const _BypassedContent({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              '已在白名单',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '此应用已被加入电池优化白名单，后台任务可以正常运行。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onClose,
            child: const Text('好的'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GuideContent extends StatelessWidget {
  const _GuideContent({
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.battery_alert,
              color: Theme.of(context).colorScheme.tertiary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '建议关闭电池优化',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '当前系统对本应用启用了电池优化，可能导致后台任务被延迟或中断。\n\n'
          '建议将本应用加入电池优化白名单，确保后台任务准时运行：\n\n'
          '  1. 点击下方"前往设置"\n'
          '  2. 在弹出对话框中选择"不优化"\n'
          '  3. 确认后返回即可',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('前往设置'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onDismiss,
            child: const Text('稍后再说'),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
