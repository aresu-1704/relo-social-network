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
import 'package:relo/screen/conversation_settings_screen.dart';
import 'package:relo/screen/forward_message_screen.dart';
import 'package:relo/screen/add_member_screen.dart';
import 'package:relo/screen/group_members_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final String? chatName;
  final List<String>? memberIds;
  final int? memberCount;
  final String? avatarUrl;

  final void Function(String conversationId)? onConversationSeen;
  final void Function()? onLeftGroup;
  final void Function(String userId)? onUserBlocked;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.isGroup,
    this.chatName,
    this.memberIds,
    this.onConversationSeen,
    this.memberCount,
    this.onLeftGroup,
    this.onUserBlocked,
    this.avatarUrl,
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

  // Member count (cho group chat)
  int? _memberCount;

  // Member IDs (cho group chat) - cập nhật realtime
  List<String>? _memberIds;

  @override
  void initState() {
    super.initState();
    _memberCount = widget.memberCount;
    _memberIds = widget.memberIds != null ? List.from(widget.memberIds!) : null;
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
    // Cancel subscription cũ nếu có
    _webSocketSubscription?.cancel();

    _webSocketSubscription = webSocketService.stream.listen((message) async {
      try {
        final data = jsonDecode(message);

        // Ignore friend_request_received events (not relevant to chat screen)
        if (data['type'] == 'friend_request_received') return;
        if (data['type'] == 'friend_request_accepted') return;
        if (data['type'] == 'friend_added') return;

        if (data['type'] == 'new_message') {
          final msgData = data['payload']?['message'];
          if (msgData == null) {
            print('ChatScreen: msgData is null');
            return;
          }

          // Nếu message từ chính mình, không cần xử lý
          if (msgData['senderId'] == _currentUserId) {
            return;
          }

          // Chỉ xử lý message từ conversation hiện tại
          if (msgData['conversationId'] != _conversationId) {
            return;
          }

          // Kiểm tra message đã tồn tại chưa để tránh duplicate
          final messageId = msgData['id'] ?? '';
          final existingIndex = _messages.indexWhere((m) => m.id == messageId);
          if (existingIndex != -1) return; // Message đã tồn tại, bỏ qua

          // Cập nhật số lượng thành viên và danh sách thành viên nếu có trong metadata hoặc conversation data
          final metadata = data['payload']?['metadata'];
          final conversationData = data['payload']?['conversation'];
          if (metadata != null) {
            setState(() {
              if (metadata['participantCount'] != null) {
                _memberCount = metadata['participantCount'];
              }
              if (metadata['participantIds'] != null && widget.isGroup) {
                _memberIds = List<String>.from(metadata['participantIds']);
              }
            });
          } else if (conversationData != null) {
            setState(() {
              if (conversationData['participantCount'] != null) {
                _memberCount = conversationData['participantCount'];
              }
              if (conversationData['participantIds'] != null &&
                  widget.isGroup) {
                _memberIds = List<String>.from(
                  conversationData['participantIds'],
                );
              }
            });
          }

          // Mark as seen khi message đến từ conversation đang mở
          await _messageService.markAsSeen(_conversationId!, _currentUserId!);
          widget.onConversationSeen?.call(_conversationId!);

          // Parse content - đảm bảo là Map
          final rawContent = msgData['content'];
          Map<String, dynamic> parsedContent;
          if (rawContent is Map<String, dynamic>) {
            parsedContent = rawContent;
          } else if (rawContent is String) {
            // Backward compatibility
            parsedContent = {'type': 'text', 'text': rawContent};
          } else {
            parsedContent = {'type': 'unsupported'};
          }

          final newMsg = Message(
            id: messageId,
            conversationId: msgData['conversationId'],
            senderId: msgData['senderId'],
            content: parsedContent,
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
        } else if (data['type'] == 'user_blocked' ||
            data['type'] == 'you_were_blocked' ||
            data['type'] == 'user_unblocked') {
          // Handle block/unblock events
          final payload = data['payload'];
          if (payload == null) return;

          final blockedUserId = payload['user_id'];

          // Only update if it's relevant to this conversation
          final isRelevant =
              _memberIds != null && _memberIds!.contains(blockedUserId);

          if (isRelevant) {
            // Re-check block status (silently, no toast)
            await _checkBlockStatus();
          }
        }
      } catch (e) {
        // Silently ignore unhandled websocket messages to prevent crashes
        print('ChatScreen: Unhandled WebSocket message type: ${e.toString()}');
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
      } else if (widget.isGroup && _memberIds != null) {
        // Chat nhóm: Check xem có ai trong group bị mình block không
        List<String> blockedInGroup = [];

        for (String memberId in _memberIds!) {
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
      _handleLeaveGroup();
    }
  }

  Future<void> _handleLeaveGroup() async {
    try {
      await _messageService.leaveGroup(_conversationId!);
      if (mounted) {
        await ShowNotification.showToast(context, 'Đã rời khỏi nhóm');

        // Gọi callback để xóa conversation khỏi message screen
        if (widget.onLeftGroup != null) {
          widget.onLeftGroup!();
        }

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Không thể rời nhóm');
      }
    }
  }

  Future<void> _showChangeGroupNameDialog() async {
    if (!mounted) return;

    final dialogContext = context; // Save context before showing dialog
    final TextEditingController nameController = TextEditingController(
      text: widget.chatName ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogBuildContext) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nhập tên nhóm mới'),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogBuildContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                Navigator.pop(dialogBuildContext);
                return;
              }

              Navigator.pop(dialogBuildContext);
              try {
                await _messageService.updateGroupName(
                  _conversationId!,
                  newName,
                );
                if (mounted) {
                  await ShowNotification.showToast(
                    dialogContext,
                    'Đã đổi tên nhóm',
                  );
                }
              } catch (e) {
                if (mounted) {
                  await ShowNotification.showToast(
                    dialogContext,
                    'Không thể đổi tên nhóm',
                  );
                }
              }
            },
            child: const Text('Đổi tên'),
          ),
        ],
      ),
    );
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
    try {
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
        if (mounted && _currentlyPlayingUrl == url) {
          setState(() => _currentlyPlayingUrl = null);
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() => _currentlyPlayingUrl = null);
      if (mounted) {
        await ShowNotification.showToast(context, 'Không thể phát audio');
      }
    }
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

  Future<void> _forwardMessage(
    Message message,
    Set<String> conversationIds,
  ) async {
    try {
      // Create forward content
      Map<String, dynamic> forwardContent;

      if (message.content['type'] == 'text') {
        forwardContent = {
          'type': 'text',
          'text': '[Chuyển tiếp] ${message.content['text']}',
        };
      } else {
        // For other message types, forward as text with a note
        forwardContent = {
          'type': 'text',
          'text': '[Chuyển tiếp] [${message.content['type']}]',
        };
      }

      // Send the forwarded message to each selected conversation
      for (final targetConversationId in conversationIds) {
        await _messageService.sendMessage(
          targetConversationId,
          forwardContent,
          _currentUserId!,
        );
      }

      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Đã chuyển tiếp đến ${conversationIds.length} cuộc trò chuyện',
        );
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể chuyển tiếp tin nhắn: ${e.toString()}',
        );
      }
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
                onTap: () async {
                  Navigator.pop(context);
                  final selectedConversations =
                      await Navigator.push<Set<String>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForwardMessageScreen(
                            message: message,
                            conversationId: _conversationId!,
                          ),
                        ),
                      );

                  if (selectedConversations != null &&
                      selectedConversations.isNotEmpty) {
                    await _forwardMessage(message, selectedConversations);
                  }
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
        (_memberIds != null && _memberIds!.contains('deleted'));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationSettingsScreen(
          isGroup: widget.isGroup,
          chatName: widget.chatName,
          avatarUrl: widget.avatarUrl,
          currentUserId: _currentUserId,
          memberIds: _memberIds,
          isDeletedAccount: isDeletedAccount,
          isBlocked: _isBlocked,
          conversationId: _conversationId!,
          onViewProfile: (friendId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfileScreen(userId: friendId, hideMessageButton: true),
              ),
            );
          },
          onAddMember: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddMemberScreen(
                  conversationId: _conversationId!,
                  currentMemberIds: _memberIds ?? [],
                ),
              ),
            );
          },
          onViewMembers: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupMembersScreen(
                  memberIds: _memberIds ?? [],
                  groupName: widget.chatName ?? 'Nhóm',
                ),
              ),
            );
          },
          onLeaveGroup: () {
            _handleLeaveGroup();
          },
          onChangeGroupName: () {
            _showChangeGroupNameDialog();
          },
          onBlockUser: (friendId) async {
            try {
              await _userService.blockUser(friendId);
              if (mounted) {
                await ShowNotification.showToast(context, 'Đã chặn người dùng');
                if (widget.onUserBlocked != null) {
                  widget.onUserBlocked!(friendId);
                }
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
          onDeleteConversation: () async {
            try {
              await _messageService.deleteConversation(_conversationId!);
              if (mounted) {
                await ShowNotification.showToast(
                  context,
                  'Đã xóa cuộc trò chuyện',
                );
                Navigator.of(context).pop(); // Back to messages screen
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
      ),
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
                  if (widget.isGroup && _memberCount != null)
                    Text(
                      '$_memberCount thành viên',
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
            icon: const Icon(LucideIcons.info, color: Colors.white),
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
