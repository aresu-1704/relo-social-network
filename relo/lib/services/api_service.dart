import 'dart:convert';
import 'package:http/http.dart' as http;

/// Một lớp cơ sở cho tất cả các dịch vụ API, xử lý các yêu cầu HTTP chung.
class ApiService {
  // URL cơ sở cho tất cả các điểm cuối API.
  final String _baseUrl = "http://192.168.2.3:8000/api";

  // Token xác thực (sẽ được lưu sau khi đăng nhập).
  static String? _token;

  /// Thiết lập token xác thực để sử dụng trong các yêu cầu tiếp theo.
  void setAuthToken(String? token) {
    _token = token;
  }

  /// Lấy các header mặc định cho một yêu cầu, bao gồm cả token xác thực nếu có.
  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json; charset=UTF-8'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Xử lý phản hồi từ API, giải mã JSON và kiểm tra lỗi.
  dynamic _handleResponse(http.Response response) {
    // Kiểm tra nếu body rỗng thì trả về null
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      } else {
        throw Exception(
          'API Error ${response.statusCode} on ${response.request?.url}',
        );
      }
    }

    final responseBody = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception(
        'API Error on ${response.request?.url}: ${responseBody['detail']}',
      );
    }
  }

  /// Gửi yêu cầu GET.
  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.get(url, headers: _getHeaders());
    return _handleResponse(response);
  }

  /// Gửi yêu cầu POST với body là JSON.
  Future<dynamic> post(String endpoint, {dynamic body}) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  /// Gửi yêu cầu POST với body là form-urlencoded (dùng cho đăng nhập).
  Future<dynamic> postForm(String endpoint, {Map<String, String>? body}) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    return _handleResponse(response);
  }

  /// Gửi yêu cầu PUT.
  Future<dynamic> put(String endpoint, {dynamic body}) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.put(
      url,
      headers: _getHeaders(),
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  /// Gửi yêu cầu DELETE.
  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.delete(url, headers: _getHeaders());
    return _handleResponse(response);
  }
}
