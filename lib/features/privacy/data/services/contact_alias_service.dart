import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class ContactAliasEntry {
  const ContactAliasEntry({required this.original, required this.alias});

  final String original;
  final String alias;
}

class ContactAliasResult {
  const ContactAliasResult({
    required this.originalText,
    required this.sanitizedText,
    required this.aliases,
  });

  final String originalText;
  final String sanitizedText;
  final List<ContactAliasEntry> aliases;

  bool get hasAliases => aliases.isNotEmpty;
}

class ContactAliasService {
  ContactAliasService({required KeychainPreferencesStore preferences})
    : _preferences = preferences;

  static final RegExp _candidatePattern = RegExp(
    r'(?:联系人|联系|问|叫|找|给|发给|通知|转告|发送给|打给|约|提醒)([\u4E00-\u9FFF]{2,4}?)(?=发|说|回|确认|回复|联系|通知|提醒|打|明天|今天|下午|上午|开会|[，。！？、\s]|$)',
  );

  static const Set<String> _stopWords = <String>{
    '今天',
    '明天',
    '下午',
    '上午',
    '一下',
    '一个',
    '这个',
    '那个',
    '事情',
    '已经',
    '马上',
  };

  final KeychainPreferencesStore _preferences;

  Future<ContactAliasResult> sanitizeText({
    required String? conversationId,
    required String text,
  }) async {
    if (conversationId == null || conversationId.trim().isEmpty || text.isEmpty) {
      return ContactAliasResult(
        originalText: text,
        sanitizedText: text,
        aliases: const <ContactAliasEntry>[],
      );
    }

    final storedMappings = await _loadMappings(conversationId);
    final nextMappings = <String, String>{...storedMappings};

    final candidates = <String>{};
    for (final match in _candidatePattern.allMatches(text)) {
      final value = match.group(1);
      if (value == null || value.isEmpty || _stopWords.contains(value)) {
        continue;
      }
      candidates.add(value);
    }

    var aliasIndex = nextMappings.length;
    for (final candidate in candidates) {
      if (!nextMappings.containsKey(candidate)) {
        nextMappings[candidate] = '联系人${_aliasLabel(aliasIndex)}';
        aliasIndex += 1;
      }
    }

    var sanitized = text;
    final aliases = <ContactAliasEntry>[];
    final orderedEntries = nextMappings.entries.toList(growable: false)
      ..sort((left, right) => right.key.length.compareTo(left.key.length));
    for (final entry in orderedEntries) {
      if (sanitized.contains(entry.key)) {
        sanitized = sanitized.replaceAll(entry.key, entry.value);
        aliases.add(ContactAliasEntry(original: entry.key, alias: entry.value));
      }
    }

    if (nextMappings.length != storedMappings.length) {
      await _saveMappings(conversationId, nextMappings);
    }

    return ContactAliasResult(
      originalText: text,
      sanitizedText: sanitized,
      aliases: aliases,
    );
  }

  Future<Map<String, String>> _loadMappings(String conversationId) async {
    final raw = await _preferences.readString(_mappingKey(conversationId));
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  Future<void> _saveMappings(
    String conversationId,
    Map<String, String> mappings,
  ) async {
    await _preferences.saveString(
      _mappingKey(conversationId),
      jsonEncode(mappings),
    );
  }

  String _mappingKey(String conversationId) {
    return 'privacy.contact_aliases.$conversationId';
  }

  String _aliasLabel(int index) {
    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < alphabet.length) {
      return alphabet[index];
    }
    final first = alphabet[(index ~/ alphabet.length) - 1];
    final second = alphabet[index % alphabet.length];
    return '$first$second';
  }
}

final contactAliasServiceProvider = Provider<ContactAliasService>((ref) {
  return ContactAliasService(
    preferences: ref.watch(keychainPreferencesStoreProvider),
  );
});
