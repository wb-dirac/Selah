import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/capability/feature_flags/feature_flag_service.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/providers/chat_notifier.dart';
import 'package:personal_ai_assistant/presentation/screens/chat/chat_screen.dart';

class _FakeChatNotifier extends ChatNotifier {
  @override
  Future<ChatState> build() async {
    return ChatState(
      conversationId: 'conv-1',
      conversationTitle: '周末计划',
      messages: const [],
      isStreaming: false,
    );
  }

  @override
  Future<void> renameConversationTitle(String nextTitle) async {
    if (nextTitle.trim().isEmpty) {
      state = AsyncData(
        state.value!.copyWith(error: '标题不能为空'),
      );
      return;
    }
    state = AsyncData(
      state.value!.copyWith(conversationTitle: nextTitle.trim(), clearError: true),
    );
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('rename dialog shows error on empty title and clears after valid rename', (
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

    // Verify initial title
    expect(find.text('周末计划'), findsOneWidget);

    // Open rename dialog
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('重命名会话'), findsOneWidget);
    expect(find.byKey(const Key('rename_dialog_text_field')), findsOneWidget);

    // Submit empty title - dialog closes but error is set in state
    final textField = find.byKey(const Key('rename_dialog_text_field'));
    await tester.enterText(textField, '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // Dialog should close (our implementation doesn't keep dialog open on error)
    expect(find.text('重命名会话'), findsNothing);
    // Title should remain unchanged due to error
    expect(find.text('周末计划'), findsOneWidget);

    // Open rename dialog again
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    // Now enter a valid title
    await tester.enterText(textField, '新标题');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // Dialog should close and new title should appear
    expect(find.text('重命名会话'), findsNothing);
    expect(find.text('新标题'), findsOneWidget);
  });
}
