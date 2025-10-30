import 'package:flutter/material.dart';

class ShowNotification {
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    String title = "Xác nhận?",
    String cancelText = "Quay lại",
    String confirmText = "Xóa ghi âm",
    Color confirmColor = const Color(0xFF7A2FC0),
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340), // 👈 Giới hạn ngang
          child: AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 50, 0),
            content: Text(
              title,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 16),
            ),
            actionsPadding: EdgeInsets.zero,
            actions: [
              const SizedBox(height: 15),
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    TextButton(
                      onPressed: () => {
                        if (context.mounted) {Navigator.pop(context, true)},
                      },
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          color: confirmColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> showCustomAlertDialog(
    BuildContext context, {
    required String message,
    String buttonText = "Ok",
    Color buttonColor = Colors.red,
  }) async {
    final result = await showDialog(
      context: context,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320), // 👈 Giới hạn ngang
          child: AlertDialog(
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
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
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
        ),
      ),
    );
    return result ?? false;
  }

  static Future<void> showToast(BuildContext context, String msg) async {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 120, // cách đáy màn hình
        left: 50,
        right: 50,
        child: Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color.fromARGB(221, 136, 136, 136),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  static Future<void> showLoadingDialog(BuildContext context, String message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF7A2FC0)),
            SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
