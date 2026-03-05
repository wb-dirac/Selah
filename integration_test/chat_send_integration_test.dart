import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_ai_assistant/presentation/app/personal_assistant_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat input and send button work with stable keys', (
    WidgetTester tester,
  ) async {
    final message = 'integration_e2e_message_0305';

    await tester.pumpWidget(
      const ProviderScope(
        child: PersonalAssistantApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    final inputFinder = find.byKey(const ValueKey('chat_input'));
    final sendFinder = find.byKey(const ValueKey('chat_send_button'));

    expect(inputFinder, findsOneWidget);
    expect(sendFinder, findsOneWidget);

    await tester.enterText(inputFinder, message);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(sendFinder);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(message), findsWidgets);
  });
}
