import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/presentation/screens/chat/chat_screen.dart';

class _FakeChatNotifier extends ChatNotifier {
  @override
  Future<ChatState> build() async {
    return ChatState(
      conversationId: 'conv-1',
      messages: [
        DisplayMessage(
          id: 'assistant-streaming',
          role: ChatRole.assistant,
          content: '已回复一点',
          createdAt: DateTime(2026, 3, 5),
          isStreaming: true,
        ),
      ],
      isStreaming: true,
    );
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('assistant partial reply is visible in chat UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagServiceProvider.overrideWith((ref) => FeatureFlagService()),
          chatNotifierProvider.overrideWith(_FakeChatNotifier.new),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('已回复一点'), findsOneWidget);
  });
}
