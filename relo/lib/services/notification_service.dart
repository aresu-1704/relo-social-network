import 'package:dio/dio.dart';
import '../models/notification.dart';

class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  /// Lấy danh sách thông báo của người dùng
  Future<List<Notification>> getNotifications({
    int limit = 50,
    int skip = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        'notifications/',
        queryParameters: {
          'limit': limit,
          'skip': skip,
          'unread_only': unreadOnly,
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => Notification.fromJson(json)).toList();
      } else {
        throw Exception('Không thể tải thông báo');
      }
    } on DioException catch (e) {
      print('DioException in getNotifications: ${e.message}');
      throw Exception('Không thể tải thông báo: ${e.message}');
    } catch (e) {
      print('Unknown error in getNotifications: $e');
      throw Exception('Đã xảy ra lỗi không xác định');
    }
  }

  /// Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('notifications/unread-count');

      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      } else {
        return 0;
      }
    } on DioException catch (e) {
      print('DioException in getUnreadCount: ${e.message}');
      return 0;
    } catch (e) {
      print('Unknown error in getUnreadCount: $e');
      return 0;
    }
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.put('notifications/$notificationId/read');
    } on DioException catch (e) {
      print('DioException in markAsRead: ${e.message}');
      throw Exception('Không thể đánh dấu đã đọc: ${e.message}');
    } catch (e) {
      print('Unknown error in markAsRead: $e');
      throw Exception('Đã xảy ra lỗi không xác định');
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> markAllAsRead() async {
    try {
      await _dio.put('notifications/read-all');
    } on DioException catch (e) {
      print('DioException in markAllAsRead: ${e.message}');
      throw Exception('Không thể đánh dấu tất cả là đã đọc: ${e.message}');
    } catch (e) {
      print('Unknown error in markAllAsRead: $e');
      throw Exception('Đã xảy ra lỗi không xác định');
    }
  }

  /// Xóa một thông báo
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _dio.delete('notifications/$notificationId');
    } on DioException catch (e) {
      print('DioException in deleteNotification: ${e.message}');
      throw Exception('Không thể xóa thông báo: ${e.message}');
    } catch (e) {
      print('Unknown error in deleteNotification: $e');
      throw Exception('Đã xảy ra lỗi không xác định');
    }
  }
}
