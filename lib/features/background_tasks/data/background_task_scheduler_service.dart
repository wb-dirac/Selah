import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';
import 'package:workmanager/workmanager.dart';

// =============================================================================
// Desktop platform channel setup instructions
// =============================================================================
//
// macOS (LaunchAgent):
//   The macOS runner must implement the method channel handler in
//   macos/Runner/AppDelegate.swift (or MainFlutterWindow.swift).
//   Steps to schedule a LaunchAgent plist programmatically:
//     1. Create ~/Library/LaunchAgents/com.personal-ai.tasks.<taskId>.plist
//        with ProgramArguments pointing to the app launcher binary.
//     2. Set StartCalendarInterval for cron scheduling, or StartInterval for
//        interval-based scheduling.
//     3. Load with: launchctl load ~/Library/LaunchAgents/<plist>
//   The macOS method channel handler in the native runner should call
//   NSTask or shell out to launchctl when it receives "scheduleTask".
//
// Windows (Task Scheduler):
//   The Windows runner must implement the method channel handler in
//   windows/runner/flutter_window.cpp or a dedicated plugin file.
//   Steps to schedule a Task Scheduler task:
//     1. Use schtasks.exe:
//        schtasks /create /tn "PersonalAI\<taskId>" /tr "<app_path>" \
//          /sc DAILY /st HH:MM /f
//     2. Or use the COM ITaskService interface:
//        CoCreateInstance(CLSID_TaskScheduler, ..., IID_ITaskService, ...)
//   The Windows method channel handler should invoke schtasks or ITaskService
//   when it receives "scheduleTask" with taskId, taskType, cronExpression,
//   and offsetSeconds arguments.
//
// =============================================================================

// Top-level callback dispatcher required by the workmanager package.
// Call Workmanager().initialize(backgroundCallbackDispatcher) once in main().
// This function runs in a separate isolate; keep it lightweight.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // taskName corresponds to the task ID (e.g. com.personal-ai.tasks.morning_briefing).
    // Full background execution (inference + notification) requires initialising
    // a minimal Flutter engine here. For now this stub returns success so
    // WorkManager considers the task complete; extend as needed.
    return true;
  });
}

class BackgroundTaskSchedulerService {
  static const _channel =
      MethodChannel('personal_ai_assistant/background_tasks');
  static const _pendingForegroundKey = 'bg_pending_foreground_tasks';

  BackgroundTaskSchedulerService({
    FlutterSecureStorage? secureStorage,
    AppLogger? logger,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _logger = logger;

  final FlutterSecureStorage _secureStorage;
  final AppLogger? _logger;

  // Call once from main() before scheduling any tasks.
  Future<void> initialize() async {
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        await Workmanager().initialize(
          backgroundCallbackDispatcher,
          isInDebugMode: false,
        );
        _logger?.info('Workmanager initialised');
      } catch (e, st) {
        _logger?.error('Workmanager initialisation failed', error: e, stackTrace: st);
      }
    }
  }

  Future<void> scheduleAll(List<BackgroundTask> tasks) async {
    for (final task in tasks) {
      if (task.status == BackgroundTaskStatus.active) {
        await scheduleTask(task);
      }
    }
  }

