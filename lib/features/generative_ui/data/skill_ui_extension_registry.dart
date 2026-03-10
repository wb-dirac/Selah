import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/generative_ui/domain/skill_ui_component_definition.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/ui_component_registry.dart';

const List<String> _kBuiltInUiTypes = <String>[
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
];

class SkillUiExtensionRegistryState {
  const SkillUiExtensionRegistryState({
    this.extensions = const <String, SkillUiComponentDefinition>{},
  });

  final Map<String, SkillUiComponentDefinition> extensions;

  SkillUiComponentDefinition? findByType(String uiType) =>
      extensions[uiType];

  bool contains(String uiType) => extensions.containsKey(uiType);
}

class SkillUiExtensionRegistryNotifier
    extends Notifier<SkillUiExtensionRegistryState> {
  @override
  SkillUiExtensionRegistryState build() =>
      const SkillUiExtensionRegistryState();

  void registerSkillComponent(SkillUiComponentDefinition definition) {
    if (_kBuiltInUiTypes.contains(definition.uiType)) {
      return;
    }

    final updated = Map<String, SkillUiComponentDefinition>.from(
      state.extensions,
    )..[definition.uiType] = definition;

    state = SkillUiExtensionRegistryState(extensions: updated);
  }

  void unregisterByType(String uiType) {
    if (!state.contains(uiType)) return;
    final updated = Map<String, SkillUiComponentDefinition>.from(
      state.extensions,
    )..remove(uiType);
    state = SkillUiExtensionRegistryState(extensions: updated);
  }

  void unregisterAllForSkill(Iterable<String> uiTypes) {
    final updated = Map<String, SkillUiComponentDefinition>.from(
      state.extensions,
    )..removeWhere((key, _) => uiTypes.contains(key));
    state = SkillUiExtensionRegistryState(extensions: updated);
  }
}

final skillUiExtensionRegistryProvider = NotifierProvider<
    SkillUiExtensionRegistryNotifier, SkillUiExtensionRegistryState>(
  SkillUiExtensionRegistryNotifier.new,
);

class ExtendedUiComponentRegistry {
  const ExtendedUiComponentRegistry({
    required UiComponentRegistry base,
    required SkillUiExtensionRegistryState extensions,
  })  : _base = base,
        _extensions = extensions;

  final UiComponentRegistry _base;
  final SkillUiExtensionRegistryState _extensions;

  UiComponentData parse(Map<String, dynamic> raw) {
    final parsed = _base.parse(raw);
    if (parsed is! UnknownUiComponentData) return parsed;

    final uiType = parsed.uiTypeName;
    final definition = _extensions.findByType(uiType);
    if (definition == null) return parsed;

    final data = raw['data'];
    if (data is! Map<String, dynamic>) {
      return UnknownUiComponentData(
        uiTypeName: uiType,
        raw: raw,
        error: '缺少 data 或 data 不是对象',
      );
    }

    final result = definition.parse(data);
    if (result.data != null) return result.data!;

    return UnknownUiComponentData(
      uiTypeName: uiType,
      raw: raw,
      error: result.error ?? 'Skill 组件解析失败',
    );
  }

  Widget build(BuildContext context, UiComponentData data) {
    final builtIn = _tryBuildBuiltIn(context, data);
    if (builtIn != null) return builtIn;

    final definition = _extensions.findByType(data.uiType);
    if (definition != null) {
      return definition.buildWidget(context, data);
    }

    return _base.build(context, data);
  }

  Widget? _tryBuildBuiltIn(BuildContext context, UiComponentData data) {
    if (!_kBuiltInUiTypes.contains(data.uiType)) return null;
    return _base.build(context, data);
  }
}

final extendedUiComponentRegistryProvider =
    Provider<ExtendedUiComponentRegistry>((ref) {
  final base = ref.watch(uiComponentRegistryProvider);
  final extensions = ref.watch(skillUiExtensionRegistryProvider);
  return ExtendedUiComponentRegistry(base: base, extensions: extensions);
});
