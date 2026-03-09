import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

void main() {
  const validator = AgentCardValidator();

  final validJson = <String, dynamic>{
    'name': '我的助理',
    'description': '处理日程、邮件、购物等任务',
    'url': 'https://my-agent.local:8080/a2a',
    'version': '1.0.0',
    'capabilities': <String, dynamic>{
      'streaming': true,
      'pushNotifications': true,
      'stateTransitionHistory': false,
    },
    'skills': <dynamic>[
      <String, dynamic>{
        'id': 'schedule',
        'name': '日程管理',
        'description': '创建和管理日历事件',
      },
    ],
  };

  group('AgentCard.fromJson / toJson round-trip', () {
    test('parses all fields correctly', () {
      final card = AgentCard.fromJson(validJson);
      expect(card.name, '我的助理');
      expect(card.url, 'https://my-agent.local:8080/a2a');
      expect(card.version, '1.0.0');
      expect(card.capabilities.streaming, isTrue);
      expect(card.capabilities.pushNotifications, isTrue);
      expect(card.capabilities.stateTransitionHistory, isFalse);
      expect(card.skills, hasLength(1));
      expect(card.skills.first.id, 'schedule');
    });

    test('toJson produces parseable output', () {
      final card = AgentCard.fromJson(validJson);
      final json = card.toJson();
      final card2 = AgentCard.fromJson(json);
      expect(card2.name, card.name);
      expect(card2.url, card.url);
      expect(card2.skills.first.name, card.skills.first.name);
    });

    test('optional fields absent when null', () {
      const card = AgentCard(
        name: 'minimal',
        url: 'https://example.com/a2a',
        capabilities: AgentCapabilities(),
        skills: <AgentSkill>[
          AgentSkill(id: 'x', name: 'X', description: 'does X'),
        ],
      );
      final json = card.toJson();
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('version'), isFalse);
    });
  });

  group('AgentCardValidator — valid cases', () {
    test('accepts well-formed card', () {
      final result = validator.validate(validJson);
      expect(result, isA<AgentCardValid>());
      expect((result as AgentCardValid).card.name, '我的助理');
    });

    test('accepts card with multiple skills', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['skills'] = <dynamic>[
          <String, dynamic>{'id': 'a', 'name': 'A', 'description': 'd'},
          <String, dynamic>{'id': 'b', 'name': 'B', 'description': 'd'},
        ];
      final result = validator.validate(json);
      expect(result, isA<AgentCardValid>());
      expect((result as AgentCardValid).card.skills, hasLength(2));
    });
  });

  group('AgentCardValidator — invalid cases', () {
    test('rejects missing name', () {
      final json = Map<String, dynamic>.from(validJson)..remove('name');
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'name');
    });

    test('rejects empty name', () {
      final json = Map<String, dynamic>.from(validJson)..['name'] = '';
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'name');
    });

    test('rejects missing url', () {
      final json = Map<String, dynamic>.from(validJson)..remove('url');
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'url');
    });

    test('rejects http:// url (non-TLS)', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['url'] = 'http://insecure.example.com/a2a';
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'https://');
    });

    test('rejects missing capabilities', () {
      final json = Map<String, dynamic>.from(validJson)..remove('capabilities');
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'capabilities');
    });

    test('rejects non-map capabilities', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['capabilities'] = 'invalid';
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'capabilities');
    });

    test('rejects null skills', () {
      final json = Map<String, dynamic>.from(validJson)..['skills'] = null;
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'skills');
    });

    test('rejects empty skills list', () {
      final json = Map<String, dynamic>.from(validJson)
        ..['skills'] = <dynamic>[];
      final result = validator.validate(json);
      _expectInvalidWithMessage(result, 'skills');
    });

    test('collects multiple errors', () {
      final json = <String, dynamic>{};
      final result = validator.validate(json);
      expect(result, isA<AgentCardInvalid>());
      expect((result as AgentCardInvalid).errors.length, greaterThan(1));
    });
  });

  group('AgentCapabilities', () {
    test('defaults all to false', () {
      const caps = AgentCapabilities();
      expect(caps.streaming, isFalse);
      expect(caps.pushNotifications, isFalse);
      expect(caps.stateTransitionHistory, isFalse);
    });

    test('round-trips json', () {
      const caps = AgentCapabilities(
        streaming: true,
        pushNotifications: false,
        stateTransitionHistory: true,
      );
      final caps2 = AgentCapabilities.fromJson(caps.toJson());
      expect(caps2.streaming, isTrue);
      expect(caps2.pushNotifications, isFalse);
      expect(caps2.stateTransitionHistory, isTrue);
    });
  });
}

void _expectInvalidWithMessage(AgentCardValidationResult result, String fragment) {
  expect(result, isA<AgentCardInvalid>());
  final errors = (result as AgentCardInvalid).errors;
  expect(
    errors.any((e) => e.contains(fragment)),
    isTrue,
    reason: 'Expected error containing "$fragment", got: $errors',
  );
}
