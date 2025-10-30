import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/services/service_locator.dart';

class BlockComposer extends StatelessWidget {
  final String blockedUserId;
  final String chatName;
  final bool isBlockedByMe;
  final VoidCallback? onUnblockSuccess;

  const BlockComposer({
    super.key,
    required this.blockedUserId,
    required this.chatName,
    this.isBlockedByMe = false,
    this.onUnblockSuccess,
  });

  Future<void> _handleUnblock(BuildContext context) async {
    bool? confirm = await ShowNotification.showConfirmDialog(
      context,
      title: 'Bỏ chặn $chatName?',
      confirmText: 'Bỏ chặn',
      cancelText: 'Hủy',
      confirmColor: const Color(0xFF7A2FC0),
    );

    if (confirm == true) {
      try {
        final userService = ServiceLocator.userService;
        await userService.unblockUser(blockedUserId);

        if (context.mounted) {
          await ShowNotification.showToast(context, 'Đã bỏ chặn $chatName');
          onUnblockSuccess?.call();
        }
      } catch (e) {
        if (context.mounted) {
          await ShowNotification.showToast(
            context,
            'Không thể bỏ chặn người dùng',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, color: Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Text(
            'Người này hiện không có mặt.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isBlockedByMe) ...[
            const SizedBox(width: 2),
            TextButton(
              onPressed: () => _handleUnblock(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Bỏ chặn',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF7A2FC0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
