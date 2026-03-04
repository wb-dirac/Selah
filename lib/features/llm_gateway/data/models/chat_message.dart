enum ChatRole {
	system,
	user,
	assistant,
	tool,
}

class ChatMessage {
	const ChatMessage({
		required this.role,
		required this.content,
		this.name,
	});

	final ChatRole role;
	final String content;
	final String? name;
}