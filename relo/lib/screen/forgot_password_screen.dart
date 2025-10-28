import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/verify_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final identifier = _usernameController.text.trim();
        final email = await _authService.sendOTP(identifier);

        if (mounted) {
          // Chuyển sang màn hình nhập OTP
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyOTPScreen(
                email: email,
                identifier: identifier,
                flow: OTPFlow.forgotPassword,
                autoSend: false,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Debug: In ra console để xem lỗi chi tiết
          print('Error in sendOTP: $e');
          print('Response data: ${e.toString()}');

          await ShowNotification.showCustomAlertDialog(
            context,
            message: e.toString().replaceFirst('Exception: ', ''),
            buttonText: 'OK',
            buttonColor: const Color(0xFF7A2FC0),
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
      appBar: AppBar(
        shadowColor: Colors.black,
        backgroundColor: const Color(0xFF7A2FC0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quên mật khẩu',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7A2FC0),
              Color(0xFF9B57D3),
              Color(0xFFCDA9EC),
              Colors.white,
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Nhập email',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chúng tôi sẽ gửi mã OTP đến email của bạn',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameController,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Tên đăng nhập hoặc Email',
                      hintStyle: GoogleFonts.poppins(),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: primaryColor,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: _buildBorder(),
                      focusedBorder: _buildBorder(width: 2),
                      errorBorder: _buildBorder(color: Colors.red),
                      focusedErrorBorder: _buildBorder(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên đăng nhập hoặc email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP,
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
                              'Gửi mã OTP',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
