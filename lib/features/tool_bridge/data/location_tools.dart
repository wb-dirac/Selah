import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationCoordinates {
  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitudeMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitudeMeters;

  @override
  String toString() {
    final parts = <String>[
      '纬度: $latitude',
      '经度: $longitude',
    ];
    if (accuracy != null) parts.add('精度: ${accuracy!.toStringAsFixed(1)}m');
    if (altitudeMeters != null) {
      parts.add('海拔: ${altitudeMeters!.toStringAsFixed(1)}m');
    }
    return parts.join(', ');
  }
}

abstract class LocationDataSource {
  Future<LocationCoordinates?> getCurrentLocation();
}

class StubLocationDataSource implements LocationDataSource {
  const StubLocationDataSource();

  @override
  Future<LocationCoordinates?> getCurrentLocation() async => null;
}

abstract class MapSearchLauncher {
  Future<bool> searchPlace(String query);
}

class WebMapSearchLauncher implements MapSearchLauncher {
  const WebMapSearchLauncher();

  @override
  Future<bool> searchPlace(String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

class _InMemoryLocationSession {
  static LocationCoordinates? _current;

  static void store(LocationCoordinates coords) {
    _current = coords;
  }

  static LocationCoordinates? retrieve() => _current;

  static void clear() {
    _current = null;
  }
}

class LocationCurrentTool implements ToolExecutor {
  const LocationCurrentTool({LocationDataSource? dataSource})
      : _dataSource = dataSource ?? const StubLocationDataSource();

  final LocationDataSource _dataSource;

  @override
  String get toolId => 'location.current';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    try {
      final coords = await _dataSource.getCurrentLocation();
      if (coords == null) {
        return const ToolCallResult.error(
          toolId: 'location.current',
          errorMessage: '无法获取当前位置（位置服务未授权或不可用）',
        );
      }
      _InMemoryLocationSession.store(coords);
      return ToolCallResult.success(
        toolId: 'location.current',
        output: coords.toString(),
      );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'location.current',
        errorMessage: '获取位置失败: $e',
      );
    }
  }
}

class LocationSearchTool implements ToolExecutor {
  const LocationSearchTool({MapSearchLauncher? launcher})
      : _launcher = launcher ?? const WebMapSearchLauncher();

  final MapSearchLauncher _launcher;

  @override
  String get toolId => 'location.search';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query']?.toString();
    if (query == null || query.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'location.search',
        errorMessage: '缺少参数 query（地点名称或关键词）',
      );
    }

    try {
      final launched = await _launcher.searchPlace(query.trim());
      if (launched) {
        return ToolCallResult.success(
          toolId: 'location.search',
          output: '已打开地图搜索: ${query.trim()}',
        );
      }
      return ToolCallResult.success(
        toolId: 'location.search',
        output: '请在地图应用中搜索: ${query.trim()}',
      );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'location.search',
        errorMessage: '地点搜索失败: $e',
      );
    }
  }
}

LocationCoordinates? get sessionLocation =>
    _InMemoryLocationSession.retrieve();

void clearSessionLocation() => _InMemoryLocationSession.clear();
