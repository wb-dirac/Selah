enum RoutingComplexity {
  simple,
  complex,
  any,
}

enum RoutingModality {
  text,
  image,
  audio,
  file,
  any,
}

class RoutingContext {
  const RoutingContext({
    required this.promptTokens,
    required this.modality,
    this.primaryProviderAvailable = true,
  });

  final int promptTokens;
  final RoutingModality modality;
  final bool primaryProviderAvailable;

  RoutingComplexity get complexity {
    if (promptTokens < 500) {
      return RoutingComplexity.simple;
    }
    return RoutingComplexity.complex;
  }
}

class RoutingRule {
  const RoutingRule({
    required this.targetProviderId,
    this.targetModelId,
    this.complexity = RoutingComplexity.any,
    this.modality = RoutingModality.any,
    this.fallbackProviderId,
    this.fallbackModelId,
  });

  final String targetProviderId;
  final String? targetModelId;
  final RoutingComplexity complexity;
  final RoutingModality modality;
  final String? fallbackProviderId;
  final String? fallbackModelId;
}

class RoutingDecision {
  const RoutingDecision({
    required this.providerId,
    this.modelId,
    this.usedFallback = false,
    this.reason,
  });

  final String providerId;
  final String? modelId;
  final bool usedFallback;
  final String? reason;
}