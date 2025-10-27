import 'package:flutter/material.dart';

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
