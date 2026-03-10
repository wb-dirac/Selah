import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/background_task_registry.dart';
import 'package:personal_ai_assistant/features/background_tasks/data/notification_quick_action_handler.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/notification_quick_action.dart';

final _sampleTask = BackgroundTask(
  id: 'task_001',
  type: BackgroundTaskType.cron,
  label: '晨间简报',
  action: const TaskAction(
    type: TaskActionType.sendNotification,
    notificationTitle: '晨间简报',
    notificationBody: '今天的摘要已准备好',
  ),
  status: BackgroundTaskStatus.active,
  createdAt: DateTime(2025, 1, 1),
);

BackgroundTaskRegistryNotifier _registryNotifier(ProviderContainer c) =>
    c.read(backgroundTaskRegistryProvider.notifier);

BackgroundTaskRegistryState _registryState(ProviderContainer c) =>
    c.read(backgroundTaskRegistryProvider);

NotificationQuickActionHandler _handler(ProviderContainer c) =>
    c.read(notificationQuickActionHandlerProvider);

void main() {
  group('NotificationQuickAction enum', () {
    test('ids are unique and non-empty', () {
      final ids = NotificationQuickAction.values.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id, isNotEmpty);
      }
    });

    test('labels are non-empty', () {
      for (final action in NotificationQuickAction.values) {
        expect(action.label, isNotEmpty);
      }
    });

    test('fromId round-trips all values', () {
      for (final action in NotificationQuickAction.values) {
        expect(NotificationQuickActionX.fromId(action.id), action);
      }
    });

    test('fromId returns null for unknown id', () {
      expect(NotificationQuickActionX.fromId('unknown.action'), isNull);
    });

    test('snooze label is 稍后提醒', () {
      expect(NotificationQuickAction.snooze.label, '稍后提醒');
    });

    test('done label is 已完成', () {
      expect(NotificationQuickAction.done.label, '已完成');
    });

    test('handleNow label is 立即处理', () {
      expect(NotificationQuickAction.handleNow.label, '立即处理');
    });
  });

  group('NotificationQuickActionPayload', () {
    test('default snoozeDuration is 30 minutes', () {
      const payload = NotificationQuickActionPayload(
        taskId: 'task_001',
        action: NotificationQuickAction.snooze,
      );
      expect(payload.snoozeDuration, kDefaultSnoozeDuration);
      expect(payload.snoozeDuration.inMinutes, 30);
    });

    test('custom snoozeDuration respected', () {
      const payload = NotificationQuickActionPayload(
        taskId: 'task_001',
        action: NotificationQuickAction.snooze,
        snoozeDuration: Duration(minutes: 60),
      );
      expect(payload.snoozeDuration.inMinutes, 60);
    });
  });

  group('NotificationQuickActionHandler — task not found', () {
    test('returns QuickActionTaskNotFound for unknown task id', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final result = _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'nonexistent',
          action: NotificationQuickAction.done,
        ),
        _registryState(c),
      );

      expect(result, isA<QuickActionTaskNotFound>());
      expect((result as QuickActionTaskNotFound).taskId, 'nonexistent');
    });
  });

  group('NotificationQuickActionHandler — snooze', () {
    test('sets task status to paused', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.snooze,
        ),
        _registryState(c),
      );

      final updated = _registryState(c).tasks.first;
      expect(updated.status, BackgroundTaskStatus.paused);
    });

    test('sets nextRunAt to now + snoozeDuration', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      final before = DateTime.now();
      _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.snooze,
          snoozeDuration: Duration(minutes: 30),
        ),
        _registryState(c),
      );
      final after = DateTime.now();

      final nextRunAt = _registryState(c).tasks.first.nextRunAt!;
      expect(
        nextRunAt.isAfter(before.add(const Duration(minutes: 29))),
        isTrue,
      );
      expect(
        nextRunAt.isBefore(after.add(const Duration(minutes: 31))),
        isTrue,
      );
    });

    test('returns QuickActionSnoozed with correct taskId and resumeAt', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      final result = _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.snooze,
        ),
        _registryState(c),
      );

      expect(result, isA<QuickActionSnoozed>());
      final snoozed = result as QuickActionSnoozed;
      expect(snoozed.taskId, 'task_001');
      expect(snoozed.resumeAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('NotificationQuickActionHandler — done', () {
    test('sets task status to completed', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.done,
        ),
        _registryState(c),
      );

      final updated = _registryState(c).tasks.first;
      expect(updated.status, BackgroundTaskStatus.completed);
    });

    test('returns QuickActionCompleted', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      final result = _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.done,
        ),
        _registryState(c),
      );

      expect(result, isA<QuickActionCompleted>());
      expect((result as QuickActionCompleted).taskId, 'task_001');
    });
  });

  group('NotificationQuickActionHandler — handle now', () {
    test('does not modify task status', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.handleNow,
        ),
        _registryState(c),
      );

      final task = _registryState(c).tasks.first;
      expect(task.status, BackgroundTaskStatus.active);
    });

    test('returns QuickActionOpenRequested', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _registryNotifier(c).addTask(_sampleTask);

      final result = _handler(c).handle(
        const NotificationQuickActionPayload(
          taskId: 'task_001',
          action: NotificationQuickAction.handleNow,
        ),
        _registryState(c),
      );

      expect(result, isA<QuickActionOpenRequested>());
      expect((result as QuickActionOpenRequested).taskId, 'task_001');
    });
  });
}
