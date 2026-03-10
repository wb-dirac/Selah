import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';

class ChatChunk {
	const ChatChunk({
		required this.textDelta,
		this.isDone = false,
		this.inputTokens,
		this.outputTokens,
		this.toolCalls,
	});

	final String textDelta;
	final bool isDone;
	final int? inputTokens;
	final int? outputTokens;

	/// Tool calls requested by the LLM (non-null means the model wants to invoke tools).
	final List<ToolCallRequest>? toolCalls;

	bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}