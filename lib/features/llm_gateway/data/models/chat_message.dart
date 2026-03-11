import 'dart:typed_data';

import 'package:personal_ai_assistant/features/llm_gateway/data/models/tool_spec.dart';

enum ChatRole { system, user, assistant, tool }

/// An image attached to a [ChatMessage] for multimodal LLM input.
///
/// Stores raw bytes and MIME type so that gateway implementations can
/// encode it however the upstream provider requires (base64, URL, etc.).
class ChatImage {
  const ChatImage({required this.bytes, required this.mimeType});

  /// Raw image bytes.
  final Uint8List bytes;

  /// MIME type, e.g. 'image/jpeg', 'image/png'.
  final String mimeType;
}

/// An audio clip attached to a [ChatMessage] for multimodal LLM input.
class ChatAudio {
  const ChatAudio({required this.bytes, required this.mimeType});

  /// Raw audio bytes.
  final Uint8List bytes;

  /// MIME type, e.g. 'audio/m4a', 'audio/wav'.
  final String mimeType;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.images,
    this.audios,
    this.toolCallId,
    this.toolCalls,
  });

  final ChatRole role;
  final String content;

  /// For [ChatRole.tool] messages: the name of the tool that was called.
  /// For Gemini function responses: required to identify the function.
  final String? name;

  /// Optional images for multimodal input (vision models).
  /// Only meaningful for [ChatRole.user] messages.
  final List<ChatImage>? images;

  /// Optional audio clips for multimodal input.
  /// Only meaningful for [ChatRole.user] messages.
  final List<ChatAudio>? audios;

  /// For [ChatRole.tool] messages: the provider-issued call ID to link
  /// this result back to the originating [ToolCallRequest].
  final String? toolCallId;

  /// For [ChatRole.assistant] messages: tool calls requested by the LLM.
  final List<ToolCallRequest>? toolCalls;

  /// Whether this message contains image content.
  bool get hasImages => images != null && images!.isNotEmpty;

  /// Whether this message contains audio content.
  bool get hasAudios => audios != null && audios!.isNotEmpty;

  /// Whether this assistant message contains tool call requests.
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}
