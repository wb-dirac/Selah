import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

class SkillMarketplaceEntry {
  const SkillMarketplaceEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.category,
    required this.downloadUrl,
    this.version,
    this.installCount = 0,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String description;
  final String author;
  final String category;
  final String downloadUrl;
  final String? version;
  final int installCount;
  final String? iconUrl;

  factory SkillMarketplaceEntry.fromJson(Map<String, dynamic> json) {
    return SkillMarketplaceEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      author: json['author'] as String,
      category: json['category'] as String,
      downloadUrl: json['download_url'] as String,
      version: json['version'] as String?,
      installCount: (json['install_count'] as int?) ?? 0,
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'author': author,
        'category': category,
        'download_url': downloadUrl,
        if (version != null) 'version': version,
        'install_count': installCount,
        if (iconUrl != null) 'icon_url': iconUrl,
      };
}

class MarketplaceFetchResult {
  const MarketplaceFetchResult({
    required this.entries,
    required this.isOffline,
  });

  final List<SkillMarketplaceEntry> entries;
  final bool isOffline;
}

class SkillMarketplaceService {
  SkillMarketplaceService({
    required KeychainPreferencesStore preferences,
    AppLogger? logger,
  })  : _preferences = preferences,
        _logger = logger;

  final KeychainPreferencesStore _preferences;
  final AppLogger? _logger;

  static const String _kOfficialUrl =
      'https://skills.anthropic.com/index.json';
  static const String _kCommunityUrl =
      'https://raw.githubusercontent.com/anthropics/skill-registry/main/index.json';
  static const String _kCustomSourcesKey = 'skill_marketplace_custom_sources';

  static const List<String> categories = <String>[
    '全部',
    '效率',
    '数据分析',
    '写作',
    '开发',
    '学习',
  ];

  static const List<SkillMarketplaceEntry> demoEntries =
      <SkillMarketplaceEntry>[
    SkillMarketplaceEntry(
      id: 'code-formatter',
      name: 'Code Formatter',
      description:
          'Format code in various languages including Python, JS, Dart, and more.',
      author: 'Anthropic',
      category: '开发',
      downloadUrl:
          'https://skills.anthropic.com/packages/code-formatter.zip',
      version: '1.0.0',
      installCount: 1240,
    ),
    SkillMarketplaceEntry(
      id: 'data-table',
      name: 'Data Table',
      description:
          'Transform JSON/CSV data into formatted tables for easy reading.',
      author: 'Anthropic',
      category: '数据分析',
      downloadUrl:
          'https://skills.anthropic.com/packages/data-table.zip',
      version: '1.2.0',
      installCount: 980,
    ),
    SkillMarketplaceEntry(
      id: 'markdown-writer',
      name: 'Markdown Writer',
      description:
          'Convert structured content to well-formatted Markdown documents.',
      author: 'Anthropic',
      category: '写作',
      downloadUrl:
          'https://skills.anthropic.com/packages/markdown-writer.zip',
      version: '1.0.1',
      installCount: 756,
    ),
    SkillMarketplaceEntry(
      id: 'daily-summary',
      name: 'Daily Summary',
      description:
          "Summarize today's events, tasks, and notes into a concise briefing.",
      author: 'Anthropic',
      category: '效率',
      downloadUrl:
          'https://skills.anthropic.com/packages/daily-summary.zip',
      version: '1.1.0',
      installCount: 2100,
    ),
    SkillMarketplaceEntry(
      id: 'regex-helper',
      name: 'Regex Helper',
      description:
          'Build and test regular expressions with explanations and examples.',
      author: 'Anthropic',
      category: '开发',
      downloadUrl:
          'https://skills.anthropic.com/packages/regex-helper.zip',
      version: '1.0.0',
      installCount: 530,
    ),
  ];

  Future<MarketplaceFetchResult> fetchListings({String? category}) async {
    final result = await _fetchAllListings();
    if (result.isOffline) {
      final filtered = category == null || category == '全部'
          ? result.entries
          : result.entries
              .where((e) => e.category == category)
              .toList();
      return MarketplaceFetchResult(
        entries: filtered,
        isOffline: true,
      );
    }
    final filtered = category == null || category == '全部'
        ? result.entries
        : result.entries.where((e) => e.category == category).toList();
    return MarketplaceFetchResult(entries: filtered, isOffline: false);
  }

  Future<List<SkillMarketplaceEntry>> search(String query) async {
    if (query.trim().isEmpty) {
      final result = await fetchListings();
      return result.entries;
    }
    final all = await _fetchAllListings();
    final lower = query.toLowerCase();
    return all.entries
        .where(
          (e) =>
              e.name.toLowerCase().contains(lower) ||
              e.description.toLowerCase().contains(lower) ||
              e.author.toLowerCase().contains(lower) ||
              e.category.toLowerCase().contains(lower),
        )
        .toList();
  }

  Future<void> addCustomSource(String url) async {
    final current = await getCustomSources();
    if (current.contains(url)) return;
    final updated = <String>[...current, url];
    await _preferences.saveString(_kCustomSourcesKey, jsonEncode(updated));
  }

  Future<List<String>> getCustomSources() async {
    try {
      final raw = await _preferences.readString(_kCustomSourcesKey);
      if (raw == null || raw.isEmpty) return const <String>[];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<String>();
    } catch (e) {
      _logger?.warning(
        'SkillMarketplaceService: failed to read custom sources',
        context: {'error': e.toString()},
      );
      return const <String>[];
    }
  }

  Future<void> removeCustomSource(String url) async {
    final current = await getCustomSources();
    final updated = current.where((u) => u != url).toList();
    await _preferences.saveString(_kCustomSourcesKey, jsonEncode(updated));
  }

  Future<MarketplaceFetchResult> _fetchAllListings() async {
    final entries = await _tryFetchFromUrl(_kOfficialUrl);
    if (entries != null) {
      return MarketplaceFetchResult(entries: entries, isOffline: false);
    }

    final communityEntries = await _tryFetchFromUrl(_kCommunityUrl);
    if (communityEntries != null) {
      return MarketplaceFetchResult(
        entries: communityEntries,
        isOffline: false,
      );
    }

    final customSources = await getCustomSources();
    for (final url in customSources) {
      final customEntries = await _tryFetchFromUrl(url);
      if (customEntries != null) {
        return MarketplaceFetchResult(
          entries: customEntries,
          isOffline: false,
        );
      }
    }

    return const MarketplaceFetchResult(
      entries: demoEntries,
      isOffline: true,
    );
  }

  Future<List<SkillMarketplaceEntry>?> _tryFetchFromUrl(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .cast<Map<String, dynamic>>()
            .map(SkillMarketplaceEntry.fromJson)
            .toList();
      }
      if (decoded is Map<String, dynamic> && decoded.containsKey('skills')) {
        final list = decoded['skills'] as List<dynamic>;
        return list
            .cast<Map<String, dynamic>>()
            .map(SkillMarketplaceEntry.fromJson)
            .toList();
      }
      return null;
    } catch (e) {
      _logger?.warning(
        'SkillMarketplaceService: failed to fetch from $url',
        context: {'error': e.toString()},
      );
      return null;
    }
  }
}

