import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/a2a/data/tls_connection_policy.dart';

void main() {
  const policy = TlsConnectionPolicy();

  group('TlsConnectionPolicy — URL validation', () {
    test('accepts valid https URL', () {
      final r = policy.validateUrl('https://agent.example.com/a2a');
      expect(r, isA<TlsValidationPassed>());
    });

    test('accepts https URL with port', () {
      final r = policy.validateUrl('https://192.168.1.10:8080/a2a');
      expect(r, isA<TlsValidationPassed>());
    });

    test('rejects http:// URL', () {
      final r = policy.validateUrl('http://agent.example.com/a2a');
      expect(r, isA<TlsValidationFailed>());
      expect(
        (r as TlsValidationFailed).reason,
        contains('HTTPS'),
      );
    });

    test('rejects ws:// URL', () {
      final r = policy.validateUrl('ws://agent.example.com/a2a');
      expect(r, isA<TlsValidationFailed>());
    });

    test('rejects malformed URL', () {
      final r = policy.validateUrl('not a url @@@@');
      expect(r, isA<TlsValidationFailed>());
    });

    test('rejects https URL with empty host', () {
      final r = policy.validateUrl('https:///path');
      expect(r, isA<TlsValidationFailed>());
      expect((r as TlsValidationFailed).reason, contains('主机名'));
    });

    test('rejection reason mentions TLS', () {
      final r = policy.validateUrl('http://bad.example.com');
      final reason = (r as TlsValidationFailed).reason;
      expect(reason.toLowerCase().contains('tls') || reason.contains('HTTPS'), isTrue);
    });
  });

  group('TlsConnectionPolicy — HttpClient', () {
    test('buildSecureClient returns non-null client', () {
      final client = policy.buildSecureClient();
      expect(client, isNotNull);
      client.close();
    });

    test('client has connection timeout configured', () {
      final client = policy.buildSecureClient();
      expect(client.connectionTimeout, const Duration(seconds: 15));
      client.close();
    });
  });
}
