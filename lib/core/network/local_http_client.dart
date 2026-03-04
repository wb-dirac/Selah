import 'dart:convert';

import 'package:http/http.dart' as http;

class InsecureLocalUrlException implements Exception {
  const InsecureLocalUrlException(this.url);

  final String url;

  @override
  String toString() => 'InsecureLocalUrlException: $url';
}

class LocalHttpClient {
  LocalHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) {
    _ensureLocal(uri);
    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    _ensureLocal(uri);
    return _client
        .post(
          uri,
          headers: headers,
          body: body,
          encoding: encoding,
        )
        .timeout(timeout);
  }

  void close() {
    _client.close();
  }

  void _ensureLocal(Uri uri) {
    final host = uri.host.toLowerCase();
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    final isSecure = uri.scheme.toLowerCase() == 'https';
    final isLocalHttp = uri.scheme.toLowerCase() == 'http' && isLoopback;
    if (!isSecure && !isLocalHttp) {
      throw InsecureLocalUrlException(uri.toString());
    }
  }
}