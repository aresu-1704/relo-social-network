import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:relo/screen/login_screen.dart';
import 'package:relo/services/app_connectivity_service.dart';
import 'package:relo/services/connectivity_service.dart';
import 'package:relo/services/dio_api_service.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/auth_service.dart';

class ServiceLocator {
  // Global navigator key to allow navigation from outside the widget tree
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Service instances
  static late final DioApiService dioApiService;
  static late final Dio dio;
  static late final AuthService authService;
  static late final UserService userService;
  static late final MessageService messageService;
  static late final ConnectivityService connectivityService;
  static late final AppConnectivityService appConnectivityService;

  /// Initializes all the services.
  static void init() {
    // This function will be called from the DioApiService when the refresh token fails.
    void onSessionExpired() {
      // Use the navigator key to navigate to the login screen, clearing all other routes.
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }

    // Initialize the app connectivity service
    appConnectivityService = AppConnectivityService();

    // Create the core DioApiService with the session expiration callback
    dioApiService = DioApiService(
      onSessionExpired: onSessionExpired,
      appConnectivityService: appConnectivityService,
    );
    dio = dioApiService.dio;

    // Create other services that depend on the central Dio instance
    // Note: AuthService uses its own Dio instance for non-intercepted calls like login/register
    authService = AuthService();
    userService = UserService(dio);
    messageService = MessageService(dio);

    // Initialize the connectivity service
    connectivityService = ConnectivityService();
  }
}
