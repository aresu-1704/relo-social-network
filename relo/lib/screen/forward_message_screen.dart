import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/utils/format.dart';

class ForwardMessageScreen extends StatefulWidget {
  final Message message;
  final String conversationId;

  const ForwardMessageScreen({
    super.key,
    required this.message,
    required this.conversationId,
  });

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorageService = SecureStorageService();

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;
  Set<String> _selectedConversationIds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadConversations();
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = await _secureStorageService.getUserId();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _messageService.fetchConversations();
      // Filter out the current conversation and conversations without lastMessage
      final filteredConversations = conversations
          .where(
            (c) => c['id'] != widget.conversationId && c['lastMessage'] != null,
          )
          .map((c) => c as Map<String, dynamic>)
          .toList();

      setState(() {
        _conversations = filteredConversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể tải danh sách cuộc trò chuyện',
        );
      }
    }
  }

  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (_selectedConversationIds.contains(conversationId)) {
        _selectedConversationIds.remove(conversationId);
      } else {
        _selectedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _forwardMessage() async {
    if (_selectedConversationIds.isEmpty) {
      await ShowNotification.showToast(
        context,
        'Vui lòng chọn ít nhất 1 cuộc trò chuyện',
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context, _selectedConversationIds);
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
          _selectedConversationIds.isEmpty
              ? 'Chọn cuộc trò chuyện'
              : 'Đã chọn ${_selectedConversationIds.length}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      floatingActionButton: _selectedConversationIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _forwardMessage,
              backgroundColor: const Color(0xFF7A2FC0),
              child: const Icon(Icons.send, color: Colors.white),
            )
          : null,
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
            ? const Center(child: Text('Không có cuộc trò chuyện nào'))
            : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final isSelected = _selectedConversationIds.contains(
                    conversation['id'],
                  );

                  return _buildConversationItem(conversation, isSelected);
                },
              ),
      ),
    );
  }

  Widget _buildConversationItem(
    Map<String, dynamic> conversation,
    bool isSelected,
  ) {
    final participants = List<Map<String, dynamic>>.from(
      conversation['participants'] ?? [],
    );
    final otherParticipants = participants
        .where((p) => p['id'] != _currentUserId)
        .toList();

    String title;
    ImageProvider avatar;

    if (conversation['isGroup']) {
      title =
          conversation['name'] ??
          otherParticipants.map((p) => p['displayName']).join(", ");
      avatar = NetworkImage(
        conversation['avatarUrl'] ??
            'https://img.freepik.com/premium-vector/group-chat-icon-3d-vector-illustration-design_48866-1609.jpg',
      );
    } else {
      final friend = otherParticipants.first;
      final isDeletedAccount =
          friend['username'] == 'deleted' || friend['id'] == 'deleted';

      if (isDeletedAccount) {
        title = 'Tài khoản không tồn tại';
        avatar = const AssetImage('assets/icons/icon.png');
      } else {
        title = friend['displayName'];
        final avatarUrl = (friend['avatarUrl'] ?? '').isNotEmpty
            ? friend['avatarUrl']
            : 'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';
        avatar = NetworkImage(avatarUrl!);
      }
    }

    final lastMsg = conversation['lastMessage'];
    String lastMessage = 'Chưa có tin nhắn';
    if (lastMsg != null) {
      final isMe = _currentUserId == lastMsg['senderId'];
      final prefix = isMe ? 'Bạn: ' : '';
      final type = lastMsg['content']?['type'];
      final text = lastMsg['content']?['text'];
      switch (type) {
        case 'audio':
          lastMessage = '${prefix}[Tin nhắn thoại]';
          break;
        case 'media':
          lastMessage = '${prefix}[Đa phương tiện]';
          break;
        case 'file':
          lastMessage = '${prefix}[Tệp tin]';
          break;
        case 'delete':
          lastMessage = '${prefix}[Tin nhắn đã bị thu hồi]';
          break;
        default:
          lastMessage = '$prefix${text ?? 'Chưa có tin nhắn'}';
      }
    }

    final updatedAt = conversation['updatedAt'];

    return InkWell(
      onTap: () => _toggleConversationSelection(conversation['id']),
      child: Container(
        color: isSelected ? const Color(0xFFE8E0F5) : Colors.white,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(backgroundImage: avatar),
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A2FC0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFF7A2FC0) : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          trailing: updatedAt != null
              ? Text(
                  Format.formatZaloTime(updatedAt),
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                )
              : null,
        ),
      ),
    );
  }
}
