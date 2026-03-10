import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/data/skill_registry.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/domain/skill_record.dart';
import 'package:personal_ai_assistant/features/skill_sandbox/presentation/screens/skill_marketplace_screen.dart';

class SkillManagementScreen extends ConsumerWidget {
  const SkillManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillRegistryProvider);
    final installed = skills.skills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill 管理'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _openMarketplace(context),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('市场'),
          ),
        ],
      ),
      body: installed.isEmpty
          ? _EmptyState(
              onBrowse: () => _openMarketplace(context),
            )
          : _SkillList(skills: installed),
    );
  }

  void _openMarketplace(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const SkillMarketplaceScreen(),
      ),
    );
  }
}

class _SkillList extends ConsumerWidget {
  const _SkillList({required this.skills});

  final List<SkillRecord> skills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      itemCount: skills.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final skill = skills[index];
        return _SkillTile(
          skill: skill,
          onToggle: (enabled) => ref
              .read(skillRegistryProvider.notifier)
              .setEnabled(skill.id, enabled: enabled),
          onUninstall: () => _confirmUninstall(context, ref, skill),
          onViewLogs: () => _showComingSoon(context, '运行日志'),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 即将上线')),
    );
  }

  void _confirmUninstall(
    BuildContext context,
    WidgetRef ref,
    SkillRecord skill,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('卸载 ${skill.name}？'),
        content: const Text('卸载后将删除该 Skill 的所有文件和缓存，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(skillRegistryProvider.notifier)
                  .removeSkill(skill.id);
            },
            child: const Text('卸载'),
          ),
        ],
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.skill,
    required this.onToggle,
    required this.onUninstall,
    required this.onViewLogs,
  });

  final SkillRecord skill;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUninstall;
  final VoidCallback onViewLogs;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(skill.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _showActions(context);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SwipeAction(
              icon: Icons.article_outlined,
              label: '日志',
              onTap: onViewLogs,
            ),
            const SizedBox(width: 8),
            _SwipeAction(
              icon: Icons.delete_outline,
              label: '卸载',
              onTap: onUninstall,
              destructive: true,
            ),
          ],
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            skill.name.isNotEmpty
                ? skill.name[0].toUpperCase()
                : 'S',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(skill.name),
        subtitle: Text(
          '${skill.level1.manifest.description}\n'
          '${skill.name} · v${skill.level1.manifest.version ?? "—"}',
        ),
        isThreeLine: true,
        trailing: Switch(
          value: skill.enabled,
          onChanged: onToggle,
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('查看运行日志'),
              onTap: () {
                Navigator.pop(ctx);
                onViewLogs();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '卸载',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onUninstall();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SkillDetailSheet(skill: skill),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SkillDetailSheet extends StatelessWidget {
  const _SkillDetailSheet({required this.skill});

  final SkillRecord skill;

  @override
  Widget build(BuildContext context) {
    final manifest = skill.level1.manifest;
    final level2 = skill.level2;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  skill.name.isNotEmpty
                      ? skill.name[0].toUpperCase()
                      : 'S',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      skill.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${skill.name} · v${manifest.version ?? "—"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (manifest.author != null)
                      Text(
                        '作者: ${manifest.author}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(title: '描述', child: Text(manifest.description)),
          if (level2 != null && level2.toolDefinitions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _Section(
              title: '提供的工具 (${level2.toolDefinitions.length})',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: level2.toolDefinitions
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.build_outlined, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(t, style: Theme.of(context).textTheme.bodySmall)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            title: '包含文件',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FileRow(icon: Icons.description_outlined, name: 'SKILL.md'),
                if (level2?.readmeContent != null)
                  const _FileRow(icon: Icons.description_outlined, name: 'README.md'),
                if (level2?.systemPromptTemplate != null)
                  const _FileRow(icon: Icons.description_outlined, name: 'system_prompt.md'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Divider(height: 8),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 6),
          Text(name, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.extension_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无已安装的 Skill',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '前往市场浏览并安装 Skill',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('浏览 Skill 市场'),
          ),
        ],
      ),
    );
  }
}
