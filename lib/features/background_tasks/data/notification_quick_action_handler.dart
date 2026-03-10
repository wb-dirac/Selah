import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/background_task_registry.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/notification_quick_action.dart';

class NotificationQuickActionHandler {
  NotificationQuickActionHandler({
    required BackgroundTaskRegistryNotifier registry,
  }) : _registry = registry;

  final BackgroundTaskRegistryNotifier _registry;

  NotificationQuickActionResult handle(
    NotificationQuickActionPayload payload,
    BackgroundTaskRegistryState registryState,
  ) {
    final task = registryState.tasks.cast<BackgroundTask?>().firstWhere(
          (t) => t!.id == payload.taskId,
          orElse: () => null,
        );

    if (task == null) {
      return QuickActionTaskNotFound(taskId: payload.taskId);
    }

    switch (payload.action) {
      case NotificationQuickAction.snooze:
        return _snooze(task, payload.snoozeDuration);
      case NotificationQuickAction.done:
        return _markDone(task);
      case NotificationQuickAction.handleNow:
        return _handleNow(task);
    }
  }

  NotificationQuickActionResult _snooze(
    BackgroundTask task,
    Duration snoozeDuration,
  ) {
    final resumeAt = DateTime.now().add(snoozeDuration);
    _registry.updateTask(
      task.copyWith(
        status: BackgroundTaskStatus.paused,
        nextRunAt: resumeAt,
      ),
    );
    return QuickActionSnoozed(taskId: task.id, resumeAt: resumeAt);
  }

  NotificationQuickActionResult _markDone(BackgroundTask task) {
    _registry.updateTask(
      task.copyWith(status: BackgroundTaskStatus.completed),
    );
    return QuickActionCompleted(taskId: task.id);
  }

  NotificationQuickActionResult _handleNow(BackgroundTask task) {
    return QuickActionOpenRequested(taskId: task.id);
  }
}

final notificationQuickActionHandlerProvider =
    Provider<NotificationQuickActionHandler>((ref) {
  return NotificationQuickActionHandler(
    registry: ref.watch(backgroundTaskRegistryProvider.notifier),
  );
});
