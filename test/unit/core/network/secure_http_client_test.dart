import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';

void main() {
  group('SecureHttpClient', () {
    test('rejects non-https url for get', () {
      final client = SecureHttpClient();

      expect(
        () => client.get(Uri.parse('http://example.com/models')),
        throwsA(isA<InsecureUrlException>()),
      );
    });

    test('rejects non-https url for post', () {
      final client = SecureHttpClient();

      expect(
        () => client.post(Uri.parse('http://example.com/chat')),
        throwsA(isA<InsecureUrlException>()),
      );
    });
  });
}