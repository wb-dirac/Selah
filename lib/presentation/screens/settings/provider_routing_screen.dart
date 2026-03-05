import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/model_routing_models.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/routing/routing_settings_service.dart';

final routingRulesProvider = FutureProvider<List<RoutingRule>>((ref) {
  return ref.watch(routingSettingsServiceProvider).listRules();
});

final routingProviderOptionsProvider =
    FutureProvider<List<ManagedProviderConfig>>((ref) {
      return ref.watch(providerManagementServiceProvider).listConfigs();
    });

class ProviderRoutingScreen extends ConsumerWidget {
  const ProviderRoutingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(routingRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('模型路由规则')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加规则'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载规则失败：$e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('暂无路由规则，当前使用默认提供商'));
          }
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return ListTile(
                title: Text('${rule.modality.name} · ${rule.complexity.name}'),
                subtitle: Text(
                  '目标: ${rule.targetProviderId}${rule.targetModelId != null ? ' / ${rule.targetModelId}' : ''}\n'
                  'Fallback: ${rule.fallbackProviderId ?? '无'}${rule.fallbackModelId != null ? ' / ${rule.fallbackModelId}' : ''}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _openEditor(context, ref, index: index, existing: rule);
                      return;
                    }
                    if (action == 'delete') {
                      final next = List<RoutingRule>.from(rules)..removeAt(index);
                      await ref
                          .read(routingSettingsServiceProvider)
                          .saveRules(next);
                      ref.invalidate(routingRulesProvider);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  int? index,
  RoutingRule? existing,
}) async {
  final providerOptions = await ref.read(routingProviderOptionsProvider.future);
  if (!context.mounted) return;

  if (providerOptions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先在“提供商管理”中添加至少一个提供商')),
    );
    return;
  }

  final complexity = ValueNotifier<RoutingComplexity>(
    existing?.complexity ?? RoutingComplexity.any,
  );
  final modality = ValueNotifier<RoutingModality>(
    existing?.modality ?? RoutingModality.any,
  );
  final targetProviderId = ValueNotifier<String>(
    existing?.targetProviderId ?? providerOptions.first.providerId,
  );
  final targetModelCtrl = TextEditingController(text: existing?.targetModelId ?? '');
  final fallbackProviderId = ValueNotifier<String?>(existing?.fallbackProviderId);
  final fallbackModelCtrl = TextEditingController(
    text: existing?.fallbackModelId ?? '',
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? '添加规则' : '编辑规则'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<RoutingComplexity>(
                  valueListenable: complexity,
                  builder: (context, value, _) {
                    return DropdownButtonFormField<RoutingComplexity>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: '复杂度条件'),
                      items: RoutingComplexity.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (next) {
                        if (next != null) complexity.value = next;
                      },
                    );
                  },
                ),
                ValueListenableBuilder<RoutingModality>(
                  valueListenable: modality,
                  builder: (context, value, _) {
                    return DropdownButtonFormField<RoutingModality>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: '模态条件'),
                      items: RoutingModality.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (next) {
                        if (next != null) modality.value = next;
                      },
                    );
                  },
                ),
                ValueListenableBuilder<String>(
                  valueListenable: targetProviderId,
                  builder: (context, value, _) {
                    return DropdownButtonFormField<String>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: '目标提供商'),
                      items: providerOptions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.providerId,
                              child: Text('${item.displayName} (${item.providerId})'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (next) {
                        if (next != null) targetProviderId.value = next;
                      },
                    );
                  },
                ),
                TextField(
                  controller: targetModelCtrl,
                  decoration: const InputDecoration(labelText: '目标模型（可选）'),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: fallbackProviderId,
                  builder: (context, value, _) {
                    return DropdownButtonFormField<String?>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: 'Fallback 提供商（可选）'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('无')),
                        ...providerOptions.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.providerId,
                            child: Text('${item.displayName} (${item.providerId})'),
                          ),
                        ),
                      ],
                      onChanged: (next) {
                        fallbackProviderId.value = next;
                      },
                    );
                  },
                ),
                TextField(
                  controller: fallbackModelCtrl,
                  decoration: const InputDecoration(labelText: 'Fallback 模型（可选）'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final rule = RoutingRule(
                targetProviderId: targetProviderId.value,
                targetModelId: targetModelCtrl.text.trim().isEmpty
                    ? null
                    : targetModelCtrl.text.trim(),
                complexity: complexity.value,
                modality: modality.value,
                fallbackProviderId: fallbackProviderId.value,
                fallbackModelId: fallbackModelCtrl.text.trim().isEmpty
                    ? null
                    : fallbackModelCtrl.text.trim(),
              );

              final current = await ref.read(routingSettingsServiceProvider).listRules();
              final next = List<RoutingRule>.from(current);
              if (index == null) {
                next.add(rule);
              } else {
                next[index] = rule;
              }

              await ref.read(routingSettingsServiceProvider).saveRules(next);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );

  complexity.dispose();
  modality.dispose();
  targetProviderId.dispose();
  targetModelCtrl.dispose();
  fallbackProviderId.dispose();
  fallbackModelCtrl.dispose();

  if (saved == true) {
    ref.invalidate(routingRulesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('路由规则已保存')),
      );
    }
  }
}
