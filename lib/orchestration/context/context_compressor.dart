import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/llm_gateway/data/models/chat_message.dart';
import 'package:personal_ai_assistant/features/llm_gateway/domain/llm_gateway.dart';
import 'package:personal_ai_assistant/orchestration/context/token_estimator.dart';

/// Result of a context compression pass.
class ContextCompressionResult {
  const ContextCompressionResult({
    required this.messages,
    required this.wasCompressed,
    this.summaryText,
  });

  /// The (possibly compressed) message list ready to send to the LLM.
  final List<ChatMessage> messages;

  /// `true` if compression was applied in this pass.
  final bool wasCompressed;

  /// The generated summary text, if compression occurred.
  final String? summaryText;
}

/// Manages automatic context window compression.
///
/// When the total estimated token count of a conversation exceeds
/// [compressionThresholdRatio] of the model's context window, early
/// messages are replaced by an LLM-generated summary.
///
/// The summarisation prompt asks the LLM to produce a concise recap of the
/// removed messages. The summary is injected as a `system` message at the
/// start of the history, followed by a separator marker so the UI can
/// display "上下文已压缩".
class ContextCompressor {
  const ContextCompressor({
    this.compressionThresholdRatio = 0.8,
    this.targetRatio = 0.5,
  });

  /// Fraction of context window that triggers compression (spec: 80%).
  final double compressionThresholdRatio;

  /// After compression, aim to use at most this fraction of the window.
  final double targetRatio;

  /// System prompt used to ask the LLM to summarise earlier messages.
  static const _summarisePrompt =
      '请将以下对话内容压缩为简洁的摘要，保留关键信息和上下文。'
      '仅输出摘要内容，不要添加前缀或解释。';

  /// Checks whether [messages] exceed the context window threshold and,
  /// if so, compresses the early portion via an LLM-generated summary.
  ///
  /// [contextWindowTokens] is the model's total context size.
  /// [gateway] is used to generate the summary (if needed).
  ///
  /// Returns a [ContextCompressionResult] with the processed messages.
  /// If no compression is needed, the original messages are returned.
  Future<ContextCompressionResult> compressIfNeeded({
    required List<ChatMessage> messages,
    required int contextWindowTokens,
    required LlmGateway gateway,
  }) async {
    final contents = messages.map((m) => m.content).toList();
    final estimatedTokens = TokenEstimator.estimateMessages(contents);

    final threshold = (contextWindowTokens * compressionThresholdRatio).floor();

    if (estimatedTokens <= threshold) {
      return ContextCompressionResult(messages: messages, wasCompressed: false);
    }

    // Determine how many messages to compress (from the start).
    // Keep enough recent messages to stay under targetRatio.
    final targetTokens = (contextWindowTokens * targetRatio).floor();
    int keepFromIndex = messages.length;
    int keptTokens = 0;

    for (int i = messages.length - 1; i >= 0; i--) {
      final msgTokens = TokenEstimator.estimate(messages[i].content) + 4;
      if (keptTokens + msgTokens > targetTokens) {
        keepFromIndex = i + 1;
        break;
      }
      keptTokens += msgTokens;
      if (i == 0) keepFromIndex = 0;
    }

    // Need at least 1 message to compress
    if (keepFromIndex <= 1) {
      return ContextCompressionResult(messages: messages, wasCompressed: false);
    }

    final toCompress = messages.sublist(0, keepFromIndex);
    final toKeep = messages.sublist(keepFromIndex);

    // Generate summary of compressed messages
    final summaryText = await _generateSummary(toCompress, gateway);

    // Build new message list: summary (system) + kept messages
    final compressedMessages = <ChatMessage>[
      ChatMessage(role: ChatRole.system, content: '[上下文摘要] $summaryText'),
      ...toKeep,
    ];

    return ContextCompressionResult(
      messages: compressedMessages,
      wasCompressed: true,
      summaryText: summaryText,
    );
  }

  /// Asks the LLM to summarise the given messages.
  Future<String> _generateSummary(
    List<ChatMessage> messages,
    LlmGateway gateway,
  ) async {
    // Build a prompt that includes the conversation to summarise
    final conversationText = StringBuffer();
    for (final msg in messages) {
      final roleLabel = msg.role == ChatRole.user ? '用户' : '助理';
      conversationText.writeln('$roleLabel: ${msg.content}');
    }

    final summariseMessages = <ChatMessage>[
      ChatMessage(role: ChatRole.system, content: _summarisePrompt),
      ChatMessage(role: ChatRole.user, content: conversationText.toString()),
    ];

    final buffer = StringBuffer();
    await for (final chunk in gateway.chat(summariseMessages)) {
      buffer.write(chunk.textDelta);
    }
    return buffer.toString().trim();
  }
}

final contextCompressorProvider = Provider<ContextCompressor>((ref) {
  return const ContextCompressor();
});
