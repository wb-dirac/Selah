package com.example.personal_ai_assistant

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		// ── Network channel (pre-existing) ───────────────────────────────────
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"personal_ai_assistant/network"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getSystemProxy" -> result.success(readSystemProxy())
				else -> result.notImplemented()
			}
		}

		// ── Background tasks channel ─────────────────────────────────────────
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"personal_ai_assistant/background_tasks"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"scheduleTask" -> {
					// WorkManager scheduling is handled by the workmanager Flutter plugin.
					// This stub allows the Dart scheduler service to call through without
					// a MissingPluginException on Android while workmanager handles the
					// real scheduling.
					result.success(null)
				}

				"cancelTask" -> {
					// WorkManager task cancellation is handled by the workmanager plugin.
					result.success(null)
				}

				"cancelAll" -> {
					// WorkManager cancel-all is handled by the workmanager plugin.
					result.success(null)
				}

				"isBatteryOptimizationBypassed" -> {
					try {
						val pm = getSystemService(POWER_SERVICE) as PowerManager
						result.success(pm.isIgnoringBatteryOptimizations(packageName))
					} catch (e: Throwable) {
						result.error("BATTERY_CHECK_FAILED", e.message, null)
					}
				}

				"openBatteryOptimizationSettings" -> {
					try {
						val intent = Intent(
							Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
						).apply {
							data = Uri.parse("package:$packageName")
						}
						startActivity(intent)
						result.success(null)
					} catch (e: Throwable) {
						// Fallback: open general battery settings if direct intent fails.
						try {
							startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
							result.success(null)
						} catch (_: Throwable) {
							result.error("SETTINGS_OPEN_FAILED", e.message, null)
						}
					}
				}

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
