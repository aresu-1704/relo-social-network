import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/user_service.dart';
import 'package:uuid/uuid.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:relo/widgets/messages/message_list.dart';
import 'package:relo/widgets/messages/message_composer.dart';
import 'package:relo/utils/message_utils.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/widgets/action_button.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:relo/widgets/messages/block_composer.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final String? chatName;
  final List<String>? memberIds;
  final int? memberCount;

  final void Function(String conversationId)? onConversationSeen;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.isGroup,
    this.chatName,
    this.memberIds,
    this.onConversationSeen,
    this.memberCount,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = ServiceLocator.messageService;
  final UserService _userService = ServiceLocator.userService;
  final SecureStorageService _secureStorageService = SecureStorageService();
  final Uuid _uuid = const Uuid();

  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  StreamSubscription? _webSocketSubscription;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _conversationId;
  String? _currentUserId;
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;
  bool _showReachedTopNotification = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;

  // Block status
  bool _isBlocked = false;
  bool _isBlockedByMe = false;
  String? _blockedUserId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _webSocketSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen((message) async {
      final data = jsonDecode(message);
      if (data['type'] == 'new_message') {
        final msgData = data['payload']?['message'];
        if (msgData == null) return;

        // Nếu message từ chính mình, không cần xử lý
        if (msgData['senderId'] == _currentUserId) return;

        // Chỉ xử lý message từ conversation hiện tại
        if (msgData['conversationId'] != _conversationId) return;

        // Mark as seen khi message đến từ conversation đang mở
        await _messageService.markAsSeen(_conversationId!, _currentUserId!);
        widget.onConversationSeen?.call(_conversationId!);

        final newMsg = Message(
          id: msgData['id'] ?? '',
          conversationId: msgData['conversationId'],
          senderId: msgData['senderId'],
          content: msgData['content'] ?? '',
          avatarUrl: msgData['avatarUrl'] ?? '',
          timestamp:
              DateTime.tryParse(msgData['createdAt'] ?? '') ?? DateTime.now(),
          status: 'sent',
        );

        if (mounted) {
          setState(() {
            _messages.insert(0, newMsg);
          });
        }
      } else if (data['type'] == 'recalled_message') {
        final msgData = data['payload']?['message'];
        if (msgData == null) return;

        final messageId = msgData['id'];
        final index = _messages.indexWhere((m) => m.id == messageId);

        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(
              content: {'type': 'delete'},
            );
          });
        }
      }
    }, onError: (error) => print("WebSocket Error: $error"));
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _secureStorageService.getUserId();
      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        _conversationId = widget.conversationId;
      });

      if (_conversationId != null) {
        await _loadMessages(isInitial: true);
        // Check block status asynchronously after loading messages
        _checkBlockStatus();
      } else {
        throw Exception("Could not establish a conversation.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBlockStatus() async {
    if (_currentUserId == null) return;

    try {
      if (!widget.isGroup && widget.memberIds != null) {
        // Chat 1-1: Check block status với user còn lại
        try {
          String otherUserId = widget.memberIds!.firstWhere(
            (id) => id != _currentUserId,
            orElse: () => '',
          );

          if (otherUserId.isEmpty) {
            return;
          }

          final blockStatus = await _userService.checkBlockStatus(otherUserId);

          if (mounted) {
            setState(() {
              _isBlocked = blockStatus['isBlocked'] ?? false;
              _isBlockedByMe = blockStatus['isBlockedByMe'] ?? false;
              _blockedUserId = otherUserId;
            });
          }
        } catch (e) {
          // Ignore errors
        }
      } else if (widget.isGroup && widget.memberIds != null) {
        // Chat nhóm: Check xem có ai trong group bị mình block không
        List<String> blockedInGroup = [];

        for (String memberId in widget.memberIds!) {
          if (memberId != _currentUserId) {
            try {
              final blockStatus = await _userService.checkBlockStatus(memberId);
              if (blockStatus['isBlockedByMe'] ?? false) {
                blockedInGroup.add(memberId);
              }
            } catch (e) {
              // Ignore errors
            }
          }
        }

        if (blockedInGroup.isNotEmpty && mounted) {
          // Show confirm dialog
          await _showGroupBlockDialog();
        }
      }
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  Future<void> _showGroupBlockDialog() async {
    if (!mounted) return;

    final result = await ShowNotification.showConfirmDialog(
      context,
      title:
          'Có thành viên trong danh sách chặn trong nhóm. Bạn có muốn rời nhóm?',
      confirmText: 'Rời nhóm',
      cancelText: 'Ở lại',
      confirmColor: Colors.red,
    );

    if (result == true && mounted) {
      // TODO: Logic rời nhóm
      await ShowNotification.showToast(
        context,
        'Chức năng rời nhóm đang được phát triển',
      );
      Navigator.pop(context);
    }
  }

  Future<void> _loadMessages({bool isInitial = false}) async {
    if (_conversationId == null) return;
    if (!isInitial && (_isLoadingMore || !_hasMore)) return;

    if (!isInitial) setState(() => _isLoadingMore = true);

    try {
      final newMessages = await _messageService.getMessages(
        _conversationId!,
        offset: _offset,
        limit: _limit,
      );

      if (!mounted) return;
      setState(() {
        if (isInitial) _messages.clear();
        if (newMessages.isEmpty) {
          _hasMore = false;
        } else {
          _messages.insertAll(0, newMessages);
          _offset += newMessages.length;
          if (newMessages.length < _limit) _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
        );
      }
    } finally {
      if (!isInitial && mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final position = _scrollController.position;
    final threshold = 200.0;

    if (_hasMore && position.pixels >= position.maxScrollExtent - threshold) {
      _loadMessages();
    }

    if (!_hasMore && position.atEdge && position.pixels > 0) {
      if (mounted && !_showReachedTopNotification) {
        setState(() => _showReachedTopNotification = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showReachedTopNotification = false);
        });
      }
    }
  }

  void _playAudio(String url) async {
    if (_currentlyPlayingUrl == url) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingUrl = null);
      return;
    }

    if (_currentlyPlayingUrl != null) {
      await _audioPlayer.stop();
    }

    setState(() => _currentlyPlayingUrl = url);

    await _audioPlayer.play(UrlSource(url));

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _currentlyPlayingUrl = null);
      }
    });
  }

  Future<void> _recallMessage(Message message) async {
    try {
      // Call the service to recall the message
      await _messageService.recallMessage(message);

      // Update UI based on message status
      if (message.status == 'pending' || message.status == 'failed') {
        // If the message was pending or failed, it was deleted locally.
        // Remove it from the list to update the UI instantly.
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      } else {
        // If the message was sent, the websocket event will update the UI for all users.
        // For the current user, we can update it immediately.
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(
              content: {'type': 'delete'},
            );
          });
        }
      }
    } catch (e) {
      await ShowNotification.showToast(
        context,
        'Thu hồi tin nhắn thất bại: ${e.toString()}',
      );
    }
  }

  void _showMessageActions(Message message) {
    final isMe = message.senderId == _currentUserId;
    final isDeletedAccount = message.senderId == 'deleted';

    // Không hiển thị actions cho tin nhắn từ tài khoản đã bị xóa
    if (isDeletedAccount) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (message.content['type'] == 'text')
                // Nút sao chép
                ActionButton(
                  icon: LucideIcons.copy,
                  label: 'Sao chép',
                  color: const Color(0xFF4CAF50),
                  onTap: () async {
                    Navigator.pop(context);
                    Clipboard.setData(
                      ClipboardData(text: message.content['text']),
                    );
                    await ShowNotification.showToast(
                      context,
                      'Đã sao chép văn bản vào bộ nhớ tạm',
                    );
                  },
                ),

              // Nút chuyển tiếp
              ActionButton(
                icon: LucideIcons.share2, // icon mới gọn, đẹp hơn
                label: 'Chuyển tiếp',
                color: const Color(0xFF2979FF),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: logic chuyển tiếp
                },
              ),

              // Nút thu hồi (chỉ hiện với tin nhắn của mình)
              if (isMe)
                ActionButton(
                  icon: LucideIcons.trash2,
                  label: 'Thu hồi',
                  color: const Color(0xFFFF5252),
                  onTap: () {
                    Navigator.pop(context);
                    _recallMessage(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showConversationSettings() {
    // Kiểm tra nếu đang chat với tài khoản đã bị xóa
    final isDeletedAccount =
        widget.chatName == 'Tài khoản không tồn tại' ||
        (widget.memberIds != null && widget.memberIds!.contains('deleted'));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // Danh sách nút hành động động
        final actions = <ActionButton>[
          if (!widget.isGroup && !isDeletedAccount && !_isBlocked)
            ActionButton(
              icon: LucideIcons.userCircle2,
              label: 'Xem trang cá nhân',
              color: const Color(0xFF2979FF),
              onTap: () async {
                Navigator.pop(context);
                String friendId = widget.memberIds!.firstWhere(
                  (id) => id != _currentUserId,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ProfileScreen(userId: friendId);
                    },
                  ),
                );
              },
            ),
          if (!_isBlocked)
            ActionButton(
              icon: LucideIcons.bellOff,
              label: 'Tắt thông báo',
              color: const Color(0xFF2979FF),
              onTap: () async {
                final result = await ShowNotification.showConfirmDialog(
                  context,
                  title: 'Tắt thông báo cuộc trò chuyện ?',
                  confirmText: 'Đồng ý',
                  confirmColor: Colors.red,
                );

                if (!result!) return;
                Navigator.pop(context);
                // TODO: logic tắt thông báo
              },
            ),
          if (widget.isGroup)
            ActionButton(
              icon: LucideIcons.edit3,
              label: 'Đổi tên nhóm',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pop(context);
                // TODO: logic đổi tên nhóm
              },
            )
          else if (!isDeletedAccount && !_isBlocked)
            ActionButton(
              icon: LucideIcons.users,
              label: 'Tạo nhóm với ${widget.chatName}',
              color: const Color(0xFF00BCD4),
              onTap: () {
                Navigator.pop(context);
                // TODO: logic tạo nhóm
              },
            ),
          if (widget.isGroup)
            ActionButton(
              icon: LucideIcons.logOut,
              label: 'Rời nhóm',
              color: const Color(0xFFFF5722),
              onTap: () async {
                final result = await ShowNotification.showConfirmDialog(
                  context,
                  title: 'Bạn muốn rời khỏi cuộc trò chuyện ?',
                  confirmText: 'Đồng ý',
                  confirmColor: Colors.red,
                );

                if (!result!) return;
                // TODO: logic rời nhóm
              },
            )
          else if (!isDeletedAccount && !_isBlocked)
            ActionButton(
              icon: LucideIcons.userX,
              label: 'Chặn người dùng',
              color: const Color(0xFFFF5252),
              onTap: () async {
                final result = await ShowNotification.showConfirmDialog(
                  context,
                  title: 'Bạn muốn chặn người dùng này ?',
                  confirmText: 'Đồng ý',
                  confirmColor: Colors.red,
                );

                if (!result!) return;
                Navigator.pop(context);

                // Logic chặn người dùng
                try {
                  String friendId = widget.memberIds!.firstWhere(
                    (id) => id != _currentUserId,
                    orElse: () => '',
                  );

                  if (friendId.isEmpty) {
                    if (mounted) {
                      await ShowNotification.showToast(
                        context,
                        'Không tìm thấy người dùng',
                      );
                    }
                    return;
                  }

                  await _userService.blockUser(friendId);

                  if (mounted) {
                    await ShowNotification.showToast(
                      context,
                      'Đã chặn người dùng',
                    );
                    // Quay về màn hình messages
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    await ShowNotification.showToast(
                      context,
                      'Không thể chặn người dùng',
                    );
                  }
                }
              },
            ),
          ActionButton(
            icon: LucideIcons.trash2,
            label: 'Xóa cuộc trò chuyện',
            color: const Color(0xFFE91E63),
            onTap: () async {
              final result = await ShowNotification.showConfirmDialog(
                context,
                title: 'Xóa tin nhắn ?',
                confirmText: 'Xóa',
                confirmColor: Colors.red,
              );

              if (!result!) return;
              Navigator.pop(context);

              try {
                await _messageService.deleteConversation(_conversationId!);
                if (mounted) {
                  await ShowNotification.showToast(
                    context,
                    'Đã xóa cuộc trò chuyện',
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  await ShowNotification.showToast(
                    context,
                    'Không thể xóa cuộc trò chuyện',
                  );
                }
              }
            },
          ),
        ];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                VerticalActionButton(button: actions[i]),
                if (i != actions.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        backgroundColor: const Color(0xFF7A2FC0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName ?? 'Tài khoản không tồn tại',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    Text(
                      '${widget.memberCount!} thành viên',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings2, color: Colors.white),
            onPressed: () {
              _showConversationSettings();
            },
          ),
        ],
      ),

      backgroundColor: const Color.fromARGB(255, 232, 233, 235),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.message_outlined,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 20),
                              Text(
                                "Chưa có tin nhắn nào, hãy gửi một lời chào",
                              ),
                            ],
                          ),
                        )
                      : MessageList(
                          messages: _messages,
                          currentUserId: _currentUserId!,
                          isLoadingMore: _isLoadingMore,
                          hasMore: _hasMore,
                          scrollController: _scrollController,
                          currentlyPlayingUrl: _currentlyPlayingUrl,
                          onPlayAudio: _playAudio,
                          onMessageLongPress: _showMessageActions,
                        ),
                ),
                _isBlocked && !widget.isGroup
                    ? BlockComposer(
                        blockedUserId: _blockedUserId!,
                        chatName: widget.chatName ?? 'Người này',
                        isBlockedByMe: _isBlockedByMe,
                        onUnblockSuccess: () {
                          setState(() {
                            _isBlocked = false;
                            _isBlockedByMe = false;
                          });
                        },
                      )
                    : MessageComposer(
                        onSend: (content) => MessageUtils.performSend(
                          context,
                          _messageService,
                          _uuid,
                          _messages,
                          _conversationId!,
                          _currentUserId!,
                          content,
                          (updatedMessages) => setState(() {
                            _messages
                              ..clear()
                              ..addAll(updatedMessages);
                          }),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
