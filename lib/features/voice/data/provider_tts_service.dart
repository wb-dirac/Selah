import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_health_check_service.dart';

class ProviderTtsService {
  ProviderTtsService({
    required ProviderManagementService providerManagementService,
    required ProviderApiKeyStore keyStore,
    required SecureHttpClient httpClient,
    AudioPlayer? player,
  }) : _providerManagementService = providerManagementService,
       _keyStore = keyStore,
       _httpClient = httpClient,
       _player = player ?? AudioPlayer();

  final ProviderManagementService _providerManagementService;
  final ProviderApiKeyStore _keyStore;
  final SecureHttpClient _httpClient;
  final AudioPlayer _player;

  Future<bool> speakText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    final selected = await _providerManagementService.selectedOrFirstEnabled();
    if (selected == null || !selected.enabled) return false;

    switch (selected.type) {
      case ManagedProviderType.openAiCompatible:
        return _speakViaOpenAiCompatible(selected, normalized);
      case ManagedProviderType.anthropic:
      case ManagedProviderType.gemini:
      case ManagedProviderType.ollama:
        return false;
    }
  }

  Future<bool> _speakViaOpenAiCompatible(
    ManagedProviderConfig config,
    String text,
  ) async {
    final apiKey = await _keyStore.read(providerId: config.providerId);
    if (apiKey == null || apiKey.trim().isEmpty) {
      return false;
    }

    final baseUrl = Uri.parse(
      config.baseUrl?.trim().isNotEmpty == true
          ? config.baseUrl!.trim()
          : 'https://api.openai.com/v1',
    );
    final model = _resolveTtsModel(config.defaultModel);

    final response = await _httpClient.post(
      baseUrl.resolve('audio/speech'),
      headers: {
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'voice': 'alloy',
        'input': text,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}${Platform.pathSeparator}provider_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';

    final file = File(path);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    try {
      await _player.setFilePath(path);
      await _player.play();
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
      return true;
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _resolveTtsModel(String? configuredModel) {
    final model = (configuredModel ?? '').trim();
    if (model.contains('tts')) {
      return model;
    }
    return 'gpt-4o-mini-tts';
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

final providerTtsServiceProvider = Provider<ProviderTtsService>((ref) {
  final service = ProviderTtsService(
    providerManagementService: ref.watch(providerManagementServiceProvider),
    keyStore: ref.watch(providerApiKeyStoreProvider),
    httpClient: ref.watch(secureHttpClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
