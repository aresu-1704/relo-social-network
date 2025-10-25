import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/screen/main_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/utils/format.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessageService messageService = ServiceLocator.messageService;
  final UserService userService = ServiceLocator.userService;
  final SecureStorageService _secureStorage = const SecureStorageService();
  StreamSubscription? _webSocketSubscription;
  String? _currentUserId;

  bool _isLoading = true;
  List<dynamic> conversations = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentUserId();
    await fetchConversations();
    _listenToWebSocket();
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = await _secureStorage.getUserId();
    if (mounted) {
      setState(() {});
    }
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen(
      (message) {
        final data = jsonDecode(message);

        // Assuming the server sends an event type
        if (data['type'] == 'new_message' ||
            data['type'] == 'conversation_seen' ||
            data['type'] == 'recalled_message') {
          // A new message has arrived, refresh the conversation list
          // A more optimized approach would be to update the specific conversation
          fetchConversations();
        }
      },
      onError: (error) {
        print("WebSocket Error: $error");
      },
    );
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchConversations() async {
    try {
      final fetchedConversations = await messageService.fetchConversations();
      if (mounted) {
        setState(() {
          conversations = fetchedConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasLastMessage = conversations.any((c) => c['lastMessage'] != null);

    if (!hasLastMessage || conversations.isEmpty) {
      return _buildEmptyState();
    }

    return _buildConversationList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 20),
          Text(
            'Bạn chưa có cuộc trò chuyện nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Hãy thử tìm vài người bạn để trò chuyện nhé'),
            onPressed: () {
              // Find the MainScreenState and call the method to change the tab
              context.findAncestorStateOfType<MainScreenState>()?.changeTab(2);
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFF7A2FC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final participants = List<Map<String, dynamic>>.from(
          conversation['participants'],
        );

        // Loại bỏ user hiện tại khỏi danh sách hiển thị
        final otherParticipants = participants
            .where((p) => p['id'] != _currentUserId)
            .toList();

        String title;
        ImageProvider avatar;

        if (conversation['isGroup']) {
          // Group chat
          title =
              conversation['name'] ??
              otherParticipants.map((p) => p['displayName']).join(", ");
          avatar = const AssetImage('assets/icons/group_icon.png');
        } else {
          // Chat 1-1
          final friend = otherParticipants.first;
          title = friend['displayName'];
          final avatarUrl = (friend['avatarUrl'] ?? '').isNotEmpty
              ? friend['avatarUrl']
              : 'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';

          avatar = NetworkImage(avatarUrl);
        }

        String lastMessage = 'Chưa có tin nhắn';

        final lastMsg = conversation['lastMessage'];
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
            case 'delete':
              lastMessage = '${prefix}[Tin nhắn đã bị thu hồi]';
              break;
            default:
              lastMessage = '$prefix${text ?? 'Chưa có tin nhắn'}';
          }
        }

        final updatedAt = conversation['updatedAt'];

        if (conversation['lastMessage'] == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(backgroundImage: avatar),
              title: Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight:
                      (
                      // Nếu tin nhắn cuối cùng do mình gửi → không cần in đậm
                      conversation['lastMessage']?['senderId'] ==
                              _currentUserId ||
                          // Hoặc nếu mình đã xem rồi → không cần in đậm
                          (conversation['seenIds'] != null &&
                              (conversation['seenIds'] as List).contains(
                                _currentUserId,
                              )))
                      ? FontWeight
                            .normal // đã đọc
                      : FontWeight.bold, // chưa đọc),
                ),
              ),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (
                    // Nếu tin nhắn cuối cùng do mình gửi → không cần in đậm
                    conversation['lastMessage']?['senderId'] ==
                            _currentUserId ||
                        // Hoặc nếu mình đã xem rồi → không cần in đậm
                        (conversation['seenIds'] != null &&
                            (conversation['seenIds'] as List).contains(
                              _currentUserId,
                            )))
                    ? TextStyle(
                        fontWeight: FontWeight.normal, // đã đọc
                        fontSize: 14,
                        color: Colors.grey,
                      )
                    : TextStyle(
                        fontWeight: FontWeight.bold, // chưa đọc
                        fontSize: 14,
                        color: Colors.black,
                      ),
              ),
              trailing: updatedAt != null
                  ? Text(
                      Format.formatZaloTime(updatedAt),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight:
                            (conversation['seenIds'] != null &&
                                (conversation['seenIds'] as List).contains(
                                  _currentUserId,
                                ) &&
                                conversation['lastMessage']?['senderId'] !=
                                    _currentUserId)
                            ? FontWeight
                                  .normal // đã đọc
                            : FontWeight.bold, // chưa đọc
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      conversationId: conversation['id'],
                      isGroup: conversation['isGroup'],
                      friendName: title,
                      memberIds: participants
                          .map((p) => p['id']?.toString() ?? '')
                          .where((id) => id.isNotEmpty)
                          .toList(),
                    ),
                  ),
                );
                // Đánh dấu cuộc trò chuyện là đã xem
                messageService.markAsSeen(conversation['id'], _currentUserId!);
              },
            ),
            const Divider(
              color: Color.fromARGB(255, 207, 205, 205),
              thickness: 1,
              indent: 70,
            ),
          ],
        );
      },
    );
  }
}
