import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/contact_tools.dart';

class _FakeContactsDataSource implements ContactsDataSource {
  _FakeContactsDataSource({
    List<ContactEntry>? contacts,
    bool throwOnCreate = false,
  })  : _contacts = contacts ?? const <ContactEntry>[],
        _throwOnCreate = throwOnCreate;

  final List<ContactEntry> _contacts;
  final bool _throwOnCreate;

  @override
  Future<List<ContactEntry>> readAll() async => _contacts;

  @override
  Future<List<ContactEntry>> search(String query) async {
    return _contacts
        .where(
          (c) =>
              c.displayName.contains(query) ||
              (c.phone?.contains(query) ?? false) ||
              (c.email?.contains(query) ?? false),
        )
        .toList();
  }

  @override
  Future<String> create(ContactEntry entry) async {
    if (_throwOnCreate) throw Exception('平台错误');
    return 'created_${entry.id}';
  }
}

const _alice = ContactEntry(
  id: 'c1',
  displayName: '张三',
  phone: '13800000001',
  email: 'zhang@example.com',
  organization: '公司A',
);

const _bob = ContactEntry(
  id: 'c2',
  displayName: '李四',
  phone: '13900000002',
);

void main() {
  group('ContactEntry', () {
    test('toMap includes present fields', () {
      final m = _alice.toMap();
      expect(m['name'], '张三');
      expect(m['phone'], '13800000001');
      expect(m['email'], 'zhang@example.com');
      expect(m['organization'], '公司A');
    });

    test('toMap excludes absent optional fields', () {
      const entry = ContactEntry(id: 'x', displayName: 'X');
      final m = entry.toMap();
      expect(m.containsKey('phone'), isFalse);
      expect(m.containsKey('email'), isFalse);
    });

    test('toString includes all present fields', () {
      expect(_alice.toString(), contains('张三'));
      expect(_alice.toString(), contains('13800000001'));
    });
  });

  group('ContactReadTool', () {
    test('returns empty message when no contacts', () async {
      final tool =
          ContactReadTool(dataSource: _FakeContactsDataSource());
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('为空'));
    });

    test('returns formatted contact list', () async {
      final tool = ContactReadTool(
        dataSource: _FakeContactsDataSource(contacts: [_alice, _bob]),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('张三'));
      expect(result.output, contains('李四'));
    });

    test('toolId is contacts.read', () {
      expect(const ContactReadTool().toolId, 'contacts.read');
    });
  });

  group('ContactSearchTool', () {
    test('returns error when query is missing', () async {
      final tool = ContactSearchTool(
        dataSource: _FakeContactsDataSource(contacts: [_alice]),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('query'));
    });

    test('returns not-found message when no match', () async {
      final tool = ContactSearchTool(
        dataSource: _FakeContactsDataSource(contacts: [_alice]),
      );
      final result = await tool.execute(<String, dynamic>{'query': '王五'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('未找到'));
    });

    test('returns matching contacts', () async {
      final tool = ContactSearchTool(
        dataSource: _FakeContactsDataSource(contacts: [_alice, _bob]),
      );
      final result = await tool.execute(<String, dynamic>{'query': '张三'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('张三'));
      expect(result.output, isNot(contains('李四')));
    });

    test('search by phone number', () async {
      final tool = ContactSearchTool(
        dataSource: _FakeContactsDataSource(contacts: [_alice, _bob]),
      );
      final result =
          await tool.execute(<String, dynamic>{'query': '13800000001'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('张三'));
    });

    test('toolId is contacts.search', () {
      expect(const ContactSearchTool().toolId, 'contacts.search');
    });
  });

  group('ContactCreateTool', () {
    test('returns error when name is missing', () async {
      final tool = ContactCreateTool(
        dataSource: _FakeContactsDataSource(),
      );
      final result = await tool.execute(const <String, dynamic>{});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('name'));
    });

    test('creates contact with name only', () async {
      final tool = ContactCreateTool(
        dataSource: _FakeContactsDataSource(),
      );
      final result = await tool.execute(<String, dynamic>{'name': '王五'});
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('王五'));
    });

    test('creates contact with all fields', () async {
      final tool = ContactCreateTool(
        dataSource: _FakeContactsDataSource(),
      );
      final result = await tool.execute(<String, dynamic>{
        'name': '赵六',
        'phone': '18600000003',
        'email': 'zhao@example.com',
        'organization': '公司B',
      });
      expect(result.isSuccess, isTrue);
      expect(result.output, contains('赵六'));
    });

    test('handles platform error gracefully', () async {
      final tool = ContactCreateTool(
        dataSource: _FakeContactsDataSource(throwOnCreate: true),
      );
      final result = await tool.execute(<String, dynamic>{'name': '测试'});
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('失败'));
    });

    test('toolId is contacts.create', () {
      expect(const ContactCreateTool().toolId, 'contacts.create');
    });
  });

  group('StubContactsDataSource', () {
    test('readAll returns empty', () async {
      final result = await const StubContactsDataSource().readAll();
      expect(result, isEmpty);
    });

    test('search returns empty', () async {
      final result = await const StubContactsDataSource().search('x');
      expect(result, isEmpty);
    });

    test('create returns entry id', () async {
      const e = ContactEntry(id: 'stub_id', displayName: 'Test');
      final id = await const StubContactsDataSource().create(e);
      expect(id, 'stub_id');
    });
  });
}
