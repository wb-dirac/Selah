import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class UrlLauncher {
  Future<bool> launch(Uri uri);
}

class DefaultUrlLauncher implements UrlLauncher {
  const DefaultUrlLauncher();

  @override
  Future<bool> launch(Uri uri) async {
    // Prefer Android native intents to avoid url_launcher channel edge cases.
    if (Platform.isAndroid) {
      final launchedByIntent = await _launchWithAndroidIntent(uri);
      if (launchedByIntent) return true;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchWithAndroidIntent(Uri uri) async {
    try {
      final action = switch (uri.scheme) {
        'mailto' => 'android.intent.action.SENDTO',
        'sms' => 'android.intent.action.SENDTO',
        'tel' => 'android.intent.action.DIAL',
        _ => 'android.intent.action.VIEW',
      };
      final intent = AndroidIntent(
        action: action,
        data: uri.toString(),
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class MailComposeTool implements ToolExecutor {
  const MailComposeTool({UrlLauncher? launcher})
      : _launcher = launcher ?? const DefaultUrlLauncher();

  final UrlLauncher _launcher;

  @override
  String get toolId => 'mail.compose';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final to = arguments['to']?.toString();
    if (to == null || to.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'mail.compose',
        errorMessage: '缺少参数 to（收件人地址）',
      );
    }

    final subject = arguments['subject']?.toString() ?? '';
    final body = arguments['body']?.toString() ?? '';

    final params = <String, String>{};
    if (subject.isNotEmpty) params['subject'] = subject;
    if (body.isNotEmpty) params['body'] = body;

    final uri = Uri(
      scheme: 'mailto',
      path: to.trim(),
      queryParameters: params.isEmpty ? null : params,
    );

    try {
      final launched = await _launcher.launch(uri);
      return launched
          ? ToolCallResult.success(
              toolId: 'mail.compose',
              output: '已打开邮件草稿: to=$to',
            )
          : const ToolCallResult.error(
              toolId: 'mail.compose',
              errorMessage: '无法打开邮件客户端',
            );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'mail.compose',
        errorMessage: '打开邮件失败: $e',
      );
    }
  }
}

class SmsSendTool implements ToolExecutor {
  const SmsSendTool({UrlLauncher? launcher})
      : _launcher = launcher ?? const DefaultUrlLauncher();

  final UrlLauncher _launcher;

  @override
  String get toolId => 'sms.send';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final to = arguments['to']?.toString();
    if (to == null || to.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'sms.send',
        errorMessage: '缺少参数 to（收件人号码）',
      );
    }

    final body = arguments['body']?.toString() ?? '';

    final uri = Uri(
      scheme: 'sms',
      path: to.trim(),
      queryParameters: body.isNotEmpty ? <String, String>{'body': body} : null,
    );

    try {
      final launched = await _launcher.launch(uri);
      return launched
          ? ToolCallResult.success(
              toolId: 'sms.send',
              output: '已打开短信草稿: to=$to',
            )
          : const ToolCallResult.error(
              toolId: 'sms.send',
              errorMessage: '无法打开短信应用',
            );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'sms.send',
        errorMessage: '打开短信失败: $e',
      );
    }
  }
}

class PhoneCallTool implements ToolExecutor {
  const PhoneCallTool({UrlLauncher? launcher})
      : _launcher = launcher ?? const DefaultUrlLauncher();

  final UrlLauncher _launcher;

  @override
  String get toolId => 'phone.call';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final number = arguments['number']?.toString();
    if (number == null || number.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'phone.call',
        errorMessage: '缺少参数 number（电话号码）',
      );
    }

    final digits = number.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(scheme: 'tel', path: digits);

    try {
      final launched = await _launcher.launch(uri);
      return launched
          ? ToolCallResult.success(
              toolId: 'phone.call',
              output: '已发起拨号: $digits',
            )
          : const ToolCallResult.error(
              toolId: 'phone.call',
              errorMessage: '无法发起拨号',
            );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'phone.call',
        errorMessage: '拨号失败: $e',
      );
    }
  }
}
