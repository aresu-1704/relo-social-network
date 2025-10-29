import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/websocket_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/utils/format.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:relo/providers/message_provider.dart';

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
    // Refresh message provider count khi vào màn hình
    if (mounted) {
      final messageProvider = Provider.of<MessageProvider>(
        context,
        listen: false,
      );
      messageProvider.refresh();
    }
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = await _secureStorage.getUserId();
    if (mounted) setState(() {});
  }

  void _listenToWebSocket() {
    // Cancel subscription cũ nếu có
    _webSocketSubscription?.cancel();

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

            // Cập nhật message provider count
            final messageProvider = Provider.of<MessageProvider>(
              context,
              listen: false,
            );
            messageProvider.refresh();
          } else {
            // Nếu conversation mới, fetch lại toàn bộ danh sách
            // Điều này thường xảy ra khi người dùng được thêm vào nhóm mới
            Future.microtask(() => fetchConversations());
          }
        }
      } else if (data['type'] == 'conversation_updated') {
        // Xử lý khi conversation được cập nhật (ví dụ: đổi avatar, thêm thành viên)
        final conversationData = data['payload']?['conversation'];
        if (conversationData != null) {
          final conversationId = conversationData['id'];
          final index = conversations.indexWhere(
            (c) => c['id'] == conversationId,
          );

          if (index != -1) {
            // Cập nhật conversation hiện có
            setState(() {
              if (conversationData['avatarUrl'] != null) {
                conversations[index]['avatarUrl'] =
                    conversationData['avatarUrl'];
              }
              // Cập nhật mute status nếu có
              if (conversationData['participantsInfo'] != null) {
                conversations[index]['participantsInfo'] =
                    conversationData['participantsInfo'];
              }
            });
          } else {
            // Nếu không tìm thấy, reload danh sách
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
        String? avatarUrl; // Store avatar URL

        if (conversation['isGroup']) {
          title =
              conversation['name'] ??
              otherParticipants.map((p) => p['displayName']).join(", ");
          avatarUrl =
              conversation['avatarUrl'] ??
              'https://img.freepik.com/premium-vector/group-chat-icon-3d-vector-illustration-design_48866-1609.jpg';
          avatar = NetworkImage(avatarUrl!);
        } else {
          final friend = otherParticipants.first;
          final isDeletedAccount =
              friend['username'] == 'deleted' || friend['id'] == 'deleted';

          if (isDeletedAccount) {
            title = 'Tài khoản không tồn tại';
            avatarUrl = null;
            avatar = const AssetImage(
              'assets/icons/icon.png',
            ); // hoặc icon mặc định
          } else {
            title = friend['displayName'];
            avatarUrl = (friend['avatarUrl'] ?? '').isNotEmpty
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
        final seen = (conversation['seenIds'] ?? []).contains(_currentUserId);
        final isMine = lastMsg?['senderId'] == _currentUserId;

        // Lấy mute status từ participantsInfo
        final participantsInfo = conversation['participantsInfo'] as List?;
        bool isMuted = false;
        if (participantsInfo != null && _currentUserId != null) {
          final myInfo = participantsInfo.firstWhere(
            (p) => p['userId'] == _currentUserId,
            orElse: () => null,
          );
          if (myInfo != null) {
            isMuted = myInfo['muteNotifications'] ?? false;
          }
        }

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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMuted)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.notifications_off,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              Format.formatZaloTime(updatedAt),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: (isMine || seen)
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            if (!isMine && !seen)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : isMuted
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.notifications_off,
                        size: 16,
                        color: Colors.grey[600],
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
                      avatarUrl: avatarUrl,
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
                      onMuteToggled: () {
                        // Reload conversations để cập nhật mute icon
                        fetchConversations();
                      },
                    ),
                  ),
                );
                messageService.markAsSeen(conversation['id'], _currentUserId!);
                // Cập nhật message provider sau khi mark as seen
                final messageProvider = Provider.of<MessageProvider>(
                  context,
                  listen: false,
                );
                messageProvider.refresh();
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
