import 'package:dio/dio.dart';
import 'package:relo/models/message.dart';
import 'message_database.dart';

class MessageService {
  final Dio _dio;

  MessageService(this._dio);

  /// Lấy danh sách các cuộc trò chuyện (có thể group hoặc cá nhân)
  Future<List<dynamic>> fetchConversations() async {
    try {
      final response = await _dio.get('messages/conversations');
      return response.data;
    } on DioException catch (e) {
      print('Failed to fetch conversations: $e');
      return [];
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  //Lấy danh sách tin nhắn trong một cuộc trò chuyện
  Future<List<Message>> getMessages(
    String conversationId, {
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        'messages/conversations/$conversationId/messages',
        queryParameters: {'offset': offset, 'limit': limit},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => Message.fromServerJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch messages: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  //Thêm hoặc tao cuộc trò chuyện
  Future<Map<String, dynamic>> getOrCreateConversation(
    List<String> participantIds,
    bool isGroup,
    String? name,
  ) async {
    try {
      final response = await _dio.post(
        'messages/conversations',
        data: {
          'participant_ids': participantIds,
          'is_group': isGroup,
          'name': name,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        'Failed to get or create conversation: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  // Gửi tin nhắn
  Future<Message> sendMessage(
    String conversationId,
    Map<String, dynamic> content,
    String senderId, {
    String? tempId,
  }) async {
    final tempMessage = Message(
      id: tempId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderId: senderId,
      conversationId: conversationId,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    await MessageDatabase.instance.create(tempMessage);

    try {
      FormData? formData;

      if (content['type'] == 'text') {
        formData = FormData.fromMap({
          'type': content['type'],
          'text': content['text'],
        });
      } else if (content['type'] == 'audio' || content['type'] == 'file') {
        formData = FormData.fromMap({
          'type': content['type'],
          'files': await MultipartFile.fromFile(content['path']),
        });
      } else if (content['type'] == 'media') {
        List<MultipartFile> files = [];
        for (var filePath in content['paths']) {
          files.add(await MultipartFile.fromFile(filePath));
        }
        formData = FormData.fromMap({'type': content['type'], 'files': files});
      }

      // Gửi form-data lên server
      final response = await _dio.post(
        'messages/conversations/$conversationId/messages',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/multipart/form-data'},
        ),
      );

      final sentMessage = Message.fromJson(response.data);

      // Create a new message with the final ID but with the original content
      final finalMessage = Message(
        id: sentMessage.id,
        content: tempMessage.content,
        senderId: tempMessage.senderId,
        conversationId: tempMessage.conversationId,
        timestamp: sentMessage.timestamp,
        status: 'sent',
        avatarUrl: tempMessage.avatarUrl,
      );

      // Delete the temporary message and insert the final one
      await MessageDatabase.instance.delete(tempMessage.id);
      await MessageDatabase.instance.create(finalMessage);

      return finalMessage;
    } catch (e) {
      final failedMessage = tempMessage.copyWith(status: 'failed');
      await MessageDatabase.instance.update(failedMessage);
      print("Send message error: $e");
      return failedMessage;
    }
  }

  //Đánh dấu đã xem
  Future<void> markAsSeen(String conversationId, String userId) async {
    try {
      await _dio.post('messages/conversations/$conversationId/seen');
    } on DioException catch (e) {
      print('Failed to mark as seen: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  // Thu hồi tin nhắn
  Future<void> recallMessage(Message message) async {
    if (message.status == 'pending' || message.status == 'failed') {
      // Nếu tin nhắn chưa được gửi hoặc gửi thất bại, chỉ cần xóa nó khỏi local DB
      await MessageDatabase.instance.delete(message.id);
    } else {
      // Nếu tin nhắn đã được gửi, hãy gọi API để thu hồi
      try {
        print(message.id);
        await _dio.post('messages/messages/${message.id}/recall');
      } on DioException catch (e) {
        throw Exception('Failed to recall message: $e');
      } catch (e) {
        throw Exception('An unknown error occurred: $e');
      }
    }
  }

  //Xóa cuộc trò chuyện
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _dio.delete('messages/conversations/$conversationId');
    } on DioException catch (e) {
      throw Exception('Failed to delete conversation: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }

  // Cập nhật tên nhóm
  Future<void> updateGroupName(String conversationId, String newName) async {
    try {
      await _dio.put(
        'messages/conversations/$conversationId/name',
        data: {'new_name': newName},
      );
    } catch (e) {
      throw Exception('Failed to update group name: $e');
    }
  }

  // Cập nhật ảnh đại diện nhóm
  Future<String> updateGroupAvatar(
    String conversationId,
    String imagePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(imagePath),
      });

      final response = await _dio.put(
        'messages/conversations/$conversationId/avatar',
        data: formData,
      );

      return response.data['avatarUrl'];
    } catch (e) {
      throw Exception('Failed to update group avatar: $e');
    }
  }

  // Rời khỏi nhóm
  Future<void> leaveGroup(String conversationId) async {
    try {
      await _dio.post('messages/conversations/$conversationId/leave');
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  // Thêm thành viên vào nhóm
  Future<void> addMemberToGroup(String conversationId, String memberId) async {
    try {
      await _dio.post(
        'messages/conversations/$conversationId/members',
        data: {'member_id': memberId},
      );
    } catch (e) {
      throw Exception('Failed to add member to group: $e');
    }
  }
}
