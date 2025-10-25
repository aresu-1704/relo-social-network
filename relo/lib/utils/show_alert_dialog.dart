import 'package:flutter/material.dart';

/// Alert dialog đơn giản với 1 nút (backward compatible)
Future<void> showCustomAlertDialog(
  BuildContext context, {
  required String message,
  String buttonText = "Ok",
  Color buttonColor = Colors.red,
}) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: Colors.grey[400]),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  buttonText,
                  style: TextStyle(
                    color: buttonColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Alert dialog nâng cao với title, nhiều actions, trả về true/false
/// Dùng cho các trường hợp cần xác nhận hoặc có nhiều lựa chọn
Future<bool?> showAlertDialog(
  BuildContext context, {
  String? title,
  required String message,
  String confirmText = "Đồng ý",
  String? cancelText,
  bool showCancel = false,
  Color confirmColor = const Color(0xFF7C3AED),
  Color cancelColor = Colors.grey,
  bool barrierDismissible = true,
}) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: title != null
          ? Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      contentPadding: EdgeInsets.fromLTRB(24, title != null ? 16 : 20, 24, 0),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: showCancel
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: [
              if (showCancel && cancelText != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    cancelText,
                    style: TextStyle(
                      color: cancelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  confirmText,
                  style: TextStyle(
                    color: confirmColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Alert dialog với custom actions (cho trường hợp phức tạp)
Future<T?> showCustomActionDialog<T>(
  BuildContext context, {
  String? title,
  required String message,
  required List<AlertAction<T>> actions,
  bool barrierDismissible = true,
}) async {
  return await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: title != null
          ? Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      contentPadding: EdgeInsets.fromLTRB(24, title != null ? 16 : 20, 24, 0),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: actions.length > 2
                ? MainAxisAlignment.spaceEvenly
                : MainAxisAlignment.spaceBetween,
            children: actions.map((action) {
              return TextButton(
                onPressed: () => Navigator.pop(context, action.value),
                child: Text(
                  action.label,
                  style: TextStyle(
                    color: action.color,
                    fontWeight: action.isBold ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

/// Class đại diện cho một action trong dialog
class AlertAction<T> {
  final String label;
  final T value;
  final Color color;
  final bool isBold;

  const AlertAction({
    required this.label,
    required this.value,
    this.color = const Color(0xFF7C3AED),
    this.isBold = false,
  });
}
