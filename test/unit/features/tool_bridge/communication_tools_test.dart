import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/communication_tools.dart';

class _FakeLauncher implements UrlLauncher {
  _FakeLauncher({bool succeed = true}) : _succeed = succeed;

  final bool _succeed;
  Uri? lastUri;

  @override
  Future<bool> launch(Uri uri) async {
    lastUri = uri;
    return _succeed;
  }
}

void main() {
  group('MailComposeTool', () {
    test('toolId is mail.compose', () {
      expect(const MailComposeTool().toolId, 'mail.compose');
    });

    test('returns error when "to" is missing', () async {
      final launcher = _FakeLauncher();
      final tool = MailComposeTool(launcher: launcher);
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('to'));
    });

    test('launches mailto URI with to only', () async {
      final launcher = _FakeLauncher();
      final tool = MailComposeTool(launcher: launcher);
      final result = await tool.execute(<String, dynamic>{
        'to': 'user@example.com',
      });
      expect(result.isSuccess, isTrue);
      expect(launcher.lastUri?.scheme, 'mailto');
      expect(launcher.lastUri?.path, 'user@example.com');
    });

    test('includes subject and body in URI', () async {
      final launcher = _FakeLauncher();
      final tool = MailComposeTool(launcher: launcher);
      await tool.execute(<String, dynamic>{
        'to': 'user@example.com',
        'subject': '测试主题',
        'body': '你好',
      });
      final query = launcher.lastUri?.queryParameters ?? const <String, String>{};
      expect(query['subject'], '测试主题');
      expect(query['body'], '你好');
    });

    test('returns error when launcher fails', () async {
      final launcher = _FakeLauncher(succeed: false);
      final tool = MailComposeTool(launcher: launcher);
      final result = await tool.execute(<String, dynamic>{
        'to': 'user@example.com',
      });
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('客户端'));
    });

    test('output contains recipient address on success', () async {
      final launcher = _FakeLauncher();
      final tool = MailComposeTool(launcher: launcher);
      final result = await tool.execute(<String, dynamic>{
        'to': 'user@example.com',
      });
      expect(result.output, contains('user@example.com'));
    });
  });

  group('SmsSendTool', () {
    test('toolId is sms.send', () {
      expect(const SmsSendTool().toolId, 'sms.send');
    });

    test('returns error when "to" is missing', () async {
      final launcher = _FakeLauncher();
      final tool = SmsSendTool(launcher: launcher);
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('to'));
    });

    test('launches sms URI with number', () async {
      final launcher = _FakeLauncher();
      final tool = SmsSendTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'to': '13800138000'});
      expect(launcher.lastUri?.scheme, 'sms');
      expect(launcher.lastUri?.path, '13800138000');
    });

    test('includes body in URI when provided', () async {
      final launcher = _FakeLauncher();
      final tool = SmsSendTool(launcher: launcher);
      await tool.execute(<String, dynamic>{
        'to': '13800138000',
        'body': '你好世界',
      });
      expect(launcher.lastUri?.queryParameters['body'], '你好世界');
    });

    test('no body query param when body is empty', () async {
      final launcher = _FakeLauncher();
      final tool = SmsSendTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'to': '13800138000'});
      expect(launcher.lastUri?.queryParameters.containsKey('body'), isFalse);
    });

    test('returns error when launcher fails', () async {
      final launcher = _FakeLauncher(succeed: false);
      final tool = SmsSendTool(launcher: launcher);
      final result =
          await tool.execute(<String, dynamic>{'to': '13800138000'});
      expect(result.isSuccess, isFalse);
    });
  });

  group('PhoneCallTool', () {
    test('toolId is phone.call', () {
      expect(const PhoneCallTool().toolId, 'phone.call');
    });

    test('returns error when "number" is missing', () async {
      final launcher = _FakeLauncher();
      final tool = PhoneCallTool(launcher: launcher);
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('number'));
    });

    test('launches tel URI', () async {
      final launcher = _FakeLauncher();
      final tool = PhoneCallTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'number': '13800138000'});
      expect(launcher.lastUri?.scheme, 'tel');
      expect(launcher.lastUri?.path, '13800138000');
    });

    test('strips spaces and hyphens from number', () async {
      final launcher = _FakeLauncher();
      final tool = PhoneCallTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'number': '138-0013-8000'});
      expect(launcher.lastUri?.path, '13800138000');
    });

    test('strips parentheses from number', () async {
      final launcher = _FakeLauncher();
      final tool = PhoneCallTool(launcher: launcher);
      await tool.execute(<String, dynamic>{'number': '+86 (138) 0013 8000'});
      expect(launcher.lastUri?.path, contains('138'));
      expect(launcher.lastUri?.path, isNot(contains(' ')));
      expect(launcher.lastUri?.path, isNot(contains('(')));
    });

    test('returns error when launcher fails', () async {
      final launcher = _FakeLauncher(succeed: false);
      final tool = PhoneCallTool(launcher: launcher);
      final result =
          await tool.execute(<String, dynamic>{'number': '13800138000'});
      expect(result.isSuccess, isFalse);
    });

    test('output contains number on success', () async {
      final launcher = _FakeLauncher();
      final tool = PhoneCallTool(launcher: launcher);
      final result =
          await tool.execute(<String, dynamic>{'number': '13800138000'});
      expect(result.output, contains('13800138000'));
    });
  });
}
