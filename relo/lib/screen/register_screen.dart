import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
    // Validate form, nếu không hợp lệ thì dừng
    if (!_formKey.currentState!.validate()) return;

    // Bắt đầu loading
    setState(() => _isLoading = true);

    // Lấy dữ liệu từ controllers
    final username = _usernameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final displayName = _displayNameController.text;

    // TODO: Gọi service đăng ký ở đây
    // Ví dụ:
    // try {
    //   await authService.register(username, email, password, displayName);
    //   if (!mounted) return;
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Đăng ký thành công!')),
    //   );
    //   Navigator.pop(context);
    // } catch (e) {
    //   if (!mounted) return;
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Đăng ký thất bại: $e')),
    //   );
    // } finally {
    //   setState(() => _isLoading = false);
    // }

    // Giả lập gọi API để test UI
    await Future.delayed(const Duration(seconds: 2));

    // Dừng loading
    setState(() => _isLoading = false);

    // Kiểm tra nếu widget còn tồn tại
    if (!mounted) return;

    // Hiển thị thông báo thành công và quay về màn hình trước đó
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công!')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
    });
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
                    fontSize: 28, fontWeight: FontWeight.bold, color: mainColor),
              ),
              const SizedBox(height: 25),

              // Trường nhập Tên đăng nhập
              _buildTextFormField(
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
              _buildTextFormField(
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
              _buildTextFormField(
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
              _buildTextFormField(
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
              _buildTextFormField(
                controller: _confirmPasswordController,
                hintText: 'Xác nhận mật khẩu',
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                toggleObscure: () {
                  setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword);
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
                              color: Colors.white),
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
                          fontWeight: FontWeight.bold, color: mainColor),
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

  // Widget helper để xây dựng các trường TextFormField cho gọn
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    const Color mainColor = Color(0xFF7A2FC0);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      cursorColor: mainColor,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: mainColor),
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mainColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mainColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: mainColor),
                onPressed: toggleObscure,
              )
            : null,
      ),
    );
  }
}