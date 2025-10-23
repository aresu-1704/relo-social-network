import 'package:intl/intl.dart';

class Format {
  static String formatZaloTime(dynamic updatedAt) {
    try {
      DateTime date;

      if (updatedAt is int) {
        // Nếu là timestamp (milliseconds)
        date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
      } else if (updatedAt is String) {
        date = DateTime.parse(updatedAt);
      } else {
        return '';
      }

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Vừa xong';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inDays == 1) {
        return 'Hôm qua';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      } else {
        // Nếu quá 7 ngày, chỉ hiển thị ngày/tháng
        return DateFormat('dd/MM').format(date);
      }
    } catch (e) {
      print('Lỗi format thời gian: $e');
      return '';
    }
  }
}
