import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final bool isLoading = false;
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 90),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30), // chỉnh độ bo tròn
                child: Image.asset(
                  'assets/icons/app_logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ĐĂNG NHẬP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B38D7),
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: email,
                hint: 'Địa chỉ Email',
                icon: Icons.email_outlined,
                validatorMsg: 'Email không được để trống',
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: password,
                hint: 'Mật khẩu',
                icon: Icons.lock_outline,
                obscure: true,
                validatorMsg: 'Mật khẩu không được để trống',
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                    // Navigator.push(context,
                    //     // MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));
                  },
                  child: const Text('Quên mật khẩu ?', style: TextStyle(color: Color(0xFF7A2FC0))),
                ),
              ),

              const SizedBox(height: 1),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (_formKey.currentState!.validate()) {
                      // FocusScope.of(context).unfocus();
                      // final userId = await login(_onSetState);
                      //
                      // if(userId == -3) {
                      //   _showSnackBar('Không thể kết nối đến máy chủ, vui lòng thử lại sau.');
                      // } else if (userId == -2) {
                      //   _showSnackBar('Bạn đã đăng nhập quá nhiều lần, vui lòng thử lại sau.');
                      // } else if (userId != null && userId > 0) {
                      //   _showSnackBar('Đăng nhập thành công');
                      //   await Future.delayed(const Duration(seconds: 1));
                      //   Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //       builder: (context) => CameraScreen(UserId: userId),
                      //     ),
                      //   );
                      // } else {
                      //   _showSnackBar('Sai tài khoản hoặc mật khẩu.');
                      // }
                      //
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B38D7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : const Text('Đăng nhập',
                      style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Không có tài khoản ?'),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                      // Navigator.push(
                      //     context,
                      //     MaterialPageRoute(builder: (_) => RegisterScreen()
                      //     )
                      // );
                    },
                    child: const Text('Đăng ký',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A2FC0)
                        )
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
      cursorColor: const Color(0xFF8B38D7),
      validator: (value) =>
      (value == null || value.trim().isEmpty) ? validatorMsg : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
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
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color ?? const Color(0xFF8B38D7), width: width),
    );
  }
}