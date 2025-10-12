import 'package:dio/dio.dart';
import '../models/user.dart';

class UserService {
  final Dio _dio;

  UserService(this._dio);

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
