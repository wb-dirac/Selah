import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/calendar_tools.dart';

final _now = DateTime(2025, 6, 1, 10, 0);
final _later = DateTime(2025, 6, 1, 11, 0);
final _yesterday = DateTime(2025, 5, 31, 10, 0);

final _sampleEvent = CalendarEvent(
  id: 'evt1',
  title: '团队会议',
  startTime: _now,
  endTime: _later,
  location: '会议室A',
  notes: '季度回顾',
);

class _FakeCalendarDataSource implements CalendarDataSource {
  _FakeCalendarDataSource({
    List<CalendarEvent>? events,
    bool throwOnWrite = false,
  })  : _events = List.from(events ?? <CalendarEvent>[]),
        _throwOnWrite = throwOnWrite;

  final List<CalendarEvent> _events;
  final bool _throwOnWrite;

  String? lastDeletedId;
  CalendarEvent? lastUpdated;
  CalendarEvent? lastCreated;

  @override
  Future<List<CalendarEvent>> readRange({
    required DateTime from,
    required DateTime to,
  }) async {
    return _events
        .where(
          (e) => !e.startTime.isAfter(to) && !e.endTime.isBefore(from),
        )
        .toList();
  }

  @override
  Future<String> createEvent(CalendarEvent event) async {
    if (_throwOnWrite) throw Exception('平台错误');
    lastCreated = event;
    _events.add(event);
    return event.id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    if (_throwOnWrite) throw Exception('平台错误');
    lastUpdated = event;
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i >= 0) _events[i] = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    if (_throwOnWrite) throw Exception('平台错误');
    lastDeletedId = eventId;
    _events.removeWhere((e) => e.id == eventId);
  }

  @override
  Future<CalendarEvent?> findById(String eventId) async {
    return _events.cast<CalendarEvent?>().firstWhere(
          (e) => e!.id == eventId,
          orElse: () => null,
        );
  }
}

