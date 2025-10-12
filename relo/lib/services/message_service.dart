import 'package:dio/dio.dart';

class MessageService {
  final Dio _dio;

  MessageService(this._dio);

  Future<List<dynamic>> fetchConversations() async {
    try {
      print('Fetching conversations...');
      final response = await _dio.get('messages/conversations');
      print('Response: ${response.data}');
      // Assuming the response data is the list
      return response.data;
    } on DioException catch (e) {
      print('Error fetching conversations: $e');
      throw Exception('Failed to fetch conversations: $e');
    } catch (e) {
      print('Error fetching conversations: $e');
      throw Exception('An unknown error occurred: $e');
    }
  }
}
