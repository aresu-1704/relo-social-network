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

    // 🔹 Nếu mất mạng thì KHÔNG xử lý token, chỉ chờ có mạng để reconnect
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('[WebSocket] Mất mạng, chờ có mạng sẽ tự reconnect...');
      Connectivity().onConnectivityChanged
          .firstWhere((status) => status != ConnectivityResult.none)
          .then((_) {
            if (!_isManualDisconnect) {
              print('[WebSocket] Mạng đã trở lại, reconnect...');
              _reconnect();
            }
          });
      return;
    }

    // 🔹 Nếu vẫn có mạng → xử lý như bình thường (refresh token, reconnect, v.v.)
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[WebSocket] Quá số lần thử reconnect, ngắt kết nối.');
      disconnect();
      return;
    }

    _reconnectAttempts++;

    try {
      print('[WebSocket] Đang thử refresh token...');
      final newAccessToken = await _authService.refreshToken();

      if (newAccessToken != null) {
        print('[WebSocket] Refresh token thành công, reconnect...');
        await _reconnect();
      } else {
        print('[WebSocket] Refresh token thất bại, gọi onAuthError.');
        if (onAuthError != null) onAuthError!();
        disconnect();
      }
    } catch (e) {
      // 🔹 Nếu refresh lỗi do mất mạng (hiếm khi trùng thời điểm), bỏ qua
      final currentConn = await Connectivity().checkConnectivity();
      if (currentConn != ConnectivityResult.none) {
        print('[WebSocket] Lỗi refresh token khi có mạng, gọi onAuthError.');
        if (onAuthError != null) onAuthError!();
      } else {
        print('[WebSocket] Refresh token lỗi nhưng không có mạng, bỏ qua.');
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
