import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/pii_detection_service.dart';

void main() {
  group('PiiDetectionService', () {
    final service = PiiDetectionService();

    test('masks phone number identity number and bank card', () {
      final result = service.detect(
        '手机号 13812345678，身份证 110101199003071234，银行卡 6222021234567890123',
      );

      expect(result.hasPii, isTrue);
      expect(result.matches.length, 3);
      expect(result.sanitizedText, contains('138****5678'));
      expect(result.sanitizedText, contains('110***********1234'));
      expect(result.sanitizedText, contains('6222 **** **** 0123'));
      expect(result.sanitizedText, isNot(contains('13812345678')));
    });

    test('returns unchanged text when no pii exists', () {
      final result = service.detect('今天下午帮我整理会议纪要');

      expect(result.hasPii, isFalse);
      expect(result.sanitizedText, equals('今天下午帮我整理会议纪要'));
    });
  });
}
