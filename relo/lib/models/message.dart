import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  final String id;
  final String content;
  final String senderId;
  final String conversationId;
  final DateTime timestamp;
  final String status; // pending, sent, failed
  final String? avatarUrl;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.conversationId,
    required this.timestamp,
    required this.status,
    this.avatarUrl,
  });

  /// ✅ Dành cho dữ liệu từ SQLite hoặc file JSON local
  factory Message.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    return Message(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      content: rawContent is Map
          ? rawContent['text'] ?? ''
          : rawContent?.toString() ?? '',
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
    return Message(
      id: json['_id']?.toString() ?? '',
      content: rawContent is Map ? rawContent['text'] ?? '' : rawContent ?? '',
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
    String? content,
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
