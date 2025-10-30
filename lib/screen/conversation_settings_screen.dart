import 'package:flutter/material.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:image_picker/image_picker.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/screen/create_group_screen.dart';

class ConversationSettingsScreen extends StatefulWidget {
  final bool isGroup;
  final String? chatName;
  final String? avatarUrl;
  final String? currentUserId;
  final List<String>? memberIds;
  final bool isDeletedAccount;
  final bool isBlocked;
  final bool initialMuted;
  final Function(String)? onViewProfile;
  final Function()? onLeaveGroup;
  final Function()? onChangeGroupName;
  final Function(String)? onBlockUser;
  final Function()? onAddMember;
  final Function()? onViewMembers;
  final Function()? onDeleteConversation;
  final Function(bool muted)? onMuteToggled;

  ConversationSettingsScreen({
    super.key,
    required this.isGroup,
    this.chatName,
    this.avatarUrl,
    this.currentUserId,
    this.memberIds,
    required this.isDeletedAccount,
    required this.isBlocked,
    this.initialMuted = false,
    this.onViewProfile,
    this.onLeaveGroup,
    this.onChangeGroupName,
    this.onBlockUser,
    this.onAddMember,
    this.onViewMembers,
    this.onDeleteConversation,
    this.onMuteToggled,
    required this.conversationId,
  });

  final String conversationId;

  @override
  State<ConversationSettingsScreen> createState() =>
      _ConversationSettingsScreenState();
}

