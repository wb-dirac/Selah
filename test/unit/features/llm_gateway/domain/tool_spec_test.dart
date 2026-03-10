import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';

void main() {
  group('ToolParamProperty.toJson', () {
    test('string type serialises correctly', () {
      const prop = ToolParamProperty(
        type: ToolParamType.string,
        description: 'User name',
      );
      final json = prop.toJson();
      expect(json['type'], equals('string'));
      expect(json['description'], equals('User name'));
      expect(json.containsKey('enum'), isFalse);
      expect(json.containsKey('items'), isFalse);
    });

    test('string type with enumValues includes enum field', () {
      const prop = ToolParamProperty(
        type: ToolParamType.string,
        description: 'Action',
        enumValues: ['create', 'delete'],
      );
      final json = prop.toJson();
      expect(json['enum'], equals(['create', 'delete']));
    });

    test('array type with itemsType includes items field', () {
      const prop = ToolParamProperty(
        type: ToolParamType.array,
        description: 'Phone numbers',
        itemsType: ToolParamType.string,
      );
      final json = prop.toJson();
      expect(json['type'], equals('array'));
      expect(json['items'], equals({'type': 'string'}));
    });

    test('boolean type serialises without extra fields', () {
      const prop = ToolParamProperty(
        type: ToolParamType.boolean,
        description: 'Is active',
      );
      final json = prop.toJson();
      expect(json['type'], equals('boolean'));
      expect(json.containsKey('enum'), isFalse);
      expect(json.containsKey('items'), isFalse);
    });
  });

  group('ToolParameterSchema.toJson', () {
    test('empty schema produces correct structure', () {
      const schema = ToolParameterSchema();
      final json = schema.toJson();
      expect(json['type'], equals('object'));
      expect(json['properties'], equals({}));
      expect(json.containsKey('required'), isFalse);
    });

    test('schema with required fields includes required array', () {
      const schema = ToolParameterSchema(
        properties: {
          'name': ToolParamProperty(
            type: ToolParamType.string,
            description: 'Contact name',
          ),
          'phone': ToolParamProperty(
            type: ToolParamType.string,
            description: 'Phone number',
          ),
        },
        required: ['name'],
      );
      final json = schema.toJson();
      expect(json['required'], equals(['name']));
      expect((json['properties'] as Map).keys, containsAll(['name', 'phone']));
    });
  });

  group('ToolSpec.toJson', () {
    test('simple spec without parameters serialises correctly', () {
      const spec = ToolSpec(
        name: 'clipboard.read',
        description: '读取剪贴板',
      );
      final json = spec.toJson();
      expect(json['name'], equals('clipboard.read'));
      expect(json['description'], equals('读取剪贴板'));
      expect(json['parameters'], isNotNull);
    });

    test('spec with parameters includes parameter schema', () {
      const spec = ToolSpec(
        name: 'location.search',
        description: '搜索地点',
        parameters: ToolParameterSchema(
          properties: {
            'query': ToolParamProperty(
              type: ToolParamType.string,
              description: '地点关键词',
            ),
          },
          required: ['query'],
        ),
      );
      final json = spec.toJson();
      final params = json['parameters'] as Map;
      expect(params['required'], contains('query'));
    });
  });

  group('ToolCallRequest', () {
    test('direct constructor stores values', () {
      const req = ToolCallRequest(
        callId: 'call_abc',
        name: 'clipboard.write',
        arguments: {'text': 'hello'},
      );
      expect(req.callId, equals('call_abc'));
      expect(req.name, equals('clipboard.write'));
      expect(req.arguments['text'], equals('hello'));
    });

    test('fromArgumentsJson parses valid JSON', () {
      final req = ToolCallRequest.fromArgumentsJson(
        callId: 'c1',
        name: 'location.search',
        argumentsJson: '{"query": "coffee shop"}',
      );
      expect(req.arguments['query'], equals('coffee shop'));
    });

    test('fromArgumentsJson returns empty map for malformed JSON', () {
      final req = ToolCallRequest.fromArgumentsJson(
        callId: 'c2',
        name: 'contacts.read',
        argumentsJson: '{invalid json}',
      );
      expect(req.arguments, isEmpty);
    });

    test('fromArgumentsJson returns empty map for empty string', () {
      final req = ToolCallRequest.fromArgumentsJson(
        callId: 'c3',
        name: 'contacts.read',
        argumentsJson: '',
      );
      expect(req.arguments, isEmpty);
    });

    test('fromArgumentsJson returns empty map when JSON is not an object', () {
      final req = ToolCallRequest.fromArgumentsJson(
        callId: 'c4',
        name: 'contacts.read',
        argumentsJson: '"just a string"',
      );
      expect(req.arguments, isEmpty);
    });
  });
}
