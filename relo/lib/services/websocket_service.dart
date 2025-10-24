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
        _reconnect();
      }
    });
  }

  Future<void> _handleDisconnect() async {
    if (_isManualDisconnect) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      disconnect();
      return;
    }

    _reconnectAttempts++;

    try {
      final newAccessToken = await _authService.refreshToken();
      if (newAccessToken != null) {
        await _reconnect();
      } else {
        if (onAuthError != null) {
          onAuthError!();
        }
        disconnect();
      }
    } catch (e) {
      if (onAuthError != null) {
        onAuthError!();
      }
      disconnect();
    }
  }

  Future<void> _reconnect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

    await _channel?.sink.close(status.normalClosure);
    await _connect();
  }

  Future<void> _connect() async {
    final token = await _authService.accessToken;
    if (token == null) {
      return;
    }

    final url = 'ws://$webSocketBaseUrl/ws?token=$token';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (data) {
          _streamController.add(data);
        },
        onDone: () async {
          await _handleDisconnect();
        },
        onError: (error) async {
          _streamController.addError(error);
          await _handleDisconnect();
        },
      );

      _reconnectAttempts = 0;
    } catch (e) {
      await _handleDisconnect();
    }
  }

  void send(dynamic data) {
    if (_channel != null) {
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
  }

  bool get isConnected => _channel != null && _channel!.closeCode == null;
}

final webSocketService = WebSocketService();
