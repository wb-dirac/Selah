/// Represents a file attachment associated with a message.
///
/// Attachments are stored as local files; only metadata is persisted in the DB.
/// The [type] field distinguishes between image, document, and other media types.
class AttachmentEntity {
  const AttachmentEntity({
    required this.id,
    required this.messageId,
    required this.type,
    required this.filePath,
    required this.createdAt,
    this.mimeType,
    this.thumbnailPath,
    this.width,
    this.height,
    this.sizeBytes,
  });

  final String id;

  /// The message this attachment belongs to.
  final String messageId;

  /// Attachment type: 'image', 'document', 'audio', etc.
  final String type;

  /// Absolute path to the attachment file on the local filesystem.
  final String filePath;

  /// MIME type, e.g. 'image/jpeg', 'image/png'.
  final String? mimeType;

  /// Path to a smaller thumbnail for preview (images only).
  final String? thumbnailPath;

  /// Image dimensions, if applicable.
  final int? width;
  final int? height;

  /// File size in bytes.
  final int? sizeBytes;

  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'message_id': messageId,
      'type': type,
      'file_path': filePath,
      'mime_type': mimeType,
      'thumbnail_path': thumbnailPath,
      'width': width,
      'height': height,
      'size_bytes': sizeBytes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory AttachmentEntity.fromMap(Map<String, Object?> map) {
    return AttachmentEntity(
      id: map['id']! as String,
      messageId: map['message_id']! as String,
      type: map['type']! as String,
      filePath: map['file_path']! as String,
      mimeType: map['mime_type'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      sizeBytes: map['size_bytes'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }

  AttachmentEntity copyWith({
    String? messageId,
    String? type,
    String? filePath,
    String? mimeType,
    String? thumbnailPath,
    int? width,
    int? height,
    int? sizeBytes,
  }) {
    return AttachmentEntity(
      id: id,
      messageId: messageId ?? this.messageId,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt,
    );
  }
}
