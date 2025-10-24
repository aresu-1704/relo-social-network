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
      throw Exception('Failed to fetch conversations: $e');
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
    String senderId,
  ) async {
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      } else if (content['type'] == 'audio') {
        formData = FormData.fromMap({
          'type': content['type'],
          'files': await MultipartFile.fromFile(content['path']),
        });
      } else if (content['type'] == 'media') {
        List<MultipartFile> files = [];
        for (var filePath in content['paths']) {
          files.add(await MultipartFile.fromFile(filePath));
        }
        formData = FormData.fromMap({
          'type': content['type'],
          'files': files,
        });
      }

      // 🚀 Gửi form-data lên server
      final response = await _dio.post(
        'messages/conversations/$conversationId/messages',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      // ✅ Cập nhật trạng thái thành sent
      final sentMessage = Message.fromJson(response.data);
      final updatedMessage = tempMessage.copyWith(
        id: sentMessage.id,
        timestamp: sentMessage.timestamp,
        status: 'sent',
      );

      await MessageDatabase.instance.update(updatedMessage);
      return updatedMessage;
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
      throw Exception('Failed to mark as seen: $e');
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }
}
