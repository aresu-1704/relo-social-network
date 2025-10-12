import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<String?> getDeviceToken() async {
    try {
      // Yêu cầu quyền gửi thông báo từ người dùng (quan trọng cho iOS)
      await _firebaseMessaging.requestPermission();

      // Lấy FCM token
      String? token = await _firebaseMessaging.getToken();
      print("Firebase Messaging Token: $token");
      return token;
    } catch (e) {
      print("Lỗi khi lấy FCM token: $e");
      return null;
    }
  }
}