void main() {
  group('CalendarEvent', () {
    test('toString contains title and time', () {
      final s = _sampleEvent.toString();
      expect(s, contains('团队会议'));
      expect(s, contains('2025'));
    });

    test('toString includes location and notes when present', () {
      final s = _sampleEvent.toString();
      expect(s, contains('会议室A'));
      expect(s, contains('季度回顾'));
    });

    test('toString for all-day event shows date only', () {
      final e = CalendarEvent(
        id: 'e2',
        title: '全天事件',
        startTime: _now,
        endTime: _later,
        isAllDay: true,
      );
      expect(e.toString(), contains('2025-06-01'));
      expect(e.toString(), isNot(contains('10:00')));
    });
  });

  group('CalendarReadTool', () {
    test('toolId is calendar.read', () {
      expect(const CalendarReadTool().toolId, 'calendar.read');
    });

    test('error when from is missing', () async {
      final tool = CalendarReadTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'to': _later.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('from'));
    });

    test('error when to is missing', () async {
      final tool = CalendarReadTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'from': _now.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
    });

    test('error when to is before from', () async {
      final tool = CalendarReadTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'from': _later.toIso8601String(),
        'to': _now.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('to'));
    });

    test('returns empty message when no events in range', () async {
      final tool = CalendarReadTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'from': _now.toIso8601String(),
        'to': _later.toIso8601String(),
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('没有'));
    });

    test('returns events in range', () async {
      final tool = CalendarReadTool(
        dataSource: _FakeCalendarDataSource(events: [_sampleEvent]),
      );
      final result = await tool.execute(<String, dynamic>{
        'from': _yesterday.toIso8601String(),
        'to': _later.toIso8601String(),
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('团队会议'));
    });
  });

  group('CalendarCreateTool', () {
    test('toolId is calendar.create', () {
      expect(const CalendarCreateTool().toolId, 'calendar.create');
    });

    test('error when title is missing', () async {
      final tool = CalendarCreateTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'start_time': _now.toIso8601String(),
        'end_time': _later.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('title'));
    });

    test('error when start_time is missing', () async {
      final tool = CalendarCreateTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'title': '会议',
        'end_time': _later.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('start_time'));
    });

    test('error when end_time is before start_time', () async {
      final tool = CalendarCreateTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'title': '会议',
        'start_time': _later.toIso8601String(),
        'end_time': _now.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('end_time'));
    });

    test('creates event successfully', () async {
      final ds = _FakeCalendarDataSource();
      final tool = CalendarCreateTool(dataSource: ds);
      final result = await tool.execute(<String, dynamic>{
        'title': '新会议',
        'start_time': _now.toIso8601String(),
        'end_time': _later.toIso8601String(),
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('新会议'));
      expect(ds.lastCreated?.title, '新会议');
    });

    test('creates event with optional fields', () async {
      final ds = _FakeCalendarDataSource();
      final tool = CalendarCreateTool(dataSource: ds);
      await tool.execute(<String, dynamic>{
        'title': '带附加信息的会议',
        'start_time': _now.toIso8601String(),
        'end_time': _later.toIso8601String(),
        'location': '会议室B',
        'notes': '带备注',
        'is_all_day': false,
      });
      expect(ds.lastCreated?.location, '会议室B');
      expect(ds.lastCreated?.notes, '带备注');
    });

    test('handles platform error', () async {
      final tool = CalendarCreateTool(
        dataSource: _FakeCalendarDataSource(throwOnWrite: true),
      );
      final result = await tool.execute(<String, dynamic>{
        'title': '会议',
        'start_time': _now.toIso8601String(),
        'end_time': _later.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('失败'));
    });
  });

  group('CalendarUpdateDeleteTool', () {
    test('toolId is calendar.update_delete', () {
      expect(const CalendarUpdateDeleteTool().toolId, 'calendar.update_delete');
    });

    test('error when event_id is missing', () async {
      final tool =
          CalendarUpdateDeleteTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{'action': 'delete'});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('event_id'));
    });

    test('error when action is invalid', () async {
      final tool =
          CalendarUpdateDeleteTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'invalid',
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('action'));
    });

    test('error when event not found', () async {
      final tool =
          CalendarUpdateDeleteTool(dataSource: _FakeCalendarDataSource());
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'nonexistent',
        'action': 'delete',
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('未找到'));
    });

    test('deletes existing event', () async {
      final ds = _FakeCalendarDataSource(events: [_sampleEvent]);
      final tool = CalendarUpdateDeleteTool(dataSource: ds);
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'delete',
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('已删除'));
      expect(ds.lastDeletedId, 'evt1');
    });

    test('updates existing event title', () async {
      final ds = _FakeCalendarDataSource(events: [_sampleEvent]);
      final tool = CalendarUpdateDeleteTool(dataSource: ds);
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'update',
        'title': '更新后的标题',
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('更新'));
      expect(ds.lastUpdated?.title, '更新后的标题');
    });

    test('preserves unchanged fields on update', () async {
      final ds = _FakeCalendarDataSource(events: [_sampleEvent]);
      final tool = CalendarUpdateDeleteTool(dataSource: ds);
      await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'update',
        'title': '新标题',
      });
      expect(ds.lastUpdated?.location, '会议室A');
      expect(ds.lastUpdated?.notes, '季度回顾');
    });

    test('error when updated end_time is before start_time', () async {
      final ds = _FakeCalendarDataSource(events: [_sampleEvent]);
      final tool = CalendarUpdateDeleteTool(dataSource: ds);
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'update',
        'start_time': _later.toIso8601String(),
        'end_time': _now.toIso8601String(),
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('end_time'));
    });

    test('handles platform error', () async {
      final tool = CalendarUpdateDeleteTool(
        dataSource: _FakeCalendarDataSource(
          events: [_sampleEvent],
          throwOnWrite: true,
        ),
      );
      final result = await tool.execute(<String, dynamic>{
        'event_id': 'evt1',
        'action': 'delete',
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('失败'));
    });
  });

  group('StubCalendarDataSource', () {
    test('readRange returns empty', () async {
      final result = await const StubCalendarDataSource().readRange(
        from: _now,
        to: _later,
      );
      expect(result, isEmpty);
    });

    test('createEvent returns id', () async {
      final id = await const StubCalendarDataSource().createEvent(_sampleEvent);
      expect(id, 'evt1');
    });

    test('findById returns null', () async {
      final result = await const StubCalendarDataSource().findById('any');
      expect(result, isNull);
    });
  });
}
