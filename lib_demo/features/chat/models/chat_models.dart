enum MessageType { text, image, file }

/// Preview of a DM conversation shown in the inbox list.
class DmConversation {
  const DmConversation({
    required this.roomId,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
    this.lastMessage,
    required this.unreadCount,
    this.lastActivityAt,
  });

  final String roomId;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastActivityAt;

  DmConversation copyWith({
    int? unreadCount,
    ChatMessage? lastMessage,
    DateTime? lastActivityAt,
  }) =>
      DmConversation(
        roomId: roomId,
        peerId: peerId,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      );
}

/// A single message in a DM room. Supports text, image, and file types.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.messageType,
    this.body,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMime,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String roomId;
  final String senderId;
  final MessageType messageType;
  final String? body;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMime;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatarUrl;

  bool get isText => messageType == MessageType.text;
  bool get isImage => messageType == MessageType.image;
  bool get isFile => messageType == MessageType.file;

  /// Short preview text for inbox conversation card.
  String get previewText => switch (messageType) {
        MessageType.text => body ?? '',
        MessageType.image => '📷 Hình ảnh',
        MessageType.file => '📎 ${attachmentName ?? 'Tệp đính kèm'}',
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final typeStr = map['message_type'] as String? ?? 'text';
    final messageType = switch (typeStr) {
      'image' => MessageType.image,
      'file' => MessageType.file,
      _ => MessageType.text,
    };

    final sender = map['sender'] as Map<String, dynamic>?;

    return ChatMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      senderId: map['sender_id'] as String? ?? '',
      messageType: messageType,
      body: map['body'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      attachmentName: map['attachment_name'] as String?,
      attachmentSize: map['attachment_size'] as int?,
      attachmentMime: map['attachment_mime'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      senderName: sender?['display_name'] as String?,
      senderAvatarUrl: sender?['avatar_url'] as String?,
    );
  }
}
