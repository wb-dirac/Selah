class OpenAiCompatibleProviderConfig {
	const OpenAiCompatibleProviderConfig({
		required this.providerId,
		required this.baseUrl,
		this.defaultModel,
	});

	final String providerId;
	final Uri baseUrl;
	final String? defaultModel;
}