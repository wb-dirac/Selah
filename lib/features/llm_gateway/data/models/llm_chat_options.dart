class LlmChatOptions {
	const LlmChatOptions({
		this.model,
		this.temperature,
		this.maxOutputTokens,
		this.topP,
	});

	final String? model;
	final double? temperature;
	final int? maxOutputTokens;
	final double? topP;
}