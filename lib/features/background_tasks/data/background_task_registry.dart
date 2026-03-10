import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/background_task_scheduler_service.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';

class BackgroundTaskRegistryState {
  const BackgroundTaskRegistryState({
    this.tasks = const <BackgroundTask>[],
    this.logs = const <String, List<TaskExecutionLog>>{},
  });

  final List<BackgroundTask> tasks;
  final Map<String, List<TaskExecutionLog>> logs;

  List<BackgroundTask> get active =>
      tasks.where((t) => t.status == BackgroundTaskStatus.active).toList();

  List<BackgroundTask> get paused =>
      tasks.where((t) => t.status == BackgroundTaskStatus.paused).toList();

  List<TaskExecutionLog> logsFor(String taskId) => logs[taskId] ?? const <TaskExecutionLog>[];

  BackgroundTaskRegistryState copyWith({
    List<BackgroundTask>? tasks,
    Map<String, List<TaskExecutionLog>>? logs,
  }) {
    return BackgroundTaskRegistryState(
      tasks: tasks ?? this.tasks,
      logs: logs ?? this.logs,
    );
  }
}

class BackgroundTaskRegistryNotifier
    extends Notifier<BackgroundTaskRegistryState> {
  @override
  BackgroundTaskRegistryState build() => const BackgroundTaskRegistryState();

  BackgroundTaskSchedulerService get _scheduler =>
      ref.read(backgroundTaskSchedulerServiceProvider);

  void addTask(BackgroundTask task) {
    state = state.copyWith(tasks: [...state.tasks, task]);
    _scheduler.scheduleTask(task);
  }

  void updateTask(BackgroundTask task) {
    final updated = state.tasks
        .map((t) => t.id == task.id ? task : t)
        .toList();
    state = state.copyWith(tasks: updated);
    // Reschedule if active, cancel if paused/completed/failed.
    if (task.status == BackgroundTaskStatus.active) {
      _scheduler.scheduleTask(task);
    } else {
      _scheduler.cancelTask(task.id);
    }
  }

  void removeTask(String taskId) {
    final updated = state.tasks.where((t) => t.id != taskId).toList();
    final updatedLogs = Map<String, List<TaskExecutionLog>>.from(state.logs)
      ..remove(taskId);
    state = BackgroundTaskRegistryState(tasks: updated, logs: updatedLogs);
    _scheduler.cancelTask(taskId);
  }

  void pauseTask(String taskId) {
    _setStatus(taskId, BackgroundTaskStatus.paused);
    _scheduler.cancelTask(taskId);
  }

  void resumeTask(String taskId) {
    _setStatus(taskId, BackgroundTaskStatus.active);
    final task = state.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      _scheduler.scheduleTask(task);
    }
  }

  void appendLog(String taskId, TaskExecutionLog log) {
    final existing = List<TaskExecutionLog>.from(state.logs[taskId] ?? <TaskExecutionLog>[]);
    existing.insert(0, log);
    final updatedLogs = Map<String, List<TaskExecutionLog>>.from(state.logs)
      ..[taskId] = existing;
    state = state.copyWith(logs: updatedLogs);
  }

  void _setStatus(String taskId, BackgroundTaskStatus status) {
    final updated = state.tasks
        .map((t) => t.id == taskId ? t.copyWith(status: status) : t)
        .toList();
    state = state.copyWith(tasks: updated);
  }
}

final backgroundTaskRegistryProvider = NotifierProvider<
    BackgroundTaskRegistryNotifier, BackgroundTaskRegistryState>(
  BackgroundTaskRegistryNotifier.new,
);
