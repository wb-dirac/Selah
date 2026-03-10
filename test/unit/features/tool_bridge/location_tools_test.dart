import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/location_tools.dart';

class _FakeLocationDataSource implements LocationDataSource {
  _FakeLocationDataSource({LocationCoordinates? coords, bool throwError = false})
      : _coords = coords,
        _throwError = throwError;

  final LocationCoordinates? _coords;
  final bool _throwError;

  @override
  Future<LocationCoordinates?> getCurrentLocation() async {
    if (_throwError) throw Exception('GPS 不可用');
    return _coords;
  }
}

class _FakeMapSearchLauncher implements MapSearchLauncher {
  _FakeMapSearchLauncher({bool succeed = true}) : _succeed = succeed;

  final bool _succeed;
  String? lastQuery;

  @override
  Future<bool> searchPlace(String query) async {
    lastQuery = query;
    return _succeed;
  }
}

const _sampleCoords = LocationCoordinates(
  latitude: 39.9042,
  longitude: 116.4074,
  accuracy: 15.0,
  altitudeMeters: 50.0,
);

void main() {
  tearDown(clearSessionLocation);

  group('LocationCoordinates', () {
    test('toString includes lat and lng', () {
      const coords = LocationCoordinates(latitude: 39.9, longitude: 116.4);
      expect(coords.toString(), contains('39.9'));
      expect(coords.toString(), contains('116.4'));
    });

    test('toString includes optional accuracy', () {
      const coords = LocationCoordinates(
        latitude: 39.9,
        longitude: 116.4,
        accuracy: 12.5,
      );
      expect(coords.toString(), contains('12.5'));
    });

    test('toString includes optional altitude', () {
      const coords = LocationCoordinates(
        latitude: 39.9,
        longitude: 116.4,
        altitudeMeters: 100.0,
      );
      expect(coords.toString(), contains('100.0'));
    });

    test('toString omits absent optional fields', () {
      const coords = LocationCoordinates(latitude: 39.9, longitude: 116.4);
      expect(coords.toString(), isNot(contains('精度')));
      expect(coords.toString(), isNot(contains('海拔')));
    });
  });

  group('LocationCurrentTool', () {
    test('toolId is location.current', () {
      expect(const LocationCurrentTool().toolId, 'location.current');
    });

    test('error when location unavailable', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('位置'));
    });

    test('success returns formatted coordinates', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(coords: _sampleCoords),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('39.9042'));
      expect(result.output, contains('116.4074'));
    });

    test('stores location in session on success', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(coords: _sampleCoords),
      );
      await tool.execute(const <String, dynamic>{});
      expect(sessionLocation, isNotNull);
      expect(sessionLocation!.latitude, 39.9042);
    });

    test('does not store location on failure', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(),
      );
      await tool.execute(const <String, dynamic>{});
      expect(sessionLocation, isNull);
    });

    test('handles platform error', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(throwError: true),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('失败'));
    });

    test('session location cleared by clearSessionLocation()', () async {
      final tool = LocationCurrentTool(
        dataSource: _FakeLocationDataSource(coords: _sampleCoords),
      );
      await tool.execute(const <String, dynamic>{});
      clearSessionLocation();
      expect(sessionLocation, isNull);
    });
  });

  group('LocationSearchTool', () {
    test('toolId is location.search', () {
      expect(const LocationSearchTool().toolId, 'location.search');
    });

    test('error when query is missing', () async {
      final launcher = _FakeMapSearchLauncher();
      final tool = LocationSearchTool(launcher: launcher);
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('query'));
    });

    test('passes query to launcher', () async {
      final launcher = _FakeMapSearchLauncher();
      final tool = LocationSearchTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'query': '天安门广场'});
      expect(launcher.lastQuery, '天安门广场');
    });

    test('returns success with launched message when launcher succeeds',
        () async {
      final launcher = _FakeMapSearchLauncher(succeed: true);
      final tool = LocationSearchTool(launcher: launcher);
      final result =
          await tool.execute(<String, dynamic>{'query': '天安门广场'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('天安门广场'));
    });

    test('returns fallback message when launcher fails', () async {
      final launcher = _FakeMapSearchLauncher(succeed: false);
      final tool = LocationSearchTool(launcher: launcher);
      final result =
          await tool.execute(<String, dynamic>{'query': '上海外滩'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('上海外滩'));
    });

    test('trims whitespace from query', () async {
      final launcher = _FakeMapSearchLauncher();
      final tool = LocationSearchTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'query': '  故宫  '});
      expect(launcher.lastQuery, '故宫');
    });
  });
}
