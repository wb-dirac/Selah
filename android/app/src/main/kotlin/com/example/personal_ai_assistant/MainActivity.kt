package com.example.personal_ai_assistant

import android.content.Context
import android.net.ConnectivityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"personal_ai_assistant/network"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getSystemProxy" -> result.success(readSystemProxy())
				else -> result.notImplemented()
			}
		}
	}

	private fun readSystemProxy(): Map<String, Any>? {
		try {
			val connectivityManager =
				getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
			val network = connectivityManager?.activeNetwork
			val linkProperties = connectivityManager?.getLinkProperties(network)
			val proxyInfo = linkProperties?.httpProxy
			val host = proxyInfo?.host?.trim()
			val port = proxyInfo?.port ?: -1

			if (!host.isNullOrEmpty() && port > 0) {
				return mapOf("host" to host, "port" to port)
			}
		} catch (_: Throwable) {
		}

		val host = System.getProperty("http.proxyHost")?.trim()
		val port = System.getProperty("http.proxyPort")?.toIntOrNull()
		if (!host.isNullOrEmpty() && (port ?: 0) > 0) {
			return mapOf("host" to host, "port" to port!!)
		}

		return null
	}
}
