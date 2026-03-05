import 'dart:convert';

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
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_health_check_service.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

enum ManagedProviderType {
  openAiCompatible,
  anthropic,
  gemini,
  ollama,
}

extension ManagedProviderTypeX on ManagedProviderType {
  String get value {
    switch (this) {
      case ManagedProviderType.openAiCompatible:
        return 'openai_compatible';
      case ManagedProviderType.anthropic:
        return 'anthropic';
      case ManagedProviderType.gemini:
        return 'gemini';
      case ManagedProviderType.ollama:
        return 'ollama';
    }
  }

  String get label {
    switch (this) {
      case ManagedProviderType.openAiCompatible:
        return 'OpenAI Compatible';
      case ManagedProviderType.anthropic:
        return 'Anthropic';
      case ManagedProviderType.gemini:
        return 'Gemini';
      case ManagedProviderType.ollama:
        return 'Ollama';
    }
  }

  static ManagedProviderType fromValue(String value) {
    return ManagedProviderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ManagedProviderType.openAiCompatible,
    );
  }
}

class ManagedProviderConfig {
  const ManagedProviderConfig({
    required this.providerId,
    required this.type,
    required this.displayName,
    this.baseUrl,
    this.defaultModel,
    this.enabled = true,
  });

  final String providerId;
  final ManagedProviderType type;
  final String displayName;
  final String? baseUrl;
  final String? defaultModel;
  final bool enabled;

  ManagedProviderConfig copyWith({
    String? providerId,
    ManagedProviderType? type,
    String? displayName,
    String? baseUrl,
    String? defaultModel,
    bool? enabled,
  }) {
    return ManagedProviderConfig(
      providerId: providerId ?? this.providerId,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'provider_id': providerId,
      'type': type.value,
      'display_name': displayName,
      'base_url': baseUrl,
      'default_model': defaultModel,
      'enabled': enabled,
    };
  }

