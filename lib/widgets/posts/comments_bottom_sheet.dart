import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:relo/models/comment.dart';
import 'package:relo/services/comment_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:relo/utils/show_notification.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final VoidCallback? onCommentAdded;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    this.onCommentAdded,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final CommentService _commentService = ServiceLocator.commentService;
  final TextEditingController _commentController = TextEditingController();
  final List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _commentService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(comments);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await ShowNotification.showToast(context, 'Không thể tải bình luận');
      }
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await _commentService.createComment(widget.postId, content);
      _commentController.clear();
      await _loadComments();
      widget.onCommentAdded?.call();
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(context, 'Lỗi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _commentService.deleteComment(commentId);
      await _loadComments();
      widget.onCommentAdded?.call();
      if (mounted) {
        await ShowNotification.showToast(context, 'Đã xóa bình luận');
      }
    } catch (e) {
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Bình luận đã bị xáo trước đó',
        );
      }
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.99,
      expand: false,
      builder: (context, scrollController) => AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Bình luận',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.messageCircle,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có bình luận nào',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          print('Avatar URL: ${comment.authorInfo.avatarUrl}');
                          print(
                            'Display Name: ${comment.authorInfo.displayName}',
                          );
                          final canDelete =
                              widget.currentUserId == comment.authorId ||
                              widget.currentUserId == widget.postAuthorId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      comment.authorInfo.avatarUrl != null &&
                                          comment
                                              .authorInfo
                                              .avatarUrl!
                                              .isNotEmpty
                                      ? CachedNetworkImageProvider(
                                              comment.authorInfo.avatarUrl!,
                                            )
                                            as ImageProvider?
                                      : const AssetImage(
                                          'assets/none_images/avatar.jpg',
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment.authorInfo.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment.content,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Row(
                                          children: [
                                            Text(
                                              _formatTimeAgo(comment.createdAt),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (canDelete) ...[
                                              const SizedBox(width: 4),
                                              TextButton(
                                                onPressed: () async {
                                                  final confirm =
                                                      await ShowNotification.showConfirmDialog(
                                                        context,
                                                        title:
                                                            'Bạn có chắc chắn muốn xóa bình luận này?',
                                                        cancelText: 'Hủy',
                                                        confirmText: 'Xóa',
                                                        confirmColor:
                                                            Colors.red,
                                                      );
                                                  if (confirm == true) {
                                                    await _deleteComment(
                                                      comment.id,
                                                    );
                                                  }
                                                },
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 0,
                                                      ),
                                                ),
                                                child: const Text(
                                                  'Xóa',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Viết bình luận...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Color(0xFF7A2FC0),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          onSubmitted: (_) => _postComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isPosting
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                LucideIcons.send,
                                color: Color(0xFF7A2FC0),
                              ),
                              onPressed: _postComment,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
