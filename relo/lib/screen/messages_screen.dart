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
import 'package:shimmer/shimmer.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

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
  bool _allImagesLoaded = false;
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
    if (mounted) setState(() {});
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen((message) {
      final data = jsonDecode(message);

      if (data['type'] == 'new_message') {
        final conversationData = data['payload']?['conversation'];
        if (conversationData != null) {
          final conversationId = conversationData['id'];
          final index = conversations.indexWhere(
            (c) => c['id'] == conversationId,
          );

          if (index != -1) {
            // Nếu conversation đã tồn tại, cập nhật nó
            setState(() {
              conversations[index]['lastMessage'] =
                  conversationData['lastMessage'];
              conversations[index]['updatedAt'] = conversationData['updatedAt'];
              conversations[index]['seenIds'] = conversationData['seenIds'];

              // Sắp xếp lại: chuyển conversation cập nhật lên đầu
              final updatedConv = conversations.removeAt(index);
              conversations.insert(0, updatedConv);
            });
          } else {
            // Nếu conversation mới, fetch lại
            fetchConversations();
          }
        }
      } else if (data['type'] == 'delete_conversation') {
        setState(() {
          conversations.removeWhere(
            (conv) => conv['id'] == data['payload']['conversationId'],
          );
        });
      } else if (data['type'] == 'recalled_message') {
        setState(() {
          final convoId = data['payload']['conversation']['id'];
          final updatedLastMessage =
              data['payload']['conversation']['lastMessage'];
          final index = conversations.indexWhere(
            (conv) => conv['id'] == convoId,
          );
          if (index != -1) {
            conversations[index]['lastMessage'] = updatedLastMessage;
          }
        });
      } else if (data['type'] == 'conversation_deleted') {
        final deletedConversationId = data['payload']['conversationId'];
        setState(() {
          conversations.removeWhere(
            (conv) => conv['id'] == deletedConversationId,
          );
        });
      }
    }, onError: (error) => print("WebSocket Error: $error"));
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateSeenStatus(String conversationId) async {
    final index = conversations.indexWhere((c) => c['id'] == conversationId);
    if (index != -1) {
      final seenIds = List<String>.from(conversations[index]['seenIds'] ?? []);
      if (!seenIds.contains(_currentUserId)) {
        setState(() {
          seenIds.add(_currentUserId!);
          conversations[index]['seenIds'] = seenIds;
        });
      }
    }
  }

  Future<void> fetchConversations() async {
    try {
      final fetchedConversations = await messageService.fetchConversations();
      if (!mounted) return;
      setState(() {
        conversations = fetchedConversations;
        _isLoading = false;
        _allImagesLoaded = false;
      });
      _preloadAvatars(fetchedConversations);
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _preloadAvatars(List<dynamic> fetchedConversations) async {
    List<Future> tasks = [];
    for (var conversation in fetchedConversations) {
      if (conversation['isGroup'] == false) {
        final participants = List<Map<String, dynamic>>.from(
          conversation['participants'],
        );
        final friend = participants.firstWhere(
          (p) => p['id'] != _currentUserId,
          orElse: () => {},
        );
        if (friend.isNotEmpty && (friend['avatarUrl'] ?? '').isNotEmpty) {
          tasks.add(precacheImage(NetworkImage(friend['avatarUrl']), context));
        }
      }
    }
    await Future.wait(tasks);
    if (mounted) setState(() => _allImagesLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_allImagesLoaded) {
      return _buildShimmerList();
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
          const SizedBox(height: 20),
          Text(
            'Bạn chưa có cuộc trò chuyện nào',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text(
              'Tìm bạn để trò chuyện',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            onPressed: () {
              context.findAncestorStateOfType<MainScreenState>()?.changeTab(2);
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF7A2FC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              minimumSize: const Size(0, 36),
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
            avatar = const AssetImage(
              'assets/icons/icon.png',
            ); // hoặc icon mặc định
          } else {
            title = friend['displayName'];
            final avatarUrl = (friend['avatarUrl'] ?? '').isNotEmpty
                ? friend['avatarUrl']
                : 'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';
            avatar = NetworkImage(avatarUrl);
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
        final seen = (conversation['seenIds'] ?? []).contains(_currentUserId);
        final isMine = lastMsg?['senderId'] == _currentUserId;

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
                  fontWeight: (isMine || seen)
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: (isMine || seen)
                      ? FontWeight.normal
                      : FontWeight.bold,
                  color: (isMine || seen) ? Colors.grey : Colors.black,
                  fontSize: 14,
                ),
              ),
              trailing: updatedAt != null
                  ? Text(
                      Format.formatZaloTime(updatedAt),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: (isMine || seen)
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    )
                  : null,
              onTap: () async {
                setState(() {
                  final index = conversations.indexWhere(
                    (c) => c['id'] == conversation['id'],
                  );
                  if (index != -1) {
                    final seenList = List<String>.from(
                      conversations[index]['seenIds'] ?? [],
                    );
                    if (!seenList.contains(_currentUserId)) {
                      seenList.add(_currentUserId!);
                      conversations[index]['seenIds'] = seenList;
                    }
                  }
                });
                final conversationId = conversation['id'];
                final isGroup = conversation['isGroup'];

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      conversationId: conversationId,
                      isGroup: isGroup,
                      chatName: title,
                      memberIds: participants
                          .map((p) => p['id']?.toString() ?? '')
                          .where((id) => id.isNotEmpty)
                          .toList(),
                      memberCount: conversation['participants'].length,
                      onConversationSeen: _updateSeenStatus,
                      onLeftGroup: () {
                        // Xóa conversation khỏi danh sách khi rời nhóm
                        setState(() {
                          conversations.removeWhere(
                            (c) => c['id'] == conversationId,
                          );
                        });
                      },
                    ),
                  ),
                );
                messageService.markAsSeen(conversation['id'], _currentUserId!);
              },
            ),
            const Divider(color: Color(0xFFD0D0D0), thickness: 1, indent: 70),
          ],
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListTile(
          leading: const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
          ),
          title: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          subtitle: Container(
            height: 12,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
    );
  }
}
