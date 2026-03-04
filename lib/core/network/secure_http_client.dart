import 'dart:convert';

import 'package:http/http.dart' as http;

class InsecureUrlException implements Exception {
	const InsecureUrlException(this.url);

	final String url;

	@override
	String toString() => 'InsecureUrlException: $url';
}

class SecureHttpClient {
	SecureHttpClient({http.Client? client}) : _client = client ?? http.Client();

	final http.Client _client;
	static const Duration _defaultTimeout = Duration(seconds: 30);

	Future<http.Response> get(
		Uri uri, {
		Map<String, String>? headers,
		Duration timeout = _defaultTimeout,
	}) {
		_ensureHttps(uri);
		return _client.get(uri, headers: headers).timeout(timeout);
	}

	Future<http.Response> post(
		Uri uri, {
		Map<String, String>? headers,
		Object? body,
		Encoding? encoding,
		Duration timeout = _defaultTimeout,
	}) {
		_ensureHttps(uri);
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

	void _ensureHttps(Uri uri) {
		if (uri.scheme.toLowerCase() != 'https') {
			throw InsecureUrlException(uri.toString());
		}
	}
}