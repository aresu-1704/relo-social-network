import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/models/user.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/screen/friend_requests_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<User>> _friendsFuture;
  late Future<List<Map<String, dynamic>>> _groupsFuture;
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  int requestCount = 0;

  bool _allImagesLoaded = false;
  bool _allGroupImagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _friendsFuture = _userService.getFriends();
      _groupsFuture = _messageService.fetchConversations().then((
        conversations,
      ) {
        try {
          // Filter only group conversations and convert to Map
          final groups = <Map<String, dynamic>>[];
          for (var c in conversations) {
            try {
              if (c is Map<String, dynamic> && c['isGroup'] == true) {
                groups.add(c);
              }
            } catch (e) {
              print('Error processing conversation: $e');
            }
          }
          return groups;
        } catch (e) {
          print('Error filtering groups: $e');
          return <Map<String, dynamic>>[];
        }
      });
    });

    // Load request count
    try {
      final requests = await _userService.getPendingFriendRequests();
      if (mounted) {
        setState(() {
          requestCount = requests.length;
        });
      }
    } catch (e) {
      print('Error loading request count: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, List<User>> _groupFriends(List<User> friends) {
    friends.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    final Map<String, List<User>> groupedFriends = {};
    for (var friend in friends) {
      if (friend.displayName.isNotEmpty) {
        final firstLetter = friend.displayName[0].toUpperCase();
        groupedFriends.putIfAbsent(firstLetter, () => []).add(friend);
      }
    }
    return groupedFriends;
  }

  Future<void> _preloadAllImages(List<User> friends) async {
    List<Future> tasks = [];
    for (var friend in friends) {
      if (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty) {
        final image = NetworkImage(friend.avatarUrl!);
        tasks.add(precacheImage(image, context));
      }
    }
    await Future.wait(tasks);
    setState(() {
      _allImagesLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Color(0xFF7A2FC0),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF7A2FC0),
            tabs: const [
              Tab(text: 'Bạn bè'),
              Tab(text: 'Nhóm'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFriendsTab(), _buildGroupsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _allImagesLoaded = false;
          _friendsFuture = _userService.getFriends();
        });
      },
      child: FutureBuilder<List<User>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList();
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text("Không thể tải danh sách bạn bè"));
          }

          final friends = snapshot.data!;
          if (!_allImagesLoaded) {
            _preloadAllImages(friends);
            return _buildShimmerList();
          }

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn chưa kết bạn với bất kỳ người dùng nào',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final groupedFriends = _groupFriends(friends);
          final sortedKeys = groupedFriends.keys.toList()..sort();

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final letter = sortedKeys[index];
              final friendsInGroup = groupedFriends[letter]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...friendsInGroup.map((friend) => _buildFriendTile(friend)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _allGroupImagesLoaded = false;
          _groupsFuture = _messageService.fetchConversations().then((
            conversations,
          ) {
            try {
              // Filter only group conversations and convert to Map
              final groups = <Map<String, dynamic>>[];
              for (var c in conversations) {
                try {
                  if (c is Map<String, dynamic> && c['isGroup'] == true) {
                    groups.add(c);
                  }
                } catch (e) {
                  print('Error processing conversation: $e');
                }
              }
              return groups;
            } catch (e) {
              print('Error filtering groups: $e');
              return <Map<String, dynamic>>[];
            }
          });
        });
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList();
          }

          if (snapshot.hasError) {
            print('Error loading groups: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Không thể tải danh sách nhóm"),
                  const SizedBox(height: 10),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.data == null) {
            return const Center(child: Text("Không thể tải danh sách nhóm"));
          }

          final groups = snapshot.data!;
          if (groups.isEmpty) {
            return const Center(child: Text("Bạn chưa tham gia nhóm nào"));
          }

          if (!_allGroupImagesLoaded) {
            _preloadGroupImages(groups);
            return _buildShimmerList();
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildGroupTile(group);
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(120),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  '   Bạn bè',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    // Navigate to friend requests screen
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FriendRequestsScreen(),
                      ),
                    );
                    // Reload data when back
                    _loadData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.group,
                            color: Color(0xFF7A2FC0),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lời mời kết bạn',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (requestCount > 0)
                                Text(
                                  '($requestCount)',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(User friend) {
    return InkWell(
      onTap: () async {
        if (!mounted) return;
        try {
          // Get current user ID
          final SecureStorageService secureStorage =
              const SecureStorageService();
          final currentUserId = await secureStorage.getUserId();

          final conversation = await _messageService.getOrCreateConversation(
            [currentUserId!, friend.id],
            false,
            null,
          );

          if (conversation.isEmpty || conversation['id'] == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Không thể tạo cuộc trò chuyện")),
              );
            }
            return;
          }

          final participants = (conversation['participants'] ?? []) as List;

          // Extract member IDs from participants
          List<String> memberIds = [];
          if (participants.isNotEmpty) {
            for (var p in participants) {
              if (p is Map) {
                String? id = p['id']?.toString() ?? p['userId']?.toString();
                if (id != null && id.isNotEmpty) {
                  memberIds.add(id);
                }
              } else if (p is String) {
                memberIds.add(p);
              }
            }
          }

          // Fallback to friend.id if no participants found
          if (memberIds.isEmpty) {
            memberIds = [friend.id];
          }

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  conversationId: conversation['id'],
                  isGroup: false,
                  chatName: friend.displayName,
                  memberIds: memberIds,
                  avatarUrl: friend.avatarUrl,
                  onUserBlocked: (blockedUserId) {
                    // Xóa user khỏi danh sách bạn bè và refresh
                    setState(() {
                      _friendsFuture = _userService.getFriends();
                    });
                  },
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Lỗi khi mở chat: $e")));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                  ? NetworkImage(friend.avatarUrl!)
                  : null,
              child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                  ? Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '#',
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                friend.displayName,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.grey),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: Colors.grey),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preloadGroupImages(List<Map<String, dynamic>> groups) async {
    List<Future> tasks = [];
    for (var group in groups) {
      if (group['avatarUrl'] != null &&
          group['avatarUrl'].toString().isNotEmpty) {
        try {
          final image = NetworkImage(group['avatarUrl'].toString());
          tasks.add(
            precacheImage(image, context).catchError((e) {
              print('Error preloading group image: $e');
            }),
          );
        } catch (e) {
          print('Error creating NetworkImage: $e');
        }
      }
    }
    await Future.wait(tasks);
    if (mounted) {
      setState(() {
        _allGroupImagesLoaded = true;
      });
    }
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    return InkWell(
      onTap: () async {
        if (!mounted) return;
        try {
          final groupId = group['id'] as String;
          final groupName = group['name'] as String? ?? 'Nhóm';
          final participants = group['participants'] as List? ?? [];

          List<String> memberIds = [];
          for (var p in participants) {
            if (p is Map) {
              String? id = p['id']?.toString() ?? p['userId']?.toString();
              if (id != null && id.isNotEmpty) {
                memberIds.add(id);
              }
            } else if (p is String) {
              memberIds.add(p);
            }
          }

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  conversationId: groupId,
                  isGroup: true,
                  chatName: groupName,
                  memberIds: memberIds,
                  avatarUrl: group['avatarUrl'],
                  onLeftGroup: () {
                    // Reload groups when back
                    if (mounted) {
                      setState(() {
                        _allGroupImagesLoaded = false;
                        _groupsFuture = _messageService.fetchConversations().then((
                          conversations,
                        ) {
                          try {
                            // Filter only group conversations and convert to Map
                            final groups = <Map<String, dynamic>>[];
                            for (var c in conversations) {
                              try {
                                if (c is Map<String, dynamic> &&
                                    c['isGroup'] == true) {
                                  groups.add(c);
                                }
                              } catch (e) {
                                print('Error processing conversation: $e');
                              }
                            }
                            return groups;
                          } catch (e) {
                            print('Error filtering groups: $e');
                            return <Map<String, dynamic>>[];
                          }
                        });
                      });
                    }
                  },
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Lỗi khi mở nhóm: $e")));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(
                group['avatarUrl'] ??
                    'https://img.freepik.com/premium-vector/group-chat-icon-3d-vector-illustration-design_48866-1609.jpg',
              ),
              onBackgroundImageError: (_, __) {},
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                group['name'] ?? 'Nhóm không có tên',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hiệu ứng shimmer khi đang tải dữ liệu hoặc ảnh
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListTile(
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
          ),
          title: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
          subtitle: Container(
            height: 14,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
    );
  }
}
