import 'package:dio/dio.dart';
import '../models/user.dart';

class UserService {
  final Dio _dio;

  UserService(this._dio);

  Future<User?> getMe() async {
    try {
      final response = await _dio.get('/api/users/me');
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

  /// Lấy danh sách bạn bè của người dùng hiện tại.
  Future<List<User>> getFriends() async {
    try {
      final response = await _dio.get('users/friends');
      if (response.data is List) {
        return (response.data as List)
            .map((friendJson) => User.fromJson(friendJson))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      // Handle Dio-specific errors
      print(e);
      throw Exception('Không thể tải danh sách bạn bè.');
    } catch (e) {
      print(e);
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }
}
