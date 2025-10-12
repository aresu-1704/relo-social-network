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
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Biến để ẩn/hiện mật khẩu
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  // Biến trạng thái loading
  bool _isLoading = false;

  // Biểu thức chính quy để validate
  final RegExp emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
  final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]{4,20}$');

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
          content: Text("Đăng ký thành công! Chuẩn bị quay lại trang đăng nhập."),
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
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 58),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Logo ứng dụng
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/icons/app_logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 15),
              // Tiêu đề
              const Text(
                'ĐĂNG KÝ TÀI KHOẢN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên hiển thị';
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
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
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
            ],
          ),
        ),
      ),
    );
  }
}
