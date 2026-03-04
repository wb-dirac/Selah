import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_models.dart';

class ModelRoutingEngine {
  const ModelRoutingEngine();

  RoutingDecision route({
    required RoutingContext context,
    required List<RoutingRule> rules,
    required String defaultProviderId,
    String? defaultModelId,
  }) {
    for (final rule in rules) {
      if (!_matches(rule: rule, context: context)) {
        continue;
      }

      if (!context.primaryProviderAvailable && rule.fallbackProviderId != null) {
        return RoutingDecision(
          providerId: rule.fallbackProviderId!,
          modelId: rule.fallbackModelId,
          usedFallback: true,
          reason: 'Primary unavailable, fallback applied',
        );
      }

      return RoutingDecision(
        providerId: rule.targetProviderId,
        modelId: rule.targetModelId,
        reason: 'Matched routing rule',
      );
    }

    return RoutingDecision(
      providerId: defaultProviderId,
      modelId: defaultModelId,
      reason: 'No rule matched, using default',
    );
  }

  bool _matches({
    required RoutingRule rule,
    required RoutingContext context,
  }) {
    final complexityMatched =
        rule.complexity == RoutingComplexity.any || rule.complexity == context.complexity;
    final modalityMatched =
        rule.modality == RoutingModality.any || rule.modality == context.modality;
    return complexityMatched && modalityMatched;
  }
}