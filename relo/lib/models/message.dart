import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

enum MessageType { text, image, video, audio, unsupported }

@JsonSerializable()
class Message {
  final String id;
  final Map<String, dynamic> content;
  final String senderId;
  final String conversationId;
  final DateTime timestamp;
  final String status; // pending, sent, failed
  final String? avatarUrl;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final MessageType type;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.conversationId,
    required this.timestamp,
    required this.status,
    this.avatarUrl,
  }) : type = _mapContentType(content);

  static MessageType _mapContentType(Map<String, dynamic> content) {
    switch (content['type']) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      default:
        return MessageType.unsupported;
    }
  }

  String get textContent =>
      type == MessageType.text ? content['text'] ?? '' : '';

  String get url => content['url'] ?? '';
  String get fileName => content['fileName'] ?? '';

  /// ✅ Dành cho dữ liệu từ SQLite hoặc file JSON local
  factory Message.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    Map<String, dynamic> parsedContent;
    if (rawContent is String) {
      // For backward compatibility with old text-only messages
      parsedContent = {'type': 'text', 'text': rawContent};
    } else if (rawContent is Map<String, dynamic>) {
      parsedContent = rawContent;
    } else {
      parsedContent = {'type': 'unsupported'};
    }

    return Message(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      content: parsedContent,
      senderId: json['senderId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  /// ✅ Dành riêng cho dữ liệu từ backend API
  factory Message.fromServerJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    Map<String, dynamic> parsedContent;
    if (rawContent is Map<String, dynamic>) {
      parsedContent = rawContent;
    } else if (rawContent is String) {
      // Should not happen with new backend, but for safety
      parsedContent = {'type': 'text', 'text': rawContent};
    } else {
      parsedContent = {'type': 'unsupported'};
    }

    return Message(
      id: json['id']?.toString() ?? '',
      content: parsedContent,
      senderId: json['senderId'] ?? '',
      conversationId: json['conversationId'] ?? '',
      timestamp: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      status: 'sent',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  Message copyWith({
    String? id,
    Map<String, dynamic>? content,
    String? senderId,
    String? conversationId,
    DateTime? timestamp,
    String? status,
    String? avatarUrl,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      conversationId: conversationId ?? this.conversationId,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
