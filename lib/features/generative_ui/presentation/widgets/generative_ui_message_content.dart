import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/conversation/presentation/widgets/markdown_message_content.dart';
import 'package:personal_ai_assistant/features/generative_ui/presentation/ui_component_registry.dart';

class GenerativeUiMessageContent extends ConsumerWidget {
  const GenerativeUiMessageContent({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extracted = _extractPayload(content);
    if (extracted == null) {
      return MarkdownMessageContent(content: content);
    }

    final registry = ref.watch(uiComponentRegistryProvider);
    final component = registry.parse(extracted.payload);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (extracted.leadingMarkdown.trim().isNotEmpty)
          MarkdownMessageContent(content: extracted.leadingMarkdown.trim()),
        registry.build(context, component),
        if (extracted.trailingMarkdown.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MarkdownMessageContent(content: extracted.trailingMarkdown.trim()),
          ),
      ],
    );
  }
}

class _ExtractedUiPayload {
  const _ExtractedUiPayload({
    required this.leadingMarkdown,
    required this.payload,
    required this.trailingMarkdown,
  });

  final String leadingMarkdown;
  final Map<String, dynamic> payload;
  final String trailingMarkdown;
}

_ExtractedUiPayload? _extractPayload(String content) {
  final trimmed = content.trim();
  final directPayload = _tryDecodeJsonObject(trimmed);
  if (directPayload != null) {
    return _ExtractedUiPayload(
      leadingMarkdown: '',
      payload: directPayload,
      trailingMarkdown: '',
    );
  }

  final fencedMatch = RegExp(
    r'```json\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  ).firstMatch(content);
  if (fencedMatch == null) {
    return null;
  }

  final fencedBody = fencedMatch.group(1);
  if (fencedBody == null) {
    return null;
  }
  final payload = _tryDecodeJsonObject(fencedBody.trim());
  if (payload == null) {
    return null;
  }

  return _ExtractedUiPayload(
    leadingMarkdown: content.substring(0, fencedMatch.start),
    payload: payload,
    trailingMarkdown: content.substring(fencedMatch.end),
  );
}

Map<String, dynamic>? _tryDecodeJsonObject(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  } catch (_) {
    return null;
  }
}
