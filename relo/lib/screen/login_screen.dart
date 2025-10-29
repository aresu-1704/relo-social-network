import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/screen/register_screen.dart';
import 'package:relo/screen/forgot_password_screen.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/app_notification_service.dart';
import 'package:relo/screen/main_screen.dart';
import 'package:relo/services/websocket_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final AppNotificationService _notificationService = AppNotificationService();

  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      FocusScope.of(context).unfocus();

      try {
        // Lấy device token
        final String? deviceToken = await _notificationService.getDeviceToken();

        // Đăng nhập. Service sẽ tự động lưu trữ tokens một cách an toàn.
        await _authService.login(
          _usernameController.text,
          _passwordController.text,
          deviceToken: deviceToken,
        );

        // After successful login, connect to the WebSocket service.
        // The service will handle token retrieval internally.
        await webSocketService.connect();

        // Nếu đăng nhập thành công, chuyển đến màn hình chính
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } on AccountDeletedException catch (e) {
        // Hiển thị dialog cho tài khoản đã bị xóa
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text('Tài khoản đã bị xóa'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.message, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text(
                    'Tài khoản của bạn đã bị xóa và không thể đăng nhập.\n\n'
                    'Vui lòng liên hệ bộ phận hỗ trợ nếu bạn cho rằng đây là lỗi.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Hiển thị lỗi cho người dùng
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7A2FC0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7A2FC0), // tím đậm
              Color(0xFF9B57D3), // tím vừa
              Color(0xFFCDA9EC), // tím nhạt
              Colors.white, // trắng
            ],
          ),
        ),

        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 90),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    color: Colors.white.withOpacity(
                      0.8,
                    ), // hoặc Colors.black.withOpacity(0.1)
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/icons/app_logo.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'MẠNG XÃ HỘI RELO, NHẮN TIN TRỰC TUYẾN VÀ CHIA SẼ CẢM XÚC',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Trường nhập tên đăng nhập
                _buildTextField(
                  controller: _usernameController,
                  hint: 'Tên đăng nhập',
                  icon: Icons.person_outline,
                  validatorMsg: 'Tên đăng nhập không được để trống',
                ),
                const SizedBox(height: 16),

                // Trường nhập mật khẩu
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Mật khẩu',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validatorMsg: 'Mật khẩu không được để trống',
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: Text(
                      'Quên mật khẩu ?',
                      style: GoogleFonts.poppins(color: primaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 1),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : Text(
                            'Đăng nhập',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Không có tài khoản ?', style: GoogleFonts.poppins()),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: Text(
                        'Đăng ký',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    required String validatorMsg,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      cursorColor: const Color(0xFF7A2FC0),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? validatorMsg : null,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(),
        prefixIcon: Icon(icon, color: const Color(0xFF7A2FC0)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: _buildBorder(),
        focusedBorder: _buildBorder(width: 2),
        errorBorder: _buildBorder(color: Colors.red),
        focusedErrorBorder: _buildBorder(color: Colors.red, width: 2),
      ),
    );
  }

  OutlineInputBorder _buildBorder({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(100),
      borderSide: BorderSide(
        color: color ?? const Color(0xFF7A2FC0),
        width: width,
      ),
    );
  }
}
