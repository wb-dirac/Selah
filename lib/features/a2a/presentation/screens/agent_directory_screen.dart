import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';

const String _kDirectoryUrl =
    // Community registry placeholder — replace with the real index URL
    // when available. The app falls back to demo agents if this is unreachable.
    'https://a2a-directory.example.com/agents.json';

final List<_DirectoryEntry> _kDemoAgents = <_DirectoryEntry>[
  _DirectoryEntry(
    name: 'Weather Agent',
    description: '提供实时天气查询，支持全球城市。',
    skillsCount: 3,
    url: 'https://demo-agents.example.com/weather/a2a',
  ),
  _DirectoryEntry(
    name: 'Translation Agent',
    description: '多语言翻译，支持中英日韩等 50+ 语言。',
    skillsCount: 2,
    url: 'https://demo-agents.example.com/translate/a2a',
  ),
  _DirectoryEntry(
    name: 'Code Review Agent',
    description: '代码审查与优化建议，支持主流编程语言。',
    skillsCount: 5,
    url: 'https://demo-agents.example.com/code-review/a2a',
  ),
  _DirectoryEntry(
    name: 'Research Agent',
    description: '联网搜索并整理研究报告，支持引用溯源。',
    skillsCount: 4,
    url: 'https://demo-agents.example.com/research/a2a',
  ),
  _DirectoryEntry(
    name: 'Calendar Scheduler Agent',
    description: '智能日程规划与冲突检测，可跨时区同步。',
    skillsCount: 6,
    url: 'https://demo-agents.example.com/scheduler/a2a',
  ),
];

class _DirectoryEntry {
  const _DirectoryEntry({
    required this.name,
    required this.description,
    required this.skillsCount,
    required this.url,
  });

  final String name;
  final String description;
  final int skillsCount;
  final String url;
}

class AgentDirectoryScreen extends StatefulWidget {
  const AgentDirectoryScreen({super.key, required this.onAddAgent});

  final void Function(AgentCard card) onAddAgent;

  @override
  State<AgentDirectoryScreen> createState() => _AgentDirectoryScreenState();
}

class _AgentDirectoryScreenState extends State<AgentDirectoryScreen> {
  List<_DirectoryEntry> _all = <_DirectoryEntry>[];
  List<_DirectoryEntry> _filtered = <_DirectoryEntry>[];
  bool _isLoading = true;
  String? _networkError;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    setState(() {
      _isLoading = true;
      _networkError = null;
    });

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(_kDirectoryUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as List<dynamic>;
        final entries = json
            .map((e) => _DirectoryEntry(
                  name: (e as Map<String, dynamic>)['name'] as String? ?? '',
                  description: e['description'] as String? ?? '',
                  skillsCount: (e['skills'] as List?)?.length ?? 0,
                  url: e['url'] as String? ?? '',
                ))
            .where((e) => e.url.isNotEmpty && e.name.isNotEmpty)
            .toList();
        _all = entries;
      } else {
        _networkError = '目录服务返回 HTTP ${response.statusCode}，已显示示例 Agent';
        _all = _kDemoAgents;
      }
      client.close();
    } catch (_) {
      _networkError = '无法连接到公开 Agent 目录，已显示示例 Agent';
      _all = _kDemoAgents;
    }

    _applyFilter();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _query.toLowerCase();
    _filtered = q.isEmpty
        ? List<_DirectoryEntry>.from(_all)
        : _all
            .where(
              (e) =>
                  e.name.toLowerCase().contains(q) ||
                  e.description.toLowerCase().contains(q),
            )
            .toList();
  }

  void _onSearch(String value) {
    setState(() {
      _query = value;
      _applyFilter();
    });
  }

  void _addAgent(_DirectoryEntry entry) {
    final card = AgentCard(
      name: entry.name,
      url: entry.url,
      description: entry.description,
      capabilities: const AgentCapabilities(),
      skills: <AgentSkill>[
        AgentSkill(
          id: 'default',
          name: entry.name,
          description: entry.description,
        ),
      ],
    );
    widget.onAddAgent(card);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${entry.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公开 Agent 目录'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: '搜索 Agent 名称或描述…',
                prefixIcon: const Icon(Icons.search_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          if (_networkError != null)
            _NetworkErrorBanner(message: _networkError!),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _EmptyResults(query: _query)
                    : RefreshIndicator(
                        onRefresh: _fetchAgents,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _AgentCard(
                            entry: _filtered[i],
                            onAdd: () => _addAgent(_filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _NetworkErrorBanner extends StatelessWidget {
  const _NetworkErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.wifi_off_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.entry, required this.onAdd});
  final _DirectoryEntry entry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 22,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.build_outlined,
                        size: 13,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.skillsCount} 项技能',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.url,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty ? '目录为空' : '未找到匹配的 Agent',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (query.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '尝试更换关键词',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
