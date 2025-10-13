import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants.dart';
import 'secure_storage_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _token;
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  bool _isManualDisconnect = false;
  final SecureStorageService _storage = const SecureStorageService();
  Timer? _refreshTimer;

  // Giới hạn số lần reconnect liên tiếp
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // Khởi tạo WebSocket với token
  void connect(String token) {
    _token = token;
    _isManualDisconnect = false;
    _reconnectAttempts = 0;
    _connect();
    _startTokenRefreshTimer();
  }

  void _startTokenRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 110), (timer) async {
      await _refreshAccessToken();
    });
  }

  Future<void> _refreshAccessToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        disconnect();
        return;
      }

      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await dio.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        await _storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
        );

        // Reconnect với token mới
        _token = newAccessToken;
        _reconnect();
        print('✅ WebSocket token refreshed');
      }
    } catch (e) {
      print('❌ Failed to refresh WebSocket token: $e');
      disconnect();
    }
  }

  Future<void> _reconnect() async {
    // Kiểm tra mạng trước khi reconnect
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print('❌ Không có mạng, sẽ không reconnect');
      return;
    }

    // Đóng channel cũ nếu có
    _channel?.sink.close(status.normalClosure);
    _connect();
  }

  void _connect() {
    if (_token == null) return;

    final url = 'ws://$webSocketBaseUrl/ws?token=$_token';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (data) {
          _streamController.add(data);
        },
        onDone: () async {
          if (!_isManualDisconnect &&
              _reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            print(
              '⚡ WebSocket disconnected, reconnect attempt $_reconnectAttempts',
            );
            await Future.delayed(const Duration(seconds: 5));
            _reconnect();
          }
        },
        onError: (error) async {
          _streamController.addError(error);
          if (!_isManualDisconnect &&
              _reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            print('⚡ WebSocket error, reconnect attempt $_reconnectAttempts');
            await Future.delayed(const Duration(seconds: 5));
            _reconnect();
          }
        },
      );

      // Nếu kết nối thành công, reset reconnectAttempts
      _reconnectAttempts = 0;
    } catch (e) {
      print('❌ WebSocket connect failed: $e');
      // Nếu thất bại, thử reconnect sau 5s
      if (!_isManualDisconnect && _reconnectAttempts < _maxReconnectAttempts) {
        _reconnectAttempts++;
        Future.delayed(const Duration(seconds: 5), () => _reconnect());
      }
    }
  }

  // Gửi dữ liệu lên server
  void send(dynamic data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  // Lắng nghe dữ liệu từ server
  Stream<dynamic> get stream => _streamController.stream;

  // Đóng kết nối WebSocket
  void disconnect() {
    _isManualDisconnect = true;
    _refreshTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  // Kiểm tra trạng thái kết nối
  bool get isConnected => _channel != null && _channel!.closeCode == null;
}

// Sử dụng toàn app
final webSocketService = WebSocketService();
