import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_manifest_parser.dart';

void main() {
  const parser = SkillManifestParser();

  group('SkillManifestParser', () {
    test('parses valid frontmatter with name and description', () {
      const content = '''
---
name: my_skill
description: A useful skill that does things
version: 1.0.0
author: Alice
---
# Skill body
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isTrue);
      expect(result.manifest!.name, 'my_skill');
      expect(result.manifest!.description, 'A useful skill that does things');
      expect(result.manifest!.version, '1.0.0');
      expect(result.manifest!.author, 'Alice');
    });

    test('parses quoted string values', () {
      const content = '''
---
name: "my-skill"
description: "Does something useful here"
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isTrue);
      expect(result.manifest!.name, 'my-skill');
      expect(result.manifest!.description, 'Does something useful here');
    });

    test('fails when no frontmatter present', () {
      const content = '# Just a markdown file\nNo frontmatter here.';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('fails when name is missing', () {
      const content = '''
---
description: A valid description here
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors!.any((e) => e.contains('name')), isTrue);
    });

    test('fails when description is missing', () {
      const content = '''
---
name: my_skill
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors!.any((e) => e.contains('description')), isTrue);
    });

    test('fails when description is too short', () {
      const content = '''
---
name: my_skill
description: hi
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors!.any((e) => e.contains('description')), isTrue);
    });

    test('fails when name has invalid characters', () {
      const content = '''
---
name: my skill with spaces
description: A valid description here
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors!.any((e) => e.contains('name')), isTrue);
    });

    test('collects multiple validation errors', () {
      const content = '''
---
name:
description:
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isFalse);
      expect(result.errors!.length, greaterThanOrEqualTo(2));
    });

    test('stores extra unknown fields in extra map', () {
      const content = '''
---
name: my_skill
description: A valid description here
license: MIT
homepage: https://example.com
---
''';
      final result = parser.parse(content);
      expect(result.isSuccess, isTrue);
      expect(result.manifest!.extra['license'], 'MIT');
      expect(result.manifest!.extra['homepage'], 'https://example.com');
    });

    test('name can contain hyphens but not leading hyphen', () {
      const valid = '''
---
name: my-cool-skill
description: A valid description here
---
''';
      expect(parser.parse(valid).isSuccess, isTrue);

      const invalid = '''
---
name: -invalid
description: A valid description here
---
''';
      expect(parser.parse(invalid).isSuccess, isFalse);
    });
  });
}
