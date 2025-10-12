import './api_service.dart';

class AuthService extends ApiService {
  /// Đăng nhập người dùng và lưu token nếu thành công.
  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? deviceToken,
  }) async {
    final body = {'username': username, 'password': password};

    if (deviceToken != null) {
      body['device_token'] = deviceToken;
    }

    final response = await post('auth/login', body: body);

    // Nếu đăng nhập thành công, trích xuất và lưu token
    if (response['access_token'] != null) {
      setAuthToken(response['access_token']);
    }

    return response;
  }

  /// Đăng ký người dùng mới.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      return await post(
        'auth/register',
        body: {
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Username already exists')) {
        throw Exception('Tên người dùng đã tồn tại.');
      } else if (errorMessage.contains('Email already registered')) {
        throw Exception('Email đã tồn tại.');
      } else {
        // Ném lại lỗi gốc nếu không phải lỗi cụ thể cần xử lý
        throw Exception('Đã xảy ra lỗi không xác định.');
      }
    }
  }

  /// Đăng xuất người dùng (xóa token ở phía client).
  void logout() {
    setAuthToken(null);
  }
}
