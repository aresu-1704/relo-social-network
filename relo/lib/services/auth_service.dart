import 'package:dio/dio.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';
import 'package:relo/services/websocket_service.dart';

/// Custom exception cho tài khoản đã bị xóa
class AccountDeletedException implements Exception {
  final String message;
  AccountDeletedException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final SecureStorageService _storageService = const SecureStorageService();

  // Add a flag to prevent multiple refresh calls
  static bool _isRefreshing = false;

  Future<String?> get accessToken => _storageService.getAccessToken();

  /// Gửi mã OTP qua email
  Future<String> sendOTP(String identifier) async {
    try {
      final response = await _dio.post(
        'auth/send-otp',
        data: {'identifier': identifier},
      );

      if (response.statusCode == 200) {
        return response.data['email'];
      }
      throw Exception('Không thể gửi OTP');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Không tìm thấy tài khoản');
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Xác minh mã OTP
  Future<void> verifyOTP(String email, String otpCode) async {
    try {
      await _dio.post(
        'auth/verify-otp',
        data: {'email': email, 'otp_code': otpCode},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['detail'] ?? 'Mã OTP không hợp lệ.');
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

  /// Đặt lại mật khẩu mới
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      await _dio.post(
        'auth/reset-password',
        data: {'email': email, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(
          e.response?.data['detail'] ?? 'Không thể đặt lại mật khẩu.',
        );
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định.');
    }
  }

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
      // Handle Dio-specific errors
      if (e.response?.statusCode == 401) {
        throw Exception('Tên đăng nhập hoặc mật khẩu không chính xác.');
      } else if (e.response?.statusCode == 403) {
        // Tài khoản đã bị xóa
        final errorMessage =
            e.response?.data['detail'] ?? 'Tài khoản đã bị xóa.';
        throw AccountDeletedException(errorMessage);
      }
      throw Exception('Đã xảy ra lỗi mạng.');
    } catch (e) {
      if (e is AccountDeletedException) {
        rethrow;
      }
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
    webSocketService.disconnect();
  }

  // Lấy access token mới bằng refresh token.
  Future<String?> refreshToken() async {
    // Prevent multiple refresh calls at the same time
    if (_isRefreshing) {
      return null;
    }
    _isRefreshing = true;

    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) {
        // This isn't a network error, but a state error. No token, so can't refresh.
        await logout();
        return null;
      }

      final response = await _dio.post(
        'auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        await _storageService.saveTokens(
          accessToken: newAccessToken,
          refreshToken:
              refreshToken, // The refresh token might be rotated, but the example doesn't show it
        );
        return newAccessToken;
      } else {
        // A non-200 response that isn't a DioException (unlikely but possible)
        // should be treated as a session failure.
        await logout();
        return null;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        await logout();
        final errorMessage =
            e.response?.data['detail'] ?? 'Tài khoản đã bị xóa.';
        throw AccountDeletedException(errorMessage);
      }
      // If refresh fails, logout the user
      await logout();
      return null;
    } catch (e) {
      if (e is AccountDeletedException) {
        rethrow;
      }
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, dynamic>> changeEmailVerifyPassword(
    String userId,
    String newEmail,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/auth/change-email/verify-password',
        data: {'user_id': userId, 'new_email': newEmail, 'password': password},
      );

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['detail'] ?? 'Thất bại');
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    }
  }

  Future<String> updateEmail(String userId, String newEmail) async {
    try {
      final response = await _dio.post(
        '/auth/change-email/update',
        data: {'user_id': userId, 'new_email': newEmail},
      );

      return response.data['message'];
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception(e.response?.data['detail'] ?? 'Thất bại');
      }
      throw Exception('Lỗi kết nối. Vui lòng thử lại.');
    }
  }
}
