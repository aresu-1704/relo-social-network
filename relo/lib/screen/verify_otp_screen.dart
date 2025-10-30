import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/services/auth_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/reset_password_screen.dart';
import 'package:relo/screen/change_password_screen.dart';

enum OTPFlow { forgotPassword, changePassword, changeEmail }

class VerifyOTPScreen extends StatefulWidget {
  final String? email;
  final String identifier; // Username hoặc email đã nhập
  final OTPFlow flow; // Forgot password hoặc change password hoặc change email
  final bool autoSend; // Tự động gửi OTP khi init
  final String? userId; // Cần cho flow changeEmail
  final String? newEmail; // Cần cho flow changeEmail

  const VerifyOTPScreen({
    super.key,
    this.email,
    required this.identifier,
    this.flow = OTPFlow.forgotPassword,
    this.autoSend = false,
    this.userId,
    this.newEmail,
  });

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final AuthService _authService = ServiceLocator.authService;
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _email;
  bool _isInitializing = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoSend) {
      _sendOTP();
    } else {
      _email = widget.email;
      // Bắt đầu countdown ngay nếu không auto send
      _countdown = 60;
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      final email = await _authService.sendOTP(widget.identifier);

      if (mounted) {
        setState(() {
          _email = email;
          _isInitializing = false;
          _countdown = 60;
          _startCountdown();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        await ShowNotification.showCustomAlertDialog(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          buttonText: 'OK',
          buttonColor: const Color(0xFF7A2FC0),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '${username.substring(0, 1)}***@$domain';
    }

    return '${username.substring(0, 2)}***@$domain';
  }

  Future<void> _verifyOTP() async {
    // Kiểm tra tất cả các ô đã được điền
    for (var controller in _controllers) {
      if (controller.text.isEmpty) {
        if (mounted) {
          ShowNotification.showToast(context, 'Vui lòng nhập đầy đủ 6 số');
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ghép 6 số thành mã OTP
      final otpCode = _controllers.map((c) => c.text).join();

      if (_email == null) {
        throw Exception('Email không được xác định');
      }

      await _authService.verifyOTP(_email!, otpCode);

      if (mounted) {
        // Chuyển sang màn hình tương ứng
        if (widget.flow == OTPFlow.changePassword) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChangePasswordScreen(email: _email!),
            ),
          );
        } else if (widget.flow == OTPFlow.changeEmail) {
          // Update email sau khi verify OTP
          try {
            await _authService.updateEmail(widget.userId!, widget.newEmail!);

            if (mounted) {
              await ShowNotification.showCustomAlertDialog(
                context,
                message: 'Đổi email thành công!',
                buttonText: 'OK',
                buttonColor: const Color(0xFF7A2FC0),
              );

              // Quay về privacy settings (pop 2 lần)
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              }
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
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(email: _email!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showCustomAlertDialog(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          buttonText: 'OK',
          buttonColor: const Color(0xFF7A2FC0),
        );

        // Xóa các ô sau khi nhập sai
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        // Chuyển sang ô tiếp theo
        _focusNodes[index + 1].requestFocus();
      } else {
        // Đã điền xong ô cuối, ẩn bàn phím và xác minh
        _focusNodes[index].unfocus();
        _verifyOTP();
      }
    } else {
      // Khi xóa, chuyển về ô trước nếu không phải ô đầu
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7A2FC0);

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF7A2FC0),
        appBar: AppBar(
          shadowColor: Colors.black,
          backgroundColor: const Color(0xFF7A2FC0),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Xác minh OTP',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

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
          'Xác minh OTP',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Nhập mã OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _email != null
                      ? (widget.flow == OTPFlow.changePassword ||
                                widget.flow == OTPFlow.changeEmail)
                            ? 'Nhập OTP được gửi đến ${_maskEmail(_email!)}'
                            : 'Mã đã được gửi đến $_email'
                      : 'Đang gửi mã OTP...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 6 ô nhập OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          onChanged: (value) => _onChanged(index, value),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
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
                            'Xác minh',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: (_isLoading || _countdown > 0)
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            await _authService.sendOTP(widget.identifier);

                            if (mounted) {
                              ShowNotification.showToast(
                                context,
                                'Đã gửi lại mã OTP',
                              );

                              // Xóa các ô
                              for (var controller in _controllers) {
                                controller.clear();
                              }
                              _focusNodes[0].requestFocus();

                              // Bắt đầu countdown lại
                              setState(() {
                                _countdown = 60;
                              });
                              _startCountdown();
                            }
                          } catch (e) {
                            if (mounted) {
                              ShowNotification.showToast(
                                context,
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  child: Text(
                    _countdown > 0
                        ? 'Gửi lại mã ($_countdown giây)'
                        : 'Gửi lại mã',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
