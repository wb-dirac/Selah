class ChatChunk {
	const ChatChunk({
		required this.textDelta,
		this.isDone = false,
		this.inputTokens,
		this.outputTokens,
	});

	final String textDelta;
	final bool isDone;
	final int? inputTokens;
	final int? outputTokens;
}