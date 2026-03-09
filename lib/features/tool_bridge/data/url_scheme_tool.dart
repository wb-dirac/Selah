import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:url_launcher/url_launcher.dart';

enum MapProvider { amap, baidu, google }

class UrlSchemeTool implements ToolExecutor {
  const UrlSchemeTool();

  @override
  String get toolId => 'url_scheme.launch';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final rawUrl = arguments['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      return const ToolCallResult.error(
        toolId: 'url_scheme.launch',
        errorMessage: '缺少参数 url',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return ToolCallResult.error(
        toolId: 'url_scheme.launch',
        errorMessage: '无效的 URL：$rawUrl',
      );
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return launched
        ? ToolCallResult.success(toolId: 'url_scheme.launch', output: '已打开：$rawUrl')
        : ToolCallResult.error(
            toolId: 'url_scheme.launch',
            errorMessage: '无法打开 URL：$rawUrl',
          );
  }
}

abstract final class MapSchemes {
  static Uri amap({required double lat, required double lng, String? name}) {
    final params = StringBuffer('androidamap://viewMap?sourceApplication=personal_ai'
        '&poiname=${Uri.encodeComponent(name ?? '')}' 
        '&lat=$lat&lon=$lng&dev=0');
    return Uri.parse(params.toString());
  }

  static Uri amapWeb({required double lat, required double lng, String? name}) {
    return Uri.parse(
      'https://uri.amap.com/marker?position=$lng,$lat'
      '&name=${Uri.encodeComponent(name ?? '')}',
    );
  }

  static Uri baidu({required double lat, required double lng, String? name}) {
    return Uri.parse(
      'baidumap://map/marker?location=$lat,$lng'
      '&title=${Uri.encodeComponent(name ?? '')}&content=${Uri.encodeComponent(name ?? '')}'
      '&traffic=1&src=personal_ai|andr.personal_ai',
    );
  }

  static Uri baiduWeb({required double lat, required double lng, String? name}) {
    return Uri.parse(
      'https://api.map.baidu.com/marker?location=$lat,$lng'
      '&title=${Uri.encodeComponent(name ?? '')}&content=${Uri.encodeComponent(name ?? '')}'
      '&output=html&src=webapp.baidu.openAPIdemo',
    );
  }

  static Uri google({required double lat, required double lng, String? name}) {
    return Uri.parse(
      'geo:$lat,$lng?q=$lat,${lng}(${Uri.encodeComponent(name ?? 'location')})',
    );
  }

  static Uri googleWeb({required double lat, required double lng, String? name}) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$lat,$lng',
    );
  }
}

abstract final class AppSchemes {
  static Uri wechat() => Uri.parse('weixin://');

  static Uri alipay() => Uri.parse('alipays://');

  static Uri dingtalk() => Uri.parse('dingtalk://');

  static Uri feishu() => Uri.parse('lark://');

  static Uri feishuWeb() => Uri.parse('https://applink.feishu.cn/client/');
}

class MapLaunchService {
  const MapLaunchService();

  Future<bool> openMap({
    required double lat,
    required double lng,
    String? name,
    MapProvider preferred = MapProvider.amap,
  }) async {
    Uri nativeUri;
    Uri webFallback;

    switch (preferred) {
      case MapProvider.amap:
        nativeUri = MapSchemes.amap(lat: lat, lng: lng, name: name);
        webFallback = MapSchemes.amapWeb(lat: lat, lng: lng, name: name);
      case MapProvider.baidu:
        nativeUri = MapSchemes.baidu(lat: lat, lng: lng, name: name);
        webFallback = MapSchemes.baiduWeb(lat: lat, lng: lng, name: name);
      case MapProvider.google:
        nativeUri = MapSchemes.google(lat: lat, lng: lng, name: name);
        webFallback = MapSchemes.googleWeb(lat: lat, lng: lng, name: name);
    }

    final canLaunchNative = await canLaunchUrl(nativeUri);
    if (canLaunchNative) {
      return launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    }
    return launchUrl(webFallback, mode: LaunchMode.externalApplication);
  }

  Future<bool> openApp(Uri scheme, {Uri? webFallback}) async {
    final canOpen = await canLaunchUrl(scheme);
    if (canOpen) {
      return launchUrl(scheme, mode: LaunchMode.externalApplication);
    }
    if (webFallback != null) {
      return launchUrl(webFallback, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
