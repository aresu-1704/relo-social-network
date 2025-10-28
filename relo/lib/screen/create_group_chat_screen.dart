import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:relo/utils/show_toast.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorage = SecureStorageService();
  final TextEditingController _groupNameController = TextEditingController();
  
  List<User> _friends = [];
  Set<String> _selectedFriendIds = Set<String>();
  bool _isLoadingFriends = true;
  bool _isCreating = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadFriends();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = await _secureStorage.getUserId();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _userService.getFriends();
      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFriends = false;
      });
      if (mounted) {
        await showToast(context, 'Không thể tải danh sách bạn bè');
      }
    }
  }


  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      if (mounted) {
        await showToast(context, 'Vui lòng nhập tên nhóm');
      }
      return;
    }

    if (_selectedFriendIds.isEmpty) {
      if (mounted) {
        await showToast(context, 'Vui lòng chọn ít nhất một bạn bè để thêm vào nhóm');
      }
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Create group conversation (backend automatically adds current user)
      final conversation = await _messageService.getOrCreateConversation(
        _selectedFriendIds.toList(),
        true, // isGroup
        _groupNameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isCreating = false;
        });

        // Get all participant IDs (including current user)
        final allParticipantIds = [..._selectedFriendIds];
        if (_currentUserId != null) {
          allParticipantIds.add(_currentUserId!);
        }

        // Navigate to the new group chat
        Navigator.of(context).pop(); // Close this screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation['id'] ?? conversation['_id'],
              isGroup: true,
              chatName: _groupNameController.text.trim(),
              memberIds: allParticipantIds,
            ),
          ),
        );

        await showToast(context, 'Đã tạo nhóm thành công');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        await showToast(context, 'Không thể tạo nhóm: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF7A2FC0),
        title: Text('Tạo nhóm chat'),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isCreating)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: Text(
                'Tạo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Group name input
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: 'Tên nhóm',
              hintText: 'Nhập tên nhóm',
              prefixIcon: Icon(Icons.group, color: Color(0xFF7A2FC0)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 24),
          
          // Friends list header
          Text(
            'Chọn bạn bè để thêm vào nhóm',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Đã chọn: ${_selectedFriendIds.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          
          // Friends list
          if (_isLoadingFriends)
            Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else if (_friends.isEmpty)
            Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 50, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Bạn chưa có bạn bè nào',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ))
          else
            ..._friends.map((friend) => _buildFriendTile(friend)),
        ],
      ),
    );
  }

  Widget _buildFriendTile(User friend) {
    final isSelected = _selectedFriendIds.contains(friend.id);
    final fallbackAvatarUrl = 'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFriendIds.remove(friend.id);
          } else {
            _selectedFriendIds.add(friend.id);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedFriendIds.add(friend.id);
                  } else {
                    _selectedFriendIds.remove(friend.id);
                  }
                });
              },
              activeColor: Color(0xFF7A2FC0),
            ),
            SizedBox(width: 12),
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                    ? friend.avatarUrl!
                    : fallbackAvatarUrl,
              ),
              onBackgroundImageError: (_, __) {},
              backgroundColor: Colors.grey[200],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '@${friend.username}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

