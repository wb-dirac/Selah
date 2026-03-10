import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/a2a/data/agent_registry.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';
import 'package:personal_ai_assistant/features/a2a/presentation/widgets/add_agent_sheet.dart';

class AgentNetworkScreen extends ConsumerWidget {
  const AgentNetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentRegistryProvider);
    final connected = state.connected;
    final unconnected = state.unconnectedDiscovered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent 网络'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _openAddSheet(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加'),
          ),
        ],
      ),
      body: connected.isEmpty && unconnected.isEmpty
          ? _EmptyAgentState(onAddTap: () => _openAddSheet(context, ref))
          : ListView(
              children: <Widget>[
                if (connected.isNotEmpty) ...<Widget>[
                  _SectionHeader(title: '已连接 (${connected.length})'),
                  ...connected.map(
                    (a) => _ConnectedAgentTile(
                      agent: a,
                      onTap: () => _openDetail(context, a),
                      onDisconnect: () => ref
                          .read(agentRegistryProvider.notifier)
                          .removeAgent(a.card.url),
                    ),
                  ),
                ],
                if (unconnected.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _SectionHeader(title: '局域网发现 (${unconnected.length})'),
                  ...unconnected.map(
                    (d) => _DiscoveredAgentTile(
                      agent: d,
                      onAdd: () => _addDiscovered(context, ref, d),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  void _openAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddAgentSheet(
        onAddUrl: (url) => _addByUrl(context, ref, url),
      ),
    );
  }

  void _openDetail(BuildContext context, ConnectedAgent agent) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentDetailScreen(agent: agent),
      ),
    );
  }

  Future<void> _addByUrl(
      BuildContext context, WidgetRef ref, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final card = AgentCard(
      name: Uri.parse(url).host,
      url: url,
      capabilities: const AgentCapabilities(),
      skills: const <AgentSkill>[],
    );
    ref.read(agentRegistryProvider.notifier).addAgent(card, AgentSource.manual);
    messenger.showSnackBar(
      SnackBar(content: Text('已添加 ${card.name}')),
    );
  }

  void _addDiscovered(
      BuildContext context, WidgetRef ref, DiscoveredAgent discovered) {
    final card = AgentCard(
      name: discovered.deviceName ?? discovered.host,
      url: discovered.a2aUrl,
      capabilities: const AgentCapabilities(),
      skills: const <AgentSkill>[],
    );
    ref
        .read(agentRegistryProvider.notifier)
        .addAgent(card, discovered.source);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加 ${card.name}')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ConnectedAgentTile extends StatelessWidget {
  const _ConnectedAgentTile({
    required this.agent,
    required this.onTap,
    required this.onDisconnect,
  });

  final ConnectedAgent agent;
  final VoidCallback onTap;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final isOnline = agent.status == AgentConnectionStatus.online;
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.smart_toy_outlined)),
      title: Text(agent.card.name),
      subtitle: Text(
        _sourceLabel(agent.source),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.circle,
            size: 10,
            color: isOnline ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? '在线' : '未知',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'disconnect') onDisconnect();
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'disconnect', child: Text('断开连接')),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _sourceLabel(AgentSource source) {
    switch (source) {
      case AgentSource.lan:
        return '局域网';
      case AgentSource.internet:
        return '公网';
      case AgentSource.manual:
        return '手动添加';
    }
  }
}

class _DiscoveredAgentTile extends StatelessWidget {
  const _DiscoveredAgentTile({
    required this.agent,
    required this.onAdd,
  });

  final DiscoveredAgent agent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.search_outlined),
      ),
      title: Text(agent.deviceName ?? agent.host),
      subtitle: Text(
        '设备: ${agent.deviceName ?? agent.host}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: FilledButton.tonal(
        onPressed: onAdd,
        child: const Text('添加'),
      ),
    );
  }
}

class _EmptyAgentState extends StatelessWidget {
  const _EmptyAgentState({required this.onAddTap});
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.hub_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('暂无 Agent 连接', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '添加外部 Agent，扩展助理能力',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.add),
            label: const Text('添加 Agent'),
          ),
        ],
      ),
    );
  }
}

class AgentDetailScreen extends ConsumerWidget {
  const AgentDetailScreen({super.key, required this.agent});

  final ConnectedAgent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = agent.status == AgentConnectionStatus.online;
    return Scaffold(
      appBar: AppBar(title: const Text('Agent 详情')),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.smart_toy_outlined, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      agent.card.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? '在线' : '未知',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (agent.card.description != null) ...<Widget>[
            _DetailSection(
              title: '描述',
              child: Text(
                agent.card.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 1),
          ],
          if (agent.card.skills.isNotEmpty) ...<Widget>[
            _DetailSection(
              title: '能力 (Skills)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: agent.card.skills
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            const Text('• '),
                            Expanded(child: Text(s.name)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1),
          ],
          _DetailSection(
            title: '连接信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoRow(label: '地址', value: agent.card.url),
                _InfoRow(label: '协议', value: 'A2A · TLS 1.3'),
                _InfoRow(
                  label: '认证',
                  value: agent.card.capabilities.streaming
                      ? 'OAuth 2.0'
                      : 'API Key',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                ref
                    .read(agentRegistryProvider.notifier)
                    .removeAgent(agent.card.url);
                Navigator.pop(context);
              },
              child: const Text('断开连接'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
