import 'package:dio/dio.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';
// import removed; use ServiceLocator.websocketService instead
import 'package:relo/services/service_locator.dart';

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

  /// Đăng xuất người dùng (gọi API logout và xóa tokens ở phía client).
  /// skipApiCall: Nếu true, chỉ xóa tokens ở client, không gọi API (dùng để tránh recursive)
  Future<void> logout({String? deviceToken, bool skipApiCall = false}) async {
    try {
      // Nếu skip API call, chỉ xóa tokens ở client
      if (skipApiCall) {
        print('📱 Logout: Skipping API call, clearing local tokens only');
        await _storageService.deleteTokens();
        ServiceLocator.websocketService.disconnect();
        return;
      }

      // Gọi API logout để xóa device token trên server
      // Sử dụng Dio từ ServiceLocator để có interceptor tự động refresh token
      final requestData = deviceToken != null && deviceToken.isNotEmpty
          ? {'device_token': deviceToken}
          : {};

      print(
        '📱 Logout request - Device token: ${deviceToken != null ? "${deviceToken.substring(0, deviceToken.length > 20 ? 20 : deviceToken.length)}..." : "null"}',
      );

      // Lấy Dio từ ServiceLocator để có interceptor tự động refresh token
      // Nếu ServiceLocator chưa init, fallback về _dio riêng
      Dio dioInstance;
      try {
        dioInstance = ServiceLocator.dio;
        print('📱 Using DioApiService Dio (with interceptor)');
      } catch (e) {
        // Nếu ServiceLocator chưa init, dùng Dio riêng và thử refresh manually
        print(
          '⚠️ ServiceLocator not available, using local Dio and manual refresh',
        );

        // Thử refresh token trước
        final refreshed = await refreshToken();
        final token = refreshed ?? await accessToken;
        if (token == null) {
          print('⚠️ Cannot get valid token, clearing local tokens');
          await _storageService.deleteTokens();
          ServiceLocator.websocketService.disconnect();
          return;
        }

        dioInstance = _dio;
      }

      // Gọi API logout - interceptor sẽ tự động xử lý token refresh nếu cần
      final response = await dioInstance.post('auth/logout', data: requestData);

      // Chỉ logout khi server trả về 200 (đã xóa device token thành công)
      if (response.statusCode == 200) {
        await _storageService.deleteTokens();
        ServiceLocator.websocketService.disconnect();
      } else {
        throw Exception('Đã xảy ra lỗi, không thể đăng xuất');
      }
    } on DioException catch (e) {
      // Nếu API logout thất bại (401, 403, etc.),
      // vẫn xóa tokens ở client để đảm bảo logout local
      print(
        '⚠️ Logout API failed: ${e.response?.statusCode}, clearing local tokens anyway',
      );

      // Xóa tokens ở client ngay cả khi API thất bại
      // (Người dùng vẫn muốn logout, dù server không thể xóa device token)
      try {
        await _storageService.deleteTokens();
        ServiceLocator.websocketService.disconnect();

        // Nếu là 401/403, có thể token đã hết hạn, vẫn cho phép logout
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          // Token hết hạn nhưng vẫn logout được ở client
          return;
        }

        // Các lỗi khác, vẫn throw exception để thông báo
        throw Exception(
          'Đã xảy ra lỗi, không thể đăng xuất: ${e.response?.data['detail'] ?? 'Lỗi kết nối'}',
        );
      } catch (storageError) {
        // Nếu xóa tokens cũng fail, vẫn throw exception gốc
        throw Exception(
          'Đã xảy ra lỗi, không thể đăng xuất: ${e.response?.data['detail'] ?? 'Lỗi kết nối'}',
        );
      }
    } catch (e) {
      // Các lỗi khác - cố gắng xóa tokens ở client
      print('⚠️ Unexpected error during logout: $e, clearing local tokens');
      try {
        await _storageService.deleteTokens();
        ServiceLocator.websocketService.disconnect();
      } catch (_) {
        // Ignore errors khi xóa tokens
      }
      throw Exception('Đã xảy ra lỗi, không thể đăng xuất');
    }
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
        // Không gọi logout() để tránh recursive, chỉ return null
        print('⚠️ No refresh token available');
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
        // Chỉ logout khi là 401 hoặc 403, không logout khi là lỗi khác (400, 500, etc.)
        if (response.statusCode == 401 || response.statusCode == 403) {
          // Gọi logout với skipApiCall=true để tránh recursive
          await logout(skipApiCall: true);
        }
        return null;
      }
    } on DioException catch (e) {
      // Chỉ logout khi 401 (Unauthorized) hoặc 403 (Forbidden)
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (e.response?.statusCode == 403) {
          final errorMessage =
              e.response?.data['detail'] ?? 'Tài khoản đã bị xóa.';
          throw AccountDeletedException(errorMessage);
        }
        // Gọi logout với skipApiCall=true để tránh recursive
        await logout(skipApiCall: true);
        return null;
      }
      // Các lỗi khác (400, 500, network error, etc.) - KHÔNG logout
      // Chỉ return null để reconnect sau
      return null;
    } catch (e) {
      if (e is AccountDeletedException) {
        rethrow;
      }
      // Các lỗi khác (exception không phải DioException) - KHÔNG logout
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
