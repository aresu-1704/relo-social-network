import 'package:flutter/material.dart';
import 'package:relo/models/post.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/widgets/posts/post_card.dart';
import 'package:relo/widgets/posts/post_composer_widget.dart';
import 'package:relo/screen/create_post_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final PostService _postService = ServiceLocator.postService;
  final List<Post> _posts = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _skip = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _postService.getFeed(skip: 0, limit: _limit);
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _skip = posts.length;
          _hasMore = posts.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải bài viết: $e')));
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newPosts = await _postService.getFeed(skip: _skip, limit: _limit);
      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _skip += newPosts.length;
          _hasMore = newPosts.length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );

    if (result == true) {
      _loadPosts(); // Refresh feed after creating post
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.layoutGrid,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có bài viết nào',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _navigateToCreatePost,
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('Tạo bài viết đầu tiên'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A2FC0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 0),
                cacheExtent: 1000, // Cache 1000 pixels of off-screen content
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                itemCount: _posts.length + 1 + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Composer widget at index 0
                  if (index == 0) {
                    return PostComposerWidget(onTap: _navigateToCreatePost);
                  }

                  // Loading indicator at the end
                  if (_isLoadingMore && index == _posts.length + 1) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Posts (offset by 1 because of composer)
                  final postIndex = index - 1;
                  return PostCard(
                    key: ValueKey(_posts[postIndex].id),
                    post: _posts[postIndex],
                    onPostDeleted: _loadPosts,
                  );
                },
              ),
      ),
    );
  }
}
