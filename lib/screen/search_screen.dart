import 'dart:async';
import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/screen/profile_screen.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final SecureStorageService _secureStorageService = SecureStorageService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<User> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false; // Để biết đã thực hiện tìm kiếm hay chưa
  StreamSubscription? _webSocketSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    _webSocketSubscription = ServiceLocator.websocketService.stream.listen((
      message,
    ) async {
      try {
        final data = jsonDecode(message);
        final type = data['type'] as String?;
        final payload = data['payload'];

        // Listen to friend-related events
        if (payload != null &&
            (type == 'friend_request_accepted' ||
                type == 'friend_added' ||
                type == 'friend_request_declined' ||
                type == 'friend_request_received')) {
          String? relevantUserId;

          if (type == 'friend_request_received') {
            relevantUserId = payload['from_user_id'] as String?;
          } else if (type == 'friend_request_accepted' ||
              type == 'friend_added') {
            relevantUserId = payload['user_id'] as String?;
          } else if (type == 'friend_request_declined') {
            relevantUserId = payload['user_id'] as String?;
          }

          // Update friend status in search results if user is in the list
          if (relevantUserId != null && mounted) {
            _updateFriendStatusInResults(relevantUserId, type);
          }
        }
      } catch (e) {
        print('Error in WebSocket listener (SearchScreen): $e');
      }
    });
  }

  void _updateFriendStatusInResults(String userId, String? eventType) {
    if (!mounted) return;

    bool shouldUpdate = false;
    final updatedResults = _searchResults.map((user) {
      if (user.id == userId) {
        shouldUpdate = true;
        String newStatus;
        if (eventType == 'friend_request_accepted' ||
            eventType == 'friend_added') {
          newStatus = 'friends';
        } else if (eventType == 'friend_request_declined') {
          newStatus = 'none';
        } else if (eventType == 'friend_request_received') {
          newStatus = 'pending_received';
        } else {
          newStatus = user.friendStatus ?? 'none';
        }

        // Create new User object with updated friendStatus
        return User(
          id: user.id,
          username: user.username,
          email: user.email,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          backgroundUrl: user.backgroundUrl,
          bio: user.bio,
          status: user.status,
          createdAt: user.createdAt,
          friendStatus: newStatus,
        );
      }
      return user;
    }).toList();

    if (shouldUpdate) {
      setState(() {
        _searchResults = updatedResults;
      });
    }
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
      setState(() {
        _searchResults = results;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        leadingWidth: 40,
        titleSpacing: 0,
        title: Container(
          margin: EdgeInsets.only(right: 10),
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              cursorColor: Color(0xFF7A2FC0),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm người dùng...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerList();
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
        final user = _searchResults[index];
        return _UserSearchResultItem(
          user: user,
          messageService: _messageService,
          secureStorageService: _secureStorageService,
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 150,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    Container(height: 14, width: 100, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 80,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSearchResultItem extends StatefulWidget {
  final User user;
  final MessageService messageService;
  final SecureStorageService secureStorageService;

  const _UserSearchResultItem({
    required this.user,
    required this.messageService,
    required this.secureStorageService,
  });

  @override
  State<_UserSearchResultItem> createState() => _UserSearchResultItemState();
}

class _UserSearchResultItemState extends State<_UserSearchResultItem> {
  final String _fallbackAvatarUrl = 'assets/none_images/avatar.jpg';
  final UserService _userService = ServiceLocator.userService;

  late String _friendStatus;

  @override
  void initState() {
    super.initState();
    // Use friendStatus directly from API response, normalize to lowercase
    final status = widget.user.friendStatus?.toLowerCase().trim() ?? 'none';
    _friendStatus = status;
    // Debug: print to check if friendStatus is correct
    print(
      'Search result - User: ${widget.user.displayName}, friendStatus: $_friendStatus',
    );
  }

  @override
  void didUpdateWidget(_UserSearchResultItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update friendStatus when widget is rebuilt with new user data
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.friendStatus != widget.user.friendStatus) {
      setState(() {
        final status = widget.user.friendStatus?.toLowerCase().trim() ?? 'none';
        _friendStatus = status;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      // Nếu đã gửi lời mời, hủy lời mời
      if (_friendStatus == 'pending_sent') {
        await _userService.cancelFriendRequest(widget.user.id);
        if (mounted) {
          setState(() => _friendStatus = 'none');
          await ShowNotification.showToast(context, 'Đã hủy lời mời kết bạn');
        }
      } else if (_friendStatus == 'pending_received') {
        // Người khác đã gửi lời mời cho tôi → Hiển thị menu chấp nhận/từ chối
        _showPendingRequestOptions();
      } else if (_friendStatus == 'none') {
        // Gửi lời mời mới
        await _userService.sendFriendRequest(widget.user.id);
        if (mounted) {
          setState(() => _friendStatus = 'pending_sent');
        }
      }
      // Không xử lý trường hợp 'friends'
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(
          context,
          _friendStatus == 'pending_sent'
              ? 'Không thể hủy lời mời kết bạn'
              : 'Không thể gửi lời mời kết bạn',
        );
      }
    }
  }

  String _getButtonLabel() {
    // Debug: print current status
    print('_getButtonLabel - _friendStatus: $_friendStatus');

    if (_friendStatus == 'pending_sent') {
      return 'Đã gửi';
    } else if (_friendStatus == 'pending_received') {
      return 'Phản hồi';
    } else {
      return 'Kết bạn';
    }
  }

  void _showPendingRequestOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bạn có lời mời kết bạn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await _userService.respondToFriendRequestByUser(
                          widget.user.id,
                          'accept',
                        );
                        if (mounted) {
                          setState(() => _friendStatus = 'friends');
                        }
                      } catch (e) {
                        print('Error accepting friend request: $e');
                      }
                    },
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text(
                      'Chấp nhận',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7A2FC0),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await _userService.respondToFriendRequestByUser(
                          widget.user.id,
                          'reject',
                        );
                        if (mounted) {
                          setState(() => _friendStatus = 'none');
                        }
                      } catch (e) {
                        if (mounted) {
                          print('Error rejecting friend request: $e');
                        }
                      }
                    },
                    icon: Icon(Icons.close, color: Colors.white),
                    label: Text(
                      'Từ chối',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ProfileScreen(userId: widget.user.id, hideMessageButton: true),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: (() {
                final url =
                    widget.user.avatarUrl != null &&
                        widget.user.avatarUrl!.isNotEmpty
                    ? widget.user.avatarUrl!
                    : _fallbackAvatarUrl;
                return (url.startsWith('assets/')
                        ? AssetImage(url)
                        : NetworkImage(url))
                    as ImageProvider;
              })(),
              onBackgroundImageError: (_, __) {},
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${widget.user.username}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            // Nút kết bạn - chỉ hiển thị khi không phải bạn bè
            if (_friendStatus != 'friends') const SizedBox(width: 8),
            if (_friendStatus != 'friends')
              TextButton.icon(
                onPressed: _sendFriendRequest,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: Color(0xFF7A2FC0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon:
                    _friendStatus == 'pending_sent' ||
                        _friendStatus == 'pending_received'
                    ? const Icon(
                        LucideIcons.userCheck,
                        color: Colors.white,
                        size: 18,
                      )
                    : const Icon(
                        LucideIcons.userPlus,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  _getButtonLabel(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
