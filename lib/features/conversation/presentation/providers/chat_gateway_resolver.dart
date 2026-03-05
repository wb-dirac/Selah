import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/ollama_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/openai_compatible_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/ollama_provider.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/openai_compatible_provider.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_health_check_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_models.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/routing_settings_service.dart';

class ChatGatewayResolver {
  ChatGatewayResolver({
    required ProviderApiKeyStore keyStore,
    required ProviderManagementService providerManagementService,
    required RoutingSettingsService routingSettingsService,
    required SecureHttpClient secureHttpClient,
    required LocalHttpClient localHttpClient,
  })  : _keyStore = keyStore,
        _providerManagementService = providerManagementService,
        _routingSettingsService = routingSettingsService,
        _secureHttpClient = secureHttpClient,
        _localHttpClient = localHttpClient;

  final ProviderApiKeyStore _keyStore;
  final ProviderManagementService _providerManagementService;
  final RoutingSettingsService _routingSettingsService;
  final SecureHttpClient _secureHttpClient;
  final LocalHttpClient _localHttpClient;

  Future<LlmGateway?> resolveForInput({
    required String userContent,
    required bool hasImages,
  }) async {
    final decision = await _routingSettingsService.decide(
      promptTokens: _estimatePromptTokens(userContent),
      modality: hasImages ? RoutingModality.image : RoutingModality.text,
    );

    if (decision != null) {
      final target = await _providerManagementService.findEnabledById(
        decision.providerId,
      );
      if (target != null) {
        final routed = await _providerManagementService.buildGatewayFromConfig(
          target,
          overrideModelId: decision.modelId,
        );
        if (routed != null) return routed;
      }
    }

    return resolve();
  }

  Future<LlmGateway?> resolve() async {
    final selectedConfig = await _providerManagementService.selectedOrFirstEnabled();
    if (selectedConfig != null) {
      final gateway = await _providerManagementService.buildGatewayFromConfig(
        selectedConfig,
      );
      if (gateway != null) return gateway;
    }

    final ollama = await _resolveOllama();
    if (ollama != null) return ollama;

    final openAi = await _resolveOpenAiFromEnv();
    if (openAi != null) return openAi;

    return null;
  }

  int _estimatePromptTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 1;
    return (trimmed.length / 4).ceil();
  }

  Future<LlmGateway?> _resolveOllama() async {
    const baseUrl = String.fromEnvironment(
      'OLLAMA_BASE_URL',
      defaultValue: 'http://localhost:11434',
    );
    const modelFromEnv = String.fromEnvironment('OLLAMA_MODEL');
    final model = modelFromEnv.trim().isEmpty ? null : modelFromEnv.trim();

    try {
      if (model != null) {
        return OllamaProvider(
          config: OllamaProviderConfig(baseUrl: baseUrl, defaultModel: model),
          httpClient: _localHttpClient,
        );
      }

      final probe = OllamaProvider(
        config: const OllamaProviderConfig(baseUrl: baseUrl),
        httpClient: _localHttpClient,
      );
      final models = await probe.listModels();
      if (models.isEmpty) return null;

      return OllamaProvider(
        config: OllamaProviderConfig(
          baseUrl: baseUrl,
          defaultModel: models.first.id,
        ),
        httpClient: _localHttpClient,
      );
    } catch (_) {
      return null;
    }
  }

  Future<LlmGateway?> _resolveOpenAiFromEnv() async {
    const apiKey = String.fromEnvironment('OPENAI_API_KEY');
    if (apiKey.trim().isEmpty) return null;

    const providerId = String.fromEnvironment(
      'OPENAI_PROVIDER_ID',
      defaultValue: 'openai',
    );
    const baseUrlString = String.fromEnvironment(
      'OPENAI_BASE_URL',
      defaultValue: 'https://api.openai.com/v1',
    );
    const model = String.fromEnvironment(
      'OPENAI_MODEL',
      defaultValue: 'gpt-4o-mini',
    );

    await _keyStore.save(providerId: providerId, apiKey: apiKey);

    return OpenAiCompatibleProvider(
      config: OpenAiCompatibleProviderConfig(
        providerId: providerId,
        baseUrl: Uri.parse(baseUrlString),
        defaultModel: model,
      ),
      keyStore: _keyStore,
      httpClient: _secureHttpClient,
    );
  }
}

final chatGatewayResolverProvider = Provider<ChatGatewayResolver>((ref) {
  final keyStore = ref.watch(providerApiKeyStoreProvider);
  final providerManagementService = ref.watch(providerManagementServiceProvider);
  final routingSettingsService = ref.watch(routingSettingsServiceProvider);
  return ChatGatewayResolver(
    keyStore: keyStore,
    providerManagementService: providerManagementService,
    routingSettingsService: routingSettingsService,
    secureHttpClient: ref.watch(secureHttpClientProvider),
    localHttpClient: ref.watch(localHttpClientProvider),
  );
});
