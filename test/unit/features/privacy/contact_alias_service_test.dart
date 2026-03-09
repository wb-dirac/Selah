import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/keychain/keychain_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/contact_alias_service.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class _InMemoryKeychainService implements KeychainService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }
}

void main() {
  group('ContactAliasService', () {
    late ContactAliasService service;

    setUp(() {
      final keychain = _InMemoryKeychainService();
      service = ContactAliasService(
        preferences: KeychainPreferencesStore(keychain),
      );
    });

    test('replaces detected contact names consistently within conversation', () async {
      final first = await service.sanitizeText(
        conversationId: 'conversation-1',
        text: '给张三发消息，然后提醒张三明天开会',
      );
      final second = await service.sanitizeText(
        conversationId: 'conversation-1',
        text: '联系张三确认时间',
      );

      expect(first.hasAliases, isTrue);
      expect(first.sanitizedText, contains('联系人A'));
      expect(first.sanitizedText, isNot(contains('张三')));
      expect(second.sanitizedText, contains('联系人A'));
    });
  });
}
