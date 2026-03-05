import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_engine.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_models.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class RoutingSettingsService {
  RoutingSettingsService({
    required KeychainPreferencesStore preferencesStore,
    required ProviderManagementService providerManagementService,
    ModelRoutingEngine? engine,
  }) : _preferencesStore = preferencesStore,
       _providerManagementService = providerManagementService,
       _engine = engine ?? const ModelRoutingEngine();

  final KeychainPreferencesStore _preferencesStore;
  final ProviderManagementService _providerManagementService;
  final ModelRoutingEngine _engine;

  static const _rulesKey = 'llm.routing.rules.v1';

  Future<List<RoutingRule>> listRules() async {
    final source = await _preferencesStore.readString(_rulesKey);
    if (source == null || source.trim().isEmpty) return const [];

    final decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_ruleFromJson)
        .toList(growable: false);
  }

  Future<void> saveRules(List<RoutingRule> rules) async {
    final payload = jsonEncode(rules.map(_ruleToJson).toList(growable: false));
    await _preferencesStore.saveString(_rulesKey, payload);
  }

  Future<RoutingDecision?> decide({
    required int promptTokens,
    required RoutingModality modality,
    bool primaryProviderAvailable = true,
  }) async {
    final selected = await _providerManagementService.selectedOrFirstEnabled();
    if (selected == null) return null;

    final rules = await listRules();
    final decision = _engine.route(
      context: RoutingContext(
        promptTokens: promptTokens,
        modality: modality,
        primaryProviderAvailable: primaryProviderAvailable,
      ),
      rules: rules,
      defaultProviderId: selected.providerId,
      defaultModelId: selected.defaultModel,
    );

    return decision;
  }

  static Map<String, Object?> _ruleToJson(RoutingRule rule) {
    return {
      'target_provider_id': rule.targetProviderId,
      'target_model_id': rule.targetModelId,
      'complexity': rule.complexity.name,
      'modality': rule.modality.name,
      'fallback_provider_id': rule.fallbackProviderId,
      'fallback_model_id': rule.fallbackModelId,
    };
  }

  static RoutingRule _ruleFromJson(Map<String, dynamic> json) {
    return RoutingRule(
      targetProviderId: json['target_provider_id'] as String,
      targetModelId: json['target_model_id'] as String?,
      complexity: RoutingComplexity.values.firstWhere(
        (item) => item.name == (json['complexity'] as String? ?? ''),
        orElse: () => RoutingComplexity.any,
      ),
      modality: RoutingModality.values.firstWhere(
        (item) => item.name == (json['modality'] as String? ?? ''),
        orElse: () => RoutingModality.any,
      ),
      fallbackProviderId: json['fallback_provider_id'] as String?,
      fallbackModelId: json['fallback_model_id'] as String?,
    );
  }
}

final routingSettingsServiceProvider = Provider<RoutingSettingsService>((ref) {
  return RoutingSettingsService(
    preferencesStore: ref.watch(keychainPreferencesStoreProvider),
    providerManagementService: ref.watch(providerManagementServiceProvider),
  );
});
