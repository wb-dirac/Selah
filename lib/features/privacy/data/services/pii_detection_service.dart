import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PiiType {
  phoneNumber,
  identityNumber,
  bankCard,
}

extension PiiTypeX on PiiType {
  String get label {
    switch (this) {
      case PiiType.phoneNumber:
        return '手机号';
      case PiiType.identityNumber:
        return '身份证号';
      case PiiType.bankCard:
        return '银行卡号';
    }
  }
}

class PiiMatch {
  const PiiMatch({
    required this.type,
    required this.start,
    required this.end,
    required this.originalText,
    required this.maskedText,
  });

  final PiiType type;
  final int start;
  final int end;
  final String originalText;
  final String maskedText;
}

class PiiDetectionResult {
  const PiiDetectionResult({
    required this.originalText,
    required this.sanitizedText,
    required this.matches,
  });

  final String originalText;
  final String sanitizedText;
  final List<PiiMatch> matches;

  bool get hasPii => matches.isNotEmpty;
}

class PiiDetectionService {
  static final RegExp _phonePattern = RegExp(r'(?<!\d)(1[3-9]\d{9})(?!\d)');
  static final RegExp _identityPattern = RegExp(
    r'(?<![0-9Xx])(\d{17}[0-9Xx])(?![0-9Xx])',
  );
  static final RegExp _bankCardPattern = RegExp(
    r'(?<!\d)(\d(?:[ -]?\d){12,18}\d)(?!\d)',
  );

  PiiDetectionResult detect(String text) {
    final matches = <PiiMatch>[];

    _appendMatches(
      matches: matches,
      text: text,
      pattern: _phonePattern,
      type: PiiType.phoneNumber,
      mask: _maskPhoneNumber,
    );
    _appendMatches(
      matches: matches,
      text: text,
      pattern: _identityPattern,
      type: PiiType.identityNumber,
      mask: _maskIdentityNumber,
    );
    _appendMatches(
      matches: matches,
      text: text,
      pattern: _bankCardPattern,
      type: PiiType.bankCard,
      mask: _maskBankCard,
      predicate: (value) {
        final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
        return digitsOnly.length >= 13 && digitsOnly.length <= 19;
      },
    );

    matches.sort((left, right) => left.start.compareTo(right.start));

    var sanitized = text;
    for (final match in matches.reversed) {
      sanitized = sanitized.replaceRange(match.start, match.end, match.maskedText);
    }

    return PiiDetectionResult(
      originalText: text,
      sanitizedText: sanitized,
      matches: matches,
    );
  }

  void _appendMatches({
    required List<PiiMatch> matches,
    required String text,
    required RegExp pattern,
    required PiiType type,
    required String Function(String value) mask,
    bool Function(String value)? predicate,
  }) {
    for (final match in pattern.allMatches(text)) {
      final value = match.group(0);
      if (value == null || value.isEmpty) {
        continue;
      }
      if (predicate != null && !predicate(value)) {
        continue;
      }
      final start = match.start;
      final end = match.end;
      final isOverlapping = matches.any(
        (existing) => start < existing.end && end > existing.start,
      );
      if (isOverlapping) {
        continue;
      }
      matches.add(
        PiiMatch(
          type: type,
          start: start,
          end: end,
          originalText: value,
          maskedText: mask(value),
        ),
      );
    }
  }

  static String _maskPhoneNumber(String value) {
    if (value.length < 7) {
      return value;
    }
    return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  }

  static String _maskIdentityNumber(String value) {
    if (value.length < 8) {
      return value;
    }
    return '${value.substring(0, 3)}***********${value.substring(value.length - 4)}';
  }

  static String _maskBankCard(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 8) {
      return value;
    }
    return '${digitsOnly.substring(0, 4)} **** **** ${digitsOnly.substring(digitsOnly.length - 4)}';
  }
}

final piiDetectionServiceProvider = Provider<PiiDetectionService>((ref) {
  return PiiDetectionService();
});
