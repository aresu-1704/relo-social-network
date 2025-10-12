// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: (json['id'] as num).toInt(),
  content: json['content'] as String,
  senderId: json['senderId'] as String,
  receiverId: json['receiverId'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  status: json['status'] as String,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'content': instance.content,
  'senderId': instance.senderId,
  'receiverId': instance.receiverId,
  'timestamp': instance.timestamp.toIso8601String(),
  'status': instance.status,
};
