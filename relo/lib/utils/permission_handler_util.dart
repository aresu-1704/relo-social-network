import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:relo/utils/show_alert_dialog.dart';
import 'package:relo/utils/show_toast.dart';

/// Utility class để xử lý quyền người dùng một cách thống nhất
/// Tích hợp với alert dialog và toast có sẵn
class PermissionHandlerUtil {
  /// Kiểm tra và yêu cầu quyền camera
  /// Hiển thị alert nếu bị từ chối và cung cấp nút "Mở Cài đặt"
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      await _showPermissionDeniedDialog(
        context,
        'Quyền Camera',
        'Ứng dụng cần quyền truy cập camera để chụp ảnh.',
      );
      return false;
    } else if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context,
        'Quyền Camera',
        'Bạn đã từ chối quyền camera. Vui lòng cấp quyền trong phần Cài đặt.',
      );
      return false;
    }
    
    return false;
  }

  /// Kiểm tra và yêu cầu quyền microphone
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      await _showPermissionDeniedDialog(
        context,
        'Quyền Microphone',
        'Ứng dụng cần quyền truy cập microphone để ghi âm.',
      );
      return false;
    } else if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context,
        'Quyền Microphone',
        'Bạn đã từ chối quyền microphone. Vui lòng cấp quyền trong phần Cài đặt.',
      );
      return false;
    }
    
    return false;
  }

  /// Kiểm tra và yêu cầu quyền photo library
  static Future<bool> requestPhotoLibraryPermission(BuildContext context) async {
    final status = await Permission.photos.request();
    
    if (status.isGranted || status.isLimited) {
      return true;
    } else if (status.isDenied) {
      await _showPermissionDeniedDialog(
        context,
        'Quyền Thư viện ảnh',
        'Ứng dụng cần quyền truy cập thư viện ảnh để chọn ảnh.',
      );
      return false;
    } else if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context,
        'Quyền Thư viện ảnh',
        'Bạn đã từ chối quyền thư viện ảnh. Vui lòng cấp quyền trong phần Cài đặt.',
      );
      return false;
    }
    
    return false;
  }

  /// Kiểm tra và yêu cầu nhiều quyền cùng lúc
  static Future<bool> requestMultiplePermissions(
    BuildContext context,
    List<Permission> permissions,
  ) async {
    final statuses = await permissions.request();
    
    final deniedPermissions = <String>[];
    final permanentlyDeniedPermissions = <String>[];
    
    for (final entry in statuses.entries) {
      if (entry.value.isDenied) {
        deniedPermissions.add(_getPermissionName(entry.key));
      } else if (entry.value.isPermanentlyDenied) {
        permanentlyDeniedPermissions.add(_getPermissionName(entry.key));
      }
    }
    
    if (permanentlyDeniedPermissions.isNotEmpty) {
      await _showPermanentlyDeniedDialog(
        context,
        'Quyền bị từ chối',
        'Bạn cần cấp các quyền sau: ${permanentlyDeniedPermissions.join(", ")}. Vui lòng mở Cài đặt để cấp quyền.',
      );
      return false;
    }
    
    if (deniedPermissions.isNotEmpty) {
      await _showPermissionDeniedDialog(
        context,
        'Quyền bị từ chối',
        'Ứng dụng cần các quyền sau: ${deniedPermissions.join(", ")}.',
      );
      return false;
    }
    
    return true;
  }

  /// Hiển thị dialog khi quyền bị từ chối lần đầu
  static Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showAlertDialog(
      context,
      title: title,
      message: message,
      confirmText: 'Đồng ý',
    );
  }

  /// Hiển thị dialog khi quyền bị từ chối vĩnh viễn (với nút Settings)
  static Future<void> _showPermanentlyDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showAlertDialog(
      context,
      title: title,
      message: message,
      confirmText: 'Mở Cài đặt',
      cancelText: 'Hủy',
      showCancel: true,
    );
    
    if (result == true) {
      // Mở trang settings của ứng dụng
      await openAppSettings();
    }
  }

  /// Convert Permission sang tên tiếng Việt dễ đọc
  static String _getPermissionName(Permission permission) {
    if (permission == Permission.camera) return 'Camera';
    if (permission == Permission.microphone) return 'Microphone';
    if (permission == Permission.photos) return 'Thư viện ảnh';
    if (permission == Permission.storage) return 'Bộ nhớ';
    if (permission == Permission.location) return 'Vị trí';
    return permission.toString();
  }

  /// Hiển thị toast thông báo lỗi quyền
  static Future<void> showPermissionDeniedToast(BuildContext context, String permissionName) async {
    await showToast(context, 'Cần quyền $permissionName để sử dụng tính năng này');
  }

  /// Hiển thị toast thông báo thành công
  static Future<void> showSuccessToast(BuildContext context, String message) async {
    await showToast(context, message);
  }

  /// Hiển thị toast thông báo lỗi
  static Future<void> showErrorToast(BuildContext context, String message) async {
    await showToast(context, message);
  }
}
