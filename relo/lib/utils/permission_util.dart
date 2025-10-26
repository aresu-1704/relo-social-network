import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:relo/utils/show_notification.dart';
import 'dart:io';

class PermissionUtils {
  /// 📸 Kiểm tra & xin quyền truy cập ảnh/video
  static Future<bool> ensurePhotoPermission(BuildContext context) async {
    try {
      final permitted = await PhotoManager.requestPermissionExtend();

      if (!permitted.isAuth) {
        final openSettings = await ShowNotification.showCustomAlertDialog(
          context,
          message: "Ứng dụng cần quyền truy cập ảnh và video để gửi tệp",
          buttonText: "Mở cài đặt",
          buttonColor: const Color(0xFF7A2FC0),
        );

        if (openSettings == true) {
          await PhotoManager.openSetting();
          // Không delay, chờ user quay lại rồi check lại quyền
          return false;
        } else {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint("⚠️ Lỗi khi kiểm tra quyền ảnh/video: $e");
      return false;
    }
  }

  /// 🎙 Kiểm tra & xin quyền micro để ghi âm
  static Future<bool> ensureMicroPermission(BuildContext context) async {
    try {
      final micStatus = await Permission.microphone.request();

      if (!micStatus.isGranted) {
        final openSettings = await ShowNotification.showCustomAlertDialog(
          context,
          message: "Ứng dụng cần quyền truy cập micro để ghi âm",
          buttonText: "Mở cài đặt",
          buttonColor: const Color(0xFF7A2FC0),
        );

        if (openSettings == true) {
          await openAppSettings();
          await Future.delayed(const Duration(seconds: 1));

          final micAfter = await Permission.microphone.status;
          if (!micAfter.isGranted) {
            if (context.mounted) {
              await ShowNotification.showCustomAlertDialog(
                context,
                message: "Vẫn chưa có quyền micro, không thể ghi âm.",
              );
              Navigator.pop(context);
            }
            return false;
          }
        } else {
          if (context.mounted) Navigator.pop(context);
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint("Lỗi khi kiểm tra quyền micro: $e");
      return false;
    }
  }

  /// 💾 Kiểm tra & xin quyền ghi bộ nhớ (Android 13 trở xuống)
  static Future<bool> ensureStoragePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();

        if (!status.isGranted) {
          await ShowNotification.showToast(
            context,
            'Không có quyền truy cập thư mục. Vui lòng cấp quyền trong Cài đặt.',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint("Lỗi khi kiểm tra quyền bộ nhớ: $e");
      return false;
    }
  }
}
