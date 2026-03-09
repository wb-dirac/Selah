class AgentCapabilities {
  const AgentCapabilities({
    this.streaming = false,
    this.pushNotifications = false,
    this.stateTransitionHistory = false,
  });

  final bool streaming;
  final bool pushNotifications;
  final bool stateTransitionHistory;

  factory AgentCapabilities.fromJson(Map<String, dynamic> json) {
    return AgentCapabilities(
      streaming: json['streaming'] as bool? ?? false,
      pushNotifications: json['pushNotifications'] as bool? ?? false,
      stateTransitionHistory: json['stateTransitionHistory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'streaming': streaming,
        'pushNotifications': pushNotifications,
        'stateTransitionHistory': stateTransitionHistory,
      };
}

class AgentSkill {
  const AgentSkill({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory AgentSkill.fromJson(Map<String, dynamic> json) {
    return AgentSkill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
      };
}

class AgentCard {
  const AgentCard({
    required this.name,
    required this.url,
    required this.capabilities,
    required this.skills,
    this.description,
    this.version,
  });

  final String name;
  final String url;
  final AgentCapabilities capabilities;
  final List<AgentSkill> skills;
  final String? description;
  final String? version;

  factory AgentCard.fromJson(Map<String, dynamic> json) {
    return AgentCard(
      name: json['name'] as String,
      url: json['url'] as String,
      capabilities: AgentCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      skills: (json['skills'] as List<dynamic>)
          .map((e) => AgentSkill.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'url': url,
        'capabilities': capabilities.toJson(),
        'skills': skills.map((s) => s.toJson()).toList(),
        if (description != null) 'description': description,
        if (version != null) 'version': version,
      };
}

sealed class AgentCardValidationResult {}

class AgentCardValid extends AgentCardValidationResult {
  AgentCardValid(this.card);
  final AgentCard card;
}

class AgentCardInvalid extends AgentCardValidationResult {
  AgentCardInvalid(this.errors);
  final List<String> errors;
}

class AgentCardValidator {
  const AgentCardValidator();

  AgentCardValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    if (!json.containsKey('name') || (json['name'] as String?)?.isEmpty != false) {
      errors.add('缺少必填字段: name');
    }

    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      errors.add('缺少必填字段: url');
    } else if (!url.startsWith('https://')) {
      errors.add('url 必须以 https:// 开头，拒绝非 TLS 连接');
    }

    if (!json.containsKey('capabilities') || json['capabilities'] is! Map) {
      errors.add('缺少必填字段: capabilities');
    }

    final skillsRaw = json['skills'];
    if (skillsRaw == null || skillsRaw is! List || skillsRaw.isEmpty) {
      errors.add('skills 列表不能为空');
    }

    if (errors.isNotEmpty) {
      return AgentCardInvalid(errors);
    }

    try {
      final card = AgentCard.fromJson(json);
      return AgentCardValid(card);
    } catch (e) {
      return AgentCardInvalid(<String>['Agent Card 解析失败: $e']);
    }
  }
}
