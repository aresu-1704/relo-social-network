import 'package:dio/dio.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';
import 'package:relo/services/websocket_service.dart';


class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final SecureStorageService _storageService = const SecureStorageService();

  // Add a flag to prevent multiple refresh calls
  static bool _isRefreshing = false;

  Future<String?> get accessToken => _storageService.getAccessToken();

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
          refreshToken: refreshToken, // The refresh token might be rotated, but the example doesn't show it
        );
        return newAccessToken;
      } else {
        // A non-200 response that isn't a DioException (unlikely but possible)
        // should be treated as a session failure.
        await logout();
        return null;
      }
    } on DioException catch (e) {
      // If refresh fails with 401/403, it means the refresh token is invalid/expired.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await logout();
      }
      // For other Dio errors (like network issues), we don't logout.
      // The interceptor in the main Dio instance will handle setting the offline status.
      // We just return null to signal that the refresh failed.
      return null;
    } catch (e) {
      // Catch any other unexpected errors, but don't logout.
      // This could be a parsing error or something else.
      print('An unexpected error occurred during token refresh: $e');
      return null;
    } finally {
      _isRefreshing = false;
    }
  }
}
