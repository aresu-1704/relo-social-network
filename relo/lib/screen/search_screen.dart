import 'dart:async';
import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _UserWithStatus {
  final User user;
  String status; // 'friends', 'pending_sent', 'pending_received', 'none', 'self'
  final Map<String, dynamic>? requestData;

  _UserWithStatus({
    required this.user,
    required this.status,
    this.requestData,
  });
}

class _SearchScreenState extends State<SearchScreen> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorageService = SecureStorageService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<_UserWithStatus> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false; // Để biết đã thực hiện tìm kiếm hay chưa

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _userService.searchUsers(query);
      
      // Check friend status for each user and include request data if pending_received
      final List<_UserWithStatus> resultsWithStatus = [];
      final incomingRequests = await _userService.getPendingFriendRequests();
      
      for (final user in results) {
        try {
          final status = await _userService.checkFriendStatus(user.id);
          
          // If status is pending_received, find the request data
          Map<String, dynamic>? requestData;
          if (status == 'pending_received') {
            try {
              requestData = incomingRequests.firstWhere(
                (req) => req['fromUserId'] == user.id,
              );
            } catch (e) {
              requestData = null;
            }
          }
          
          resultsWithStatus.add(_UserWithStatus(
            user: user,
            status: status,
            requestData: requestData,
          ));
        } catch (e) {
          print('Error checking friend status for user ${user.id}: $e');
          resultsWithStatus.add(_UserWithStatus(
            user: user,
            status: 'none',
          ));
        }
      }
      
      setState(() {
        _searchResults = resultsWithStatus;
      });
    } catch (e) {
      // Handle error, maybe show a snackbar
      print('Error searching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm người dùng...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(child: Text('Nhập để bắt đầu tìm kiếm.'));
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('Không có kết quả'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final userWithStatus = _searchResults[index];
        return _UserSearchResultItem(
          user: userWithStatus.user,
          status: userWithStatus.status,
          requestData: userWithStatus.requestData,
          onStatusChanged: () => _performSearch(_searchController.text.trim()),
        );
      },
    );
  }
}

class _UserSearchResultItem extends StatefulWidget {
  final User user;
  final String status;
  final Map<String, dynamic>? requestData;
  final VoidCallback onStatusChanged;

  const _UserSearchResultItem({
    required this.user,
    required this.status,
    this.requestData,
    required this.onStatusChanged,
  });

  @override
  State<_UserSearchResultItem> createState() => _UserSearchResultItemState();
}

class _UserSearchResultItemState extends State<_UserSearchResultItem> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorageService = SecureStorageService();

  final String _fallbackAvatarUrl =
      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';

  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  void _navigateToChat(BuildContext context) async {
    try {
      final currentUserId = await _secureStorageService.getUserId();
      if (currentUserId == null) {
        // Handle not being logged in
        return;
      }

      // Don't allow messaging yourself
      if (widget.user.id == currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không thể nhắn tin cho chính mình.'),
          ),
        );
        return;
      }

      final conversation = await _messageService.getOrCreateConversation(
        [currentUserId, widget.user.id],
        false,
        null,
      );
      final conversationId = conversation['id'];

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              chatName: widget.user.displayName,
              isGroup: false,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to chat: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở cuộc trò chuyện: $e')),
        );
      }
    }
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: widget.user.id),
      ),
    );
  }

  void _handleSendFriendRequest() async {
    try {
      await _userService.sendFriendRequest(widget.user.id);
      setState(() {
        _currentStatus = 'pending_sent';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi lời mời kết bạn'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi lời mời: $e')),
        );
      }
    }
  }

  void _handleAcceptFriendRequest() async {
    try {
      final requestId = widget.requestData?['id'];
      if (requestId == null) return;

      await _userService.respondToFriendRequest(requestId, 'accept');
      setState(() {
        _currentStatus = 'friends';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận lời mời kết bạn'),
          ),
        );
      }
      widget.onStatusChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chấp nhận: $e')),
        );
      }
    }
  }

  void _handleDeclineFriendRequest() async {
    try {
      final requestId = widget.requestData?['id'];
      if (requestId == null) return;

      await _userService.respondToFriendRequest(requestId, 'reject');
      setState(() {
        _currentStatus = 'none';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lời mời kết bạn'),
          ),
        );
      }
      widget.onStatusChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể từ chối: $e')),
        );
      }
    }
  }

  Widget _buildActionButton() {
    switch (_currentStatus) {
      case 'friends':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check, color: Color(0xFF7A2FC0)),
          label: const Text('Bạn bè', style: TextStyle(color: Color(0xFF7A2FC0))),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF7A2FC0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      
      case 'pending_sent':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule, color: Colors.grey),
          label: const Text('Đã gửi lời mời', style: TextStyle(color: Colors.grey)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      
      case 'pending_received':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _handleAcceptFriendRequest,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Chấp nhận', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A2FC0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _handleDeclineFriendRequest,
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Từ chối', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        );
      
      case 'self':
        return const SizedBox.shrink();
      
      default:
        return ElevatedButton.icon(
          onPressed: _handleSendFriendRequest,
          icon: const Icon(Icons.person_add),
          label: const Text('Kết bạn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF7A2FC0),
            side: const BorderSide(color: Color(0xFF7A2FC0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _navigateToProfile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                    ? widget.user.avatarUrl!
                    : _fallbackAvatarUrl,
              ),
              onBackgroundImageError: (_, __) {}, // Handle image load error
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.user.username}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(),
            if (_currentStatus != 'self' && _currentStatus != 'pending_received') ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.message_outlined,
                  color: Color(0xFF7C3AED),
                ),
                tooltip: 'Nhắn tin',
                onPressed: () => _navigateToChat(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
