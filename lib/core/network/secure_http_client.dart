import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:personal_ai_assistant/core/network/proxy_settings_service.dart';

class InsecureUrlException implements Exception {
	const InsecureUrlException(this.url);

	final String url;

	@override
	String toString() => 'InsecureUrlException: $url';
}

class SecureHttpClient {
	static const MethodChannel _proxyChannel = MethodChannel(
		'personal_ai_assistant/network',
	);

	SecureHttpClient({
		http.Client? client,
		ProxySettingsService? proxySettingsService,
	}) : _client = client,
		 _proxySettingsService = proxySettingsService,
		 _fallbackClient =
				(client == null && proxySettingsService == null) ? http.Client() : null;

	final http.Client? _client;
	final ProxySettingsService? _proxySettingsService;
	final http.Client? _fallbackClient;
	static const Duration _defaultTimeout = Duration(seconds: 30);

	Future<http.Response> get(
		Uri uri, {
		Map<String, String>? headers,
		Duration timeout = _defaultTimeout,
	}) async {
		_ensureHttps(uri);
		final context = await _resolveClientContext();
		try {
			return await context.client.get(uri, headers: headers).timeout(timeout);
		} finally {
			if (context.shouldClose) {
				context.client.close();
			}
		}
	}

	Future<http.Response> post(
		Uri uri, {
		Map<String, String>? headers,
		Object? body,
		Encoding? encoding,
		Duration timeout = _defaultTimeout,
	}) async {
		_ensureHttps(uri);
		final context = await _resolveClientContext();
		try {
			return await context.client
					.post(
						uri,
						headers: headers,
						body: body,
						encoding: encoding,
					)
					.timeout(timeout);
		} finally {
			if (context.shouldClose) {
				context.client.close();
			}
		}
	}

	void close() {
		_client?.close();
		_fallbackClient?.close();
	}

	Future<_HttpClientContext> _resolveClientContext() async {
		if (_client != null) {
			return _HttpClientContext(client: _client, shouldClose: false);
		}

		if (_fallbackClient != null) {
			return _HttpClientContext(client: _fallbackClient, shouldClose: false);
		}

		final settings = await _proxySettingsService?.load() ??
				const ProxySettings();
		final ioHttpClient = HttpClient();

		if (settings.mode == ProxyMode.custom && settings.isCustomReady) {
			final proxyPrefix =
					settings.type == ProxyType.http ? 'PROXY' : 'SOCKS5';
			final proxyTarget = '${settings.host!.trim()}:${settings.port}';
			ioHttpClient.findProxy = (_) => '$proxyPrefix $proxyTarget';
		} else {
			final systemProxy = await _readAndroidSystemProxy();
			if (systemProxy != null) {
				ioHttpClient.findProxy = (_) =>
						'PROXY ${systemProxy.host}:${systemProxy.port}';
			} else {
				ioHttpClient.findProxy = HttpClient.findProxyFromEnvironment;
			}
		}

		return _HttpClientContext(
			client: IOClient(ioHttpClient),
			shouldClose: true,
		);
	}

	void _ensureHttps(Uri uri) {
		if (uri.scheme.toLowerCase() != 'https') {
			throw InsecureUrlException(uri.toString());
		}
	}

	Future<_SystemProxy?> _readAndroidSystemProxy() async {
		if (!Platform.isAndroid) return null;
		try {
			final map = await _proxyChannel.invokeMapMethod<String, dynamic>(
				'getSystemProxy',
			);
			if (map == null) return null;

			final host = (map['host'] as String?)?.trim();
			final dynamic portValue = map['port'];
			final port = switch (portValue) {
				int value => value,
				String value => int.tryParse(value),
				_ => null,
			};

			if (host == null || host.isEmpty || port == null || port <= 0) {
				return null;
			}

			return _SystemProxy(host: host, port: port);
		} on MissingPluginException {
			return null;
		} on PlatformException {
			return null;
		}
	}
}

class _HttpClientContext {
	const _HttpClientContext({required this.client, required this.shouldClose});

	final http.Client client;
	final bool shouldClose;
}

class _SystemProxy {
	const _SystemProxy({required this.host, required this.port});

	final String host;
	final int port;
}