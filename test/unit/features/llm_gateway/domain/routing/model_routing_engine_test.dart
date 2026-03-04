import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_engine.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_models.dart';

void main() {
  group('ModelRoutingEngine', () {
    const engine = ModelRoutingEngine();

    test('routes simple text request to matched rule', () {
      final decision = engine.route(
        context: const RoutingContext(
          promptTokens: 100,
          modality: RoutingModality.text,
        ),
        rules: const [
          RoutingRule(
            targetProviderId: 'ollama',
            targetModelId: 'qwen2.5:7b',
            complexity: RoutingComplexity.simple,
            modality: RoutingModality.text,
          ),
        ],
        defaultProviderId: 'openai',
        defaultModelId: 'gpt-4o',
      );

      expect(decision.providerId, equals('ollama'));
      expect(decision.modelId, equals('qwen2.5:7b'));
      expect(decision.usedFallback, isFalse);
    });

    test('uses fallback when primary unavailable', () {
      final decision = engine.route(
        context: const RoutingContext(
          promptTokens: 2000,
          modality: RoutingModality.image,
          primaryProviderAvailable: false,
        ),
        rules: const [
          RoutingRule(
            targetProviderId: 'anthropic',
            targetModelId: 'claude-sonnet-4-6',
            complexity: RoutingComplexity.complex,
            modality: RoutingModality.image,
            fallbackProviderId: 'gemini',
            fallbackModelId: 'gemini-2.5-pro',
          ),
        ],
        defaultProviderId: 'openai',
      );

      expect(decision.providerId, equals('gemini'));
      expect(decision.usedFallback, isTrue);
    });

    test('falls back to default when no rule matches', () {
      final decision = engine.route(
        context: const RoutingContext(
          promptTokens: 1200,
          modality: RoutingModality.audio,
        ),
        rules: const [
          RoutingRule(
            targetProviderId: 'anthropic',
            modality: RoutingModality.image,
          ),
        ],
        defaultProviderId: 'openai',
        defaultModelId: 'gpt-4o',
      );

      expect(decision.providerId, equals('openai'));
      expect(decision.modelId, equals('gpt-4o'));
    });
  });
}
