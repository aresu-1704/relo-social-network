import 'package:flutter/material.dart';
import 'package:relo/widgets/text_form_field.dart';
import '../services/auth_service.dart'; // Import service

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Service để gọi API
  final AuthService _authService = AuthService();

  // Key để quản lý Form state
  final _formKey = GlobalKey<FormState>();

  // Controllers cho các trường input
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Biến để ẩn/hiện mật khẩu
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  // Biến trạng thái loading
  bool _isLoading = false;

  // Biểu thức chính quy để validate
  final RegExp emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
  final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]{4,20}$');

  int _passwordStrength = 0;

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    if (password.isEmpty) return 0;

    if (password.length >= 8) strength += 25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 20;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 25;

    return strength.clamp(0, 100);
  }

  Color _getPasswordStrengthColor(int strength) {
    if (strength < 40) return Colors.red;
    if (strength < 70) return Colors.orange;
    return Colors.green;
  }

  String _getPasswordStrengthText(int strength) {
    if (strength == 0) return '';
    if (strength < 40) return 'Yếu';
    if (strength < 70) return 'Trung bình';
    return 'Mạnh';
  }

  // Hàm xử lý đăng ký
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      await _authService.register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Đăng ký thành công! Chuẩn bị quay lại trang đăng nhập.",
          ),
          backgroundColor: Color(0xFF7A2FC0),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.redAccent,
        ),
      );
      // Only set loading to false on error, so the user can try again.
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // Huỷ các controller để tránh memory leak
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color(0xFF7A2FC0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 58),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Logo ứng dụng
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
                  const SizedBox(height: 15),
                  // Tiêu đề
                  const Text(
                    'ĐĂNG KÝ TÀI KHOẢN',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Trường nhập Tên đăng nhập
                  BuildTextFormField.buildTextFormField(
                    controller: _usernameController,
                    hintText: 'Tên đăng nhập',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên đăng nhập';
                      }
                      if (!usernameRegex.hasMatch(value)) {
                        return 'Tên đăng nhập chỉ gồm chữ, số, gạch dưới (4-20 ký tự)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Trường nhập Tên hiển thị
                  BuildTextFormField.buildTextFormField(
                    controller: _displayNameController,
                    hintText: 'Tên hiển thị',
                    icon: Icons.badge,
                    maxLength: 50,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên hiển thị';
                      }
                      if (value.length > 50) {
                        return 'Tên hiển thị không được quá 50 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Trường nhập Email
                  BuildTextFormField.buildTextFormField(
                    controller: _emailController,
                    hintText: 'Email',
                    icon: Icons.email,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!emailRegex.hasMatch(value)) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Trường nhập Mật khẩu
                  BuildTextFormField.buildTextFormField(
                    controller: _passwordController,
                    hintText: 'Mật khẩu',
                    icon: Icons.lock,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    toggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    onChanged: (value) {
                      setState(() {
                        _passwordStrength = _calculatePasswordStrength(value);
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 8) {
                        return 'Mật khẩu phải có ít nhất 8 ký tự';
                      }
                      return null;
                    },
                  ),
                  if (_passwordController.text.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _passwordStrength / 90,
                          backgroundColor: Colors.grey[300],
                          color: _getPasswordStrengthColor(_passwordStrength),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Độ mạnh mật khẩu: ${_getPasswordStrengthText(_passwordStrength)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _getPasswordStrengthColor(_passwordStrength),
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                    )
                  else
                    const SizedBox(height: 15),
                  // Trường nhập Xác nhận mật khẩu
                  BuildTextFormField.buildTextFormField(
                    controller: _confirmPasswordController,
                    hintText: 'Xác nhận mật khẩu',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    toggleObscure: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu';
                      }
                      if (value != _passwordController.text) {
                        return 'Mật khẩu không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Nút đăng ký
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              // Ẩn bàn phím
                              FocusScope.of(context).unfocus();
                              _register();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'ĐĂNG KÝ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Link quay về màn hình đăng nhập
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản ?'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Security tips
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Color(0xFF7A2FC0),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Mẹo bảo mật',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildSecurityTip(
                          'Sử dụng mật khẩu dài ít nhất 8 ký tự',
                        ),
                        _buildSecurityTip('Không sử dụng mật khẩu dễ đoán'),
                        _buildSecurityTip(
                          'Không chia sẻ mật khẩu với người khác',
                        ),
                        _buildSecurityTip(
                          'Đổi mật khẩu định kỳ để bảo mật tài khoản',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