class _ConversationSettingsScreenState
    extends State<ConversationSettingsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isMuted = false;
  bool _isTogglingMute = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialMuted;
  }

  Future<void> _handleToggleMute(bool value) async {
    setState(() {
      _isTogglingMute = true;
    });

    try {
      final messageService = ServiceLocator.messageService;
      final newMuted = await messageService.toggleMuteConversation(
        widget.conversationId,
        value,
      );

      if (mounted) {
        setState(() {
          _isMuted = newMuted;
          _isTogglingMute = false;
        });

        await ShowNotification.showToast(
          context,
          newMuted ? 'Đã tắt thông báo' : 'Đã bật thông báo',
        );

        // Callback để cập nhật MessagesScreen
        if (widget.onMuteToggled != null) {
          widget.onMuteToggled!(newMuted);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingMute = false;
        });
        await ShowNotification.showToast(
          context,
          'Không thể ${value ? 'tắt' : 'bật'} thông báo: $e',
        );
      }
    }
  }

  Future<void> _changeGroupAvatar(BuildContext context) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      // Show loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final messageService = ServiceLocator.messageService;
      await messageService.updateGroupAvatar(widget.conversationId, image.path);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        await ShowNotification.showToast(context, 'Đã cập nhật ảnh nhóm');
        Navigator.of(context).pop(); // Close settings
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        await ShowNotification.showToast(
          context,
          'Không thể cập nhật ảnh nhóm: $e',
        );
      }
    }
  }

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
          widget.isGroup ? 'Cài đặt nhóm' : 'Cài đặt',
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
            if (!widget.isGroup &&
                !widget.isDeletedAccount &&
                !widget.isBlocked &&
                widget.memberIds != null &&
                widget.onViewProfile != null)
              _buildListTile(
                context: context,
                icon: Icons.person_outline,
                title: 'Xem trang cá nhân',
                onTap: () {
                  // Pop conversation settings first
                  Navigator.pop(context);
                  String friendId = widget.memberIds!.firstWhere(
                    (id) => id != widget.currentUserId,
                    orElse: () => widget.memberIds!.first,
                  );
                  // Then navigate to profile
                  widget.onViewProfile!(friendId);
                },
              ),
            if (widget.isGroup && widget.onViewMembers != null)
              _buildListTile(
                context: context,
                icon: Icons.people_outlined,
                title: 'Danh sách thành viên',
                subtitle: 'Xem tất cả thành viên trong nhóm',
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onViewMembers != null) {
                    widget.onViewMembers!();
                  }
                },
              ),

            // === CÀI ĐẶT NHÓM ===
            if (widget.isGroup) ...[
              const SizedBox(height: 8),
              _buildSectionTitle('Quản lý nhóm'),
              _buildListTile(
                context: context,
                icon: Icons.edit_outlined,
                title: 'Đổi tên nhóm',
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onChangeGroupName != null) {
                    widget.onChangeGroupName!();
                  }
                },
              ),
              _buildListTile(
                context: context,
                icon: Icons.image_outlined,
                title: 'Đổi ảnh nhóm',
                subtitle: 'Thay đổi ảnh đại diện',
                onTap: () {
                  _changeGroupAvatar(context);
                },
              ),
              _buildListTile(
                context: context,
                icon: Icons.group_add_outlined,
                title: 'Thêm thành viên',
                subtitle: 'Mời thêm người vào nhóm',
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onAddMember != null) {
                    widget.onAddMember!();
                  }
                },
              ),
            ],

            // === CÀI ĐẶT THÔNG BÁO ===
            if (!widget.isBlocked) ...[
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
                value: _isMuted,
                activeColor: const Color(0xFF7A2FC0),
                onChanged: _isTogglingMute ? null : _handleToggleMute,
              ),
            ],

            // === CÀI ĐẶT CUỘC TRÒ CHUYỆN ===
            if (!widget.isDeletedAccount &&
                !widget.isBlocked &&
                !widget.isGroup)
              const SizedBox(height: 8),
            _buildSectionTitle('Cuộc trò chuyện'),
            if (!widget.isDeletedAccount &&
                !widget.isBlocked &&
                !widget.isGroup)
              _buildListTile(
                context: context,
                icon: Icons.group_outlined,
                title: 'Tạo nhóm với ${widget.chatName}',
                subtitle: 'Bắt đầu nhóm chat',
                onTap: () async {
                  Navigator.pop(context); // Close settings screen first

                  // Lấy ID của người bạn từ memberIds
                  String? friendId;
                  if (widget.memberIds != null &&
                      widget.currentUserId != null) {
                    friendId = widget.memberIds!.firstWhere(
                      (id) => id != widget.currentUserId,
                      orElse: () => '',
                    );
                  }

                  if (friendId == null || friendId.isEmpty) {
                    if (context.mounted) {
                      await ShowNotification.showToast(
                        context,
                        'Không tìm thấy người dùng',
                      );
                    }
                    return;
                  }

                  // Navigate tới CreateGroupScreen với friendId đã được pre-select
                  if (context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateGroupScreen(initialFriendId: friendId),
                      ),
                    );
                  }
                },
              ),

            // === CẢNH BÁO ===
            if (!widget.isGroup) ...[
              const SizedBox(height: 8),
              _buildSectionTitle('Cảnh báo'),
              _buildListTile(
                context: context,
                icon: Icons.block,
                title: widget.isBlocked
                    ? 'Bỏ chặn người dùng'
                    : 'Chặn người dùng',
                subtitle: widget.isBlocked
                    ? 'Gỡ chặn người dùng này'
                    : 'Chặn tin nhắn và cuộc gọi',
                titleColor: const Color(0xFFFF5252),
                iconColor: const Color(0xFFFF5252),
                onTap: !widget.isDeletedAccount && !widget.isBlocked
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

                        if (widget.onBlockUser != null &&
                            widget.memberIds != null) {
                          String friendId = widget.memberIds!.firstWhere(
                            (id) => id != widget.currentUserId,
                            orElse: () => '',
                          );

                          if (friendId.isEmpty) {
                            await ShowNotification.showToast(
                              context,
                              'Không tìm thấy người dùng',
                            );
                            return;
                          }

                          widget.onBlockUser!(friendId);
                        }
                      }
                    : null,
              ),
            ],
            if (widget.isGroup)
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
                  try {
                    if (!result!) return;
                  } catch (e) {
                    print('Error in _leaveGroup: $e');
                  }

                  Navigator.pop(context);
                  if (widget.onLeaveGroup != null) {
                    widget.onLeaveGroup!();
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

                if (widget.onDeleteConversation != null) {
                  widget.onDeleteConversation!();
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
    final String fallbackUserAvatar = 'assets/none_images/avatar.jpg';
    final String fallbackGroupAvatar = 'assets/none_images/group.jpg';

    final String displayAvatarUrl = widget.avatarUrl?.isNotEmpty == true
        ? widget.avatarUrl!
        : (widget.isGroup ? fallbackGroupAvatar : fallbackUserAvatar);

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
              backgroundImage: displayAvatarUrl.startsWith('assets/')
                  ? AssetImage(displayAvatarUrl)
                  : NetworkImage(displayAvatarUrl),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.chatName ?? (widget.isGroup ? 'Nhóm' : 'Người dùng'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (widget.isGroup)
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
