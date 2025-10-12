// Quản lý kết nối WebSocket cho ứng dụng Relo
// Sử dụng package 'web_socket_channel' để kết nối WebSocket
// Comment tiếng Việt cho dễ hiểu

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  String? _token;

  // Khởi tạo WebSocket với token
  void connect(String token) {
    _token = token;
    // Địa chỉ WebSocket backend, thay đổi cho đúng với server của bạn
    final url = 'ws://your-server-domain/ws?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(url));
  }

  // Gửi dữ liệu lên server
  void send(dynamic data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  // Lắng nghe dữ liệu từ server
  Stream<dynamic>? get stream {
    return _channel?.stream;
  }

  // Đóng kết nối WebSocket
  void disconnect() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  // Kiểm tra trạng thái kết nối
  bool get isConnected => _channel != null;
}

// Tạo một instance dùng toàn app
final webSocketService = WebSocketService();
