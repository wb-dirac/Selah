import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';

void main() {
  group('BackgroundTask', () {
    const action = TaskAction(
      type: TaskActionType.sendNotification,
      notificationTitle: '早报',
      notificationBody: '今日天气晴',
    );

    test('creates cron task with correct type', () {
      const task = BackgroundTask(
        id: 'task-1',
        type: BackgroundTaskType.cron,
        label: '每日早报',
        action: action,
        cronTrigger: CronTrigger(expression: '0 8 * * *'),
        status: BackgroundTaskStatus.active,
      );
      expect(task.type, BackgroundTaskType.cron);
      expect(task.cronTrigger?.expression, '0 8 * * *');
      expect(task.status, BackgroundTaskStatus.active);
    });

    test('creates relative trigger task', () {
      final task = BackgroundTask(
        id: 'task-2',
        type: BackgroundTaskType.relative,
        label: '3小时后提醒',
        action: action,
        relativeTrigger: RelativeTrigger(
          offset: const Duration(hours: 3),
        ),
      );
      expect(task.relativeTrigger?.offset.inHours, 3);
    });

    test('creates location trigger task', () {
      const task = BackgroundTask(
        id: 'task-3',
        type: BackgroundTaskType.location,
        label: '到公司提醒',
        action: action,
        locationTrigger: LocationTrigger(
          latitude: 39.9042,
          longitude: 116.4074,
          radiusMeters: 200,
          onEnter: true,
        ),
      );
      expect(task.locationTrigger?.radiusMeters, 200);
      expect(task.locationTrigger?.onEnter, isTrue);
      expect(task.locationTrigger?.onExit, isFalse);
    });

    test('creates condition trigger task', () {
      const task = BackgroundTask(
        id: 'task-4',
        type: BackgroundTaskType.condition,
        label: '气温提醒',
        action: action,
        conditionTrigger: ConditionTrigger(
          conditionPrompt: '当气温低于 10 度时提醒',
          checkInterval: Duration(hours: 1),
        ),
      );
      expect(task.conditionTrigger?.checkInterval.inHours, 1);
    });

    test('copyWith updates status and timestamps', () {
      const original = BackgroundTask(
        id: 'task-5',
        type: BackgroundTaskType.cron,
        label: '测试任务',
        action: action,
        status: BackgroundTaskStatus.active,
      );

      final paused = original.copyWith(
        status: BackgroundTaskStatus.paused,
        lastRunAt: DateTime(2026, 3, 9, 8),
      );

      expect(paused.id, original.id);
      expect(paused.status, BackgroundTaskStatus.paused);
      expect(paused.lastRunAt, DateTime(2026, 3, 9, 8));
      expect(paused.nextRunAt, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const original = BackgroundTask(
        id: 'task-6',
        type: BackgroundTaskType.periodic,
        label: '周期汇总',
        action: action,
      );
      final copy = original.copyWith();
      expect(copy.label, original.label);
      expect(copy.type, original.type);
    });
  });

  group('TaskExecutionLog', () {
    test('records inference time and model type', () {
      final log = TaskExecutionLog(
        taskId: 'task-1',
        scheduledTime: DateTime(2026, 3, 9, 8),
        actualExecutionTime: DateTime(2026, 3, 9, 8, 0, 1),
        result: TaskExecutionResult.notificationSent,
        inferenceTimeMs: 340,
        usedLocalModel: true,
        notificationTitle: '早报',
      );

      expect(log.inferenceTimeMs, 340);
      expect(log.usedLocalModel, isTrue);
      expect(log.result, TaskExecutionResult.notificationSent);
      expect(log.errorMessage, isNull);
    });

    test('records failed execution with error', () {
      final log = TaskExecutionLog(
        taskId: 'task-err',
        scheduledTime: DateTime(2026, 3, 9),
        actualExecutionTime: DateTime(2026, 3, 9, 0, 0, 1),
        result: TaskExecutionResult.failed,
        inferenceTimeMs: 0,
        usedLocalModel: false,
        errorMessage: 'model not loaded',
      );

      expect(log.result, TaskExecutionResult.failed);
      expect(log.errorMessage, 'model not loaded');
    });
  });

  group('ScheduledTaskIds', () {
    test('all IDs use reverse domain format', () {
      const ids = <String>[
        ScheduledTaskIds.morningBriefing,
        ScheduledTaskIds.locationReminder,
        ScheduledTaskIds.conditionCheck,
        ScheduledTaskIds.periodicSummary,
      ];
      for (final id in ids) {
        expect(id.startsWith('com.personal-ai.tasks.'), isTrue,
            reason: '$id does not use correct prefix');
      }
    });

    test('all IDs are unique', () {
      const ids = <String>[
        ScheduledTaskIds.morningBriefing,
        ScheduledTaskIds.locationReminder,
        ScheduledTaskIds.conditionCheck,
        ScheduledTaskIds.periodicSummary,
      ];
      expect(ids.toSet().length, ids.length);
    });
  });

  group('TaskAction', () {
    test('notification action has title and body', () {
      const action = TaskAction(
        type: TaskActionType.sendNotification,
        notificationTitle: '提醒',
        notificationBody: '请喝水',
      );
      expect(action.type, TaskActionType.sendNotification);
      expect(action.notificationTitle, '提醒');
    });

    test('skill action has skillId and args', () {
      const action = TaskAction(
        type: TaskActionType.executeSkill,
        skillId: 'weather-checker',
        skillArgs: <String, dynamic>{'city': 'Beijing'},
      );
      expect(action.skillId, 'weather-checker');
      expect(action.skillArgs['city'], 'Beijing');
    });
  });
}
