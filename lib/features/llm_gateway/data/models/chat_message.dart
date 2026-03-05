import 'dart:typed_data';

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

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.images,
  });

  final ChatRole role;
  final String content;
  final String? name;

  /// Optional images for multimodal input (vision models).
  /// Only meaningful for [ChatRole.user] messages.
  final List<ChatImage>? images;

  /// Whether this message contains image content.
  bool get hasImages => images != null && images!.isNotEmpty;
}
