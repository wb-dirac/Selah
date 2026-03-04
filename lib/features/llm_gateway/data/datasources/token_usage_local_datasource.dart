import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/database/sqlcipher_database.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/token_usage_record.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

abstract class TokenUsageLocalDataSource {
  Future<void> insert(TokenUsageRecord record);

  Future<MonthlyTokenUsage> getMonthlyUsage({
    required String providerId,
    required DateTime month,
  });
}

class SqlTokenUsageLocalDataSource implements TokenUsageLocalDataSource {
  SqlTokenUsageLocalDataSource(this._database);

  final SqlCipherDatabase _database;

  @override
  Future<void> insert(TokenUsageRecord record) async {
    final db = await _database.open();
    await db.insert(
      'token_usage_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<MonthlyTokenUsage> getMonthlyUsage({
    required String providerId,
    required DateTime month,
  }) async {
    final db = await _database.open();
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);

    final result = await db.rawQuery(
      '''
SELECT
  COALESCE(SUM(prompt_tokens), 0) AS prompt_total,
  COALESCE(SUM(completion_tokens), 0) AS completion_total
FROM token_usage_records
WHERE provider_id = ?
  AND created_at >= ?
  AND created_at < ?
''',
      [
        providerId,
        monthStart.millisecondsSinceEpoch,
        monthEnd.millisecondsSinceEpoch,
      ],
    );

    final row = result.first;
    return MonthlyTokenUsage(
      providerId: providerId,
      month: monthStart,
      promptTokens: row['prompt_total'] as int? ?? 0,
      completionTokens: row['completion_total'] as int? ?? 0,
    );
  }
}

final tokenUsageLocalDataSourceProvider = Provider<TokenUsageLocalDataSource>(
  (ref) {
    final db = ref.watch(sqlCipherDatabaseProvider);
    return SqlTokenUsageLocalDataSource(db);
  },
);