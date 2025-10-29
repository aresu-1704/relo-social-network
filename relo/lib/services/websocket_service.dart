import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants.dart';
import 'auth_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  bool _isManualDisconnect = false;
  final AuthService _authService = AuthService();
  Function()? onAuthError;

  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _reconnectTimer;

  void setAuthErrorHandler(Function() handler) {
    onAuthError = handler;
  }

  Future<void> connect() async {
    _isManualDisconnect = false;
    _reconnectAttempts = 0;

    // Tạo StreamController mới nếu cái cũ đã bị đóng
    if (_streamController.isClosed) {
      _streamController = StreamController<dynamic>.broadcast();
    }

    // Hủy subscription cũ nếu có
    await _connectivitySubscription?.cancel();

    await _connect();

    // Lắng nghe thay đổi connectivity để tự động reconnect khi mạng quay lại
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (result != ConnectivityResult.none &&
          !isConnected &&
          !_isManualDisconnect) {
        // Reset reconnect attempts khi mạng quay lại
        _reconnectAttempts = 0;
        // Delay một chút để đảm bảo mạng ổn định
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(Duration(seconds: 2), () {
          _reconnect();
        });
      }
    });
  }

  Future<void> _handleDisconnect({int? closeCode}) async {
    if (_isManualDisconnect) return;

    // Chỉ logout khi gặp lỗi 401 (Unauthorized) hoặc 403 (Forbidden)
    // WebSocket close code 1008 = Policy Violation (thường dùng cho auth errors)
    // closeCode 1002 = Protocol Error (không phải auth error, không logout)
    if (closeCode == 1008) {
      // Authentication error - logout user
      if (onAuthError != null) {
        onAuthError!();
      }
      disconnect();
      return;
    }

    // Các lỗi khác (400, 500, lỗi kết nối, protocol error, etc.) - không logout, chỉ reconnect
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
        // Refresh token failed - KHÔNG logout ở đây vì có thể là lỗi network/server (400, 500)
        // Chỉ disconnect để reconnect sau, chỉ logout khi refresh token trả về 401/403
        disconnect();
      }
    } catch (e) {
      // Lỗi refresh token - KHÔNG logout, có thể là lỗi network/server khác (400, 500)
      // Chỉ logout khi refresh token trả về 401/403 (đã xử lý trong auth_service.refreshToken)
      print('Error refreshing token: $e');
      // Không logout ở đây, chỉ disconnect để reconnect sau
      disconnect();
    }
  }

  Future<void> _reconnect() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

    await _channel?.sink.close(status.normalClosure);
    _channel = null;

    // Tạo StreamController mới nếu cái cũ đã bị đóng
    if (_streamController.isClosed) {
      _streamController = StreamController<dynamic>.broadcast();
    }

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
          try {
            // Wrap in try-catch to prevent crashes from unhandled messages
            if (!_streamController.isClosed) {
              _streamController.add(data);
            }
          } catch (e) {
            print('Error handling WebSocket message: $e');
          }
        },
        onDone: () async {
          // Kiểm tra close code trước khi xử lý disconnect
          final closeCode = _channel?.closeCode;
          await _handleDisconnect(closeCode: closeCode);
        },
        onError: (error) async {
          if (!_streamController.isClosed) {
            _streamController.addError(error);
          }
          // Lỗi kết nối - không phải auth error, không logout
          final closeCode = _channel?.closeCode;
          await _handleDisconnect(closeCode: closeCode);
        },
      );

      _reconnectAttempts = 0;
    } catch (e) {
      // Lỗi khi connect - không logout, chỉ disconnect để reconnect
      await _handleDisconnect(closeCode: null);
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _channel?.sink.close(status.goingAway);
    _channel = null;
    if (!_streamController.isClosed) {
      _streamController.close();
    }
  }

  bool get isConnected => _channel != null && _channel!.closeCode == null;
}

final webSocketService = WebSocketService();
