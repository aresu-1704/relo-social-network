import 'dart:async';
import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'chat_screen.dart';

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
        final user = _searchResults[index];
        return _UserSearchResultItem(
          user: user,
          messageService: _messageService,
          secureStorageService: _secureStorageService,
        );
      },
    );
  }
}

class _UserSearchResultItem extends StatelessWidget {
  final User user;
  final MessageService messageService;
  final SecureStorageService secureStorageService;

  const _UserSearchResultItem({
    required this.user,
    required this.messageService,
    required this.secureStorageService,
  });

  final String _fallbackAvatarUrl =
      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w';

  void _navigateToChat(BuildContext context) async {
    try {
      final currentUserId = await secureStorageService.getUserId();
      if (currentUserId == null) {
        // Handle not being logged in
        return;
      }

      // Don't allow messaging yourself
      if (user.id == currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không thể nhắn tin cho chính mình.'),
          ),
        );
        return;
      }

      final conversation = await messageService.getOrCreateConversation(
        [currentUserId, user.id],
        false,
        null,
      );
      final conversationId = conversation['id'];

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              friendName: user.displayName,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Điều hướng đến trang cá nhân của người dùng
        print('Navigate to profile of ${user.displayName}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(
                user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? user.avatarUrl!
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
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(
                Icons.message_outlined,
                color: Color(0xFF7C3AED),
              ),
              onPressed: () => _navigateToChat(context),
            ),
          ],
        ),
      ),
    );
  }
}
