import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personal_ai_assistant/core/network/secure_http_client.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/provider_api_key_store.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_health_check_service.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/provider_management_service.dart';
import 'package:personal_ai_assistant/features/voice/data/sherpa_onnx_local_speech_service.dart';
import 'package:personal_ai_assistant/features/voice/data/voice_settings_service.dart';

class ProviderTtsService {
  ProviderTtsService({
    required ProviderManagementService providerManagementService,
    required ProviderApiKeyStore keyStore,
    required SecureHttpClient httpClient,
    required VoiceSettingsService voiceSettingsService,
    required SherpaOnnxLocalSpeechService sherpaOnnxLocalSpeechService,
    AudioPlayer? player,
  }) : _providerManagementService = providerManagementService,
       _keyStore = keyStore,
       _httpClient = httpClient,
       _voiceSettingsService = voiceSettingsService,
       _sherpaOnnxLocalSpeechService = sherpaOnnxLocalSpeechService,
       _player = player ?? AudioPlayer();

  final ProviderManagementService _providerManagementService;
  final ProviderApiKeyStore _keyStore;
  final SecureHttpClient _httpClient;
  final VoiceSettingsService _voiceSettingsService;
  final SherpaOnnxLocalSpeechService _sherpaOnnxLocalSpeechService;
  final AudioPlayer _player;

  Future<bool> speakText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    final settings = await _voiceSettingsService.load();

    if (settings.enableLocalTts) {
      final localResult = await _speakViaLocalSherpa(normalized);
      if (localResult) return true;
    }

    final selected = await _providerManagementService.selectedOrFirstEnabled();
    if (selected == null || !selected.enabled) return false;

    final targetProviderId = settings.preferredTtsProviderId ?? selected.providerId;
    final providerConfig = await _resolveProviderConfig(targetProviderId);
    if (providerConfig == null) return false;

    final preferredModel = settings.preferredTtsModel?.trim();

