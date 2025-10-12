// Quản lý kết nối WebSocket cho ứng dụng Relo
// Sử dụng package 'web_socket_channel' để kết nối WebSocket
// Comment tiếng Việt cho dễ hiểu

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _token;
  StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();
  bool _isManualDisconnect = false;

  // Khởi tạo WebSocket với token
  void connect(String token) {
    _token = token;
    _isManualDisconnect = false;
    _connect();
  }

  void _connect() {
    if (_token == null) return;
    // URL của WebSocket server.
    final url = 'ws://$webSocketBaseUrl/ws?token=$_token';
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (data) {
        _streamController.add(data);
      },
      onDone: () {
        if (!_isManualDisconnect) {
          // Tự động kết nối lại sau 5 giây nếu không phải do người dùng ngắt kết nối
          Future.delayed(const Duration(seconds: 5), () => _connect());
        }
      },
      onError: (error) {
        // Xử lý lỗi và có thể thử kết nối lại
        _streamController.addError(error);
        if (!_isManualDisconnect) {
          Future.delayed(const Duration(seconds: 5), () => _connect());
        }
      },
    );
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
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  // Kiểm tra trạng thái kết nối
  bool get isConnected => _channel != null && _channel!.closeCode == null;
}

// Tạo một instance dùng toàn app
final webSocketService = WebSocketService();
