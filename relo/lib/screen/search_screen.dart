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
  final String _fallbackAvatarUrl =
      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';
  final UserService _userService = ServiceLocator.userService;

  late String _friendStatus;

  @override
  void initState() {
    super.initState();
    // Use friendStatus directly from API response
    _friendStatus = widget.user.friendStatus ?? 'none';
  }

  Future<void> _sendFriendRequest() async {
    try {
      await _userService.sendFriendRequest(widget.user.id);
      if (mounted) {
        setState(() => _friendStatus = 'pending_sent');
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể gửi lời mời kết bạn',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: widget.user.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                widget.user.avatarUrl != null &&
                        widget.user.avatarUrl!.isNotEmpty
                    ? widget.user.avatarUrl!
                    : _fallbackAvatarUrl,
              ),
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
                  _friendStatus == 'pending_sent' ||
                          _friendStatus == 'pending_received'
                      ? 'Đã gửi'
                      : 'Kết bạn',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