    switch (providerConfig.type) {
      case ManagedProviderType.openAiCompatible:
        return _speakViaOpenAiCompatible(
          providerConfig,
          normalized,
          modelOverride: preferredModel,
        );
      case ManagedProviderType.gemini:
        return _speakViaGemini(
          providerConfig,
          normalized,
          modelOverride: preferredModel,
        );
      case ManagedProviderType.anthropic:
        return _speakViaAnthropicAdapted(
          providerConfig,
          normalized,
          modelOverride: preferredModel,
        );
      case ManagedProviderType.ollama:
        final fallback = await _resolveFirstTtsCapableProvider(
          excludedProviderId: providerConfig.providerId,
        );
        if (fallback != null) {
          if (fallback.type == ManagedProviderType.openAiCompatible) {
            final ok = await _speakViaOpenAiCompatible(
              fallback,
              normalized,
              modelOverride: preferredModel,
            );
            if (ok) return true;
          }
          if (fallback.type == ManagedProviderType.gemini) {
            final ok = await _speakViaGemini(
              fallback,
              normalized,
              modelOverride: preferredModel,
            );
            if (ok) return true;
          }
        }
        return _speakViaLocalSherpa(normalized);
    }
  }

  Future<ManagedProviderConfig?> _resolveProviderConfig(String providerId) async {
    final configs = await _providerManagementService.listConfigs();
    for (final config in configs) {
      if (config.providerId == providerId && config.enabled) {
        return config;
      }
    }
    return null;
  }

  Future<ManagedProviderConfig?> _resolveFirstTtsCapableProvider({
    String? excludedProviderId,
  }) async {
    final configs = await _providerManagementService.listConfigs();
    for (final config in configs) {
      if (!config.enabled) continue;
      if (config.providerId == excludedProviderId) continue;
      if (config.type == ManagedProviderType.openAiCompatible ||
          config.type == ManagedProviderType.gemini) {
        return config;
      }
    }
    return null;
  }

  Future<bool> _speakViaOpenAiCompatible(
    ManagedProviderConfig config,
    String text, {
    String? modelOverride,
  }) async {
    final apiKey = await _keyStore.read(providerId: config.providerId);
    if (apiKey == null || apiKey.trim().isEmpty) return false;

    final baseUrl = Uri.parse(
      config.baseUrl?.trim().isNotEmpty == true
          ? config.baseUrl!.trim()
          : 'https://api.openai.com/v1',
    );
    final model = _resolveOpenAiTtsModel(modelOverride ?? config.defaultModel);

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
    if (response.statusCode < 200 || response.statusCode >= 300) return false;

    return _playBytesAsTempFile(response.bodyBytes, extension: 'mp3');
  }

  Future<bool> _speakViaGemini(
    ManagedProviderConfig config,
    String text, {
    String? modelOverride,
  }) async {
    final apiKey = await _keyStore.read(providerId: config.providerId);
    if (apiKey == null || apiKey.trim().isEmpty) return false;

    final baseUrl = Uri.parse(
      config.baseUrl?.trim().isNotEmpty == true
          ? config.baseUrl!.trim()
          : 'https://generativelanguage.googleapis.com',
    );
    final model = _resolveGeminiTtsModel(modelOverride ?? config.defaultModel);

    final normalizedBase = baseUrl.toString().endsWith('/')
        ? baseUrl
        : Uri.parse('${baseUrl.toString()}/');
    final endpoint = normalizedBase.resolve('v1beta/models/$model:generateContent');

    final response = await _httpClient.post(
      endpoint,
      headers: {
        'x-goog-api-key': apiKey.trim(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = payload['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) return false;
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];

    for (final part in parts.whereType<Map<String, dynamic>>()) {
      final inlineData = part['inlineData'] as Map<String, dynamic>?;
      if (inlineData == null) continue;
      final data = inlineData['data'] as String?;
      if (data == null || data.trim().isEmpty) continue;
      final mimeType = (inlineData['mimeType'] as String?) ?? 'audio/wav';
      final bytes = base64Decode(data);
      final ext = mimeType.contains('mp3')
          ? 'mp3'
          : mimeType.contains('ogg')
              ? 'ogg'
              : 'wav';
      return _playBytesAsTempFile(bytes, extension: ext);
    }

    return false;
  }

  Future<bool> _speakViaAnthropicAdapted(
    ManagedProviderConfig config,
    String text, {
    String? modelOverride,
  }) async {
    final fallback = await _resolveFirstTtsCapableProvider(
      excludedProviderId: config.providerId,
    );
    if (fallback != null) {
      if (fallback.type == ManagedProviderType.openAiCompatible) {
        final ok = await _speakViaOpenAiCompatible(
          fallback,
          text,
          modelOverride: modelOverride,
        );
        if (ok) return true;
      }
      if (fallback.type == ManagedProviderType.gemini) {
        final ok = await _speakViaGemini(
          fallback,
          text,
          modelOverride: modelOverride,
        );
        if (ok) return true;
      }
    }
    return _speakViaLocalSherpa(text);
  }

  Future<bool> _speakViaLocalSherpa(String text) async {
    final outFile = await _sherpaOnnxLocalSpeechService.synthesizeToFile(text);
    if (outFile == null) return false;

    try {
      await _player.setFilePath(outFile.path);
      await _player.play();
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
      return true;
    } finally {
      if (await outFile.exists()) {
        await outFile.delete();
      }
    }
  }

  String _resolveOpenAiTtsModel(String? configuredModel) {
    final model = (configuredModel ?? '').trim();
    if (model.contains('tts')) return model;
    return 'gpt-4o-mini-tts';
  }

  String _resolveGeminiTtsModel(String? configuredModel) {
    final model = (configuredModel ?? '').trim();
    if (model.contains('tts')) return model;
    return 'gemini-2.5-flash-preview-tts';
  }

  Future<bool> _playBytesAsTempFile(
    Uint8List bytes, {
    required String extension,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}${Platform.pathSeparator}provider_tts_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

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
    voiceSettingsService: ref.watch(voiceSettingsServiceProvider),
    sherpaOnnxLocalSpeechService: ref.watch(sherpaOnnxLocalSpeechServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
