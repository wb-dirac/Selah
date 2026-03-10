import 'package:personal_ai_assistant/features/a2a/domain/a2a_result.dart';

const int _kMaxPayloadSize = 512 * 1024;
const int _kMaxTextLength = 32 * 1024;

final RegExp _scriptPattern = RegExp(
  r'<\s*script[\s\S]*?>[\s\S]*?<\s*/\s*script\s*>',
  caseSensitive: false,
);

final RegExp _htmlTagPattern = RegExp(r'<[^>]+>', caseSensitive: false);

final RegExp _promptInjectionPattern = RegExp(
  r'ignore\s+(previous|all|prior)\s+instructions?|'
  r'system\s*:\s*(you are|act as|pretend)|'
  r'<\|im_start\|>|<\|im_end\|>|'
  r'\[INST\]|\[\/INST\]',
  caseSensitive: false,
);

class A2ASandboxProcessor {
  const A2ASandboxProcessor();

  A2ASandboxOutcome process(A2ATaskResult raw) {
    final payloadSize = _estimateSize(raw.rawPayload);
    if (payloadSize > _kMaxPayloadSize) {
      return A2ASandboxRejected(
        'A2A 响应超过最大允许大小 (${_kMaxPayloadSize ~/ 1024}KB)',
      );
    }

    final textRaw = _extractText(raw.rawPayload);

    if (_scriptPattern.hasMatch(textRaw)) {
      return A2ASandboxRejected('A2A 响应包含可执行脚本，已拒绝');
    }

    if (_promptInjectionPattern.hasMatch(textRaw)) {
      return A2ASandboxRejected('A2A 响应包含 prompt injection 特征，已拒绝');
    }

    final sanitized = _sanitize(textRaw);

    if (sanitized.length > _kMaxTextLength) {
      return A2ASandboxRejected(
        'A2A 响应文本超过最大允许长度 (${_kMaxTextLength ~/ 1024}KB)',
      );
    }

    final metadata = _extractSafeMetadata(raw.rawPayload);

    return A2ASandboxSuccess(
      SafeA2AResult(
        taskId: raw.taskId,
        agentUrl: raw.agentUrl,
        text: sanitized,
        processedAt: DateTime.now(),
        metadata: metadata,
      ),
    );
  }

  String _extractText(Map<String, dynamic> payload) {
    final text = payload['text'] ?? payload['result'] ?? payload['content'];
    if (text is String) return text;
    if (text != null) return text.toString();
    return payload.entries
        .where((e) => e.value is String)
        .map((e) => e.value as String)
        .join(' ');
  }

  String _sanitize(String raw) {
    return raw
        .replaceAll(_scriptPattern, '')
        .replaceAll(_htmlTagPattern, '');
  }

  Map<String, String> _extractSafeMetadata(Map<String, dynamic> payload) {
    final safe = <String, String>{};
    for (final entry in payload.entries) {
      if (entry.key == 'text' ||
          entry.key == 'result' ||
          entry.key == 'content') {
        continue;
      }
      final val = entry.value;
      if (val is String && val.length < 256 && !_scriptPattern.hasMatch(val)) {
        safe[entry.key] = val;
      } else if (val is num || val is bool) {
        safe[entry.key] = val.toString();
      }
    }
    return safe;
  }

  int _estimateSize(Map<String, dynamic> payload) {
    return payload.toString().length;
  }
}
