import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:relo/models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  static Widget buildWidget(Post post) => PostCard(post: post);

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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Header: Avatar + Tên + Thời gian ====
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      post.authorInfo.avatarUrl != null &&
                          post.authorInfo.avatarUrl!.isNotEmpty
                      ? NetworkImage(post.authorInfo.avatarUrl!)
                      : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorInfo.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(post.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),

            const SizedBox(height: 10),

            // ==== Nội dung bài viết ====
            if (post.content.isNotEmpty)
              Text(
                post.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),

            const SizedBox(height: 8),

            // ==== Media (ảnh/video dạng vuốt ngang) ====
            if (post.mediaUrls.isNotEmpty)
              SizedBox(
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PageView.builder(
                    itemCount: post.mediaUrls.length,
                    itemBuilder: (context, index) {
                      final url = post.mediaUrls[index];
                      final isVideo =
                          url.endsWith('.mp4') ||
                          url.endsWith('.mov') ||
                          url.endsWith('.avi');

                      if (isVideo) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white70,
                                  size: 60,
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ==== Nút Like / Bình luận ====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      "${post.reactionCounts['like'] ?? 0}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      "${post.commentCount}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