  factory ManagedProviderConfig.fromJson(Map<String, dynamic> json) {
    return ManagedProviderConfig(
      providerId: json['provider_id'] as String,
      type: ManagedProviderTypeX.fromValue(json['type'] as String? ?? ''),
      displayName: json['display_name'] as String,
      baseUrl: json['base_url'] as String?,
      defaultModel: json['default_model'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class ProviderManagementService {
  ProviderManagementService({
    required KeychainPreferencesStore preferencesStore,
    required ProviderApiKeyStore keyStore,
    required ProviderHealthCheckService healthCheckService,
    required SecureHttpClient secureHttpClient,
    required LocalHttpClient localHttpClient,
  }) : _preferencesStore = preferencesStore,
       _keyStore = keyStore,
       _healthCheckService = healthCheckService,
       _secureHttpClient = secureHttpClient,
       _localHttpClient = localHttpClient;

  final KeychainPreferencesStore _preferencesStore;
  final ProviderApiKeyStore _keyStore;
  final ProviderHealthCheckService _healthCheckService;
  final SecureHttpClient _secureHttpClient;
  final LocalHttpClient _localHttpClient;

  static const _configsKey = 'llm.providers.configs.v1';
  static const _selectedProviderKey = 'llm.providers.selected.v1';

  Future<List<ManagedProviderConfig>> listConfigs() async {
    final source = await _preferencesStore.readString(_configsKey);
    if (source == null || source.trim().isEmpty) return const [];

    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ManagedProviderConfig.fromJson)
        .toList(growable: false);
  }

  Future<void> saveConfig(ManagedProviderConfig config, {String? apiKey}) async {
    final existing = await listConfigs();
    final next = <ManagedProviderConfig>[];
    bool replaced = false;

    for (final item in existing) {
      if (item.providerId == config.providerId) {
        next.add(config);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) next.add(config);

    await _saveConfigs(next);
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _keyStore.save(providerId: config.providerId, apiKey: apiKey.trim());
    }

    final selected = await selectedProviderId();
    if (selected == null || selected.isEmpty) {
      await setSelectedProvider(config.providerId);
    }
  }

  Future<void> deleteConfig(String providerId) async {
    final existing = await listConfigs();
    final next = existing.where((item) => item.providerId != providerId).toList();
    await _saveConfigs(next);
    await _keyStore.delete(providerId: providerId);

    final selected = await selectedProviderId();
    if (selected == providerId) {
      final fallback = next.where((item) => item.enabled).firstOrNull;
      await setSelectedProvider(fallback?.providerId);
    }
  }

  Future<void> setSelectedProvider(String? providerId) async {
    if (providerId == null || providerId.isEmpty) {
      await _preferencesStore.saveString(_selectedProviderKey, '');
      return;
    }
    await _preferencesStore.saveString(_selectedProviderKey, providerId);
  }

  Future<String?> selectedProviderId() async {
    final value = await _preferencesStore.readString(_selectedProviderKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<ManagedProviderConfig?> selectedOrFirstEnabled() async {
    final configs = await listConfigs();
    if (configs.isEmpty) return null;

    final selectedId = await selectedProviderId();
    if (selectedId != null) {
      for (final item in configs) {
        if (item.providerId == selectedId && item.enabled) {
          return item;
        }
      }
    }

    return configs.where((item) => item.enabled).firstOrNull;
  }

  Future<ManagedProviderConfig?> findEnabledById(String providerId) async {
    final configs = await listConfigs();
    for (final item in configs) {
      if (item.providerId == providerId && item.enabled) {
        return item;
      }
    }
    return null;
  }

  Future<LlmGateway?> buildGatewayFromConfig(
    ManagedProviderConfig config, {
    String? overrideModelId,
  }) async {
    switch (config.type) {
      case ManagedProviderType.openAiCompatible:
        return OpenAiCompatibleProvider(
          config: OpenAiCompatibleProviderConfig(
            providerId: config.providerId,
            baseUrl: Uri.parse(
              config.baseUrl?.trim().isNotEmpty == true
                  ? config.baseUrl!.trim()
                  : 'https://api.openai.com/v1',
            ),
            defaultModel: overrideModelId ?? config.defaultModel,
          ),
          keyStore: _keyStore,
          httpClient: _secureHttpClient,
        );
      case ManagedProviderType.anthropic:
        return AnthropicProvider(
          config: AnthropicProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const AnthropicProviderConfig().baseUrl,
            defaultModel: overrideModelId ?? config.defaultModel,
          ),
          keyStore: _keyStore,
          httpClient: _secureHttpClient,
        );
      case ManagedProviderType.gemini:
        return GeminiProvider(
          config: GeminiProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const GeminiProviderConfig().baseUrl,
            defaultModel: overrideModelId ?? config.defaultModel,
          ),
          keyStore: _keyStore,
          httpClient: _secureHttpClient,
        );
      case ManagedProviderType.ollama:
        return OllamaProvider(
          config: OllamaProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const OllamaProviderConfig().baseUrl,
            defaultModel: overrideModelId ?? config.defaultModel,
          ),
          httpClient: _localHttpClient,
        );
    }
  }

  Future<ProviderHealthCheckResult> testConfig(
    ManagedProviderConfig config, {
    String? apiKey,
  }) async {
    switch (config.type) {
      case ManagedProviderType.openAiCompatible:
        final key = await _resolveApiKey(config.providerId, apiKey);
        if (key == null) {
          return const ProviderHealthCheckResult(
            success: false,
            message: '请填写 API Key',
          );
        }
        return _healthCheckService.testOpenAiCompatible(
          config: OpenAiCompatibleProviderConfig(
            providerId: config.providerId,
            baseUrl: Uri.parse(
              config.baseUrl?.trim().isNotEmpty == true
                  ? config.baseUrl!.trim()
                  : 'https://api.openai.com/v1',
            ),
            defaultModel: config.defaultModel,
          ),
          apiKey: key,
        );
      case ManagedProviderType.anthropic:
        final key = await _resolveApiKey(config.providerId, apiKey);
        if (key == null) {
          return const ProviderHealthCheckResult(
            success: false,
            message: '请填写 API Key',
          );
        }
        return _healthCheckService.testAnthropic(
          config: AnthropicProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const AnthropicProviderConfig().baseUrl,
            defaultModel: config.defaultModel,
          ),
          apiKey: key,
        );
      case ManagedProviderType.gemini:
        final key = await _resolveApiKey(config.providerId, apiKey);
        if (key == null) {
          return const ProviderHealthCheckResult(
            success: false,
            message: '请填写 API Key',
          );
        }
        return _healthCheckService.testGemini(
          config: GeminiProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const GeminiProviderConfig().baseUrl,
            defaultModel: config.defaultModel,
          ),
          apiKey: key,
        );
      case ManagedProviderType.ollama:
        return _healthCheckService.testOllama(
          config: OllamaProviderConfig(
            providerId: config.providerId,
            baseUrl: config.baseUrl?.trim().isNotEmpty == true
                ? config.baseUrl!.trim()
                : const OllamaProviderConfig().baseUrl,
            defaultModel: config.defaultModel,
          ),
        );
    }
  }

  Future<void> _saveConfigs(List<ManagedProviderConfig> configs) async {
    final payload = jsonEncode(configs.map((item) => item.toJson()).toList());
    await _preferencesStore.saveString(_configsKey, payload);
  }

  Future<String?> _resolveApiKey(String providerId, String? input) async {
    if (input != null && input.trim().isNotEmpty) {
      return input.trim();
    }
    final stored = await _keyStore.read(providerId: providerId);
    if (stored == null || stored.trim().isEmpty) return null;
    return stored.trim();
  }
}

final providerManagementServiceProvider = Provider<ProviderManagementService>(
  (ref) {
    return ProviderManagementService(
      preferencesStore: ref.watch(keychainPreferencesStoreProvider),
      keyStore: ref.watch(providerApiKeyStoreProvider),
      healthCheckService: ref.watch(providerHealthCheckServiceProvider),
      secureHttpClient: ref.watch(secureHttpClientProvider),
      localHttpClient: ref.watch(localHttpClientProvider),
    );
  },
);
