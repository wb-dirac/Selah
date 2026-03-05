/// Lightweight token-count estimator for context window management.
///
/// Uses character-based heuristics since a full BPE tokeniser (e.g. tiktoken)
/// is not available in Dart.  The estimates are intentionally conservative
/// (overcount slightly) to avoid exceeding the model's context window.
///
/// Heuristic:
/// - English text: ~4 characters per token  (GPT-style)
/// - CJK text:     ~1.5 characters per token (each character is usually 1–2 tokens)
///
/// We walk the string once, classifying each codepoint, then compute a
/// weighted token count.
class TokenEstimator {
  const TokenEstimator._();

  /// Characters per token for Latin / punctuation / numbers.
  static const double _latinCharsPerToken = 4.0;

  /// Characters per token for CJK / fullwidth characters.
  static const double _cjkCharsPerToken = 1.5;

  /// Estimate the number of tokens in [text].
  static int estimate(String text) {
    if (text.isEmpty) return 0;

    int latinChars = 0;
    int cjkChars = 0;

    for (final codeUnit in text.runes) {
      if (_isCjk(codeUnit)) {
        cjkChars++;
      } else {
        latinChars++;
      }
    }

    final tokens =
        (latinChars / _latinCharsPerToken) + (cjkChars / _cjkCharsPerToken);
    // Ceiling to be conservative
    return tokens.ceil();
  }

  /// Estimate total tokens across a list of message contents.
  static int estimateMessages(List<String> contents) {
    int total = 0;
    for (final content in contents) {
      // Each message carries ~4 tokens of overhead (role, delimiters)
      total += estimate(content) + 4;
    }
    return total;
  }

  /// Returns `true` if the codepoint falls in a CJK range.
  static bool _isCjk(int cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) || // CJK Unified Ideographs
        (cp >= 0x3400 && cp <= 0x4DBF) || // Extension A
        (cp >= 0x20000 && cp <= 0x2A6DF) || // Extension B
        (cp >= 0x2A700 && cp <= 0x2B73F) || // Extension C
        (cp >= 0x2B740 && cp <= 0x2B81F) || // Extension D
        (cp >= 0xF900 && cp <= 0xFAFF) || // Compatibility Ideographs
        (cp >= 0x3000 && cp <= 0x303F) || // CJK Symbols and Punctuation
        (cp >= 0xFF00 && cp <= 0xFFEF) || // Fullwidth Forms
        (cp >= 0x3040 && cp <= 0x309F) || // Hiragana
        (cp >= 0x30A0 && cp <= 0x30FF) || // Katakana
        (cp >= 0xAC00 && cp <= 0xD7AF); // Hangul Syllables
  }
}
