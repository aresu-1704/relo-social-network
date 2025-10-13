import 'package:dio/dio.dart';
import '../models/user.dart';

class UserService {
  final Dio _dio;

  UserService(this._dio);

  Future<User?> getMe() async {
    try {
      final response = await _dio.get('users/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      print('DioException in getMe: ${e.message}');
      return null;
    } catch (e) {
      print('Unknown error in getMe: $e');
      return null;
    }
  }

  Future<User> getUserById(String id) async {
    try {
      final response = await _dio.get('users/$id');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      print(e);
      throw Exception('Không thể tải thông tin người dùng.');
    } catch (e) {
      print(e);
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  // Lấy danh sách bạn bè
  Future<List<User>> getFriends() async {
    try {
      final response = await _dio.get('users/friends');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Không thể tải danh sách bạn bè');
      }
    } catch (e) {
      throw Exception('Failed to load friends: $e');
    }
  }

  // Tìm kiếm người dùng
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        'users/search',
        queryParameters: {'query': query},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search users');
      }
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Gửi yêu cầu kết bạn
  Future<void> sendFriendRequest(String userId) async {
    try {
      await _dio.post(
        'users/friend-request',
        data: {'to_user_id': userId},
      );
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  // Phản hồi yêu cầu kết bạn
  Future<void> respondToFriendRequest(String requestId, String response) async {
    try {
      await _dio.post(
        '/api/users/friend-request/$requestId',
        data: {'response': response}, // 'accepted' or 'declined'
      );
    } catch (e) {
      throw Exception('Failed to respond to friend request: $e');
    }
  }

  // Chặn người dùng
  Future<void> blockUser(String userId) async {
    try {
      await _dio.post(
        'users/block',
        data: {'user_id': userId},
      );
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  // Bỏ chặn người dùng
  Future<void> unblockUser(String userId) async {
    try {
      await _dio.post(
        'users/unblock',
        data: {'user_id': userId},
      );
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

    // Lấy hồ sơ công khai của người dùng
  Future<User> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('users/$userId');

      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      } else {
        throw Exception('Failed to load user profile');
      }
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }
}
