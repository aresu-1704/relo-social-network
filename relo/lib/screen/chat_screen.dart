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
import 'package:relo/widgets/audio_message_bubble.dart';
import 'package:relo/widgets/media_message_bubble.dart';
import 'package:relo/widgets/text_message_bubble.dart';
import 'package:relo/widgets/message_composer.dart';
import 'package:relo/utils/message_utils.dart';

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
    // 👇 Nếu đang phát cùng audio thì dừng lại
    if (_currentlyPlayingUrl == url) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingUrl = null);
      return;
    }

    // 👇 Nếu đang phát cái khác thì dừng trước
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
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.isGroup)
                    const Text(
                      'Nhóm trò chuyện',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.white),
            onPressed: () {
              //TODO:
            },
            tooltip: 'Gọi thoại',
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {
              //TODO:
            },
            tooltip: 'Gọi video',
          ),
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

                          final messageType = message.content['type'];

                          if (messageType == 'audio') {
                            final url = message.content['url'];
                            final isPlaying = _currentlyPlayingUrl == url;

                            return AudioMessageBubble(
                              message: message,
                              isMe: isMe,
                              isPlaying: isPlaying,
                              onPlay: () => _playAudio(url),
                            );
                          } else if (messageType == 'media') {
                            return MediaMessageBubble(
                              message: message,
                              isMe: isMe,
                            );
                          } else {
                            return TextMessageBubble(
                              message: message,
                              isMe: isMe,
                            );
                          }
                        },
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
    );
  }
}
