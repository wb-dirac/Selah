// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/presentation/app/personal_assistant_app.dart';

void main() {
  testWidgets('App shell renders primary tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PersonalAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('对话'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('Agent'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
