import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_call_result.dart';

class ContactEntry {
  const ContactEntry({
    required this.id,
    required this.displayName,
    this.phone,
    this.email,
    this.organization,
  });

  final String id;
  final String displayName;
  final String? phone;
  final String? email;
  final String? organization;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': displayName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (organization != null) 'organization': organization,
      };

  @override
  String toString() {
    final parts = <String>[displayName];
    if (phone != null) parts.add('Tel: $phone');
    if (email != null) parts.add('Email: $email');
    if (organization != null) parts.add('Org: $organization');
    return parts.join(' | ');
  }
}

abstract class ContactsDataSource {
  Future<List<ContactEntry>> readAll();

  Future<List<ContactEntry>> search(String query);

  Future<String> create(ContactEntry entry);
}

class StubContactsDataSource implements ContactsDataSource {
  const StubContactsDataSource();
  @override
  Future<List<ContactEntry>> readAll() async => const <ContactEntry>[];

  @override
  Future<List<ContactEntry>> search(String query) async =>
      const <ContactEntry>[];

  @override
  Future<String> create(ContactEntry entry) async => entry.id;
}

class ContactReadTool implements ToolExecutor {
  const ContactReadTool({ContactsDataSource? dataSource})
      : _dataSource = dataSource ?? const StubContactsDataSource();

  final ContactsDataSource _dataSource;

  @override
  String get toolId => 'contacts.read';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    try {
      final contacts = await _dataSource.readAll();
      if (contacts.isEmpty) {
        return const ToolCallResult.success(
          toolId: 'contacts.read',
          output: '通讯录为空',
        );
      }
      final output = contacts.map((c) => c.toString()).join('\n');
      return ToolCallResult.success(toolId: 'contacts.read', output: output);
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'contacts.read',
        errorMessage: '读取联系人失败: $e',
      );
    }
  }
}

class ContactSearchTool implements ToolExecutor {
  const ContactSearchTool({ContactsDataSource? dataSource})
      : _dataSource = dataSource ?? const StubContactsDataSource();

  final ContactsDataSource _dataSource;

  @override
  String get toolId => 'contacts.search';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query']?.toString();
    if (query == null || query.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'contacts.search',
        errorMessage: '缺少参数 query',
      );
    }

    try {
      final contacts = await _dataSource.search(query.trim());
      if (contacts.isEmpty) {
        return ToolCallResult.success(
          toolId: 'contacts.search',
          output: '未找到匹配联系人: $query',
        );
      }
      final output = contacts.map((c) => c.toString()).join('\n');
      return ToolCallResult.success(
          toolId: 'contacts.search', output: output);
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'contacts.search',
        errorMessage: '搜索联系人失败: $e',
      );
    }
  }
}

class ContactCreateTool implements ToolExecutor {
  const ContactCreateTool({ContactsDataSource? dataSource})
      : _dataSource = dataSource ?? const StubContactsDataSource();

  final ContactsDataSource _dataSource;

  @override
  String get toolId => 'contacts.create';

  @override
  Future<ToolCallResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name']?.toString();
    if (name == null || name.trim().isEmpty) {
      return const ToolCallResult.error(
        toolId: 'contacts.create',
        errorMessage: '缺少参数 name',
      );
    }

    final entry = ContactEntry(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name.trim(),
      phone: arguments['phone']?.toString(),
      email: arguments['email']?.toString(),
      organization: arguments['organization']?.toString(),
    );

    try {
      final createdId = await _dataSource.create(entry);
      return ToolCallResult.success(
        toolId: 'contacts.create',
        output: '联系人已创建: ${entry.displayName} (id: $createdId)',
      );
    } catch (e) {
      return ToolCallResult.error(
        toolId: 'contacts.create',
        errorMessage: '创建联系人失败: $e',
      );
    }
  }
}
