import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/a2a/data/a2a_providers.dart';
import 'package:personal_ai_assistant/features/a2a/data/agent_registry.dart';
import 'package:personal_ai_assistant/features/a2a/domain/agent_card.dart';
import 'package:personal_ai_assistant/features/a2a/domain/discovered_agent.dart';
import 'package:personal_ai_assistant/features/a2a/presentation/screens/agent_directory_screen.dart';

class AddAgentSheet extends ConsumerStatefulWidget {
  const AddAgentSheet({super.key});

  @override
  ConsumerState<AddAgentSheet> createState() => _AddAgentSheetState();
}

class _AddAgentSheetState extends ConsumerState<AddAgentSheet> {
  final TextEditingController _urlCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              '添加 Agent 服务',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _QrScanPanel(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _UrlInputPanel(
                    controller: _urlCtrl,
                    loading: _loading,
                    onConfirm: _onConfirm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search_outlined),
              title: const Text('搜索公开 Agent 目录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDirectory(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openDirectory(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentDirectoryScreen(
          onAddAgent: (AgentCard card) {
            ref
                .read(agentRegistryProvider.notifier)
                .addAgent(card, AgentSource.internet);
          },
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent URL 必须以 https:// 开头')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final hostClient = ref.read(a2aHostClientProvider);
      final result = await ref
          .read(agentRegistryProvider.notifier)
          .addAgentFromUrl(url, hostClient);

      if (!mounted) return;

      if (result is AgentCardValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${result.card.name}')),
        );
        Navigator.pop(context);
      } else if (result is AgentCardInvalid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent Card 验证失败: ${result.errors.first}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _QrScanPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.qr_code_scanner_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            '二维码扫描',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

class _UrlInputPanel extends StatelessWidget {
  const _UrlInputPanel({
    required this.controller,
    required this.loading,
    required this.onConfirm,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('输入 URL'),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'https://...',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : FilledButton(
                onPressed: onConfirm,
                child: const Text('确认添加'),
              ),
      ],
    );
  }
}
