import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';

final managedProvidersProvider = FutureProvider<List<ManagedProviderConfig>>((
  ref,
) {
  return ref.watch(providerManagementServiceProvider).listConfigs();
});

final selectedProviderIdProvider = FutureProvider<String?>((ref) {
  return ref.watch(providerManagementServiceProvider).selectedProviderId();
});

class ProviderManagementScreen extends ConsumerWidget {
  const ProviderManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(managedProvidersProvider);
    final selectedAsync = ref.watch(selectedProviderIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('LLM 提供商管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加提供商'),
      ),
      body: providersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(child: Text('暂无提供商，请先添加'));
          }

          return selectedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载默认提供商失败：$e')),
            data: (selectedId) {
              return ListView.separated(
                itemCount: providers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = providers[index];
                  final isDefault = item.providerId == selectedId;
                  return ListTile(
                    title: Text(item.displayName),
                    subtitle: Text(
                      '${item.type.label} · ${item.defaultModel ?? '未设置模型'}',
                    ),
                    leading: Icon(
                      isDefault ? Icons.star : Icons.hub_outlined,
                      color: isDefault ? Colors.amber : null,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.enabled,
                          onChanged: (value) async {
                            final service = ref.read(
                              providerManagementServiceProvider,
                            );
                            await service.saveConfig(item.copyWith(enabled: value));
                            ref.invalidate(managedProvidersProvider);
                          },
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            switch (action) {
                              case 'default':
                                await ref
                                    .read(providerManagementServiceProvider)
                                    .setSelectedProvider(item.providerId);
                                ref.invalidate(selectedProviderIdProvider);
                                return;
                              case 'test':
                                await _testProvider(context, ref, item);
                                return;
                              case 'edit':
                                await _openEditor(
                                  context,
                                  ref,
                                  existing: item,
                                );
                                return;
                              case 'delete':
                                await ref
                                    .read(providerManagementServiceProvider)
                                    .deleteConfig(item.providerId);
                                ref.invalidate(managedProvidersProvider);
                                ref.invalidate(selectedProviderIdProvider);
                                return;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'default',
                              child: Text('设为默认'),
                            ),
                            PopupMenuItem(value: 'test', child: Text('测试连通性')),
                            PopupMenuItem(value: 'edit', child: Text('编辑')),
                            PopupMenuItem(value: 'delete', child: Text('删除')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _testProvider(
    BuildContext context,
    WidgetRef ref,
    ManagedProviderConfig item,
  ) async {
    final result = await ref
        .read(providerManagementServiceProvider)
        .testConfig(item);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '测试通过${result.models.isNotEmpty ? '（${result.models.length} 个模型）' : ''}'
              : '测试失败：${result.message ?? '未知错误'}',
        ),
      ),
    );
  }
}

Future<void> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  ManagedProviderConfig? existing,
}) async {
  final type = ValueNotifier<ManagedProviderType>(
    existing?.type ?? ManagedProviderType.openAiCompatible,
  );
  final providerIdCtrl = TextEditingController(
    text: existing?.providerId ?? '',
  );
  final displayNameCtrl = TextEditingController(
    text: existing?.displayName ?? '',
  );
  final baseUrlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
  final modelCtrl = TextEditingController(text: existing?.defaultModel ?? '');
  final apiKeyCtrl = TextEditingController();
  final availableModels = ValueNotifier<List<String>>(const []);
  final selectedModel = ValueNotifier<String?>(existing?.defaultModel);

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? '添加提供商' : '编辑提供商'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<ManagedProviderType>(
                  valueListenable: type,
                  builder: (context, value, _) {
                    return DropdownButtonFormField<ManagedProviderType>(
                      initialValue: value,
                      decoration: const InputDecoration(labelText: '提供商类型'),
                      items: ManagedProviderType.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: existing == null
                          ? (next) {
                              if (next != null) type.value = next;
                            }
                          : null,
                    );
                  },
                ),
                TextField(
                  controller: providerIdCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'Provider ID'),
                ),
                TextField(
                  controller: displayNameCtrl,
                  decoration: const InputDecoration(labelText: '显示名称'),
                ),
                TextField(
                  controller: baseUrlCtrl,
                  decoration: const InputDecoration(labelText: 'Base URL（可选）'),
                ),
                ValueListenableBuilder<List<String>>(
                  valueListenable: availableModels,
                  builder: (context, models, _) {
                    if (models.isNotEmpty) {
                      final selected = selectedModel.value;
                      final effectiveValue = models.contains(selected)
                          ? selected
                          : models.first;

                      if (selectedModel.value != effectiveValue) {
                        selectedModel.value = effectiveValue;
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: effectiveValue,
                        decoration: InputDecoration(
                          labelText: '默认模型（已获取 ${models.length} 个）',
                        ),
                        items: models
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          selectedModel.value = value;
                        },
                      );
                    }

                    return TextField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(labelText: '默认模型（可选）'),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<String>>(
                  valueListenable: availableModels,
                  builder: (context, models, _) {
                    if (models.isEmpty) {
                      return const Text(
                        '点击“保存并测试”后将自动拉取模型列表，可下拉选择默认模型。',
                        style: TextStyle(fontSize: 12),
                      );
                    }
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '已拉取模型：${models.take(8).join('、')}${models.length > 8 ? '…' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<ManagedProviderType>(
                  valueListenable: type,
                  builder: (context, value, _) {
                    final requiresKey = value != ManagedProviderType.ollama;
                    if (!requiresKey) return const SizedBox.shrink();
                    return TextField(
                      controller: apiKeyCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: existing == null ? 'API Key' : 'API Key（留空则沿用）',
                      ),
                    );
                  },
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
              final providerId = providerIdCtrl.text.trim();
              final displayName = displayNameCtrl.text.trim();

              if (providerId.isEmpty || displayName.isEmpty) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Provider ID 与显示名称不能为空')),
                );
                return;
              }

              final modelFromUi = availableModels.value.isNotEmpty
                  ? selectedModel.value
                  : modelCtrl.text.trim().isEmpty
                        ? null
                        : modelCtrl.text.trim();

              final config = ManagedProviderConfig(
                providerId: providerId,
                type: type.value,
                displayName: displayName,
                baseUrl: baseUrlCtrl.text.trim().isEmpty
                    ? null
                    : baseUrlCtrl.text.trim(),
                defaultModel: modelFromUi,
                enabled: existing?.enabled ?? true,
              );

              final service = ref.read(providerManagementServiceProvider);
              final testResult = await service.testConfig(
                config,
                apiKey: apiKeyCtrl.text.trim().isEmpty
                    ? null
                    : apiKeyCtrl.text.trim(),
              );

              if (!testResult.success) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('测试失败：${testResult.message ?? '未知错误'}')),
                );
                return;
              }

              if (testResult.models.isNotEmpty && availableModels.value.isEmpty) {
                availableModels.value = testResult.models;
                final existingSelection = modelFromUi;
                selectedModel.value =
                    (existingSelection != null &&
                        testResult.models.contains(existingSelection))
                    ? existingSelection
                    : testResult.models.first;

                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('已获取模型列表，请选择默认模型后再次点击保存并测试')),
                );
                return;
              }

              await service.saveConfig(
                config.copyWith(defaultModel: selectedModel.value ?? config.defaultModel),
                apiKey: apiKeyCtrl.text.trim().isEmpty
                    ? null
                    : apiKeyCtrl.text.trim(),
              );

              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存并测试'),
          ),
        ],
      );
    },
  );

  type.dispose();
  providerIdCtrl.dispose();
  displayNameCtrl.dispose();
  baseUrlCtrl.dispose();
  modelCtrl.dispose();
  apiKeyCtrl.dispose();
  availableModels.dispose();
  selectedModel.dispose();

  if (saved == true) {
    ref.invalidate(managedProvidersProvider);
    ref.invalidate(selectedProviderIdProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提供商已保存')));
    }
  }
}
