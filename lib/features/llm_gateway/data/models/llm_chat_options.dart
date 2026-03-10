import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';

class LlmChatOptions {
	const LlmChatOptions({
		this.model,
		this.temperature,
		this.maxOutputTokens,
		this.topP,
		this.tools,
	});

	final String? model;
	final double? temperature;
	final int? maxOutputTokens;
	final double? topP;

	/// Tools/functions the LLM may call. When non-empty, providers
	/// include these in the request and parse tool-call responses.
	final List<ToolSpec>? tools;
}