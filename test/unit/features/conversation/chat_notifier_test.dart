import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';

void main() {
	group('ChatNotifier', () {
		late ProviderContainer container;

		setUp(() {
			container = ProviderContainer();
		});

		tearDown(() {
			container.dispose();
		});

		test('initial state is loading', () {
			final state = container.read(chatNotifierProvider);
			expect(state, isA<AsyncLoading<ChatState>>());
		});

		test('messages list is empty after initialization', () async {
			await container.read(chatNotifierProvider.future);
			final state = container.read(chatNotifierProvider).valueOrNull!;
			expect(state.messages, isEmpty);
			expect(state.isStreaming, isFalse);
			expect(state.error, isNull);
		});

		test('clearError clears the error field', () async {
			await container.read(chatNotifierProvider.future);
			final notifier = container.read(chatNotifierProvider.notifier);

			notifier.state = const AsyncData(ChatState(error: 'test error'));
			expect(
				container.read(chatNotifierProvider).valueOrNull?.error,
				'test error',
			);

			notifier.clearError();
			expect(
				container.read(chatNotifierProvider).valueOrNull?.error,
				isNull,
			);
		});

		test('ChatState copyWith preserves existing values', () {
			const initial = ChatState(
				conversationId: 'conv-1',
				isStreaming: false,
			);
			final updated = initial.copyWith(isStreaming: true);
			expect(updated.conversationId, 'conv-1');
			expect(updated.isStreaming, isTrue);
		});

		test('DisplayMessage copyWith updates fields', () {
			final msg = DisplayMessage(
				id: 'id-1',
				role: ChatRole.assistant,
				content: 'hello',
				createdAt: DateTime(2024),
			);
			final updated = msg.copyWith(content: 'world', isStreaming: true);
			expect(updated.content, 'world');
			expect(updated.isStreaming, isTrue);
			expect(updated.id, 'id-1');
		});
	});
}
