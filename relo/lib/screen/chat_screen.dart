import 'package:flutter/material.dart';
import 'package:relo/models/message.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

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

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _conversationId;
  String? _currentUserId;

  int _offset = 0;
  final int _limit = 50; // Giữ cố định
  bool _hasMore = true; // true: còn tin nhắn cũ, false: hết
  bool _showReachedTopNotification = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await _secureStorageService.getUserId();
      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        _conversationId = widget.conversationId;
      });

      if (_conversationId != null) {
        await _fetchMessages(isInitial: true);
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMessages({bool isInitial = false}) async {
    if (_conversationId == null) return;

    try {
      final newMessages = await _messageService.getMessages(
        _conversationId!,
        offset: _offset,
        limit: _limit,
      );

      if (!mounted) return;

      setState(() {
        if (newMessages.isEmpty) {
          _hasMore = false;
          return;
        }

        if (isInitial) {
          _messages
            ..clear()
            ..addAll(newMessages);
          _offset = newMessages.length; // Cập nhật offset = số tin đã load
        } else {
          _messages.insertAll(0, newMessages);
          _offset += newMessages.length; // Tăng offset
        }

        // Nếu số tin nhắn trả về < limit => hết tin nhắn
        if (newMessages.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch messages: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || _conversationId == null || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newMessages = await _messageService.getMessages(
        _conversationId!,
        offset: _offset,
        limit: _limit,
      );

      if (!mounted) return;

      if (newMessages.isEmpty) {
        debugPrint('⚠️ No more messages to load.');
        setState(() => _hasMore = false);
        return;
      }

      setState(() {
        _messages.insertAll(0, newMessages);
        _offset += newMessages.length;

        // Nếu số tin nhắn trả về < limit => hết tin nhắn
        if (newMessages.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    final position = _scrollController.position;
    final threshold = 200.0; // Vùng đệm để trigger load sớm hơn

    // Load thêm khi scroll gần đến đỉnh
    if (_hasMore && position.pixels >= position.maxScrollExtent - threshold) {
      _loadMoreMessages();
    }

    // Hiển thị thông báo khi đã ở đỉnh
    // `position.atEdge` is true at both ends. For a reversed list, the top is where `pixels > 0`.
    if (!_hasMore && position.atEdge && position.pixels > 0) {
      if (mounted && !_showReachedTopNotification) {
        setState(() {
          _showReachedTopNotification = true;
        });
        // Hide the notification after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showReachedTopNotification = false;
            });
          }
        });
      }
    }
  }

  void _sendMessage() async {
    if (_textController.text.trim().isEmpty || _conversationId == null) return;

    final content = _textController.text.trim();
    _textController.clear();

    // 1️⃣ Tạo message tạm thời với status pending
    final tempMessage = Message(
      id: _uuid.v4(),
      conversationId: _conversationId!,
      senderId: _currentUserId!,
      content: content,
      timestamp: DateTime.now(),
      status: 'pending',
    );

    setState(() {
      _messages.insert(0, tempMessage);
    });

    try {
      // 2️⃣ Gửi lên server
      final sentMessage = await _messageService.sendMessage(
        _conversationId!,
        content,
        _currentUserId!,
      );

      // 3️⃣ Cập nhật trạng thái thành sent
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = sentMessage.copyWith(status: 'sent');
          }
        });
      }
    } catch (_) {
      // Nếu gửi thất bại, đánh dấu failed
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = tempMessage.copyWith(status: 'failed');
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        title: Text(
          widget.friendName ?? 'Chat',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Thực hiện cuộc gọi thoại
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Thực hiện cuộc gọi video
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              // TODO: Hiển thị chi tiết cuộc trò chuyện
            },
          ),
          const SizedBox(width: 8), // khoảng cách cuối
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 232, 233, 235),
      body: Stack(
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
                            Text("Chưa có tin nhắn nào, hãy gửi một lời chào"),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoadingMore && index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final message = _messages[index];
                          final isMe = message.senderId == _currentUserId;
                          return _buildMessage(message, isMe);
                        },
                      ),
              ),
              _buildMessageComposer(),
            ],
          ),
          // Animated notification widget
          AnimatedOpacity(
            opacity: _showReachedTopNotification ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color.fromARGB(255, 8, 235, 57).withOpacity(0.7),
              child: const Text(
                'Bạn đã đến đỉnh',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Message message, bool isMe) {
    final alignment = isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bubbleColor = isMe
        ? (message.status == 'pending'
              ? const Color.fromARGB(255, 156, 156, 156)
              : message.status == 'failed'
              ? Colors.redAccent
              : const Color.fromARGB(255, 155, 121, 214))
        : const Color(0xFFE5E7EB);
    final textColor = isMe ? Colors.white : Colors.black87;

    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: alignment,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                  ? NetworkImage(message.avatarUrl!)
                  : const NetworkImage(
                      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                    ),
            ),
          ),
        Flexible(
          child: IntrinsicWidth(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(color: textColor, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      if (isMe && message.status != 'sent')
                        Icon(
                          message.status == 'pending'
                              ? Icons.schedule
                              : Icons.error,
                          size: 14,
                          color: Colors.white70,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 2,
              color: Colors.grey.withOpacity(0.1),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () {},

              child: const Icon(
                Icons.emoji_emotions_outlined,
                color: Color(0xFF7C3AED),
              ),
            ),
            SizedBox(width: 8),
            InkWell(
              onTap: () {},
              child: const Icon(Icons.photo_outlined, color: Color(0xFF7C3AED)),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Tin nhắn',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF7C3AED)),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
