import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/widgets/generative_ui_message_content.dart';

void main() {
  group('GenerativeUiMessageContent', () {
    testWidgets('renders product card from fenced json block', (tester) async {
      const content = '''这是推荐结果：

```json
{
  "ui_type": "product_card",
  "data": {
    "name": "Sony WH-1000XM5",
    "price": 2499,
    "rating": 4.8,
    "review_count": 2341
  }
}
```
''';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenerativeUiMessageContent(content: content),
            ),
          ),
        ),
      );

      expect(find.text('Sony WH-1000XM5'), findsOneWidget);
      expect(find.textContaining('¥2499'), findsOneWidget);
      expect(find.text('🛍️ 商品推荐'), findsOneWidget);
    });

    testWidgets('falls back to markdown when no ui payload exists', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GenerativeUiMessageContent(content: '普通文本消息'),
            ),
          ),
        ),
      );

      expect(find.text('普通文本消息'), findsOneWidget);
    });
  });
}
