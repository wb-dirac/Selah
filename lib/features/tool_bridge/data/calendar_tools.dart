import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.notes,
    this.isAllDay = false,
  });

  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? notes;
  final bool isAllDay;

  @override
  String toString() {
    final dateStr = isAllDay
        ? _formatDate(startTime)
        : '${_formatDateTime(startTime)} → ${_formatDateTime(endTime)}';
    final parts = <String>['[$title] $dateStr'];
    if (location != null) parts.add('📍$location');
    if (notes != null) parts.add('📝$notes');
    return parts.join(' ');
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _formatDateTime(DateTime dt) =>
      '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

abstract class CalendarDataSource {
  Future<List<CalendarEvent>> readRange({
    required DateTime from,
    required DateTime to,
  });

  Future<String> createEvent(CalendarEvent event);

  Future<void> updateEvent(CalendarEvent event);

  Future<void> deleteEvent(String eventId);

  Future<CalendarEvent?> findById(String eventId);
}

class StubCalendarDataSource implements CalendarDataSource {
  const StubCalendarDataSource();

  @override
  Future<List<CalendarEvent>> readRange({
    required DateTime from,
    required DateTime to,
  }) async =>
      const <CalendarEvent>[];

  @override
  Future<String> createEvent(CalendarEvent event) async => event.id;

  @override
  Future<void> updateEvent(CalendarEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<CalendarEvent?> findById(String eventId) async => null;
}

DateTime? _parseDateTime(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class CalendarReadTool implements ToolExecutor {
  const CalendarReadTool({CalendarDataSource? dataSource})
      : _dataSource = dataSource ?? const StubCalendarDataSource();

  final CalendarDataSource _dataSource;

  @override
  String get toolId => 'calendar.read';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final from = _parseDateTime(arguments['from']);
    final to = _parseDateTime(arguments['to']);

    if (from == null || to == null) {
      return const ToolCallResult.error(
        toolId: 'calendar.read',
        errorMessage: '缺少参数 from 或 to（ISO 8601 格式）',
      );
    }

    if (to.isBefore(from)) {
      return const ToolCallResult.error(
        toolId: 'calendar.read',
        errorMessage: '参数 to 不能早于 from',
      );
    }

    try {
      final events = await _dataSource.readRange(from: from, to: to);
      if (events.isEmpty) {
        return const ToolCallResult.success(
          toolId: 'calendar.read',
          output: '该时间段内没有日历事件',
        );
      }
      final output = events.map((e) => e.toString()).join('\n');
      return ToolCallResult.success(toolId: 'calendar.read', output: output);
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'calendar.read',
        errorMessage: '读取日历事件失败: $e',
      );
    }
  }
}

class CalendarCreateTool implements ToolExecutor {
  const CalendarCreateTool({CalendarDataSource? dataSource})
      : _dataSource = dataSource ?? const StubCalendarDataSource();

  final CalendarDataSource _dataSource;

  @override
  String get toolId => 'calendar.create';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final title = arguments['title']?.toString();
    if (title == null || title.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'calendar.create',
        errorMessage: '缺少参数 title',
      );
    }

    final startTime = _parseDateTime(arguments['start_time']);
    final endTime = _parseDateTime(arguments['end_time']);

    if (startTime == null || endTime == null) {
      return const ToolCallResult.error(
        toolId: 'calendar.create',
        errorMessage: '缺少参数 start_time 或 end_time（ISO 8601 格式）',
      );
    }

    if (endTime.isBefore(startTime)) {
      return const ToolCallResult.error(
        toolId: 'calendar.create',
        errorMessage: '参数 end_time 不能早于 start_time',
      );
    }

    final event = CalendarEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      startTime: startTime,
      endTime: endTime,
      location: arguments['location']?.toString(),
      notes: arguments['notes']?.toString(),
      isAllDay: arguments['is_all_day'] as bool? ?? false,
    );

    try {
      final createdId = await _dataSource.createEvent(event);
      return ToolCallResult.success(
        toolId: 'calendar.create',
        output: '日历事件已创建: ${event.title} (id: $createdId)',
      );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'calendar.create',
        errorMessage: '创建日历事件失败: $e',
      );
    }
  }
}

class CalendarUpdateDeleteTool implements ToolExecutor {
  const CalendarUpdateDeleteTool({CalendarDataSource? dataSource})
      : _dataSource = dataSource ?? const StubCalendarDataSource();

  final CalendarDataSource _dataSource;

  @override
  String get toolId => 'calendar.update_delete';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final eventId = arguments['event_id']?.toString();
    if (eventId == null || eventId.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'calendar.update_delete',
        errorMessage: '缺少参数 event_id',
      );
    }

    final action = arguments['action']?.toString();
    if (action != 'update' && action != 'delete') {
      return const ToolCallResult.error(
        toolId: 'calendar.update_delete',
        errorMessage: '参数 action 必须为 "update" 或 "delete"',
      );
    }

    try {
      final existing = await _dataSource.findById(eventId.trim());
      if (existing == null) {
        return ToolCallResult.error(
          toolId: 'calendar.update_delete',
          errorMessage: '未找到日历事件: $eventId',
        );
      }

      if (action == 'delete') {
        await _dataSource.deleteEvent(eventId.trim());
        return ToolCallResult.success(
          toolId: 'calendar.update_delete',
          output: '日历事件已删除: ${existing.title}',
        );
      }

      final title = arguments['title']?.toString() ?? existing.title;
      final startTime =
          _parseDateTime(arguments['start_time']) ?? existing.startTime;
      final endTime = _parseDateTime(arguments['end_time']) ?? existing.endTime;

      if (endTime.isBefore(startTime)) {
        return const ToolCallResult.error(
          toolId: 'calendar.update_delete',
          errorMessage: '参数 end_time 不能早于 start_time',
        );
      }

      final updated = CalendarEvent(
        id: existing.id,
        title: title.trim(),
        startTime: startTime,
        endTime: endTime,
        location: arguments.containsKey('location')
            ? arguments['location']?.toString()
            : existing.location,
        notes: arguments.containsKey('notes')
            ? arguments['notes']?.toString()
            : existing.notes,
        isAllDay: arguments['is_all_day'] as bool? ?? existing.isAllDay,
      );

      await _dataSource.updateEvent(updated);
      return ToolCallResult.success(
        toolId: 'calendar.update_delete',
        output: '日历事件已更新: ${updated.title}',
      );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'calendar.update_delete',
        errorMessage: '操作日历事件失败: $e',
      );
    }
  }
}
