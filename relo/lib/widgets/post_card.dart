import 'package:flutter/material.dart';
import 'package:relo/models/post.dart';
import 'package:relo/widgets/enhanced_post_card.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onPostDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onPostDeleted,
  });

  static Widget buildWidget(Post post) => PostCard(post: post);

  @override
  Widget build(BuildContext context) {
    // Use the enhanced version with full features
    return EnhancedPostCard(
      post: post,
      onPostDeleted: onPostDeleted,
    );
  }
}
