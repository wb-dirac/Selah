import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';

class _RecordingLogger implements AppLogger {
  String? lastInfo;
  String? lastWarning;
  String? lastError;
  Map<String, Object?>? lastContext;

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    lastError = message;
    lastContext = context;
  }

  @override
  void info(String message, {Map<String, Object?>? context}) {
    lastInfo = message;
    lastContext = context;
  }

  @override
  void warning(String message, {Map<String, Object?>? context}) {
    lastWarning = message;
    lastContext = context;
  }
}

void main() {
  group('SanitizedLogger', () {
    test('redacts OpenAI style API key', () {
      final logger = SanitizedLogger();
      final sanitized =
          logger.sanitize('using key sk-abcdefghijklmnopqrstuvwxyz123456');

      expect(sanitized, contains('[REDACTED]'));
      expect(sanitized, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz123456')));
    });

    test('redacts phone number and id card fragments', () {
      final logger = SanitizedLogger();
      final sanitized = logger.sanitize(
        'phone 13800138000 id 110105199001011234',
      );

      expect(sanitized, isNot(contains('13800138000')));
      expect(sanitized, isNot(contains('110105199001011234')));
      expect(
        RegExp(r'\[REDACTED\]').allMatches(sanitized).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('forwards sanitized info and context to delegate', () {
      final delegate = _RecordingLogger();
      final logger = SanitizedLogger(delegate: delegate);

      logger.info(
        'call with sk-ant-abcdefghijklmnopqrstuvwxyz123456',
        context: <String, Object?>{
          'phone': '13800138000',
        },
      );

      expect(delegate.lastInfo, contains('[REDACTED]'));
      expect(delegate.lastInfo, isNot(contains('sk-ant-')));
      expect(delegate.lastContext?['phone'], equals('[REDACTED]'));
    });

    test('forwards sanitized warning and error to delegate', () {
      final delegate = _RecordingLogger();
      final logger = SanitizedLogger(delegate: delegate);

      logger.warning('phone 13800138000');
      logger.error(
        'err with key sk-abcdefghijklmnopqrstuvwxyz123456',
        error: 'id 110105199001011234',
      );

      expect(delegate.lastWarning, contains('[REDACTED]'));
      expect(delegate.lastError, contains('[REDACTED]'));
      expect(delegate.lastError, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz123456')));
    });
  });
}