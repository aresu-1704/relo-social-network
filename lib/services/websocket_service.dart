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
  bool _isConnecting = false;
  bool _isReconnecting = false;
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
    // Tránh connect đồng thời nhiều lần
    if (_isConnecting || _isReconnecting) {
      return;
    }

    // Nếu đã connected rồi thì không cần connect lại
    if (isConnected) {
      return;
    }

    _isManualDisconnect = false;
    _reconnectAttempts = 0;
    _isConnecting = true;

    try {
      // Tạo StreamController mới nếu cái cũ đã bị đóng
      if (_streamController.isClosed) {
        _streamController = StreamController<dynamic>.broadcast();
      }

      // Hủy subscription cũ nếu có
      await _connectivitySubscription?.cancel();

      // Nếu đang offline thì không connect ngay để tránh crash
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        // Chờ sự kiện mạng quay lại qua subscription bên dưới
      } else {
        await _connect();
      }
    } finally {
      _isConnecting = false;
    }

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
        _reconnectTimer = Timer(const Duration(seconds: 2), () {
          _reconnect();
        });
      }
    });
  }

  Future<void> _handleDisconnect({int? closeCode}) async {
    if (_isManualDisconnect) return;

    // Nếu đang offline, đợi connectivity listener xử lý, không cố gắng reconnect ngay
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

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
      // Không logout ở đây, chỉ disconnect để reconnect sau
      disconnect();
    }
  }

  Future<void> _reconnect() async {
    if (_isManualDisconnect) {
      return;
    }

    // Tránh reconnect đồng thời nhiều lần
    if (_isReconnecting || _isConnecting) {
      return;
    }

    // Nếu đã connected rồi thì không cần reconnect
    if (isConnected) {
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

    _isReconnecting = true;

    try {
      // Đóng channel cũ an toàn
      if (_channel != null) {
        try {
          await _channel!.sink.close(status.normalClosure);
        } catch (e) {
          // Ignore errors
        }
        _channel = null;
      }

      // Tạo StreamController mới nếu cái cũ đã bị đóng
      if (_streamController.isClosed) {
        _streamController = StreamController<dynamic>.broadcast();
      }

      // Thêm delay để tránh reconnect quá nhanh
      await Future.delayed(Duration(milliseconds: 1000 * _reconnectAttempts));

      await _connect();
    } finally {
      _isReconnecting = false;
    }
  }

  Future<void> _connect() async {
    final token = await _authService.accessToken;
    if (token == null) {
      _isConnecting = false;
      _isReconnecting = false;
      return;
    }

    final url = 'ws://$webSocketBaseUrl/ws?token=$token';
    try {
      // Đóng channel cũ nếu có và chưa đóng
      if (_channel != null) {
        try {
          await _channel!.sink.close(status.normalClosure);
        } catch (e) {
          // Ignore errors khi đóng channel cũ
        }
        _channel = null;
      }

      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (data) {
          try {
            // Wrap in try-catch to prevent crashes from unhandled messages
            if (!_streamController.isClosed) {
              _streamController.add(data);
            }
          } catch (e) {
            // Ignore errors
          }
        },
        onDone: () async {
          // Chỉ handle disconnect nếu không phải đang reconnect từ app resume
          // Tránh vòng lặp reconnect
          if (!_isReconnecting && !_isConnecting) {
            final closeCode = _channel?.closeCode;
            await _handleDisconnect(closeCode: closeCode);
          }
        },
        onError: (error) async {
          if (!_streamController.isClosed) {
            _streamController.addError(error);
          }
          // Chỉ handle disconnect nếu không phải đang reconnect từ app resume
          if (!_isReconnecting && !_isConnecting) {
            final closeCode = _channel?.closeCode;
            await _handleDisconnect(closeCode: closeCode);
          }
        },
        cancelOnError: false, // Không cancel subscription khi có lỗi
      );

      _reconnectAttempts = 0;
      _isConnecting = false;
      _isReconnecting = false;
    } catch (e) {
      _isConnecting = false;
      _isReconnecting = false;
      // Chỉ handle disconnect nếu không phải từ app resume
      if (!_isManualDisconnect) {
        await _handleDisconnect(closeCode: null);
      }
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
    _isConnecting = false;
    _isReconnecting = false;
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

  bool get isConnected {
    try {
      return _channel != null &&
          _channel!.closeCode == null &&
          _channel!.closeReason == null;
    } catch (e) {
      // Nếu có lỗi khi check connection, coi như disconnected
      return false;
    }
  }
}

final webSocketService = WebSocketService();
