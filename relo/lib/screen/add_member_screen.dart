import 'package:flutter/material.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/utils/show_notification.dart';

class AddMemberScreen extends StatefulWidget {
  final String conversationId;
  final List<String> currentMemberIds;

  const AddMemberScreen({
    super.key,
    required this.conversationId,
    required this.currentMemberIds,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;

  List<User> _friends = [];
  List<User> _filteredFriends = [];
  bool _isLoading = true;
  Set<String> _selectedFriendIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      // Filter out current members
      final availableFriends = friends.where((friend) {
        return !widget.currentMemberIds.contains(friend.id);
      }).toList();

      setState(() {
        _friends = availableFriends;
        _filteredFriends = availableFriends;
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

  Future<void> _addMembers() async {
    if (_selectedFriendIds.isEmpty) {
      await ShowNotification.showToast(
        context,
        'Vui lòng chọn ít nhất 1 bạn bè',
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

      // Add each selected member to the group
      for (final memberId in _selectedFriendIds) {
        try {
          await _messageService.addMemberToGroup(
            widget.conversationId,
            memberId,
          );
        } catch (e) {
          print('Failed to add member $memberId: $e');
        }
      }

      // Navigate back
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pop(); // Close add member screen
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await ShowNotification.showToast(
          context,
          'Không thể thêm thành viên: $e',
        );
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
              ? 'Thêm thành viên'
              : 'Đã chọn ${_selectedFriendIds.length}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          if (_selectedFriendIds.isNotEmpty)
            TextButton(
              onPressed: _addMembers,
              child: const Text(
                'Thêm',
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
                  ? const Center(child: Text('Không có bạn bè nào để thêm'))
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
        color: isSelected ? const Color(0xFFE8E0F5) : Colors.white,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
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
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A2FC0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            friend.displayName,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFF7A2FC0) : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
