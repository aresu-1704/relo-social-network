import 'package:flutter/material.dart';
import 'package:relo/models/post.dart';
import 'package:relo/widgets/posts/enhanced_post_card.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostDeleted;

  const PostCard({super.key, required this.post, this.onPostDeleted});

  static Widget buildWidget(Post post) => PostCard(post: post);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Use the enhanced version with full features
    return EnhancedPostCard(
      post: widget.post,
      onPostDeleted: widget.onPostDeleted,
    );
  }
}
