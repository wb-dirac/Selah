import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/datasources/token_usage_local_datasource.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_chunk.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/token_usage_record.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/token_usage_service.dart';

class _FakeTokenUsageDataSource implements TokenUsageLocalDataSource {
  final List<TokenUsageRecord> records = <TokenUsageRecord>[];
  MonthlyTokenUsage monthly = const MonthlyTokenUsage(
    providerId: 'openai',
    month: DateTime(2026, 3),
    promptTokens: 0,
    completionTokens: 0,
  );

  @override
  Future<MonthlyTokenUsage> getMonthlyUsage({
    required String providerId,
    required DateTime month,
  }) async {
    return monthly;
  }

  @override
  Future<void> insert(TokenUsageRecord record) async {
    records.add(record);
  }
}

void main() {
  group('TokenUsageService', () {
    test('records usage when chunk has token data', () async {
      final dataSource = _FakeTokenUsageDataSource();
      final service = TokenUsageService(dataSource);

      await service.recordFromChunk(
        providerId: 'openai',
        modelId: 'gpt-4o',
        chunk: const ChatChunk(
          textDelta: 'ok',
          inputTokens: 10,
          outputTokens: 20,
        ),
      );

      expect(dataSource.records, hasLength(1));
      expect(dataSource.records.first.totalTokens, equals(30));
    });

    test('does not record when token fields are absent', () async {
      final dataSource = _FakeTokenUsageDataSource();
      final service = TokenUsageService(dataSource);

      await service.recordFromChunk(
        providerId: 'openai',
        modelId: 'gpt-4o',
        chunk: const ChatChunk(textDelta: 'ok'),
      );

      expect(dataSource.records, isEmpty);
    });

    test('returns threshold notification decision', () {
      final dataSource = _FakeTokenUsageDataSource();
      final service = TokenUsageService(dataSource);

      const usage = MonthlyTokenUsage(
        providerId: 'openai',
        month: DateTime(2026, 3),
        promptTokens: 600,
        completionTokens: 500,
      );

      expect(
        service.shouldNotifyThreshold(usage: usage, monthlyThreshold: 1000),
        isTrue,
      );
      expect(
        service.shouldNotifyThreshold(usage: usage, monthlyThreshold: 2000),
        isFalse,
      );
    });
  });
}
