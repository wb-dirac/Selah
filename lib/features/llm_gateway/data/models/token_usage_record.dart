class TokenUsageRecord {
  const TokenUsageRecord({
    required this.providerId,
    required this.modelId,
    required this.promptTokens,
    required this.completionTokens,
    required this.createdAt,
  });

  final String providerId;
  final String modelId;
  final int promptTokens;
  final int completionTokens;
  final DateTime createdAt;

  int get totalTokens => promptTokens + completionTokens;

  Map<String, Object?> toMap() {
    return {
      'provider_id': providerId,
      'model_id': modelId,
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TokenUsageRecord.fromMap(Map<String, Object?> map) {
    return TokenUsageRecord(
      providerId: map['provider_id']! as String,
      modelId: map['model_id']! as String,
      promptTokens: map['prompt_tokens']! as int,
      completionTokens: map['completion_tokens']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }
}

class MonthlyTokenUsage {
  const MonthlyTokenUsage({
    required this.providerId,
    required this.month,
    required this.promptTokens,
    required this.completionTokens,
  });

  final String providerId;
  final DateTime month;
  final int promptTokens;
  final int completionTokens;

  int get totalTokens => promptTokens + completionTokens;
}