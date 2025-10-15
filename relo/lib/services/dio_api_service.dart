import 'package:dio/dio.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';

class DioApiService {
  final Dio _dio;
  final SecureStorageService _storageService;
  final AuthService _authService;

  // Callback to navigate to login screen on session expiration
  final Function() onSessionExpired;

  DioApiService({required this.onSessionExpired})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl)),
        _storageService = const SecureStorageService(),
        _authService = AuthService() {
    _dio.interceptors.add(_createDioInterceptor());
  }

  Dio get dio => _dio;

  Interceptor _createDioInterceptor() {
    return QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get the access token from secure storage
        final accessToken = await _storageService.getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options); // Continue with the request
      },
      onError: (DioException e, handler) async {
        // Check if the error is 401 Unauthorized or 403 Forbidden
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          try {
            final newAccessToken = await _authService.refreshToken();

            if (newAccessToken != null) {
              // --- Retry the original request with the new token ---
              e.requestOptions.headers['Authorization'] =
                  'Bearer $newAccessToken';
              final retriedResponse = await _dio.fetch(e.requestOptions);
              return handler.resolve(
                retriedResponse,
              ); // Resolve with the retried response
            } else {
              _handleSessionExpired();
              return handler.reject(e);
            }
          } catch (_) {
            // Any error during refresh token flow means session is expired
            _handleSessionExpired();
            return handler.reject(e);
          }
        }
        return handler.next(e); // Continue with other errors
      },
    );
  }

  void _handleSessionExpired() {
    _storageService.deleteTokens();
    onSessionExpired();
  }
}
