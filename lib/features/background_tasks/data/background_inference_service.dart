import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:personal_ai_assistant/core/logger/app_logger.dart';
import 'package:personal_ai_assistant/core/logger/sanitized_logger.dart';
import 'package:personal_ai_assistant/features/background_tasks/domain/background_task_models.dart';

// Per coding standard 10.2: background inference ONLY uses local models.
// Cloud LLM calls are never made from background execution contexts.

sealed class InferenceResult {
  const InferenceResult();
}

class InferenceSuccess extends InferenceResult {
  const InferenceSuccess({
    required this.shouldNotify,
    required this.shouldSkip,
    this.notificationContent,
    required this.inferenceMethod,
    required this.inferenceTimeMs,
  });

  final bool shouldNotify;
  final bool shouldSkip;
  final String? notificationContent;

  // 'ollama' | 'rule_based'
  final String inferenceMethod;
  final int inferenceTimeMs;
}

class InferenceFailure extends InferenceResult {
  const InferenceFailure({required this.error});

  final Object error;
}

class BackgroundInferenceService {
  BackgroundInferenceService({
    http.Client? httpClient,
    AppLogger? logger,
  })  : _httpClient = httpClient ?? http.Client(),
        _logger = logger;

  static const _ollamaBaseUrl = 'http://localhost:11434';
  static const _preferredModel = 'llama3.2:3b';

  final http.Client _httpClient;
  final AppLogger? _logger;

  Future<bool> isLocalModelAvailable() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_ollamaBaseUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<InferenceResult> decide(
    BackgroundTask task, {
    String? contextData,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final available = await isLocalModelAvailable();
      if (!available) {
        stopwatch.stop();
        _logger?.info(
          'Ollama unavailable — using rule-based fallback',
          context: {'taskId': task.id},
        );
        return _ruleBased(task, stopwatch.elapsedMilliseconds);
      }

      final model = await _resolveModel();
      final prompt = _buildPrompt(task, contextData);

      final response = await _httpClient
          .post(
            Uri.parse('$_ollamaBaseUrl/api/generate'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'model': model,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      stopwatch.stop();

      if (response.statusCode != 200) {
        _logger?.warning(
          'Ollama returned ${response.statusCode} — using rule-based fallback',
          context: {'taskId': task.id},
        );
        return _ruleBased(task, stopwatch.elapsedMilliseconds);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (body['response'] as String? ?? '').toLowerCase();

      final shouldNotify =
          text.contains('yes') || text.contains('notify') || text.contains('true');
      final rawSkip =
          text.contains('skip') || text.contains('no') || text.contains('false');

      _logger?.info(
        'Ollama inference complete',
        context: {
          'taskId': task.id,
          'model': model,
          'shouldNotify': shouldNotify.toString(),
          'elapsedMs': stopwatch.elapsedMilliseconds.toString(),
        },
      );

      return InferenceSuccess(
        shouldNotify: shouldNotify,
        shouldSkip: rawSkip && !shouldNotify,
        notificationContent:
            shouldNotify ? task.action.notificationBody : null,
        inferenceMethod: 'ollama',
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, st) {
      stopwatch.stop();
      _logger?.error(
        'Ollama inference failed — using rule-based fallback',
        error: e,
        stackTrace: st,
        context: {'taskId': task.id},
      );
      return _ruleBased(task, stopwatch.elapsedMilliseconds);
    }
  }

  Future<String> _resolveModel() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$_ollamaBaseUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final models =
            (body['models'] as List<dynamic>?) ?? <dynamic>[];
        final hasPreferred = models.any(
          (m) =>
              (m as Map<String, dynamic>)['name'] == _preferredModel,
        );
        if (hasPreferred) return _preferredModel;
        if (models.isNotEmpty) {
          return (models.first as Map<String, dynamic>)['name'] as String;
        }
      }
    } catch (_) {}
    return _preferredModel;
  }

  String _buildPrompt(BackgroundTask task, String? contextData) {
    final buf = StringBuffer()
      ..writeln('You are a background task decision engine. Be concise.')
      ..writeln('Task label: ${task.label}');
    if (task.action.notificationBody != null) {
      buf.writeln('Description: ${task.action.notificationBody}');
    }
    if (contextData != null) {
      buf.writeln('Context: $contextData');
    }
    buf.writeln(
      'Should this task trigger a user notification right now? '
      'Reply with exactly "yes" or "no" and a brief one-sentence reason.',
    );
    return buf.toString();
  }

  InferenceSuccess _ruleBased(BackgroundTask task, int elapsedMs) {
    final shouldNotify = _ruleBasedShouldNotify(task);
    final shouldSkip = task.action.type == TaskActionType.silentLog;
    return InferenceSuccess(
      shouldNotify: shouldNotify,
      shouldSkip: shouldSkip,
      notificationContent:
          shouldNotify ? task.action.notificationBody : null,
      inferenceMethod: 'rule_based',
      inferenceTimeMs: elapsedMs,
    );
  }

  bool _ruleBasedShouldNotify(BackgroundTask task) {
    switch (task.action.type) {
      case TaskActionType.sendNotification:
        return true;
      case TaskActionType.silentLog:
        return false;
      case TaskActionType.executeSkill:
        final label = task.label.toLowerCase();
        return label.contains('提醒') ||
            label.contains('提示') ||
            label.contains('通知') ||
            label.contains('remind') ||
            label.contains('alert') ||
            label.contains('notify') ||
            label.contains('urgent') ||
            label.contains('重要');
    }
  }
}

final backgroundInferenceServiceProvider =
    Provider<BackgroundInferenceService>((ref) {
  return BackgroundInferenceService(
    logger: ref.watch(sanitizedLoggerProvider),
  );
});
