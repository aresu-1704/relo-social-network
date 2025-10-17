// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String,
  content: json['content'] as Map<String, dynamic>,
  senderId: json['senderId'] as String,
  conversationId: json['conversationId'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  status: json['status'] as String,
  avatarUrl: json['avatarUrl'] as String?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'senderId': instance.senderId,
  'conversationId': instance.conversationId,
  'timestamp': instance.timestamp.toIso8601String(),
  'status': instance.status,
  'avatarUrl': instance.avatarUrl,
};
