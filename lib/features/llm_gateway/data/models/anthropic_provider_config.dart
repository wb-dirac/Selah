class AnthropicProviderConfig {
  const AnthropicProviderConfig({
    this.providerId = 'anthropic',
    this.baseUrl = const String.fromEnvironment(
      'ANTHROPIC_BASE_URL',
      defaultValue: 'https://api.anthropic.com/v1',
    ),
    this.defaultModel,
    this.apiVersion = '2023-06-01',
  });

  final String providerId;
  final String baseUrl;
  final String? defaultModel;
  final String apiVersion;

  Uri get endpoint => Uri.parse(baseUrl);
}