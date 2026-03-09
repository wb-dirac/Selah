import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_manifest_parser.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_record.dart';

class SkillLoader {
  const SkillLoader();

  static const String _skillMdFile = 'SKILL.md';
  static const String _systemPromptFile = 'system_prompt.md';
  static const String _readmeFile = 'README.md';
  static const String _toolsDir = 'tools';

  static const _parser = SkillManifestParser();

  Future<SkillRecord?> loadLevel1(String skillDirPath) async {
    final dir = Directory(skillDirPath);
    if (!dir.existsSync()) return null;

    final skillMd = File(p.join(skillDirPath, _skillMdFile));
    if (!skillMd.existsSync()) return null;

    final content = await skillMd.readAsString();
    final result = _parser.parse(content);
    if (!result.isSuccess) return null;

    final id = p.basename(skillDirPath);
    return SkillRecord(
      level1: SkillLevel1(
        id: id,
        manifest: result.manifest!,
        rootPath: skillDirPath,
      ),
    );
  }

  Future<SkillRecord?> loadLevel2(SkillRecord record) async {
    if (record.loadedLevel.index >= SkillLoadLevel.level2.index) return record;

    final level1 = record.level1;
    final rootPath = level1.rootPath;

    final systemPromptFile = File(p.join(rootPath, _systemPromptFile));
    final systemPrompt = systemPromptFile.existsSync()
        ? await systemPromptFile.readAsString()
        : null;

    final readmeFile = File(p.join(rootPath, _readmeFile));
    final readme =
        readmeFile.existsSync() ? await readmeFile.readAsString() : null;

    final toolsDir = Directory(p.join(rootPath, _toolsDir));
    final toolDefs = <String>[];
    if (toolsDir.existsSync()) {
      await for (final entity in toolsDir.list()) {
        if (entity is File) {
          toolDefs.add(p.basename(entity.path));
        }
      }
      toolDefs.sort();
    }

    final level2 = SkillLevel2(
      id: level1.id,
      manifest: level1.manifest,
      rootPath: rootPath,
      enabled: level1.enabled,
      toolDefinitions: toolDefs,
      systemPromptTemplate: systemPrompt,
      readmeContent: readme,
    );
    return record.withLevel2(level2);
  }

  Future<SkillRecord?> loadLevel3(SkillRecord record) async {
    final upgraded = record.loadedLevel.index >= SkillLoadLevel.level2.index
        ? record
        : await loadLevel2(record);
    if (upgraded == null) return null;

    final level2 = upgraded.level2!;
    final toolsDir = Directory(p.join(level2.rootPath, _toolsDir));
    final assets = <String, List<int>>{};

    if (toolsDir.existsSync()) {
      await for (final entity in toolsDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          assets[p.basename(entity.path)] = bytes;
        }
      }
    }

    final level3 = SkillLevel3(
      id: level2.id,
      manifest: level2.manifest,
      rootPath: level2.rootPath,
      enabled: level2.enabled,
      toolDefinitions: level2.toolDefinitions,
      systemPromptTemplate: level2.systemPromptTemplate,
      readmeContent: level2.readmeContent,
      executableAssets: assets,
      isRuntimeReady: true,
    );
    return upgraded.withLevel3(level3);
  }

  Future<List<SkillRecord>> scanDirectory(String skillsRootPath) async {
    final root = Directory(skillsRootPath);
    if (!root.existsSync()) return const <SkillRecord>[];

    final results = <SkillRecord>[];
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final record = await loadLevel1(entity.path);
        if (record != null) results.add(record);
      }
    }
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }
}
