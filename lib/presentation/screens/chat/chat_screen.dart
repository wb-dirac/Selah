import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/widgets/markdown_message_content.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/presentation/screens/widgets/feature_disabled_view.dart';

class ChatScreen extends ConsumerStatefulWidget {
	const ChatScreen({super.key});

	@override
	ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
	final _textController = TextEditingController();
	final _scrollController = ScrollController();

	@override
	void initState() {
		super.initState();
		Future.microtask(() => ref.read(chatNotifierProvider.notifier).initialize());
	}

	@override
	void dispose() {
		_textController.dispose();
		_scrollController.dispose();
		super.dispose();
	}

	void _sendMessage() {
		final text = _textController.text.trim();
		if (text.isEmpty) return;
		_textController.clear();
		// No gateway wired up yet – notifier handles the null case
		ref.read(chatNotifierProvider.notifier).sendMessage(text, null);
	}

	@override
	Widget build(BuildContext context) {
		final flags = ref.watch(featureFlagServiceProvider);
		if (!flags.isEnabled(AppFeatureModule.multimodalChat)) {
			return const FeatureDisabledView(
				title: '多模态对话已关闭',
				message: '请在 Feature Flag 中启用 multimodalChat 模块。',
			);
		}

		final chatAsync = ref.watch(chatNotifierProvider);

		// Show error via SnackBar
		ref.listen<AsyncValue<ChatState>>(chatNotifierProvider, (_, next) {
			final error = next.valueOrNull?.error;
			if (error != null) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text(error),
						action: SnackBarAction(
							label: '关闭',
							onPressed: () {
								ref.read(chatNotifierProvider.notifier).clearError();
							},
						),
					),
				);
				ref.read(chatNotifierProvider.notifier).clearError();
			}
		});

		return Scaffold(
			appBar: AppBar(
				title: const Text('对话'),
				actions: [
					IconButton(
						icon: const Icon(Icons.history),
						tooltip: '对话历史',
						onPressed: () => context.push('/chat/history'),
					),
				],
			),
			body: chatAsync.when(
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text('加载失败: $e')),
				data: (state) => Column(
					children: [
						Expanded(
							child: state.messages.isEmpty
									? const Center(
											child: Text(
												'发送消息开始对话',
												style: TextStyle(color: Colors.grey),
											),
										)
									: ListView.builder(
											controller: _scrollController,
											reverse: true,
											padding: const EdgeInsets.symmetric(
												horizontal: 12,
												vertical: 8,
											),
											itemCount: state.messages.length,
											itemBuilder: (context, index) {
												final msg = state.messages[
														state.messages.length - 1 - index];
												return _MessageBubble(message: msg);
											},
										),
						),
						if (state.isStreaming)
							const LinearProgressIndicator(minHeight: 2),
						_InputRow(
							controller: _textController,
							isStreaming: state.isStreaming,
							onSend: _sendMessage,
						),
					],
				),
			),
		);
	}
}

class _MessageBubble extends StatelessWidget {
	const _MessageBubble({required this.message});

	final DisplayMessage message;

	@override
	Widget build(BuildContext context) {
		final isUser = message.role == ChatRole.user;
		final theme = Theme.of(context);

		return Align(
			alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
			child: Container(
				margin: const EdgeInsets.symmetric(vertical: 4),
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
				constraints: BoxConstraints(
					maxWidth: MediaQuery.of(context).size.width * 0.75,
				),
				decoration: BoxDecoration(
					color: isUser
							? theme.colorScheme.primary
							: theme.colorScheme.surfaceContainerHighest,
					borderRadius: BorderRadius.only(
						topLeft: const Radius.circular(16),
						topRight: const Radius.circular(16),
						bottomLeft: Radius.circular(isUser ? 16 : 4),
						bottomRight: Radius.circular(isUser ? 4 : 16),
					),
				),
				child: isUser
						? Text(
								message.content,
								style: TextStyle(
									color: theme.colorScheme.onPrimary,
								),
							)
						: MarkdownMessageContent(content: message.content),
			),
		);
	}
}

class _InputRow extends StatelessWidget {
	const _InputRow({
		required this.controller,
		required this.isStreaming,
		required this.onSend,
	});

	final TextEditingController controller;
	final bool isStreaming;
	final VoidCallback onSend;

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			child: Padding(
				padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
				child: Row(
					children: [
						Expanded(
							child: TextField(
								controller: controller,
								enabled: !isStreaming,
								minLines: 1,
								maxLines: 4,
								textInputAction: TextInputAction.send,
								onSubmitted: (_) => onSend(),
								decoration: const InputDecoration(
									hintText: '输入消息…',
									border: OutlineInputBorder(
										borderRadius: BorderRadius.all(Radius.circular(24)),
									),
									contentPadding: EdgeInsets.symmetric(
										horizontal: 16,
										vertical: 10,
									),
								),
							),
						),
						const SizedBox(width: 8),
						IconButton.filled(
							icon: const Icon(Icons.send),
							onPressed: isStreaming ? null : onSend,
						),
					],
				),
			),
		);
	}
}

