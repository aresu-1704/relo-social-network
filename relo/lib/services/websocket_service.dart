import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants.dart';
import 'auth_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  bool _isManualDisconnect = false;
  final AuthService _authService = AuthService();
  Function()? onAuthError;

  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  void setAuthErrorHandler(Function() handler) {
    onAuthError = handler;
  }

  Future<void> connect() async {
    _isManualDisconnect = false;
    _reconnectAttempts = 0;
    await _connect();

    Connectivity().onConnectivityChanged.listen((status) {
      if (status != ConnectivityResult.none &&
          !isConnected &&
          !_isManualDisconnect) {
        print('📶 Network restored, reconnecting WebSocket...');
        _reconnect();
      }
    });
  }

  Future<void> _handleDisconnect() async {
    if (_isManualDisconnect) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnect attempts reached. Disconnecting.');
      disconnect();
      return;
    }

    _reconnectAttempts++;
    print('⚡ WebSocket disconnected, attempting to refresh token...');

    try {
      final newAccessToken = await _authService.refreshToken();
      if (newAccessToken != null) {
        print('✅ Token refreshed successfully. Reconnecting WebSocket...');
        await _reconnect();
      } else {
        print('❌ Failed to refresh token. Closing WebSocket connection.');
        if (onAuthError != null) {
          onAuthError!();
        }
        disconnect();
      }
    } catch (e) {
      print('❌ Error during token refresh: $e. Closing WebSocket connection.');
      if (onAuthError != null) {
        onAuthError!();
      }
      disconnect();
    }
  }

  Future<void> _reconnect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('❌ No network, will not reconnect.');
      return;
    }

    await _channel?.sink.close(status.normalClosure);
    await _connect();
  }

  Future<void> _connect() async {
    final token = await _authService.accessToken;
    if (token == null) {
      print('❌ No access token found for WebSocket.');
      return;
    }

    final url = 'ws://$webSocketBaseUrl/ws?token=$token';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      print('✅ WebSocket connected');

      _channel!.stream.listen(
        (data) {
          _streamController.add(data);
        },
        onDone: () async {
          print('WebSocket connection done.');
          await _handleDisconnect();
        },
        onError: (error) async {
          _streamController.addError(error);
          print('WebSocket error: $error');
          await _handleDisconnect();
        },
      );

      _reconnectAttempts = 0;
    } catch (e) {
      print('❌ WebSocket connect failed: $e');
      await _handleDisconnect();
    }
  }

  void send(dynamic data) {
    if (_channel != null && _channel!.sink != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Stream<dynamic> get stream => _streamController.stream;

  void disconnect() {
    _isManualDisconnect = true;
    _channel?.sink.close(status.goingAway);
    _channel = null;
    if (!_streamController.isClosed) {
      _streamController.close();
    }
    print('WebSocket disconnected manually.');
  }

  bool get isConnected => _channel != null && _channel!.closeCode == null;
}

final webSocketService = WebSocketService();
