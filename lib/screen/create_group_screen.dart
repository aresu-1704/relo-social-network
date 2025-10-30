import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/utils/show_notification.dart';

class CreateGroupScreen extends StatefulWidget {
  final String? initialFriendId; // ID của người bạn sẽ được pre-select

  const CreateGroupScreen({super.key, this.initialFriendId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorageService = SecureStorageService();

  List<User> _friends = [];
  List<User> _filteredFriends = [];
  bool _isLoading = true;
  Set<String> _selectedFriendIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-select initial friend nếu có
    if (widget.initialFriendId != null) {
      _selectedFriendIds.add(widget.initialFriendId!);
    }
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _userService.getFriends();

      // Đảm bảo initialFriendId vẫn được select sau khi load friends
      final selectedIds = Set<String>.from(_selectedFriendIds);
      if (widget.initialFriendId != null &&
          widget.initialFriendId!.isNotEmpty) {
        // Kiểm tra xem initialFriendId có trong danh sách bạn bè không
        final friendExists = friends.any((f) => f.id == widget.initialFriendId);
        if (friendExists) {
          selectedIds.add(widget.initialFriendId!);
        }
      }

      setState(() {
        _friends = friends;
        _filteredFriends = friends;
        _selectedFriendIds = selectedIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể tải danh sách bạn bè',
        );
      }
    }
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((friend) {
          return friend.displayName.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              friend.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
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

  void _toggleFriendSelection(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _createGroup() async {
    // Tính tổng số người: current user + selected friends
    final totalMembers = 1 + _selectedFriendIds.length;

    // Cần ít nhất 3 người (1 người dùng hiện tại + 2 bạn bè)
    if (totalMembers < 3) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: 'Vui lòng chọn ít nhất 2 bạn bè để tạo nhóm',
        buttonText: 'Đóng',
        buttonColor: const Color(0xFF7A2FC0),
      );
      return;
    }

    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get current user ID
      final currentUserId = await _secureStorageService.getUserId();
      if (currentUserId == null) {
        throw Exception('Không thể lấy thông tin người dùng');
      }

      // Create participant list (current user + selected friends)
      final participantIds = [currentUserId, ..._selectedFriendIds.toList()];

      // Create group with default name
      final conversation = await _messageService.getOrCreateConversation(
        participantIds,
        true, // isGroup
        'Cuộc trò chuyện', // Default group name
      );

      if (conversation.isEmpty || conversation['id'] == null) {
        throw Exception('Không thể tạo nhóm');
      }

      // Navigate to chat screen
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Close create group screen và navigate tới ChatScreen mới
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation['id'],
              isGroup: true,
              chatName: 'Nhóm mới',
              memberIds: participantIds,
              memberCount: participantIds.length,
              avatarUrl: conversation['avatarUrl'],
            ),
          ),
        );

        // Show success toast
        await ShowNotification.showToast(
          context,
          'Nhóm đã được tạo thành công',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await ShowNotification.showToast(context, 'Không thể tạo nhóm: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _selectedFriendIds.isEmpty
              ? 'Tạo nhóm'
              : 'Đã chọn ${_selectedFriendIds.length}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          if (_selectedFriendIds.isNotEmpty)
            TextButton(
              onPressed: _createGroup,
              child: const Text(
                'Tạo',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: Column(
          children: [
            // Search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    cursorColor: const Color(0xFF7A2FC0),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm bạn bè',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            // Friends list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFriends.isEmpty
                  ? const Center(child: Text('Không tìm thấy bạn bè'))
                  : _buildGroupedFriendsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedFriendsList() {
    final groupedFriends = _groupFriends(_filteredFriends);
    final sortedKeys = groupedFriends.keys.toList()..sort();

    return ListView.builder(
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
            ...friendsInGroup.map((friend) => _buildFriendItem(friend)),
          ],
        );
      },
    );
  }

  Widget _buildFriendItem(User friend) {
    final isSelected = _selectedFriendIds.contains(friend.id);

    return InkWell(
      onTap: () => _toggleFriendSelection(friend.id),
      child: Container(
        color: isSelected ? Colors.grey[300] : Colors.white,
        child: ListTile(
          leading: CircleAvatar(
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
          title: Text(
            friend.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF7A2FC0) : Colors.grey,
                width: 2,
              ),
              color: isSelected ? const Color(0xFF7A2FC0) : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ),
      ),
    );
  }
}
