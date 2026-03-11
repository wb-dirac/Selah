import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/voice/data/sherpa_onnx_local_speech_service.dart';
import 'package:personal_ai_assistant/features/voice/data/sherpa_onnx_model_download_service.dart';
import 'package:personal_ai_assistant/features/voice/data/voice_settings_service.dart';

final voiceSettingsProvidersProvider =
    FutureProvider<List<ManagedProviderConfig>>((ref) {
      return ref.watch(providerManagementServiceProvider).listConfigs();
    });

final sherpaLocalTtsReadyProvider = FutureProvider<bool>((ref) {
  return ref
      .watch(sherpaOnnxLocalSpeechServiceProvider)
      .isLocalTtsReady();
});

final sherpaLocalSttReadyProvider = FutureProvider<bool>((ref) {
  return ref
      .watch(sherpaOnnxLocalSpeechServiceProvider)
      .isLocalSttReady();
});

class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(voiceSettingsProvider);
    final providersAsync = ref.watch(voiceSettingsProvidersProvider);
    final ttsReadyAsync = ref.watch(sherpaLocalTtsReadyProvider);
    final sttReadyAsync = ref.watch(sherpaLocalSttReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('语音设置')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载语音设置失败：$error')),
        data: (settings) {
          final providers = providersAsync.asData?.value ?? const <ManagedProviderConfig>[];
          final ttsReady = ttsReadyAsync.asData?.value ?? false;
          final sttReady = sttReadyAsync.asData?.value ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.autoPlayVoiceReply,
                      title: const Text('语音输入后自动播报 AI 回复'),
                      subtitle: const Text('仅在本轮输入为语音消息时生效'),
                      onChanged: (value) async {
                        await _save(
                          ref,
                          settings.copyWith(autoPlayVoiceReply: value),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('TTS 供应商'),
                      subtitle: Text(
                        settings.preferredTtsProviderId == null
                            ? '跟随当前对话模型供应商'
                            : _providerLabel(settings.preferredTtsProviderId!, providers),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickTtsProvider(context, ref, settings, providers),
                    ),
                    ListTile(
                      title: const Text('TTS 模型（可选）'),
                      subtitle: Text(settings.preferredTtsModel ?? '未设置（使用服务默认）'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editTtsModel(context, ref, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: settings.enableLocalTts,
                      title: const Text('启用本地 TTS（Sherpa-ONNX）'),
                      subtitle: Text(ttsReady ? '模型已就绪' : '模型未下载'),
                      onChanged: (value) async {
                        await _save(ref, settings.copyWith(enableLocalTts: value));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('下载本地 TTS 模型'),
                      subtitle: const Text('按需下载到本机，下载后可离线合成'),
                      onTap: () => _downloadModel(
                        context,
                        ref,
                        SherpaModelKind.tts,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.enableLocalStt,
                      title: const Text('启用本地 STT（Sherpa-ONNX）'),
                      subtitle: Text(sttReady ? '模型已就绪' : '模型未下载'),
                      onChanged: (value) async {
                        await _save(ref, settings.copyWith(enableLocalStt: value));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('下载本地 STT 模型'),
                      subtitle: const Text('按需下载到本机，下载后可离线转写'),
                      onTap: () => _downloadModel(
                        context,
                        ref,
                        SherpaModelKind.stt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '说明：Anthropic 当前无原生 TTS 接口。若当前会话是 Anthropic，系统将按语音设置中的 TTS 供应商优先级回退到可用的 TTS 供应商或本地 Sherpa。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(WidgetRef ref, VoiceSettings next) async {
    await ref.read(voiceSettingsServiceProvider).save(next);
    ref.invalidate(voiceSettingsProvider);
  }

  Future<void> _downloadModel(
    BuildContext context,
    WidgetRef ref,
    SherpaModelKind kind,
  ) async {
    final label = kind == SherpaModelKind.tts ? 'TTS' : 'STT';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开始下载 $label 模型...')),
    );
    try {
      await ref
          .read(sherpaOnnxModelDownloadServiceProvider)
          .downloadModel(kind);
      ref.invalidate(sherpaLocalTtsReadyProvider);
      ref.invalidate(sherpaLocalSttReadyProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 模型下载完成')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label 模型下载失败：$error')),
      );
    }
  }

  Future<void> _pickTtsProvider(
    BuildContext context,
    WidgetRef ref,
    VoiceSettings settings,
    List<ManagedProviderConfig> providers,
  ) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (dialogContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('跟随当前对话模型供应商'),
                trailing: settings.preferredTtsProviderId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(dialogContext).pop(null),
              ),
              ...providers
                  .where((p) => p.enabled)
                  .map(
                    (provider) => ListTile(
                      title: Text(provider.displayName),
                      subtitle: Text(provider.providerId),
                      trailing: settings.preferredTtsProviderId == provider.providerId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.of(dialogContext).pop(provider.providerId),
                    ),
                  ),
            ],
          ),
        );
      },
    );

    if (selected == settings.preferredTtsProviderId) return;
    await _save(
      ref,
      settings.copyWith(
        preferredTtsProviderId: selected,
        clearPreferredTtsProviderId: selected == null,
      ),
    );
  }

  Future<void> _editTtsModel(
    BuildContext context,
    WidgetRef ref,
    VoiceSettings settings,
  ) async {
    final ctrl = TextEditingController(text: settings.preferredTtsModel ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('设置 TTS 模型'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: '模型 ID（留空使用默认）',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      ctrl.dispose();
      return;
    }

    final value = ctrl.text.trim();
    ctrl.dispose();
    await _save(
      ref,
      settings.copyWith(
        preferredTtsModel: value,
        clearPreferredTtsModel: value.isEmpty,
      ),
    );
  }

  String _providerLabel(String providerId, List<ManagedProviderConfig> providers) {
    for (final provider in providers) {
      if (provider.providerId == providerId) {
        return '${provider.displayName} (${provider.providerId})';
      }
    }
    return providerId;
  }
}
