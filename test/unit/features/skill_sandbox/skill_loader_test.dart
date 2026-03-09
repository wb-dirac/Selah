import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_loader.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_record.dart';

Directory _makeSkillDir(String name, {String? systemPrompt}) {
  final dir = Directory(p.join(Directory.systemTemp.path, 'skills_test', name))
    ..createSync(recursive: true);

  File(p.join(dir.path, 'SKILL.md')).writeAsStringSync('''
---
name: $name
description: Test skill for $name
version: 1.0.0
---
''');

  if (systemPrompt != null) {
    File(p.join(dir.path, 'system_prompt.md'))
        .writeAsStringSync(systemPrompt);
  }

  return dir;
}

void main() {
  const loader = SkillLoader();

  tearDownAll(() {
    final root =
        Directory(p.join(Directory.systemTemp.path, 'skills_test'));
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('SkillLoader', () {
    test('loadLevel1 returns null for non-existent directory', () async {
      final result = await loader.loadLevel1('/non/existent/path');
      expect(result, isNull);
    });

    test('loadLevel1 returns null when SKILL.md is absent', () async {
      final dir = Directory(
        p.join(Directory.systemTemp.path, 'skills_test', 'no_skill_md'),
      )..createSync(recursive: true);
      addTearDown(() => dir.deleteSync(recursive: true));

      final result = await loader.loadLevel1(dir.path);
      expect(result, isNull);
    });

    test('loadLevel1 parses manifest correctly', () async {
      final dir = _makeSkillDir('my_skill');

      final record = await loader.loadLevel1(dir.path);
      expect(record, isNotNull);
      expect(record!.name, 'my_skill');
      expect(record.level1.manifest.version, '1.0.0');
      expect(record.loadedLevel, SkillLoadLevel.level1);
    });

    test('loadLevel2 upgrades to level2 with system prompt', () async {
      final dir = _makeSkillDir(
        'skill_with_prompt',
        systemPrompt: 'You are a helpful assistant.',
      );

      final level1Record = await loader.loadLevel1(dir.path);
      expect(level1Record, isNotNull);

      final level2Record = await loader.loadLevel2(level1Record!);
      expect(level2Record, isNotNull);
      expect(level2Record!.loadedLevel, SkillLoadLevel.level2);
      expect(
        level2Record.level2!.systemPromptTemplate,
        'You are a helpful assistant.',
      );
    });

    test('loadLevel2 skips upgrade if already at level2', () async {
      final dir = _makeSkillDir('already_l2');
      final level1Record = await loader.loadLevel1(dir.path);
      final level2Record = await loader.loadLevel2(level1Record!);

      final result = await loader.loadLevel2(level2Record!);
      expect(result, same(level2Record));
    });

    test('scanDirectory returns empty list for non-existent root', () async {
      final results = await loader.scanDirectory('/non/existent');
      expect(results, isEmpty);
    });

    test('scanDirectory finds all valid skill directories', () async {
      _makeSkillDir('skill_a');
      _makeSkillDir('skill_b');

      final root =
          Directory(p.join(Directory.systemTemp.path, 'skills_test'));
      final records = await loader.scanDirectory(root.path);

      expect(records.length, greaterThanOrEqualTo(2));
      final names = records.map((r) => r.name).toList();
      expect(names, containsAll(<String>['skill_a', 'skill_b']));
    });
  });

  group('SkillRecord level progression', () {
    test('starts at level1', () async {
      final dir = _makeSkillDir('level_test');
      final record = await loader.loadLevel1(dir.path);
      expect(record!.loadedLevel, SkillLoadLevel.level1);
      expect(record.level2, isNull);
      expect(record.level3, isNull);
    });

    test('withLevel2 advances load level', () async {
      final dir = _makeSkillDir('level_test2');
      final record = (await loader.loadLevel1(dir.path))!;
      final upgraded = await loader.loadLevel2(record);
      expect(upgraded!.loadedLevel, SkillLoadLevel.level2);
      expect(upgraded.level2, isNotNull);
    });
  });
}
