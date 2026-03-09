import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/outbound_privacy_guard_service.dart';
import 'package:personal_ai_assistant/features/privacy/data/services/pii_detection_service.dart';

Future<bool> showImageCloudPrivacyDialog({
  required BuildContext context,
  required String providerLabel,
  required int imageCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('图片将发送到云端模型'),
        content: Text(
          '当前即将把 $imageCount 张图片发送至 $providerLabel 进行多模态理解。\n\n发送前图片会先在本地执行 OCR，但原图仍会上传到云端模型。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续发送'),
          ),
        ],
      );
    },
  );
  return result == true;
}

enum OutboundPrivacyDecision {
  cancel,
  sendOriginal,
  sendSanitized,
}

Future<OutboundPrivacyDecision> showOutboundPrivacyReviewDialog({
  required BuildContext context,
  required String providerLabel,
  required bool isCloudProvider,
  required OutboundPrivacyReview review,
}) async {
  final hasSanitizedOption = review.sanitizedText != review.originalText;
  final result = await showDialog<OutboundPrivacyDecision>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(review.hasSensitiveData ? '检测到可能包含敏感信息' : '发送前确认'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '即将发送至: $providerLabel ${isCloudProvider ? '☁️' : '🔒'}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (review.aliases.isNotEmpty) ...<Widget>[
                  Text('联系人代号替换', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...review.aliases.map(
                    (entry) => Text('${entry.original} → ${entry.alias}'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (review.piiMatches.isNotEmpty) ...<Widget>[
                  Text('检测到以下敏感信息', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...review.piiMatches.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${item.type.label}  ${item.maskedText}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('消息预览', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      children: _buildHighlightedSpans(
                        review.aliasedText,
                        review.piiMatches,
                        theme,
                      ),
                    ),
                  ),
                ),
                if (hasSanitizedOption) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('脱敏后发送版本', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(review.sanitizedText),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(OutboundPrivacyDecision.cancel),
            child: const Text('取消'),
          ),
          if (hasSanitizedOption)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(OutboundPrivacyDecision.sendOriginal),
              child: const Text('发送原始内容'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              hasSanitizedOption
                  ? OutboundPrivacyDecision.sendSanitized
                  : OutboundPrivacyDecision.sendOriginal,
            ),
            child: Text(hasSanitizedOption ? '发送脱敏版本' : '发送'),
          ),
        ],
      );
    },
  );
  return result ?? OutboundPrivacyDecision.cancel;
}

List<InlineSpan> _buildHighlightedSpans(
  String text,
  List<PiiMatch> matches,
  ThemeData theme,
) {
  if (matches.isEmpty) {
    return <InlineSpan>[TextSpan(text: text)];
  }

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final item in matches) {
    if (item.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, item.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(item.start, item.end),
        style: TextStyle(
          backgroundColor: theme.colorScheme.errorContainer,
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    cursor = item.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}
