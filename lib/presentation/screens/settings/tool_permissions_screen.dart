import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/tool_bridge/data/tool_permission_service.dart';
import 'package:personal_ai_assistant/features/tool_bridge/domain/tool_models.dart';

class ToolPermissionsScreen extends ConsumerWidget {
  const ToolPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(toolPermissionRecordsProvider);
    final historyAsync = ref.watch(toolInvocationHistoryProvider);
    final definitions = ref.watch(toolPermissionServiceProvider).listDefinitions();

    return Scaffold(
      appBar: AppBar(title: const Text('工具权限管理')),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载工具权限失败：$error')),
        data: (records) {
          final recordMap = <String, ToolPermissionRecord>{
            for (final item in records) item.toolId: item,
          };
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              for (final category in ToolCategory.values)
                _ToolCategorySection(
                  category: category,
                  definitions: definitions
                      .where((item) => item.category == category)
                      .toList(growable: false),
                  recordMap: recordMap,
                ),
              const Divider(height: 1),
              historyAsync.when(
                loading: () => const ListTile(title: Text('加载操作历史中…')),
                error: (error, _) => ListTile(title: Text('加载操作历史失败：$error')),
                data: (history) {
                  return ExpansionTile(
                    title: const Text('最近 50 条工具调用记录'),
                    children: history.isEmpty
                        ? const <Widget>[
                            ListTile(title: Text('暂无工具调用记录')),
                          ]
                        : history
                              .map(
                                (item) => ListTile(
                                  leading: Icon(
                                    item.allowed ? Icons.check_circle : Icons.block,
                                    color: item.allowed ? Colors.green : Colors.red,
                                  ),
                                  title: Text(item.toolId),
                                  subtitle: Text(
                                    '${item.summary ?? '无摘要'}\n${item.timestamp.toLocal()}',
                                  ),
                                  isThreeLine: true,
                                ),
                              )
                              .toList(growable: false),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolCategorySection extends ConsumerWidget {
  const _ToolCategorySection({
    required this.category,
    required this.definitions,
    required this.recordMap,
  });

  final ToolCategory category;
  final List<ToolDefinition> definitions;
  final Map<String, ToolPermissionRecord> recordMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (definitions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(category.label, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...definitions.map((definition) {
          final record = recordMap[definition.id];
          final status = record?.status ?? _defaultStatusFor(definition.permissionLevel);
          return ListTile(
            title: Text(definition.displayName),
            subtitle: Text('${status.label} · ${definition.permissionLevel.label}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPermissionEditor(context, ref, definition, status),
          );
        }),
      ],
    );
  }

  ToolPermissionStatus _defaultStatusFor(ToolPermissionLevel level) {
    switch (level) {
      case ToolPermissionLevel.l0:
        return ToolPermissionStatus.granted;
      case ToolPermissionLevel.l1:
        return ToolPermissionStatus.notDetermined;
      case ToolPermissionLevel.l2:
      case ToolPermissionLevel.l3:
        return ToolPermissionStatus.askEveryTime;
    }
  }

  Future<void> _showPermissionEditor(
    BuildContext context,
    WidgetRef ref,
    ToolDefinition definition,
    ToolPermissionStatus currentStatus,
  ) async {
    final nextStatus = await showModalBottomSheet<ToolPermissionStatus>(
      context: context,
      builder: (dialogContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ToolPermissionStatus.values
                .map(
                  (status) => ListTile(
                    title: Text(status.label),
                    trailing: status == currentStatus
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(dialogContext).pop(status),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (nextStatus == null) {
      return;
    }
    await ref
        .read(toolPermissionServiceProvider)
        .setPermissionStatus(definition.id, nextStatus);
    ref.invalidate(toolPermissionRecordsProvider);
  }
}
