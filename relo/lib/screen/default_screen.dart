import 'package:flutter/material.dart';
import 'package:relo/screen/login_screen.dart';

class DefaultScreen extends StatelessWidget {
  const DefaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              SizedBox(height: 185,),
              ClipRRect(
                borderRadius: BorderRadius.circular(30), // chỉnh độ bo tròn
                child: Image.asset(
                  'assets/icons/app_logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: 60,),
              Text(
                "Chào mừng đến với Relo, trò chuyện an toàn hơn bao giờ hết",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                "Cùng bắt đầu nào, hãy tạo tài khoản mới bằng cách ấn vào Đăng ký, hoặc ấn vào Đăng nhập nếu đã có tài khoản",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black
                ),
                textAlign: TextAlign.center,
              ),
              Expanded(child: SizedBox(height: 60,)),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (){

                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B38D7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Đăng ký",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    )
                  ),
                  SizedBox(width: 15,),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (){
                        Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen())
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B38D7), width: 2),
                        foregroundColor: Color(0xFF8B38D7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10), // bo góc
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      child: const Text(
                        "Đăng nhập",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    )
                  )
                ],
              )
            ],
          ),
        )
      )
    );
  }
}