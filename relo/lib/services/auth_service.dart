import 'package:dio/dio.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final SecureStorageService _storageService = const SecureStorageService();

  /// Đăng nhập người dùng và lưu tokens nếu thành công.
  Future<void> login(
    String username,
    String password, {
    String? deviceToken,
  }) async {
    final body = {'username': username, 'password': password};

    if (deviceToken != null) {
      body['device_token'] = deviceToken;
    }

    try {
      final response = await _dio.post('auth/login', data: body);

      if (response.statusCode == 200 && response.data != null) {
        final accessToken = response.data['access_token'];
        final refreshToken = response.data['refresh_token'];

        if (accessToken != null && refreshToken != null) {
          await _storageService.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        } else {
          throw Exception('Login failed: Tokens not received.');
        }
      } else {
        throw Exception('Login failed: Invalid response from server.');
      }
    } on DioException catch (e) {
      // Handle Dio-specific errors, e.g., 401 Unauthorized
      if (e.response?.statusCode == 401) {
        throw Exception('Tên đăng nhập hoặc mật khẩu không chính xác.');
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Đăng ký người dùng mới.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _dio.post(
        'auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['detail'] ?? 'Lỗi đăng ký.');
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Đăng xuất người dùng (xóa tokens ở phía client).
  Future<void> logout() async {
    await _storageService.deleteTokens();
  }
}
