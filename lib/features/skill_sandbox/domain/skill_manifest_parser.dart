class SkillManifest {
  const SkillManifest({
    required this.name,
    required this.description,
    this.version,
    this.author,
    this.extra = const <String, String>{},
  });

  final String name;
  final String description;
  final String? version;
  final String? author;
  final Map<String, String> extra;
}

class SkillManifestParseResult {
  const SkillManifestParseResult._({this.manifest, this.errors});

  const SkillManifestParseResult.success(SkillManifest value)
      : this._(manifest: value);

  const SkillManifestParseResult.failure(List<String> errors)
      : this._(errors: errors);

  final SkillManifest? manifest;
  final List<String>? errors;

  bool get isSuccess => manifest != null;
}

class SkillManifestParser {
  const SkillManifestParser();

  static const _separator = '---';

  SkillManifestParseResult parse(String skillMdContent) {
    final frontmatter = _extractFrontmatter(skillMdContent);
    if (frontmatter == null) {
      return const SkillManifestParseResult.failure(
        <String>['未找到 YAML frontmatter（需要以 --- 分隔）'],
      );
    }

    final fields = _parseFields(frontmatter);
    final errors = <String>[];

    final name = fields['name']?.trim() ?? '';
    if (name.isEmpty) {
      errors.add('缺少必填字段：name');
    } else if (!_isValidName(name)) {
      errors.add(
        'name 格式无效（只允许小写字母、数字、连字符，2-64 字符，且不能包含保留词 anthropic/claude）',
      );
    }

    final description = fields['description']?.trim() ?? '';
    if (description.isEmpty) {
      errors.add('缺少必填字段：description');
    } else if (description.length < 5) {
      errors.add('description 过短（至少 5 个字符）');
    }

    if (errors.isNotEmpty) {
      return SkillManifestParseResult.failure(errors);
    }

    final known = const <String>{'name', 'description', 'version', 'author'};
    final extraFields = <String, String>{
      for (final entry in fields.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };

    return SkillManifestParseResult.success(
      SkillManifest(
        name: name,
        description: description,
        version: fields['version']?.trim(),
        author: fields['author']?.trim(),
        extra: extraFields,
      ),
    );
  }

  String? _extractFrontmatter(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith(_separator)) return null;

    final firstClose = trimmed.indexOf(_separator, _separator.length);
    if (firstClose < 0) return null;

    return trimmed.substring(_separator.length, firstClose);
  }

  Map<String, String> _parseFields(String frontmatter) {
    final result = <String, String>{};
    for (final rawLine in frontmatter.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final colonIdx = line.indexOf(':');
      if (colonIdx < 0) continue;
      final key = line.substring(0, colonIdx).trim().toLowerCase();
      final value = _unquote(line.substring(colonIdx + 1).trim());
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  bool _isValidName(String name) {
    if (name.length < 2 || name.length > 64) return false;
    if (!RegExp(r'^[a-z0-9][a-z0-9\-]*[a-z0-9]$').hasMatch(name)) return false;
    if (name.contains('anthropic') || name.contains('claude')) return false;
    return true;
  }
}
