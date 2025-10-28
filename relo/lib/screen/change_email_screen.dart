import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/verify_otp_screen.dart';

class ChangeEmailScreen extends StatefulWidget {
  final String userId;
  final String currentEmail;

  const ChangeEmailScreen({
    super.key,
    required this.userId,
    required this.currentEmail,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPasswordAndSendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.changeEmailVerifyPassword(
          widget.userId,
          _newEmailController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          // Chuyển sang màn hình verify OTP với email mới
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyOTPScreen(
                identifier: _newEmailController.text.trim(),
                flow: OTPFlow.changeEmail,
                autoSend: true,
                userId: widget.userId,
                newEmail: _newEmailController.text.trim(),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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
          'Đổi email',
          style: GoogleFonts.poppins(color: Colors.white),
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
                    'Nhập email mới',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email hiện tại: ${widget.currentEmail}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Trường nhập email mới
                  TextFormField(
                    controller: _newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Email mới',
                      hintStyle: GoogleFonts.poppins(),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
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
                        return 'Vui lòng nhập email mới';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Email không hợp lệ';
                      }
                      if (value.trim() == widget.currentEmail) {
                        return 'Email mới phải khác email hiện tại';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Trường nhập mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      hintStyle: GoogleFonts.poppins(),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: primaryColor,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: primaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
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
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPasswordAndSendOTP,
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
                              'Xác minh và gửi OTP',
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
