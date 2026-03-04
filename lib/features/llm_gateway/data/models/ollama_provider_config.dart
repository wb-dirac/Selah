class OllamaProviderConfig {
  const OllamaProviderConfig({
    this.providerId = 'ollama',
    this.baseUrl = 'http://localhost:11434',
    this.defaultModel,
  });

  final String providerId;
  final String baseUrl;
  final String? defaultModel;

  Uri get endpoint => Uri.parse(baseUrl);
}