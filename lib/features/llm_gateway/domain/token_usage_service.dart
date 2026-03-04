import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/datasources/token_usage_local_datasource.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/token_usage_record.dart';

class TokenUsageService {
  const TokenUsageService(this._localDataSource);

  final TokenUsageLocalDataSource _localDataSource;

  Future<void> recordFromChunk({
    required String providerId,
    required String modelId,
    required ChatChunk chunk,
    DateTime? timestamp,
  }) async {
    final promptTokens = chunk.inputTokens;
    final completionTokens = chunk.outputTokens;
    if (promptTokens == null || completionTokens == null) {
      return;
    }

    await _localDataSource.insert(
      TokenUsageRecord(
        providerId: providerId,
        modelId: modelId,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        createdAt: timestamp ?? DateTime.now(),
      ),
    );
  }

  Future<MonthlyTokenUsage> getMonthlyUsage({
    required String providerId,
    required DateTime month,
  }) {
    return _localDataSource.getMonthlyUsage(
      providerId: providerId,
      month: month,
    );
  }

  bool shouldNotifyThreshold({
    required MonthlyTokenUsage usage,
    required int monthlyThreshold,
  }) {
    if (monthlyThreshold <= 0) {
      return false;
    }
    return usage.totalTokens >= monthlyThreshold;
  }
}

final tokenUsageServiceProvider = Provider<TokenUsageService>((ref) {
  final localDataSource = ref.watch(tokenUsageLocalDataSourceProvider);
  return TokenUsageService(localDataSource);
});