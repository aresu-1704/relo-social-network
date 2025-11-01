import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/user_service.dart';
import 'package:uuid/uuid.dart';
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
  final void Function()? onMuteToggled;

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
    this.onMuteToggled,
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

  // Mute notifications status
  bool _isMuted = false;

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

    _webSocketSubscription = ServiceLocator.websocketService.stream.listen((
      message,
    ) async {
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
          // Handle block/unblock events realtime
          final payload = data['payload'];
          if (payload == null) return;

          final blockedUserId = payload['user_id'] as String?;
          if (blockedUserId == null) return;

          // Kiểm tra xem event này có liên quan đến conversation hiện tại không
          bool isRelevant = false;

          if (!widget.isGroup) {
            // Chat 1-1: Luôn kiểm tra vì chỉ có 2 người trong conversation
            // Nếu blockedUserId là một trong những người tham gia, thì event này liên quan
            if (widget.memberIds != null) {
              isRelevant = widget.memberIds!.contains(blockedUserId);
            } else if (_memberIds != null) {
              isRelevant = _memberIds!.contains(blockedUserId);
            } else {
              // Fallback: Nếu không có memberIds, vẫn kiểm tra vì có thể là chat 1-1
              // Event bạn_were_blocked hoặc user_blocked luôn liên quan đến chat 1-1 hiện tại
              isRelevant = true; // Với chat 1-1, luôn kiểm tra
            }
          } else {
            // Chat nhóm: Kiểm tra xem blockedUserId có trong memberIds không
            isRelevant =
                _memberIds != null && _memberIds!.contains(blockedUserId);
          }

          if (isRelevant) {
            // Cập nhật block status ngay lập tức dựa trên event type
            if (data['type'] == 'you_were_blocked') {
              // Tôi bị chặn: set _isBlocked = true ngay lập tức
              if (mounted) {
                setState(() {
                  _isBlocked = true;
                  _isBlockedByMe = false; // Tôi bị chặn, không phải tôi chặn
                  _blockedUserId = blockedUserId;
                });
                print(
                  '🔔 You were blocked by user: $blockedUserId - UI updated immediately',
                );
              }
              // Sau đó check lại để đảm bảo chính xác
              await _checkBlockStatus();
            } else if (data['type'] == 'user_blocked') {
              // Tôi đã chặn người khác: set _isBlockedByMe = true ngay lập tức
              if (mounted) {
                setState(() {
                  _isBlocked = true;
                  _isBlockedByMe = true; // Tôi chặn người khác
                  _blockedUserId = blockedUserId;
                });
                print(
                  '🔔 You blocked user: $blockedUserId - UI updated immediately',
                );
              }
              // Sau đó check lại để đảm bảo chính xác
              await _checkBlockStatus();
            } else if (data['type'] == 'user_unblocked') {
              // Đã bỏ chặn: set _isBlocked = false ngay lập tức
              if (mounted) {
                setState(() {
                  _isBlocked = false;
                  _isBlockedByMe = false;
                });
                print(
                  '🔔 User unblocked: $blockedUserId - UI updated immediately',
                );
              }
              // Sau đó check lại để đảm bảo chính xác
              await _checkBlockStatus();
            } else {
              // Fallback: check block status như cũ
              await _checkBlockStatus();
            }
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
        // Load mute status from conversations list
        await _loadMuteStatus();
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

  Future<void> _loadMuteStatus() async {
    if (_currentUserId == null || _conversationId == null) return;
    try {
      final conversations = await _messageService.fetchConversations();
      final conversation = conversations.firstWhere(
        (c) => c['id'] == _conversationId,
        orElse: () => null,
      );
      if (conversation != null) {
        final participantsInfo = conversation['participantsInfo'] as List?;
        if (participantsInfo != null) {
          final myInfo = participantsInfo.firstWhere(
            (p) => p['userId'] == _currentUserId,
            orElse: () => null,
          );
          if (myInfo != null && mounted) {
            setState(() {
              _isMuted = myInfo['muteNotifications'] ?? false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading mute status: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    if (_currentUserId == null) return;

    try {
      if (!widget.isGroup) {
        // Chat 1-1: Check block status với user còn lại
        String? otherUserId;

        // Thử lấy từ widget.memberIds trước
        if (widget.memberIds != null && widget.memberIds!.isNotEmpty) {
          otherUserId = widget.memberIds!.firstWhere(
            (id) => id != _currentUserId && id.isNotEmpty,
            orElse: () => '',
          );
          if (otherUserId.isEmpty) otherUserId = null;
        }

        // Nếu không có, thử lấy từ _memberIds
        if (otherUserId == null &&
            _memberIds != null &&
            _memberIds!.isNotEmpty) {
          otherUserId = _memberIds!.firstWhere(
            (id) => id != _currentUserId && id.isNotEmpty,
            orElse: () => '',
          );
          if (otherUserId.isEmpty) otherUserId = null;
        }

        // Nếu vẫn không có, thử fetch từ conversation
        if (otherUserId == null && _conversationId != null) {
          try {
            final conversation = await _messageService.fetchConversationById(
              _conversationId!,
            );
            if (conversation != null) {
              final participants = List<Map<String, dynamic>>.from(
                conversation['participants'] ?? [],
              );
              final other = participants.firstWhere(
                (p) =>
                    (p['id']?.toString() ?? p['userId']?.toString() ?? '') !=
                    _currentUserId,
                orElse: () => <String, dynamic>{},
              );
              if (other.isNotEmpty) {
                otherUserId =
                    other['id']?.toString() ?? other['userId']?.toString();
              }
            }
          } catch (e) {
            // Ignore
          }
        }

        if (otherUserId != null && otherUserId.isNotEmpty) {
          try {
            final blockStatus = await _userService.checkBlockStatus(
              otherUserId,
            );

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
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogBuildContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Đổi tên nhóm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                // Text Field
                TextField(
                  controller: nameController,
                  enabled: !isLoading,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên nhóm mới',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF7A2FC0),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    counterText: '',
                  ),
                  maxLength: 50,
                  maxLines: 1,
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(dialogBuildContext),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: isLoading ? Colors.grey[400] : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) {
                                Navigator.pop(dialogBuildContext);
                                return;
                              }

                              setDialogState(() {
                                isLoading = true;
                              });

                              try {
                                await _messageService.updateGroupName(
                                  _conversationId!,
                                  newName,
                                );
                                if (context.mounted) {
                                  Navigator.pop(dialogBuildContext);
                                  if (mounted) {
                                    await ShowNotification.showToast(
                                      dialogContext,
                                      'Đã đổi tên nhóm',
                                    );
                                  }
                                }
                              } catch (e) {
                                setDialogState(() {
                                  isLoading = false;
                                });
                                if (mounted) {
                                  await ShowNotification.showToast(
                                    dialogContext,
                                    'Không thể đổi tên nhóm',
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A2FC0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      Map<String, dynamic> forwardContent;
      String? downloadedFilePath;
      List<String>? downloadedFilePaths;

      // Xử lý theo loại tin nhắn
      if (message.content['type'] == 'text') {
        // Forward text message
        forwardContent = {
          'type': 'text',
          'text': '[Chuyển tiếp] ${message.content['text']}',
        };
      } else if (message.content['type'] == 'audio' ||
          message.content['type'] == 'file') {
        // Forward audio hoặc file
        final url = message.content['url'] as String?;
        if (url == null || url.isEmpty) {
          // Nếu không có URL, forward như text thông báo
          forwardContent = {
            'type': 'text',
            'text': '[Chuyển tiếp] [${message.content['type']}]',
          };
        } else {
          // Download file từ URL về local
          try {
            downloadedFilePath = await _downloadFileForForward(url);
            forwardContent = {
              'type': message.content['type'],
              'path': downloadedFilePath,
            };
          } catch (e) {
            // Nếu download thất bại, forward như text thông báo
            if (mounted) {
              await ShowNotification.showToast(
                context,
                'Không thể tải file, chỉ chuyển tiếp thông báo',
              );
            }
            forwardContent = {
              'type': 'text',
              'text': '[Chuyển tiếp] [${message.content['type']}]',
            };
          }
        }
      } else if (message.content['type'] == 'media') {
        // Forward media (hình ảnh/video)
        final urls = message.content['urls'] as List<dynamic>?;
        if (urls == null || urls.isEmpty) {
          // Nếu không có URLs, forward như text thông báo
          forwardContent = {'type': 'text', 'text': '[Chuyển tiếp] [media]'};
        } else {
          // Download các file từ URLs về local
          try {
            downloadedFilePaths = [];
            for (var url in urls) {
              final filePath = await _downloadFileForForward(url.toString());
              downloadedFilePaths.add(filePath);
            }
            forwardContent = {'type': 'media', 'paths': downloadedFilePaths};
          } catch (e) {
            // Nếu download thất bại, forward như text thông báo
            if (mounted) {
              await ShowNotification.showToast(
                context,
                'Không thể tải file, chỉ chuyển tiếp thông báo',
              );
            }
            forwardContent = {'type': 'text', 'text': '[Chuyển tiếp] [media]'};
          }
        }
      } else {
        // Các loại khác, forward như text thông báo
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

      // Xóa các file tạm sau khi forward xong
      if (downloadedFilePath != null) {
        try {
          final file = File(downloadedFilePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore delete errors
        }
      }
      if (downloadedFilePaths != null) {
        for (var path in downloadedFilePaths) {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Ignore delete errors
          }
        }
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

  // Helper method để download file từ URL về local
  Future<String> _downloadFileForForward(String url) async {
    final dio = Dio();
    final tempDir = await getTemporaryDirectory();
    final fileName = url.split('/').last.split('?').first;
    final filePath =
        '${tempDir.path}/forward_${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await dio.download(url, filePath);
    return filePath;
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
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await ShowNotification.showConfirmDialog(
                      context,
                      title: 'Bạn có chắc muốn thu hồi tin nhắn này?',
                      cancelText: 'Hủy',
                      confirmText: 'Thu hồi',
                      confirmColor: const Color(0xFFFF5252),
                    );
                    if (confirm == true) {
                      await _recallMessage(message);
                    }
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
          isBlockedByMe: _isBlockedByMe,
          initialMuted: _isMuted,
          conversationId: _conversationId!,
          onMuteToggled: (muted) async {
            // Cập nhật local state
            setState(() {
              _isMuted = muted;
            });
            // Reload mute status từ server
            await _loadMuteStatus();
            // Callback để MessagesScreen reload conversations
            if (widget.onMuteToggled != null) {
              widget.onMuteToggled!();
            }
          },
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
