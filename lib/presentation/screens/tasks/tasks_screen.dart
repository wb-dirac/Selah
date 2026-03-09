import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/background_task_registry.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';
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

    final registry = ref.watch(backgroundTaskRegistryProvider);
    final active = registry.active;
    final paused = registry.paused;
    final upcoming = _upcomingTasks(active);
    final periodic = _periodicTasks(active);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _openCreateTask(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建'),
          ),
        ],
      ),
      body: active.isEmpty && paused.isEmpty
          ? _EmptyTaskState(
              onCreateTap: () => _openCreateTask(context, ref),
            )
          : ListView(
              children: <Widget>[
                if (upcoming.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: '即将触发'),
                  ...upcoming.map(
                    (t) => _TaskTile(
                      task: t,
                      highlight: true,
                      onTap: () => _openDetail(context, ref, t),
                      onPause: () => ref
                          .read(backgroundTaskRegistryProvider.notifier)
                          .pauseTask(t.id),
                      onDelete: () => _confirmDelete(context, ref, t),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                if (periodic.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: '定期任务'),
                  ...periodic.map(
                    (t) => _TaskTile(
                      task: t,
                      onTap: () => _openDetail(context, ref, t),
                      onPause: () => ref
                          .read(backgroundTaskRegistryProvider.notifier)
                          .pauseTask(t.id),
                      onDelete: () => _confirmDelete(context, ref, t),
                    ),
                  ),
                ],
                if (paused.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _CollapsibleSection(
                    title: '已暂停 (${paused.length})',
                    children: paused
                        .map(
                          (t) => _TaskTile(
                            task: t,
                            dimmed: true,
                            onTap: () => _openDetail(context, ref, t),
                            onResume: () => ref
                                .read(backgroundTaskRegistryProvider.notifier)
                                .resumeTask(t.id),
                            onDelete: () => _confirmDelete(context, ref, t),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
    );
  }

  List<BackgroundTask> _upcomingTasks(List<BackgroundTask> active) {
    final now = DateTime.now();
    return active.where((t) {
      final next = t.nextRunAt;
      if (next == null) return false;
      return next.difference(now).inHours < 2;
    }).toList()
      ..sort((a, b) => (a.nextRunAt ?? DateTime(9999))
          .compareTo(b.nextRunAt ?? DateTime(9999)));
  }

  List<BackgroundTask> _periodicTasks(List<BackgroundTask> active) {
    return active
        .where((t) =>
            t.type == BackgroundTaskType.cron ||
            t.type == BackgroundTaskType.periodic ||
            t.type == BackgroundTaskType.location ||
            t.type == BackgroundTaskType.condition)
        .toList();
  }

  void _openCreateTask(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(
          onSave: (task) {
            ref
                .read(backgroundTaskRegistryProvider.notifier)
                .addTask(task);
            Navigator.pop(context);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, BackgroundTask task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskHistoryScreen(taskId: task.id, taskLabel: task.label),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BackgroundTask task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${task.label}」？'),
        content: const Text('删除后该任务及其执行历史将不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref
                  .read(backgroundTaskRegistryProvider.notifier)
                  .removeTask(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onDelete,
    this.highlight = false,
    this.dimmed = false,
    this.onPause,
    this.onResume,
  });

  final BackgroundTask task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool highlight;
  final bool dimmed;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: highlight
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
          : Colors.transparent,
      child: ListTile(
        leading: _TaskIcon(type: task.type, dimmed: dimmed),
        title: Text(
          task.label,
          style: dimmed
              ? TextStyle(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
        subtitle: _SubtitleText(task: task),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'pause':
                onPause?.call();
              case 'resume':
                onResume?.call();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            if (onPause != null)
              const PopupMenuItem(value: 'pause', child: Text('暂停')),
            if (onResume != null)
              const PopupMenuItem(value: 'resume', child: Text('恢复')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TaskIcon extends StatelessWidget {
  const _TaskIcon({required this.type, this.dimmed = false});

  final BackgroundTaskType type;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case BackgroundTaskType.cron:
        icon = Icons.schedule_outlined;
      case BackgroundTaskType.relative:
        icon = Icons.alarm_outlined;
      case BackgroundTaskType.location:
        icon = Icons.location_on_outlined;
      case BackgroundTaskType.condition:
        icon = Icons.rule_outlined;
      case BackgroundTaskType.event:
        icon = Icons.webhook_outlined;
      case BackgroundTaskType.periodic:
        icon = Icons.repeat_outlined;
    }
    return Icon(
      icon,
      color: dimmed
          ? Theme.of(context).colorScheme.outline
          : Theme.of(context).colorScheme.primary,
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({required this.task});

  final BackgroundTask task;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (task.nextRunAt != null) {
      return Text(_formatNextRun(task.nextRunAt!), style: style);
    }
    if (task.type == BackgroundTaskType.location &&
        task.locationTrigger != null) {
      return Text(
        '范围: ${task.locationTrigger!.radiusMeters.toInt()}m 内',
        style: style,
      );
    }
    return Text(task.type.name, style: style);
  }

  String _formatNextRun(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟后';
    if (diff.inHours < 24) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.schedule_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('暂无后台任务', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '新建任务，让助理在后台帮你处理事务',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('新建任务'),
          ),
        ],
      ),
    );
  }
}

class TaskEditScreen extends StatefulWidget {
  const TaskEditScreen({super.key, required this.onSave, this.existing});

  final void Function(BackgroundTask task) onSave;
  final BackgroundTask? existing;

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  BackgroundTaskType _type = BackgroundTaskType.cron;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _descCtrl = TextEditingController(
      text: e?.action.notificationBody ?? '',
    );
    if (e != null) _type = e.type;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        leadingWidth: 60,
        title: Text(widget.existing == null ? '新建任务' : '编辑任务'),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('任务名称', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '例：提醒回邮件',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '任务描述（告诉助理要做什么）',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '到时间提醒我...',
            ),
          ),
          const SizedBox(height: 16),
          Text('触发方式', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          ..._triggerOptions(),
          if (_type == BackgroundTaskType.cron ||
              _type == BackgroundTaskType.relative) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '─── 时间配置 ───',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('时间'),
              trailing: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),
          ],
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.lock_outline, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '触发时将运行本地模型进行决策推理',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _triggerOptions() {
    const options = <(BackgroundTaskType, String)>[
      (BackgroundTaskType.relative, '指定时间'),
      (BackgroundTaskType.cron, '固定时间'),
      (BackgroundTaskType.location, '位置触发'),
      (BackgroundTaskType.condition, '条件触发'),
    ];
    return [
      RadioGroup<BackgroundTaskType>(
        groupValue: _type,
        onChanged: (v) {
          if (v != null) setState(() => _type = v);
        },
        child: Column(
          children: options
              .map(
                (opt) => RadioListTile<BackgroundTaskType>(
                  value: opt.$1,
                  title: Text(opt.$2),
                  contentPadding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
      ),
    ];
  }

  void _save() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务名称')),
      );
      return;
    }

    final now = DateTime.now();
    final nextRun = DateTime(
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );

    final task = BackgroundTask(
      id: widget.existing?.id ??
          'task_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      label: label,
      action: TaskAction(
        type: TaskActionType.sendNotification,
        notificationTitle: label,
        notificationBody: _descCtrl.text.trim(),
      ),
      cronTrigger: _type == BackgroundTaskType.cron
          ? CronTrigger(expression: '0 ${_time.hour} * * *')
          : null,
      relativeTrigger: _type == BackgroundTaskType.relative
          ? RelativeTrigger(offset: nextRun.difference(now))
          : null,
      status: BackgroundTaskStatus.active,
      nextRunAt: nextRun,
      createdAt: widget.existing?.createdAt ?? now,
    );

    widget.onSave(task);
  }
}

class TaskHistoryScreen extends ConsumerWidget {
  const TaskHistoryScreen({
    super.key,
    required this.taskId,
    required this.taskLabel,
  });

  final String taskId;
  final String taskLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref
        .watch(backgroundTaskRegistryProvider)
        .logsFor(taskId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('执行历史', style: TextStyle(fontSize: 16)),
            Text(
              taskLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: logs.isEmpty
          ? const Center(child: Text('暂无执行记录'))
          : ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _LogTile(log: logs[index]);
              },
            ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final TaskExecutionLog log;

  @override
  Widget build(BuildContext context) {
    final resultOk = log.result != TaskExecutionResult.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                resultOk ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: resultOk ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(log.actualExecutionTime),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                _resultLabel(log.result),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (log.notificationTitle != null)
                  Text(
                    '操作：发送通知「${log.notificationTitle}」',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (log.result == TaskExecutionResult.silentSkip)
                  Text(
                    '操作：无需提醒，静默跳过',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (log.errorMessage != null)
                  Text(
                    '错误：${log.errorMessage}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    const Icon(Icons.lock_outline, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '推理耗时: ${(log.inferenceTimeMs / 1000).toStringAsFixed(1)}s · '
                      '${log.usedLocalModel ? '本地模型' : '云端模型'}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final prefix = isToday ? '今天' : '${dt.month}/${dt.day}';
    return '$prefix  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _resultLabel(TaskExecutionResult result) {
    switch (result) {
      case TaskExecutionResult.notificationSent:
        return '✅ 已触发';
      case TaskExecutionResult.actionExecuted:
        return '✅ 操作执行';
      case TaskExecutionResult.silentSkip:
        return '✅ 已触发 · 静默跳过';
      case TaskExecutionResult.failed:
        return '❌ 失败';
    }
  }
}
