import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_ai_assistant/core/network/local_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/ollama_provider_config.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/providers/ollama_provider.dart';

void main() {
  test('OllamaProvider listModels parses response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.host, equals('localhost'));
      return http.Response('{"models":[{"name":"qwen2.5:7b"}]}', 200);
    });

    final provider = OllamaProvider(
      config: const OllamaProviderConfig(),
      httpClient: LocalHttpClient(client: mockClient),
    );

    final models = await provider.listModels();
    expect(models, hasLength(1));
    expect(models.first.id, equals('qwen2.5:7b'));
  });

  test('LocalHttpClient rejects non-local http endpoint', () {
    final client = LocalHttpClient();
    expect(
      () => client.get(Uri.parse('http://example.com/api/tags')),
      throwsA(isA<InsecureLocalUrlException>()),
    );
  });
}
