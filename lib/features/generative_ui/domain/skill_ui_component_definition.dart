import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/ui_component_registry.dart';

abstract class SkillUiComponentDefinition {
  String get uiType;

  String get displayLabel;

  UiParseResult<UiComponentData> parse(Map<String, dynamic> data);

  Widget buildWidget(BuildContext context, UiComponentData data);
}
