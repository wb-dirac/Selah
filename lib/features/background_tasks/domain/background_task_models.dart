enum BackgroundTaskType {
  cron,
  relative,
  location,
  condition,
  event,
  periodic,
}

enum BackgroundTaskStatus {
  active,
  paused,
  completed,
  failed,
}

enum TaskActionType {
  sendNotification,
  executeSkill,
  silentLog,
}

class CronTrigger {
  const CronTrigger({required this.expression});

  final String expression;

  @override
  String toString() => 'CronTrigger($expression)';
}

class RelativeTrigger {
  const RelativeTrigger({required this.offset});

  final Duration offset;

  @override
  String toString() => 'RelativeTrigger(${offset.inMinutes}m)';
}

class LocationTrigger {
  const LocationTrigger({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.onEnter = true,
    this.onExit = false,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool onEnter;
  final bool onExit;
}

class ConditionTrigger {
  const ConditionTrigger({
    required this.conditionPrompt,
    required this.checkInterval,
  });

  final String conditionPrompt;
  final Duration checkInterval;
}

class EventTrigger {
  const EventTrigger({
    required this.webhookPath,
    this.keywordFilter,
  });

  final String webhookPath;
  final String? keywordFilter;
}

class TaskAction {
  const TaskAction({
    required this.type,
    this.notificationTitle,
    this.notificationBody,
    this.skillId,
    this.skillArgs = const <String, dynamic>{},
  });

  final TaskActionType type;
  final String? notificationTitle;
  final String? notificationBody;
  final String? skillId;
  final Map<String, dynamic> skillArgs;
}

class BackgroundTask {
  const BackgroundTask({
    required this.id,
    required this.type,
    required this.label,
    required this.action,
    this.cronTrigger,
    this.relativeTrigger,
    this.locationTrigger,
    this.conditionTrigger,
    this.eventTrigger,
    this.status = BackgroundTaskStatus.active,
    this.nextRunAt,
    this.lastRunAt,
    this.createdAt,
  });

  final String id;
  final BackgroundTaskType type;
  final String label;
  final TaskAction action;
  final CronTrigger? cronTrigger;
  final RelativeTrigger? relativeTrigger;
  final LocationTrigger? locationTrigger;
  final ConditionTrigger? conditionTrigger;
  final EventTrigger? eventTrigger;
  final BackgroundTaskStatus status;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final DateTime? createdAt;

  BackgroundTask copyWith({
    BackgroundTaskStatus? status,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
  }) {
    return BackgroundTask(
      id: id,
      type: type,
      label: label,
      action: action,
      cronTrigger: cronTrigger,
      relativeTrigger: relativeTrigger,
      locationTrigger: locationTrigger,
      conditionTrigger: conditionTrigger,
      eventTrigger: eventTrigger,
      status: status ?? this.status,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      createdAt: createdAt,
    );
  }
}

enum TaskExecutionResult {
  notificationSent,
  actionExecuted,
  silentSkip,
  failed,
}

class TaskExecutionLog {
  const TaskExecutionLog({
    required this.taskId,
    required this.scheduledTime,
    required this.actualExecutionTime,
    required this.result,
    required this.inferenceTimeMs,
    required this.usedLocalModel,
    this.errorMessage,
    this.notificationTitle,
  });

  final String taskId;
  final DateTime scheduledTime;
  final DateTime actualExecutionTime;
  final TaskExecutionResult result;
  final int inferenceTimeMs;
  final bool usedLocalModel;
  final String? errorMessage;
  final String? notificationTitle;
}

abstract final class ScheduledTaskIds {
  static const String morningBriefing = 'com.personal-ai.tasks.morning_briefing';
  static const String locationReminder = 'com.personal-ai.tasks.location_reminder';
  static const String conditionCheck = 'com.personal-ai.tasks.condition_check';
  static const String periodicSummary = 'com.personal-ai.tasks.periodic_summary';
}
