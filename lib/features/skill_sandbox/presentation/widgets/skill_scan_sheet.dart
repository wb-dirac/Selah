import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_installer.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_security_scanner.dart';

class SkillScanProgressSheet extends StatelessWidget {
  const SkillScanProgressSheet({
    super.key,
    required this.skillName,
    required this.version,
    required this.steps,
    required this.onCancel,
  });

  final String skillName;
  final String version;
  final List<InstallStep> steps;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final completed = steps
        .where((s) =>
            s.status == InstallStepStatus.passed ||
            s.status == InstallStepStatus.failed)
        .length;
    final progress = steps.isEmpty ? 0.0 : completed / steps.length;

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
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Icon(Icons.search, size: 22),
                const SizedBox(width: 8),
                Text(
                  '安全扫描中',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$skillName${version.isNotEmpty ? " v$version" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            ...steps.map((step) => _StepRow(step: step)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final InstallStep step;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (step.status) {
      case InstallStepStatus.passed:
        icon = const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case InstallStepStatus.failed:
        icon = const Icon(Icons.cancel, color: Colors.red, size: 18);
      case InstallStepStatus.running:
        icon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case InstallStepStatus.pending:
        icon = const Icon(Icons.radio_button_unchecked, size: 18, color: Colors.grey);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class SkillScanResultSheet extends StatelessWidget {
  const SkillScanResultSheet({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onCancel,
  });

  final SkillInstallResult result;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    switch (result.outcome) {
      case ScanOutcome.passed:
        return _PassedSheet(
          result: result,
          onConfirm: onConfirm,
          onCancel: onCancel,
        );
      case ScanOutcome.warning:
        return _WarningSheet(
          result: result,
          onConfirm: onConfirm,
          onCancel: onCancel,
        );
      case ScanOutcome.rejected:
        return _RejectedSheet(result: result, onCancel: onCancel);
    }
  }
}

class _PassedSheet extends StatelessWidget {
  const _PassedSheet({
    required this.result,
    required this.onConfirm,
    required this.onCancel,
  });

  final SkillInstallResult result;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DragHandle(),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Text(
                  '扫描通过',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${result.skillName}${result.version.isNotEmpty ? " v${result.version}" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '此 Skill 将获得以下权限：',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const _PermissionRow(
              icon: Icons.info_outline,
              title: 'Skill 脚本在沙箱中运行，无法访问你的通讯录、位置等隐私数据',
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(onPressed: onCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onConfirm, child: const Text('确认安装')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningSheet extends StatelessWidget {
  const _WarningSheet({
    required this.result,
    required this.onConfirm,
    required this.onCancel,
  });

  final SkillInstallResult result;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DragHandle(),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                Text(
                  '发现潜在风险',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${result.skillName}${result.version.isNotEmpty ? " v${result.version}" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              '发现以下问题，建议谨慎：',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...result.warnings.take(3).map(
                  (f) => _FindingRow(finding: f),
                ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                TextButton(onPressed: onCancel, child: const Text('取消安装')),
                TextButton(
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('忽略风险并安装'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedSheet extends StatelessWidget {
  const _RejectedSheet({required this.result, required this.onCancel});

  final SkillInstallResult result;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DragHandle(),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const Icon(Icons.block, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                Text(
                  '安装被拒绝',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${result.skillName}${result.version.isNotEmpty ? " v${result.version}" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              '发现以下明确违规，无法安装：',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...result.criticals.take(5).map((f) => _FindingRow(finding: f)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: onCancel, child: const Text('关闭')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final ScanFinding finding;

  @override
  Widget build(BuildContext context) {
    final isWarning = finding.severity == ScanSeverity.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 16,
            color: isWarning ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              finding.message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

Future<bool> showSkillInstallFlow({
  required BuildContext context,
  required String packageUrl,
  required SkillInstaller installer,
}) async {
  final steps = <InstallStep>[
    const InstallStep(label: '下载 Skill 包', status: InstallStepStatus.pending),
    const InstallStep(label: '解压校验结构', status: InstallStepStatus.pending),
    const InstallStep(label: 'SKILL.md 格式校验', status: InstallStepStatus.pending),
    const InstallStep(label: '脚本静态扫描', status: InstallStepStatus.pending),
    const InstallStep(label: 'Prompt 注入检测', status: InstallStepStatus.pending),
  ];

  final progressNotifier = ValueNotifier<List<InstallStep>>(steps);

  if (!context.mounted) return false;

  unawaited(showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    builder: (_) => ValueListenableBuilder<List<InstallStep>>(
      valueListenable: progressNotifier,
      builder: (ctx, currentSteps, _) => SkillScanProgressSheet(
        skillName: '加载中…',
        version: '',
        steps: currentSteps,
        onCancel: () => Navigator.pop(ctx),
      ),
    ),
  ));

  SkillInstallResult result;
  try {
    result = await installer.installFromUrl(
      packageUrl,
      onProgress: (updated) {
        progressNotifier.value = updated;
      },
    );
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    progressNotifier.dispose();
    return false;
  }

  if (!context.mounted) {
    progressNotifier.dispose();
    return false;
  }

  Navigator.pop(context);
  progressNotifier.dispose();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (_) => SkillScanResultSheet(
      result: result,
      onConfirm: () => Navigator.pop(context, true),
      onCancel: () => Navigator.pop(context, false),
    ),
  );

  return confirmed ?? false;
}
