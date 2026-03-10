import 'dart:io';

sealed class TlsValidationResult {}

class TlsValidationPassed extends TlsValidationResult {}

class TlsValidationFailed extends TlsValidationResult {
  TlsValidationFailed(this.reason);
  final String reason;
}

class TlsConnectionPolicy {
  const TlsConnectionPolicy();

  TlsValidationResult validateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return TlsValidationFailed('URL 格式无效: $url');
    }
    if (uri.scheme != 'https') {
      return TlsValidationFailed(
        'A2A 连接必须使用 HTTPS（当前: ${uri.scheme}），低版本或非 TLS 连接已拒绝',
      );
    }
    if (uri.host.isEmpty) {
      return TlsValidationFailed('URL 缺少主机名');
    }
    return TlsValidationPassed();
  }

  HttpClient buildSecureClient() {
    final context = SecurityContext(withTrustedRoots: true);
    final client = HttpClient(context: context)
      ..badCertificateCallback = _rejectBadCertificate
      ..connectionTimeout = const Duration(seconds: 15);
    return client;
  }

  static bool _rejectBadCertificate(
    X509Certificate cert,
    String host,
    int port,
  ) {
    return false;
  }
}
