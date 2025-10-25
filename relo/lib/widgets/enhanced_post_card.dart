import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:relo/models/post.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/screen/comments_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EnhancedPostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const EnhancedPostCard({
    super.key,
    required this.post,
    this.onPostUpdated,
  });

  @override
  State<EnhancedPostCard> createState() => _EnhancedPostCardState();
}

class _EnhancedPostCardState extends State<EnhancedPostCard> {
  final PostService _postService = ServiceLocator.postService;
  late Post _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(time);
  }

  Future<void> _handleReaction(String reactionType) async {
    try {
      final updatedPost = await _postService.reactToPost(
        postId: _currentPost.id,
        reactionType: reactionType,
      );

      setState(() => _currentPost = updatedPost);
      widget.onPostUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chọn cảm xúc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton('👍', 'like'),
                _buildReactionButton('❤️', 'love'),
                _buildReactionButton('😂', 'haha'),
                _buildReactionButton('😮', 'wow'),
                _buildReactionButton('😢', 'sad'),
                _buildReactionButton('😡', 'angry'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String emoji, String type) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _handleReaction(type);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(post: _currentPost),
      ),
    ).then((_) => widget.onPostUpdated?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==== Header: Avatar + Tên + Thời gian ====
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _currentPost.authorInfo.avatarUrl != null &&
                          _currentPost.authorInfo.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(_currentPost.authorInfo.avatarUrl!)
                      : null,
                  child: _currentPost.authorInfo.avatarUrl == null ||
                          _currentPost.authorInfo.avatarUrl!.isEmpty
                      ? Text(
                          _currentPost.authorInfo.displayName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPost.authorInfo.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(_currentPost.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // ==== Nội dung bài viết ====
          if (_currentPost.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                _currentPost.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          const SizedBox(height: 8),

          // ==== Media (ảnh) ====
          if (_currentPost.mediaUrls.isNotEmpty)
            SizedBox(
              height: 300,
              child: _currentPost.mediaUrls.length == 1
                  ? CachedNetworkImage(
                      imageUrl: _currentPost.mediaUrls[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
                      ),
                    )
                  : PageView.builder(
                      itemCount: _currentPost.mediaUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: _currentPost.mediaUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${index + 1}/${_currentPost.mediaUrls.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

          const SizedBox(height: 8),

          // ==== Thống kê reactions & comments ====
          if (_currentPost.reactionCounts.isNotEmpty ||
              _currentPost.commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reactions count
                  if (_currentPost.reactionCounts.isNotEmpty)
                    Row(
                      children: [
                        _buildReactionIcons(),
                        const SizedBox(width: 4),
                        Text(
                          _getTotalReactions().toString(),
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],
                    ),
                  // Comments count
                  if (_currentPost.commentCount > 0)
                    Text(
                      '${_currentPost.commentCount} bình luận',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                ],
              ),
            ),

          const Divider(height: 1),

          // ==== Action buttons ====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _showReactionPicker,
                    icon: const Icon(LucideIcons.heart, size: 20),
                    label: const Text('Thích'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _navigateToComments,
                    icon: const Icon(LucideIcons.messageCircle, size: 20),
                    label: const Text('Bình luận'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.share2, size: 20),
                    label: const Text('Chia sẻ'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionIcons() {
    final reactions = _currentPost.reactionCounts.keys.take(3).toList();
    return Row(
      children: reactions.map((type) {
        final emoji = _getEmojiForReaction(type);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
    );
  }

  String _getEmojiForReaction(String type) {
    switch (type) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return '👍';
    }
  }

  int _getTotalReactions() {
    return _currentPost.reactionCounts.values.fold(0, (sum, count) => sum + count);
  }
}
