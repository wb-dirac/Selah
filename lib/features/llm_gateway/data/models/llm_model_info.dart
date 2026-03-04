class LlmModelInfo {
	const LlmModelInfo({
		required this.id,
		required this.displayName,
		required this.provider,
		this.supportsVision = false,
		this.supportsTools = false,
		this.contextWindowTokens,
	});

	final String id;
	final String displayName;
	final String provider;
	final bool supportsVision;
	final bool supportsTools;
	final int? contextWindowTokens;
}