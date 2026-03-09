import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/ui_component_registry.dart';

void main() {
  group('UiComponentRegistry', () {
    const registry = UiComponentRegistry();

    test('parses product card payload', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'product_card',
        'data': <String, dynamic>{
          'name': 'Sony WH-1000XM5',
          'price': 2499,
          'rating': 4.8,
          'review_count': 2341,
          'highlights': <String>['主动降噪', '30小时续航'],
        },
      });

      expect(component, isA<ProductCardData>());
      final card = component as ProductCardData;
      expect(card.name, equals('Sony WH-1000XM5'));
      expect(card.price, equals(2499));
      expect(card.highlights, contains('主动降噪'));
    });

    test('falls back for unknown ui type', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'price_chart',
        'data': <String, dynamic>{'series': <Object>[]},
      });

      expect(component, isA<UnknownUiComponentData>());
      expect((component as UnknownUiComponentData).uiType, equals('price_chart'));
    });

    test('falls back when required fields are missing', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'calendar_event',
        'data': <String, dynamic>{'title': '上海出行'},
      });

      expect(component, isA<UnknownUiComponentData>());
      expect((component as UnknownUiComponentData).error, contains('calendar_event'));
    });

    test('parses code block payload', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'code_block',
        'data': <String, dynamic>{
          'language': 'python',
          'code': 'print("hello")',
          'can_run': true,
        },
      });

      expect(component, isA<CodeBlockCardData>());
      final card = component as CodeBlockCardData;
      expect(card.language, equals('python'));
      expect(card.canRun, isTrue);
    });

    test('parses task list payload', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'task_list',
        'data': <String, dynamic>{
          'title': '今日任务',
          'items': <Map<String, Object?>>[
            <String, Object?>{'title': '写周报', 'completed': true},
            <String, Object?>{'title': '准备会议', 'due_text': '明天'},
          ],
        },
      });

      expect(component, isA<TaskListCardData>());
      final card = component as TaskListCardData;
      expect(card.title, equals('今日任务'));
      expect(card.items, hasLength(2));
      expect(card.items.first.completed, isTrue);
    });

    test('parses price chart payload', () {
      final component = registry.parse(<String, dynamic>{
        'ui_type': 'price_chart',
        'data': <String, dynamic>{
          'title': '耳机价格走势',
          'currency_symbol': '¥',
          'points': <Map<String, Object>>[
            <String, Object>{'label': '周一', 'value': 2599},
            <String, Object>{'label': '周二', 'value': 2499},
            <String, Object>{'label': '周三', 'value': 2399},
          ],
        },
      });

      expect(component, isA<PriceChartCardData>());
      final card = component as PriceChartCardData;
      expect(card.points, hasLength(3));
      expect(card.points.last.value, equals(2399));
    });
  });
}
