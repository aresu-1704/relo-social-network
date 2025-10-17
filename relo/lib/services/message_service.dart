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
  ) async {
    try {
      final response = await _dio.post(
        'messages/conversations',
        data: {'participant_ids': participantIds},
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

  //Gửi tin nhắn
  Future<Message> sendMessage(
    String conversationId,
    Map<String, dynamic> content,
    String senderId,
  ) async {
    // 1️⃣ Tạo message local với trạng thái pending
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // ID tạm thời
      content: content,
      senderId: senderId, // current user
      conversationId: conversationId,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    // Lưu ngay vào SQLite
    await MessageDatabase.instance.create(tempMessage);

    try {
      // 2️⃣ Gửi lên server
      final response = await _dio.post(
        'messages/conversations/$conversationId/messages',
        data: {'content': content},
      );

      // 3️⃣ Cập nhật trạng thái thành sent
      final sentMessage = Message.fromJson(response.data);
      final updatedMessage = tempMessage.copyWith(
        id: sentMessage.id,
        timestamp: sentMessage.timestamp,
        status: 'sent',
      );

      await MessageDatabase.instance.update(updatedMessage);

      return updatedMessage;
    } catch (e) {
      // 3️⃣ Gửi thất bại → status = failed
      final failedMessage = tempMessage.copyWith(status: 'failed');
      await MessageDatabase.instance.update(failedMessage);
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
