import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_spec_converter.dart';

void main() {
  group('getBuiltInToolSpecs', () {
    test('returns 14 tool specs', () {
      final specs = getBuiltInToolSpecs();
      expect(specs, hasLength(14));
    });

    test('all tool names match expected IDs', () {
      final specs = getBuiltInToolSpecs();
      final names = specs.map((s) => s.name).toSet();

      expect(
        names,
        containsAll([
          'contacts.read',
          'contacts.search',
          'contacts.create',
          'mail.compose',
          'sms.send',
          'phone.call',
          'calendar.read',
          'calendar.create',
          'calendar.update_delete',
          'location.current',
          'location.search',
          'clipboard.read',
          'clipboard.write',
          'system.share',
        ]),
      );
    });

    test('builtInToolSpecs map has same 14 keys', () {
      expect(builtInToolSpecs, hasLength(14));
    });

    test('contacts.search has required query parameter', () {
      final spec = builtInToolSpecs['contacts.search']!;
      expect(spec.parameters.required, contains('query'));
      expect(spec.parameters.properties.containsKey('query'), isTrue);
    });

    test('contacts.create requires only name', () {
      final spec = builtInToolSpecs['contacts.create']!;
      expect(spec.parameters.required, equals(['name']));
      expect(
        spec.parameters.properties.keys,
        containsAll(['name', 'phone', 'email', 'organization']),
      );
    });

    test('calendar.create requires title and start_time', () {
      final spec = builtInToolSpecs['calendar.create']!;
      expect(spec.parameters.required, containsAll(['title', 'start_time']));
    });

    test('calendar.update_delete action property has enumValues', () {
      final spec = builtInToolSpecs['calendar.update_delete']!;
      final actionProp = spec.parameters.properties['action']!;
      expect(actionProp.enumValues, containsAll(['update', 'delete']));
    });

    test('clipboard.read has no required parameters', () {
      final spec = builtInToolSpecs['clipboard.read']!;
      expect(spec.parameters.required, isEmpty);
      expect(spec.parameters.properties, isEmpty);
    });

    test('location.current has no parameters', () {
      final spec = builtInToolSpecs['location.current']!;
      expect(spec.parameters.properties, isEmpty);
    });

    test('toJson produces valid OpenAI-compatible function schema', () {
      final spec = builtInToolSpecs['location.search']!;
      final json = spec.toJson();

      expect(json['name'], equals('location.search'));
      expect(json['description'], isNotEmpty);

      final params = json['parameters'] as Map<String, dynamic>;
      expect(params['type'], equals('object'));
      expect(params['required'], contains('query'));
    });

    test('system.share requires text parameter', () {
      final spec = builtInToolSpecs['system.share']!;
      expect(spec.parameters.required, contains('text'));
    });

    test('phone.call requires number parameter', () {
      final spec = builtInToolSpecs['phone.call']!;
      expect(spec.parameters.required, contains('number'));
    });
  });
}
