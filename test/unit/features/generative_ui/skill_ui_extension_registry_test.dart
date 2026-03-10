import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/generative_ui/data/skill_ui_extension_registry.dart';
import 'package:personal_ai_assistant/features/generative_ui/domain/skill_ui_component_definition.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/ui_component_registry.dart';

class _FakeSkillComponentData extends UiComponentData {
  const _FakeSkillComponentData({required this.value});
  final String value;

  @override
  String get uiType => 'skill_weather_extended';

  @override
  String get typeLabel => '🔧 Skill 天气扩展';
}

class _FakeSkillDefinition implements SkillUiComponentDefinition {
  const _FakeSkillDefinition();

  @override
  String get uiType => 'skill_weather_extended';

  @override
  String get displayLabel => '扩展天气组件';

  @override
  UiParseResult<UiComponentData> parse(Map<String, dynamic> data) {
    final val = data['value'] as String?;
    if (val == null) {
      return const UiParseResult.failure('缺少 value 字段');
    }
    return UiParseResult.success(_FakeSkillComponentData(value: val));
  }

  @override
  Widget buildWidget(BuildContext context, UiComponentData data) {
    return const SizedBox.shrink();
  }
}

SkillUiExtensionRegistryNotifier _notifier(ProviderContainer c) =>
    c.read(skillUiExtensionRegistryProvider.notifier);

SkillUiExtensionRegistryState _state(ProviderContainer c) =>
    c.read(skillUiExtensionRegistryProvider);

void main() {
  group('SkillUiExtensionRegistry — registration', () {
    test('starts empty', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(_state(c).extensions, isEmpty);
    });

    test('registerSkillComponent adds definition', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());
      expect(_state(c).contains('skill_weather_extended'), isTrue);
    });

    test('findByType returns registered definition', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());
      final def = _state(c).findByType('skill_weather_extended');
      expect(def, isNotNull);
      expect(def!.displayLabel, '扩展天气组件');
    });

    test('unregisterByType removes definition', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());
      _notifier(c).unregisterByType('skill_weather_extended');
      expect(_state(c).contains('skill_weather_extended'), isFalse);
    });

    test('unregisterAllForSkill removes multiple types', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());
      _notifier(c).unregisterAllForSkill(['skill_weather_extended']);
      expect(_state(c).extensions, isEmpty);
    });
  });

  group('SkillUiExtensionRegistry — built-in protection', () {
    test('cannot override built-in ui_types', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final builtInOverride = _BuiltInOverrideAttempt();
      _notifier(c).registerSkillComponent(builtInOverride);

      expect(_state(c).contains('product_card'), isFalse);
    });

    for (final builtIn in [
      'product_card',
      'weather_card',
      'contact_card',
      'calendar_event',
      'map_preview',
      'train_card',
      'flight_card',
      'code_block',
      'task_list',
      'price_chart',
    ]) {
      test('blocks override of $builtIn', () {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        _notifier(c)
            .registerSkillComponent(_GenericOverrideAttempt(uiType: builtIn));
        expect(_state(c).contains(builtIn), isFalse);
      });
    }
  });

  group('ExtendedUiComponentRegistry — parse', () {
    test('unknown type resolved via skill extension', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());

      final registry = c.read(extendedUiComponentRegistryProvider);
      final result = registry.parse(<String, dynamic>{
        'ui_type': 'skill_weather_extended',
        'data': <String, dynamic>{'value': 'sunny'},
      });

      expect(result, isA<_FakeSkillComponentData>());
      expect((result as _FakeSkillComponentData).value, 'sunny');
    });

    test('built-in types still parse correctly', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final registry = c.read(extendedUiComponentRegistryProvider);
      final result = registry.parse(<String, dynamic>{
        'ui_type': 'weather_card',
        'data': <String, dynamic>{
          'city': '北京',
          'temperature': '25°C',
          'condition': '晴',
        },
      });
      expect(result, isA<WeatherCardData>());
    });

    test('unregistered type falls back to UnknownUiComponentData', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final registry = c.read(extendedUiComponentRegistryProvider);
      final result = registry.parse(<String, dynamic>{
        'ui_type': 'no_such_type',
        'data': <String, dynamic>{},
      });
      expect(result, isA<UnknownUiComponentData>());
    });

    test('skill parse failure returns UnknownUiComponentData', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      _notifier(c).registerSkillComponent(const _FakeSkillDefinition());

      final registry = c.read(extendedUiComponentRegistryProvider);
      final result = registry.parse(<String, dynamic>{
        'ui_type': 'skill_weather_extended',
        'data': <String, dynamic>{},
      });

      expect(result, isA<UnknownUiComponentData>());
      expect((result as UnknownUiComponentData).error, contains('value'));
    });
  });
}

class _BuiltInOverrideAttempt implements SkillUiComponentDefinition {
  @override
  String get uiType => 'product_card';
  @override
  String get displayLabel => 'hack';
  @override
  UiParseResult<UiComponentData> parse(Map<String, dynamic> data) =>
      const UiParseResult.failure('');
  @override
  Widget buildWidget(BuildContext context, UiComponentData data) =>
      const SizedBox.shrink();
}

class _GenericOverrideAttempt implements SkillUiComponentDefinition {
  const _GenericOverrideAttempt({required this.uiType});
  @override
  final String uiType;
  @override
  String get displayLabel => 'override';
  @override
  UiParseResult<UiComponentData> parse(Map<String, dynamic> data) =>
      const UiParseResult.failure('');
  @override
  Widget buildWidget(BuildContext context, UiComponentData data) =>
      const SizedBox.shrink();
}
