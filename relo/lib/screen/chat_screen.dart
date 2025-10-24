import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:relo/widgets/message_list.dart';
import 'package:relo/widgets/message_composer.dart';
import 'package:relo/utils/message_utils.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:relo/utils/show_toast.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final bool isGroup;
  final String? friendName;
  final List<String>? memberIds;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.isGroup,
    this.friendName,
    this.memberIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = ServiceLocator.messageService;
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
    _webSocketSubscription = webSocketService.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'new_message') {
        final msgData = data['payload']?['message'];
        if (msgData == null) return;
        if (msgData['senderId'] == _currentUserId) return;
        if (msgData['conversationId'] != _conversationId) return;

        final newMsg = Message(
          id: msgData['id'] ?? '',
          conversationId: msgData['conversationId'],
          senderId: msgData['senderId'],
          content: msgData['content'] ?? '',
          timestamp:
              DateTime.tryParse(msgData['createdAt'] ?? '') ?? DateTime.now(),
          status: 'sent',
        );

        if (mounted) {
          setState(() {
            _messages.insert(0, newMsg);
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

  void _showMessageActions(Message message) {
    final isMe = message.senderId == _currentUserId;

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
                _ActionButton(
                  icon: LucideIcons.copy,
                  label: 'Sao chép',
                  color: const Color(0xFF4CAF50),
                  onTap: () async {
                    Navigator.pop(context);
                    Clipboard.setData(
                      ClipboardData(text: message.content['text']),
                    );
                    await showToast(
                      context,
                      'Đã sao chép văn bản vào bộ nhớ tạm',
                    );
                  },
                ),

              // Nút chuyển tiếp
              _ActionButton(
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
                _ActionButton(
                  icon: LucideIcons.trash2,
                  label: 'Thu hồi',
                  color: const Color(0xFFFF5252),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: logic thu hồi
                  },
                ),
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
                    widget.friendName ?? 'Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    const Text(
                      'Nhóm trò chuyện',
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
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              //TODO:
            },
            tooltip: 'Xem chi tiết',
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
                MessageComposer(
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

// Widget nút với hiệu ứng scale khi nhấn
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.9);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 28, color: widget.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(color: widget.color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
