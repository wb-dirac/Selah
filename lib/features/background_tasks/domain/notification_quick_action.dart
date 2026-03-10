const Duration kDefaultSnoozeDuration = Duration(minutes: 30);

enum NotificationQuickAction {
  snooze,
  done,
  handleNow,
}

extension NotificationQuickActionX on NotificationQuickAction {
  String get id {
    switch (this) {
      case NotificationQuickAction.snooze:
        return 'quick_action.snooze';
      case NotificationQuickAction.done:
        return 'quick_action.done';
      case NotificationQuickAction.handleNow:
        return 'quick_action.handle_now';
    }
  }

  String get label {
    switch (this) {
      case NotificationQuickAction.snooze:
        return '稍后提醒';
      case NotificationQuickAction.done:
        return '已完成';
      case NotificationQuickAction.handleNow:
        return '立即处理';
    }
  }

  static NotificationQuickAction? fromId(String id) {
    for (final action in NotificationQuickAction.values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

class NotificationQuickActionPayload {
  const NotificationQuickActionPayload({
    required this.taskId,
    required this.action,
    this.snoozeDuration = kDefaultSnoozeDuration,
  });

  final String taskId;
  final NotificationQuickAction action;
  final Duration snoozeDuration;
}

sealed class NotificationQuickActionResult {
  const NotificationQuickActionResult();
}

class QuickActionSnoozed extends NotificationQuickActionResult {
  const QuickActionSnoozed({
    required this.taskId,
    required this.resumeAt,
  });

  final String taskId;
  final DateTime resumeAt;
}

class QuickActionCompleted extends NotificationQuickActionResult {
  const QuickActionCompleted({required this.taskId});

  final String taskId;
}

class QuickActionOpenRequested extends NotificationQuickActionResult {
  const QuickActionOpenRequested({required this.taskId});

  final String taskId;
}

class QuickActionTaskNotFound extends NotificationQuickActionResult {
  const QuickActionTaskNotFound({required this.taskId});

  final String taskId;
}
