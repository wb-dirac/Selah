import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_manifest_parser.dart';

enum SkillLoadLevel {
  level1,
  level2,
  level3,
}

class SkillLevel1 {
  const SkillLevel1({
    required this.id,
    required this.manifest,
    required this.rootPath,
    this.enabled = true,
  });

  final String id;
  final SkillManifest manifest;
  final String rootPath;
  final bool enabled;

  String get name => manifest.name;
  String get description => manifest.description;
  String? get version => manifest.version;
}

class SkillLevel2 extends SkillLevel1 {
  const SkillLevel2({
    required super.id,
    required super.manifest,
    required super.rootPath,
    super.enabled,
    this.toolDefinitions = const <String>[],
    this.systemPromptTemplate,
    this.readmeContent,
  });

  final List<String> toolDefinitions;
  final String? systemPromptTemplate;
  final String? readmeContent;
}

class SkillLevel3 extends SkillLevel2 {
  const SkillLevel3({
    required super.id,
    required super.manifest,
    required super.rootPath,
    super.enabled,
    super.toolDefinitions,
    super.systemPromptTemplate,
    super.readmeContent,
    this.executableAssets = const <String, List<int>>{},
    this.isRuntimeReady = false,
  });

  final Map<String, List<int>> executableAssets;
  final bool isRuntimeReady;
}

class SkillRecord {
  SkillRecord({required SkillLevel1 level1}) : _level1 = level1;

  final SkillLevel1 _level1;
  SkillLevel2? _level2;
  SkillLevel3? _level3;

  SkillLevel1 get level1 => _level1;
  SkillLevel2? get level2 => _level2;
  SkillLevel3? get level3 => _level3;

  SkillLoadLevel get loadedLevel {
    if (_level3 != null) return SkillLoadLevel.level3;
    if (_level2 != null) return SkillLoadLevel.level2;
    return SkillLoadLevel.level1;
  }

  String get id => _level1.id;
  String get name => _level1.name;
  bool get enabled => _level1.enabled;

  SkillRecord withLevel2(SkillLevel2 data) {
    final updated = SkillRecord(level1: data);
    updated._level2 = data;
    return updated;
  }

  SkillRecord withLevel3(SkillLevel3 data) {
    final updated = SkillRecord(level1: data);
    updated._level2 = data;
    updated._level3 = data;
    return updated;
  }
}
