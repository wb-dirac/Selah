import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';

// Geofencing implementation uses periodic location polling because geolocator
// does not provide OS-native geofence APIs on all platforms. The service
// checks every 30 seconds via a fallback timer AND responds to geolocator's
// position stream (distanceFilter: 50 m) for lower-latency transitions.
//
// Only enter/exit transitions are emitted — not repeated inside/outside events.

class GeofenceMonitorService {
  GeofenceMonitorService({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  final StreamController<String> _triggeredController =
      StreamController<String>.broadcast();
  final Map<String, bool> _previouslyInside = <String, bool>{};

  List<BackgroundTask> _tasks = <BackgroundTask>[];
  StreamSubscription<Position>? _positionSub;
  Timer? _periodicTimer;

  Stream<String> get triggeredTasks => _triggeredController.stream;

  Future<void> startMonitoring(List<BackgroundTask> tasks) async {
    await stopMonitoring();

    _tasks = tasks
        .where(
          (t) =>
              t.locationTrigger != null &&
              t.status == BackgroundTaskStatus.active,
        )
        .toList();

    if (_tasks.isEmpty) {
      _logger?.info('No location tasks to monitor');
      return;
    }

    final permissionGranted = await _ensurePermission();
    if (!permissionGranted) return;

    final settings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPositionUpdate, onError: _onStreamError);

    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _periodicCheck(),
    );

    _logger?.info(
      'Geofence monitoring started',
      context: {'taskCount': _tasks.length.toString()},
    );
  }

  Future<void> stopMonitoring() async {
    await _positionSub?.cancel();
    _periodicTimer?.cancel();
    _positionSub = null;
    _periodicTimer = null;
    _previouslyInside.clear();
    _logger?.info('Geofence monitoring stopped');
  }

  void dispose() {
    _positionSub?.cancel();
    _periodicTimer?.cancel();
    if (!_triggeredController.isClosed) {
      _triggeredController.close();
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _logger?.warning(
          'Location permission denied — geofence monitoring unavailable',
        );
        return false;
      }
      return true;
    } catch (e, st) {
      _logger?.error(
        'Failed to check location permission',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _periodicCheck() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _checkPosition(pos);
    } catch (e, st) {
      _logger?.error(
        'Periodic geofence check failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onPositionUpdate(Position pos) => _checkPosition(pos);

  void _onStreamError(Object error, StackTrace st) {
    _logger?.error('Position stream error', error: error, stackTrace: st);
  }

  void _checkPosition(Position pos) {
    for (final task in _tasks) {
      final trigger = task.locationTrigger;
      if (trigger == null) continue;

      final inside = _isInsideFence(pos, trigger);
      final wasInside = _previouslyInside[task.id] ?? false;

      if (inside == wasInside) continue;

      _previouslyInside[task.id] = inside;

      if (inside && trigger.onEnter) {
        _triggeredController.add(task.id);
        _logger?.info(
          'Geofence enter triggered',
          context: {'taskId': task.id},
        );
      } else if (!inside && trigger.onExit) {
        _triggeredController.add(task.id);
        _logger?.info(
          'Geofence exit triggered',
          context: {'taskId': task.id},
        );
      }
    }
  }

  bool _isInsideFence(Position pos, LocationTrigger trigger) {
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      trigger.latitude,
      trigger.longitude,
    );
    return distance <= trigger.radiusMeters;
  }
}

final geofenceMonitorServiceProvider =
    Provider<GeofenceMonitorService>((ref) {
  final service = GeofenceMonitorService(
    logger: ref.watch(sanitizedLoggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
