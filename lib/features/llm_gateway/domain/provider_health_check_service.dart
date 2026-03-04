import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/anthropic_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/gemini_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/ollama_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/openai_compatible_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/provider_health_check_result.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/anthropic_provider.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/gemini_provider.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/ollama_provider.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/openai_compatible_provider.dart';

class ProviderHealthCheckService {
	const ProviderHealthCheckService({
		required ProviderApiKeyStore keyStore,
		required SecureHttpClient secureHttpClient,
		required LocalHttpClient localHttpClient,
	})  : _keyStore = keyStore,
				_secureHttpClient = secureHttpClient,
				_localHttpClient = localHttpClient;

	final ProviderApiKeyStore _keyStore;
	final SecureHttpClient _secureHttpClient;
	final LocalHttpClient _localHttpClient;

	Future<ProviderHealthCheckResult> testOpenAiCompatible({
		required OpenAiCompatibleProviderConfig config,
		required String apiKey,
	}) async {
		await _keyStore.save(providerId: config.providerId, apiKey: apiKey);

		try {
			final provider = OpenAiCompatibleProvider(
				config: config,
				keyStore: _keyStore,
				httpClient: _secureHttpClient,
			);
			final models = await provider.listModels();
			return ProviderHealthCheckResult(
				success: true,
				message: '连接成功',
				models: models.map((e) => e.id).toList(growable: false),
			);
		} catch (error) {
			return ProviderHealthCheckResult(
				success: false,
				message: error.toString(),
			);
		}
	}

	Future<ProviderHealthCheckResult> testAnthropic({
		required AnthropicProviderConfig config,
		required String apiKey,
	}) async {
		await _keyStore.save(providerId: config.providerId, apiKey: apiKey);

		try {
			final provider = AnthropicProvider(
				config: config,
				keyStore: _keyStore,
				httpClient: _secureHttpClient,
			);
			final models = await provider.listModels();
			return ProviderHealthCheckResult(
				success: true,
				message: '连接成功',
				models: models.map((e) => e.id).toList(growable: false),
			);
		} catch (error) {
			return ProviderHealthCheckResult(
				success: false,
				message: error.toString(),
			);
		}
	}

	Future<ProviderHealthCheckResult> testGemini({
		required GeminiProviderConfig config,
		required String apiKey,
	}) async {
		await _keyStore.save(providerId: config.providerId, apiKey: apiKey);

		try {
			final provider = GeminiProvider(
				config: config,
				keyStore: _keyStore,
				httpClient: _secureHttpClient,
			);
			final models = await provider.listModels();
			return ProviderHealthCheckResult(
				success: true,
				message: '连接成功',
				models: models.map((e) => e.id).toList(growable: false),
			);
		} catch (error) {
			return ProviderHealthCheckResult(
				success: false,
				message: error.toString(),
			);
		}
	}

	Future<ProviderHealthCheckResult> testOllama({
		required OllamaProviderConfig config,
	}) async {
		try {
			final provider = OllamaProvider(
				config: config,
				httpClient: _localHttpClient,
			);
			final models = await provider.listModels();
			return ProviderHealthCheckResult(
				success: true,
				message: '连接成功',
				models: models.map((e) => e.id).toList(growable: false),
			);
		} catch (error) {
			return ProviderHealthCheckResult(
				success: false,
				message: error.toString(),
			);
		}
	}
}

final secureHttpClientProvider = Provider<SecureHttpClient>((ref) {
	return SecureHttpClient();
});

final localHttpClientProvider = Provider<LocalHttpClient>((ref) {
	return LocalHttpClient();
});

final providerHealthCheckServiceProvider = Provider<ProviderHealthCheckService>(
	(ref) {
		final keyStore = ref.watch(providerApiKeyStoreProvider);
		final secureHttpClient = ref.watch(secureHttpClientProvider);
		final localHttpClient = ref.watch(localHttpClientProvider);
		return ProviderHealthCheckService(
			keyStore: keyStore,
			secureHttpClient: secureHttpClient,
			localHttpClient: localHttpClient,
		);
	},
);