class GeminiProviderConfig {
  const GeminiProviderConfig({
    this.providerId = 'gemini',
    this.baseUrl = const String.fromEnvironment(
      'GEMINI_BASE_URL',
      defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
    ),
    this.defaultModel,
  });

  final String providerId;
  final String baseUrl;
  final String? defaultModel;

  Uri get endpoint => Uri.parse(baseUrl);
}