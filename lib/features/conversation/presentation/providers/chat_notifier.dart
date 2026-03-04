import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/conversation/domain/conversation_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:uuid/uuid.dart';

class DisplayMessage {
	const DisplayMessage({
		required this.id,
		required this.role,
		required this.content,
		required this.createdAt,
		this.isStreaming = false,
	});

	final String id;
	final ChatRole role;
	final String content;
	final bool isStreaming;
	final DateTime createdAt;

	DisplayMessage copyWith({
		String? content,
		bool? isStreaming,
	}) {
		return DisplayMessage(
			id: id,
			role: role,
			content: content ?? this.content,
			createdAt: createdAt,
			isStreaming: isStreaming ?? this.isStreaming,
		);
	}
}

class ChatState {
	const ChatState({
		this.conversationId,
		this.messages = const [],
		this.isStreaming = false,
		this.error,
	});

	final String? conversationId;
	final List<DisplayMessage> messages;
	final bool isStreaming;
	final String? error;

	ChatState copyWith({
		String? conversationId,
		List<DisplayMessage>? messages,
		bool? isStreaming,
		String? error,
		bool clearError = false,
	}) {
		return ChatState(
			conversationId: conversationId ?? this.conversationId,
			messages: messages ?? this.messages,
			isStreaming: isStreaming ?? this.isStreaming,
			error: clearError ? null : (error ?? this.error),
		);
	}
}

class ChatNotifier extends AsyncNotifier<ChatState> {
	@override
	Future<ChatState> build() async {
		return const ChatState();
	}

	Future<void> initialize() async {
		final service = ref.read(conversationServiceProvider);
		final conversation = await service.getOrCreateActiveConversation();
		final rawMessages = await service.getMessages(conversation.id);

		// messages from DB are newest-first; reverse for chronological display
		final display = rawMessages.reversed.map((m) {
			return DisplayMessage(
				id: m.id,
				role: _roleFromString(m.role),
				content: m.content,
				createdAt: m.createdAt,
			);
		}).toList();

		state = AsyncData(
			ChatState(
				conversationId: conversation.id,
				messages: display,
			),
		);
	}

	Future<void> sendMessage(String userContent, LlmGateway? gateway) async {
		final current = state.valueOrNull;
		if (current == null) return;
		if (userContent.trim().isEmpty) return;

		final service = ref.read(conversationServiceProvider);

		String conversationId = current.conversationId ?? '';
		if (conversationId.isEmpty) {
			final conv = await service.getOrCreateActiveConversation();
			conversationId = conv.id;
		}

		final userEntity = await service.addMessage(
			conversationId: conversationId,
			role: 'user',
			content: userContent,
		);

		final userDisplay = DisplayMessage(
			id: userEntity.id,
			role: ChatRole.user,
			content: userContent,
			createdAt: userEntity.createdAt,
		);

		state = AsyncData(
			current.copyWith(
				conversationId: conversationId,
				messages: [...current.messages, userDisplay],
				isStreaming: true,
				clearError: true,
			),
		);

		if (gateway == null) {
			state = AsyncData(
				state.valueOrNull!.copyWith(
					isStreaming: false,
					error: '请先在设置中配置 LLM 提供商',
				),
			);
			return;
		}

		try {
			final history = (state.valueOrNull?.messages ?? []).map((m) {
				return ChatMessage(role: m.role, content: m.content);
			}).toList();

		final assistantMsgId = const Uuid().v4();
			final streamingMsg = DisplayMessage(
				id: assistantMsgId,
				role: ChatRole.assistant,
				content: '',
				createdAt: DateTime.now(),
				isStreaming: true,
			);

			state = AsyncData(
				state.valueOrNull!.copyWith(
					messages: [...(state.valueOrNull?.messages ?? []), streamingMsg],
				),
			);

			final buffer = StringBuffer();
			await for (final chunk in gateway.chat(history)) {
				buffer.write(chunk.textDelta);
				final updated = streamingMsg.copyWith(
					content: buffer.toString(),
					isStreaming: true,
				);
				final msgs = List<DisplayMessage>.from(
					state.valueOrNull?.messages ?? [],
				);
				final idx = msgs.indexWhere((m) => m.id == assistantMsgId);
				if (idx >= 0) msgs[idx] = updated;
				state = AsyncData(state.valueOrNull!.copyWith(messages: msgs));
			}

			final assistantEntity = await service.addMessage(
				conversationId: conversationId,
				role: 'assistant',
				content: buffer.toString(),
			);

			final finalMsg = DisplayMessage(
				id: assistantEntity.id,
				role: ChatRole.assistant,
				content: buffer.toString(),
				createdAt: assistantEntity.createdAt,
			);

			final finalMsgs = List<DisplayMessage>.from(
				state.valueOrNull?.messages ?? [],
			);
			final idx = finalMsgs.indexWhere((m) => m.id == assistantMsgId);
			if (idx >= 0) finalMsgs[idx] = finalMsg;

			state = AsyncData(
				state.valueOrNull!.copyWith(
					messages: finalMsgs,
					isStreaming: false,
				),
			);
		} catch (e) {
			state = AsyncData(
				state.valueOrNull!.copyWith(
					isStreaming: false,
					error: e.toString(),
				),
			);
		}
	}

	void clearError() {
		final current = state.valueOrNull;
		if (current == null) return;
		state = AsyncData(current.copyWith(clearError: true));
	}

	ChatRole _roleFromString(String role) {
		switch (role) {
			case 'user':
				return ChatRole.user;
			case 'assistant':
				return ChatRole.assistant;
			case 'system':
				return ChatRole.system;
			default:
				return ChatRole.user;
		}
	}
}

final chatNotifierProvider =
		AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
