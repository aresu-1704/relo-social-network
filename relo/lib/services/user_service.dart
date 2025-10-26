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
      await _dio.post('users/friend-request', data: {'to_user_id': userId});
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  // Phản hồi yêu cầu kết bạn
  Future<void> respondToFriendRequest(String requestId, String response) async {
    try {
      await _dio.post(
        'users/friend-request/$requestId',
        data: {'response': response}, // 'accepted' or 'declined'
      );
    } catch (e) {
      throw Exception('Failed to respond to friend request: $e');
    }
  }

  // Chặn người dùng
  Future<void> blockUser(String userId) async {
    try {
      await _dio.post('users/block', data: {'user_id': userId});
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  // Bỏ chặn người dùng
  Future<void> unblockUser(String userId) async {
    try {
      await _dio.post('users/unblock', data: {'user_id': userId});
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

  // Lấy danh sách lời mời kết bạn đang chờ
  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final response = await _dio.get('users/friend-requests/pending');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception('Không thể tải danh sách lời mời kết bạn');
      }
    } catch (e) {
      throw Exception('Failed to load pending friend requests: $e');
    }
  }

  // Cập nhật thông tin profile người dùng
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarBase64,
    String? backgroundBase64,
  }) async {
    try {
      Map<String, dynamic> data = {};
      if (displayName != null) data['displayName'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (avatarBase64 != null) data['avatarBase64'] = avatarBase64;
      if (backgroundBase64 != null) data['backgroundBase64'] = backgroundBase64;
      
      await _dio.put('users/me', data: data);
    } catch (e) {
      throw Exception('Không thể cập nhật hồ sơ: $e');
    }
  }

  // Cập nhật avatar và trả về user data mới
  Future<User?> updateAvatar(String base64Image) async {
    try {
      final response = await _dio.put('users/me', data: {
        'avatarBase64': base64Image,
      });
      
      // Server should return updated user data
      if (response.statusCode == 200) {
        // Fetch updated user data
        return await getMe();
      }
      return null;
    } on DioException catch (e) {
      print('Error updating avatar: ${e.response?.data}');
      throw Exception('Không thể cập nhật ảnh đại diện: ${e.message}');
    } catch (e) {
      throw Exception('Không thể cập nhật ảnh đại diện: $e');
    }
  }

  // Cập nhật ảnh bìa và trả về user data mới
  Future<User?> updateBackground(String base64Image) async {
    try {
      final response = await _dio.put('users/me', data: {
        'backgroundBase64': base64Image,
      });
      
      // Server should return updated user data
      if (response.statusCode == 200) {
        // Fetch updated user data
        return await getMe();
      }
      return null;
    } on DioException catch (e) {
      print('Error updating background: ${e.response?.data}');
      throw Exception('Không thể cập nhật ảnh bìa: ${e.message}');
    } catch (e) {
      throw Exception('Không thể cập nhật ảnh bìa: $e');
    }
  }

  // Đổi mật khẩu
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('users/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? 'Không thể đổi mật khẩu';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Không thể đổi mật khẩu: $e');
    }
  }

  // Xóa tài khoản (soft delete)
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('users/me');
    } on DioException catch (e) {
      print('Error deleting account: ${e.response?.data}');
      throw Exception('Không thể xóa tài khoản: ${e.message}');
    } catch (e) {
      throw Exception('Không thể xóa tài khoản: $e');
    }
  }
}
