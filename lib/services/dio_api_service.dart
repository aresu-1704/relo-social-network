import 'package:dio/dio.dart';
import 'package:relo/services/app_connectivity_service.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/constants.dart';

class DioApiService {
  final Dio _dio;
  final SecureStorageService _storageService;
  final AuthService _authService;
  final AppConnectivityService _appConnectivityService;

  // Callback to navigate to login screen on session expiration
  final Function() onSessionExpired;

  // Callback when account is deleted
  final Function(String message)? onAccountDeleted;

  DioApiService({
    required this.onSessionExpired,
    this.onAccountDeleted,
    required AppConnectivityService appConnectivityService,
  }) : _dio = Dio(BaseOptions(baseUrl: baseUrl)),
       _storageService = const SecureStorageService(),
       _authService = AuthService(),
       _appConnectivityService = appConnectivityService {
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
      onResponse: (response, handler) {
        // When we get a successful response, we know we are online.
        _appConnectivityService.setApiStatus(true);
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        // Handle connectivity issues
        if (_isConnectivityError(e)) {
          _appConnectivityService.setApiStatus(false);
          // We don't resolve or reject, just pass the error along
          return handler.next(e);
        }

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
          } on AccountDeletedException catch (deletedError) {
            // Account was deleted - show specific dialog
            if (onAccountDeleted != null) {
              onAccountDeleted!(deletedError.message);
            } else {
              _handleSessionExpired();
            }
            return handler.reject(e);
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

  bool _isConnectivityError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.response?.statusCode ?? 0) >= 500;
  }

  void _handleSessionExpired() {
    _storageService.deleteTokens();
    onSessionExpired();
  }
}