  Future<void> scheduleTask(BackgroundTask task) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await _scheduleViaNative(task);
      } else {
        await _scheduleViaChannel(task);
      }
    } catch (e, st) {
      _logger?.error(
        'Failed to schedule task',
        error: e,
        stackTrace: st,
        context: {'taskId': task.id},
      );
    }
  }

  Future<void> _scheduleViaNative(BackgroundTask task) async {
    final workmanager = Workmanager();
    switch (task.type) {
      case BackgroundTaskType.cron:
      case BackgroundTaskType.periodic:
        final freq = _frequencyForTask(task);
        await workmanager.registerPeriodicTask(
          task.id,
          task.id,
          frequency: freq,
          initialDelay: _initialDelayForTask(task),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            networkType: NetworkType.not_required,
          ),
        );
        _logger?.info(
          'Registered periodic workmanager task',
          context: {'taskId': task.id, 'frequencyHours': freq.inHours.toString()},
        );
      case BackgroundTaskType.relative:
        final delay = task.relativeTrigger?.offset ?? Duration.zero;
        await workmanager.registerOneOffTask(
          task.id,
          task.id,
          initialDelay: delay,
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            networkType: NetworkType.not_required,
          ),
        );
        _logger?.info(
          'Registered one-off workmanager task',
          context: {'taskId': task.id, 'delayMinutes': delay.inMinutes.toString()},
        );
      case BackgroundTaskType.location:
        // Location tasks are driven by GeofenceMonitorService; workmanager
        // is not used for these.
        _logger?.info(
          'Skipping workmanager for location task',
          context: {'taskId': task.id},
        );
      case BackgroundTaskType.condition:
        // Condition tasks use periodic checking; schedule via workmanager
        // periodic with the task's own check interval.
        final interval = task.conditionTrigger?.checkInterval;
        if (interval != null) {
          final freq = interval.inMinutes < 15
              ? const Duration(minutes: 15)
              : interval;
          await workmanager.registerPeriodicTask(
            task.id,
            task.id,
            frequency: freq,
            existingWorkPolicy: ExistingWorkPolicy.replace,
            constraints: Constraints(
              networkType: NetworkType.not_required,
            ),
          );
          _logger?.info(
            'Registered periodic condition task',
            context: {'taskId': task.id},
          );
        }
      case BackgroundTaskType.event:
        // Event tasks are triggered via webhook; no workmanager scheduling needed.
        _logger?.info(
          'Skipping workmanager for event task',
          context: {'taskId': task.id},
        );
    }
  }

  Future<void> _scheduleViaChannel(BackgroundTask task) async {
    try {
      await _channel.invokeMethod<void>('scheduleTask', <String, dynamic>{
        'taskId': task.id,
        'taskType': task.type.name,
        'cronExpression': task.cronTrigger?.expression,
        'offsetSeconds': task.relativeTrigger?.offset.inSeconds,
      });
      _logger?.info(
        'Scheduled task via desktop channel',
        context: {'taskId': task.id},
      );
    } on MissingPluginException {
      _logger?.warning(
        'Desktop platform channel not implemented — scheduling skipped',
        context: {'taskId': task.id},
      );
    }
  }

  Future<void> cancelTask(String taskId) async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await Workmanager().cancelByUniqueName(taskId);
      } else {
        await _channel.invokeMethod<void>('cancelTask', <String, dynamic>{
          'taskId': taskId,
        });
      }
      _logger?.info('Cancelled task', context: {'taskId': taskId});
    } catch (e, st) {
      _logger?.error(
        'Failed to cancel task',
        error: e,
        stackTrace: st,
        context: {'taskId': taskId},
      );
    }
  }

  Future<void> cancelAll() async {
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await Workmanager().cancelAll();
      } else {
        await _channel.invokeMethod<void>('cancelAll');
      }
      _logger?.info('Cancelled all tasks');
    } catch (e, st) {
      _logger?.error('Failed to cancel all tasks', error: e, stackTrace: st);
    }
  }

  // ── iOS 8.8 pending foreground task storage (flutter_secure_storage) ────────

  Future<void> markPendingForeground(String taskId) async {
    try {
      final existing = await getPendingForegroundTasks();
      if (!existing.contains(taskId)) {
        existing.add(taskId);
        await _secureStorage.write(
          key: _pendingForegroundKey,
          value: jsonEncode(existing),
        );
      }
    } catch (e, st) {
      _logger?.error(
        'Failed to mark pending foreground task',
        error: e,
        stackTrace: st,
        context: {'taskId': taskId},
      );
    }
  }

  Future<List<String>> getPendingForegroundTasks() async {
    try {
      final fromStorage = await _readFromSecureStorage();
      if (Platform.isIOS) {
        final fromNative = await _readNativeIosPendingTasks();
        return <String>{...fromStorage, ...fromNative}.toList();
      }
      return fromStorage;
    } catch (e, st) {
      _logger?.error(
        'Failed to read pending foreground tasks',
        error: e,
        stackTrace: st,
      );
      return <String>[];
    }
  }

  Future<void> clearPendingForeground(String taskId) async {
    try {
      final existing = await _readFromSecureStorage();
      existing.remove(taskId);
      await _secureStorage.write(
        key: _pendingForegroundKey,
        value: jsonEncode(existing),
      );
      if (Platform.isIOS) {
        await _clearNativeIosPendingTask(taskId);
      }
    } catch (e, st) {
      _logger?.error(
        'Failed to clear pending foreground task',
        error: e,
        stackTrace: st,
        context: {'taskId': taskId},
      );
    }
  }

  Future<List<String>> _readFromSecureStorage() async {
    final raw = await _secureStorage.read(key: _pendingForegroundKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> _readNativeIosPendingTasks() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getNativePendingTasks');
      return result?.cast<String>() ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _clearNativeIosPendingTask(String taskId) async {
    try {
      await _channel.invokeMethod<void>(
        'clearNativePendingTask',
        <String, dynamic>{'taskId': taskId},
      );
    } catch (_) {}
  }

  // ── Android battery optimisation ────────────────────────────────────────────

  Future<bool> isBatteryOptimizationBypassed() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isBatteryOptimizationBypassed');
      return result ?? false;
    } catch (e, st) {
      _logger?.error(
        'Failed to check battery optimisation status',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (e, st) {
      _logger?.error(
        'Failed to open battery optimisation settings',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Duration _frequencyForTask(BackgroundTask task) {
    // Workmanager enforces a minimum of 15 minutes on iOS and Android.
    // Cron tasks default to daily (24 hours).
    return const Duration(hours: 24);
  }

  Duration _initialDelayForTask(BackgroundTask task) {
    if (task.nextRunAt != null) {
      final delay = task.nextRunAt!.difference(DateTime.now());
      return delay.isNegative ? Duration.zero : delay;
    }
    return Duration.zero;
  }
}

final backgroundTaskSchedulerServiceProvider =
    Provider<BackgroundTaskSchedulerService>((ref) {
  return BackgroundTaskSchedulerService(
    logger: ref.watch(sanitizedLoggerProvider),
  );
});
