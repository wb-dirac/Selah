import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_installer.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_marketplace_service.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/presentation/widgets/skill_scan_sheet.dart';
import 'package:personal_ai_assistant/storage/config/keychain_preferences_store.dart';

final _marketplaceServiceProvider = Provider<SkillMarketplaceService>((ref) {
  final prefs = ref.watch(keychainPreferencesStoreProvider);
  return SkillMarketplaceService(preferences: prefs);
});

final _marketplaceListingsProvider =
    FutureProvider.family<MarketplaceFetchResult, String>(
  (ref, category) async {
    final service = ref.watch(_marketplaceServiceProvider);
    final cat = category == '全部' ? null : category;
    return service.fetchListings(category: cat);
  },
);

class SkillMarketplaceScreen extends ConsumerStatefulWidget {
  const SkillMarketplaceScreen({super.key});

  @override
  ConsumerState<SkillMarketplaceScreen> createState() =>
      _SkillMarketplaceScreenState();
}

class _SkillMarketplaceScreenState
    extends ConsumerState<SkillMarketplaceScreen> {
  String _selectedCategory = SkillMarketplaceService.categories.first;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustomSourceDialog,
        icon: const Icon(Icons.add_link),
        label: const Text('添加自定义源'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索 Skill 名称、描述、作者…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          if (!_isSearching) _buildCategoryChips(),
          const SizedBox(height: 4),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Skill 市场'),
      actions: <Widget>[
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true),
            tooltip: '搜索',
          ),
        if (_isSearching)
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _isSearching = false;
                _searchQuery = '';
              });
            },
            child: const Text('取消'),
          ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: SkillMarketplaceService.categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: _selectedCategory == cat,
              onSelected: (_) => setState(() => _selectedCategory = cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching && _searchQuery.trim().isNotEmpty) {
      return _SearchResultsView(
        query: _searchQuery,
        service: ref.watch(_marketplaceServiceProvider),
        onInstall: _triggerInstall,
      );
    }

    final asyncListings = ref.watch(
      _marketplaceListingsProvider(_selectedCategory),
    );

    return asyncListings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _OfflineFallbackView(
        entries: SkillMarketplaceService.demoEntries,
        onInstall: _triggerInstall,
        onRefresh: () => ref.invalidate(
          _marketplaceListingsProvider(_selectedCategory),
        ),
      ),
      data: (result) {
        if (result.isOffline) {
          return _OfflineFallbackView(
            entries: result.entries,
            onInstall: _triggerInstall,
            onRefresh: () => ref.invalidate(
              _marketplaceListingsProvider(_selectedCategory),
            ),
          );
        }
        if (result.entries.isEmpty) {
          return const Center(child: Text('该分类暂无 Skill'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_marketplaceListingsProvider(_selectedCategory));
          },
          child: _SkillGrid(
            entries: result.entries,
            onInstall: _triggerInstall,
          ),
        );
      },
    );
  }

  Future<void> _triggerInstall(SkillMarketplaceEntry entry) async {
    const installer = SkillInstaller();
    if (!mounted) return;
    await showSkillInstallFlow(
      context: context,
      packageUrl: entry.downloadUrl,
      installer: installer,
    );
  }

  Future<void> _showAddCustomSourceDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加自定义源'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/skills/index.json',
            labelText: '源 URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (confirmed == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        final service = ref.read(_marketplaceServiceProvider);
        await service.addCustomSource(url);
        if (mounted) {
          ref.invalidate(_marketplaceListingsProvider(_selectedCategory));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('自定义源已添加')),
          );
        }
      }
    }
  }
}

class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.entries, required this.onInstall});

  final List<SkillMarketplaceEntry> entries;
  final Future<void> Function(SkillMarketplaceEntry) onInstall;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _SkillMarketplaceEntryCard(
        entry: entries[index],
        onInstall: () => onInstall(entries[index]),
      ),
    );
  }
}

class _SkillMarketplaceEntryCard extends StatelessWidget {
  const _SkillMarketplaceEntryCard({
    required this.entry,
    required this.onInstall,
  });

  final SkillMarketplaceEntry entry;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    entry.name.isNotEmpty
                        ? entry.name[0].toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.name,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                entry.description,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _CategoryChip(category: entry.category),
                const Spacer(),
                Text(
                  '${entry.installCount} 安装',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '作者: ${entry.author}',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onInstall,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('安装'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSecondaryContainer,
            ),
      ),
    );
  }
}

class _SearchResultsView extends StatefulWidget {
  const _SearchResultsView({
    required this.query,
    required this.service,
    required this.onInstall,
  });

  final String query;
  final SkillMarketplaceService service;
  final Future<void> Function(SkillMarketplaceEntry) onInstall;

  @override
  State<_SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<_SearchResultsView> {
  late Future<List<SkillMarketplaceEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.search(widget.query);
  }

  @override
  void didUpdateWidget(_SearchResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _future = widget.service.search(widget.query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SkillMarketplaceEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data ?? const <SkillMarketplaceEntry>[];
        if (entries.isEmpty) {
          return Center(
            child: Text(
              '未找到相关 Skill',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return _SkillGrid(entries: entries, onInstall: widget.onInstall);
      },
    );
  }
}

class _OfflineFallbackView extends StatelessWidget {
  const _OfflineFallbackView({
    required this.entries,
    required this.onInstall,
    required this.onRefresh,
  });

  final List<SkillMarketplaceEntry> entries;
  final Future<void> Function(SkillMarketplaceEntry) onInstall;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: const Text('无法连接市场，显示预设 Skill'),
          leading: const Icon(Icons.wifi_off),
          actions: <Widget>[
            TextButton(
              onPressed: onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('暂无预设 Skill'))
              : _SkillGrid(entries: entries, onInstall: onInstall),
        ),
      ],
    );
  }
}
