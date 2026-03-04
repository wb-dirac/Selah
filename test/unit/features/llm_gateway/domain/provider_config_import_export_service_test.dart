import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_config_import_export_service.dart';

void main() {
  group('ProviderConfigImportExportService', () {
    const service = ProviderConfigImportExportService();

    test('export clears api_key fields', () {
      const configs = [
        ProviderConfiguration(
          providerId: 'openai',
          displayName: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          defaultModel: 'gpt-4o',
          apiKey: 'sk-real-secret',
        ),
      ];

      final jsonText = service.exportConfigurations(configs);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final providers = decoded['providers'] as List<dynamic>;
      final first = providers.first as Map<String, dynamic>;

      expect(first['api_key'], equals(''));
    });

    test('import always strips api_key from source', () {
      const source =
          '{"providers":[{"provider_id":"gemini","display_name":"Gemini","api_key":"leaked","enabled":true}]}' ;

      final imported = service.importConfigurations(source);
      expect(imported, hasLength(1));
      expect(imported.first.providerId, equals('gemini'));
      expect(imported.first.apiKey, equals(''));
    });
  });
}
