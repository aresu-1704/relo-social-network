import 'package:flutter/material.dart';
import 'package:relo/utils/show_notification.dart';

class ConversationSettingsScreen extends StatelessWidget {
  final bool isGroup;
  final String? chatName;
  final String? avatarUrl;
  final String? currentUserId;
  final List<String>? memberIds;
  final bool isDeletedAccount;
  final bool isBlocked;
  final Function(String)? onViewProfile;
  final Function()? onLeaveGroup;
  final Function()? onChangeGroupName;
  final Function(String)? onBlockUser;
  final Function()? onDeleteConversation;
  final String conversationId;

  const ConversationSettingsScreen({
    super.key,
    required this.isGroup,
    this.chatName,
    this.avatarUrl,
    this.currentUserId,
    this.memberIds,
    required this.isDeletedAccount,
    required this.isBlocked,
    this.onViewProfile,
    this.onLeaveGroup,
    this.onChangeGroupName,
    this.onBlockUser,
    this.onDeleteConversation,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isGroup ? 'Cài đặt nhóm' : 'Cài đặt',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: ListView(
          children: [
            // === AVATAR HEADER ===
            _buildAvatarHeader(),

            const SizedBox(height: 8),

            // === THÔNG TIN ===
            _buildSectionTitle('Thông tin'),
            if (!isGroup &&
                !isDeletedAccount &&
                !isBlocked &&
                memberIds != null &&
                onViewProfile != null)
              _buildListTile(
                context: context,
                icon: Icons.person_outline,
                title: 'Xem trang cá nhân',
                onTap: () {
                  // Pop conversation settings first
                  Navigator.pop(context);
                  String friendId = memberIds!.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => memberIds!.first,
                  );
                  // Then navigate to profile
                  onViewProfile!(friendId);
                },
              ),

            // === CÀI ĐẶT NHÓM ===
            if (isGroup) ...[
              const SizedBox(height: 8),
              _buildSectionTitle('Quản lý nhóm'),
              _buildListTile(
                context: context,
                icon: Icons.edit_outlined,
                title: 'Đổi tên nhóm',
                onTap: () {
                  Navigator.pop(context);
                  if (onChangeGroupName != null) {
                    onChangeGroupName!();
                  }
                },
              ),
              _buildListTile(
                context: context,
                icon: Icons.image_outlined,
                title: 'Đổi ảnh nhóm',
                subtitle: 'Thay đổi ảnh đại diện',
                onTap: () {
                  Navigator.pop(context);
                  ShowNotification.showToast(
                    context,
                    'Chức năng đang phát triển',
                  );
                },
              ),
              _buildListTile(
                context: context,
                icon: Icons.group_add_outlined,
                title: 'Thêm thành viên',
                subtitle: 'Mời thêm người vào nhóm',
                onTap: () {
                  Navigator.pop(context);
                  ShowNotification.showToast(
                    context,
                    'Chức năng đang phát triển',
                  );
                },
              ),
            ],

            // === CÀI ĐẶT THÔNG BÁO ===
            if (!isBlocked) ...[
              const SizedBox(height: 8),
              _buildSectionTitle('Thông báo'),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: const Text('Tắt thông báo'),
                subtitle: const Text(
                  'Ngừng nhận thông báo từ cuộc trò chuyện này',
                ),
                value: false,
                activeColor: const Color(0xFF7A2FC0),
                onChanged: (value) async {
                  final result = await ShowNotification.showConfirmDialog(
                    context,
                    title: 'Tắt thông báo cuộc trò chuyện?',
                    confirmText: 'Tắt',
                    cancelText: 'Hủy',
                    confirmColor: const Color(0xFF7A2FC0),
                  );

                  if (!result!) return;
                  // TODO: logic tắt thông báo
                },
              ),
            ],

            // === CÀI ĐẶT CUỘC TRÒ CHUYỆN ===
            if (!isDeletedAccount && !isBlocked && !isGroup)
              const SizedBox(height: 8),
            _buildSectionTitle('Cuộc trò chuyện'),
            if (!isDeletedAccount && !isBlocked && !isGroup)
              _buildListTile(
                context: context,
                icon: Icons.group_outlined,
                title: 'Tạo nhóm với $chatName',
                subtitle: 'Bắt đầu nhóm chat',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: logic tạo nhóm
                },
              ),

            // === CÀNH BÁO ===
            const SizedBox(height: 8),
            _buildSectionTitle('Cảnh báo'),
            _buildListTile(
              context: context,
              icon: Icons.block,
              title: isBlocked ? 'Bỏ chặn người dùng' : 'Chặn người dùng',
              subtitle: isBlocked
                  ? 'Gỡ chặn người dùng này'
                  : 'Chặn tin nhắn và cuộc gọi',
              titleColor: const Color(0xFFFF5252),
              iconColor: const Color(0xFFFF5252),
              onTap: !isDeletedAccount && !isBlocked
                  ? () async {
                      final result = await ShowNotification.showConfirmDialog(
                        context,
                        title: 'Bạn muốn chặn người dùng này?',
                        confirmText: 'Chặn',
                        cancelText: 'Hủy',
                        confirmColor: Colors.red,
                      );

                      if (!result!) return;
                      Navigator.pop(context);

                      if (onBlockUser != null && memberIds != null) {
                        String friendId = memberIds!.firstWhere(
                          (id) => id != currentUserId,
                          orElse: () => '',
                        );

                        if (friendId.isEmpty) {
                          await ShowNotification.showToast(
                            context,
                            'Không tìm thấy người dùng',
                          );
                          return;
                        }

                        onBlockUser!(friendId);
                      }
                    }
                  : null,
            ),
            if (isGroup)
              _buildListTile(
                context: context,
                icon: Icons.logout_outlined,
                title: 'Rời nhóm',
                subtitle: 'Rời khỏi cuộc trò chuyện nhóm này',
                titleColor: const Color(0xFFFF5722),
                iconColor: const Color(0xFFFF5722),
                onTap: () async {
                  final result = await ShowNotification.showConfirmDialog(
                    context,
                    title: 'Rời khỏi cuộc trò chuyện?',
                    confirmText: 'Rời khỏi',
                    cancelText: 'Hủy',
                    confirmColor: Colors.red,
                  );

                  if (!result!) return;
                  Navigator.pop(context);
                  if (onLeaveGroup != null) {
                    onLeaveGroup!();
                  }
                },
              ),
            _buildListTile(
              context: context,
              icon: Icons.delete_outline,
              title: 'Xóa cuộc trò chuyện',
              subtitle: 'Xóa vĩnh viễn tin nhắn và lịch sử',
              titleColor: const Color(0xFFE91E63),
              iconColor: const Color(0xFFE91E63),
              onTap: () async {
                final result = await ShowNotification.showConfirmDialog(
                  context,
                  title: 'Xóa cuộc trò chuyện?',
                  confirmText: 'Xóa',
                  cancelText: 'Hủy',
                  confirmColor: Colors.red,
                );

                if (!result!) return;
                Navigator.pop(context);

                if (onDeleteConversation != null) {
                  onDeleteConversation!();
                }
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF757575),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF7A2FC0)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDisabled
                ? const Color(0xFF9E9E9E)
                : (iconColor ?? const Color(0xFF7A2FC0)),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDisabled
                ? const Color(0xFF9E9E9E)
                : (titleColor ?? Colors.black87),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDisabled
                      ? const Color(0xFFBDBDBD)
                      : Colors.grey[600],
                ),
              )
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildAvatarHeader() {
    // Fallback avatar URLs
    final String fallbackUserAvatar =
        'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';
    final String fallbackGroupAvatar =
        'https://img.freepik.com/premium-vector/group-chat-icon-3d-vector-illustration-design_48866-1609.jpg';

    final String displayAvatarUrl = avatarUrl?.isNotEmpty == true
        ? avatarUrl!
        : (isGroup ? fallbackGroupAvatar : fallbackUserAvatar);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 42,
              backgroundImage: NetworkImage(displayAvatarUrl),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            chatName ?? (isGroup ? 'Nhóm' : 'Người dùng'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (isGroup)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nhóm chat',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
