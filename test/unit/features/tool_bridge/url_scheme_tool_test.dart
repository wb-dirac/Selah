import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/url_scheme_tool.dart';

void main() {
  group('MapSchemes', () {
    const lat = 39.9042;
    const lng = 116.4074;
    const name = 'Tiananmen';

    test('amap native URI has correct scheme and params', () {
      final uri = MapSchemes.amap(lat: lat, lng: lng, name: name);
      expect(uri.scheme, 'androidamap');
      expect(uri.toString(), contains('lat=$lat'));
      expect(uri.toString(), contains('lon=$lng'));
    });

    test('amap web URI uses https://uri.amap.com', () {
      final uri = MapSchemes.amapWeb(lat: lat, lng: lng, name: name);
      expect(uri.scheme, 'https');
      expect(uri.host, 'uri.amap.com');
      expect(uri.toString(), contains('$lng,$lat'));
    });

    test('baidu native URI has baidumap scheme', () {
      final uri = MapSchemes.baidu(lat: lat, lng: lng, name: name);
      expect(uri.scheme, 'baidumap');
      expect(uri.toString(), contains('$lat,$lng'));
    });

    test('baidu web URI uses api.map.baidu.com', () {
      final uri = MapSchemes.baiduWeb(lat: lat, lng: lng, name: name);
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.map.baidu.com');
    });

    test('google native URI uses geo scheme', () {
      final uri = MapSchemes.google(lat: lat, lng: lng, name: name);
      expect(uri.scheme, 'geo');
      expect(uri.toString(), contains('$lat'));
    });

    test('google web URI uses google.com/maps', () {
      final uri = MapSchemes.googleWeb(lat: lat, lng: lng);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
    });

    test('name with spaces is percent-encoded', () {
      final uri = MapSchemes.amapWeb(lat: lat, lng: lng, name: 'Hello World');
      expect(uri.toString(), contains('Hello%20World'));
    });
  });

  group('AppSchemes', () {
    test('wechat uses weixin scheme', () {
      expect(AppSchemes.wechat().scheme, 'weixin');
    });

    test('alipay uses alipays scheme', () {
      expect(AppSchemes.alipay().scheme, 'alipays');
    });

    test('dingtalk uses dingtalk scheme', () {
      expect(AppSchemes.dingtalk().scheme, 'dingtalk');
    });

    test('feishu uses lark scheme', () {
      expect(AppSchemes.feishu().scheme, 'lark');
    });

    test('feishuWeb uses https applink', () {
      final uri = AppSchemes.feishuWeb();
      expect(uri.scheme, 'https');
      expect(uri.host, 'applink.feishu.cn');
    });
  });

  group('UrlSchemeTool', () {
    const tool = UrlSchemeTool();

    test('toolId is url_scheme.launch', () {
      expect(tool.toolId, 'url_scheme.launch');
    });

    test('returns error when url param is missing', () async {
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('url'));
    });

    test('returns error when url param is empty string', () async {
      final result = await tool.execute({'url': ''});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('url'));
    });

    test('returns error for unparseable URL', () async {
      final result = await tool.execute({'url': ':::invalid:::'});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('无效的 URL'));
    });
  });
}
