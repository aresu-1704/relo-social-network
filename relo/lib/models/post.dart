import 'author_info.dart';
import 'reaction.dart';

class Post {
  final String id;
  final String authorId;
  final AuthorInfo authorInfo;
  final String content;
  final List<String> mediaUrls;
  final List<Reaction> reactions;
  final Map<String, int> reactionCounts;
  final int commentCount;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.authorId,
    required this.authorInfo,
    required this.content,
    required this.mediaUrls,
    required this.reactions,
    required this.reactionCounts,
    required this.commentCount,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? '',
      authorId: json['authorId'],
      authorInfo: AuthorInfo.fromJson(json['authorInfo']),
      content: json['content'] ?? '',
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) => Reaction.fromJson(r))
              .toList() ??
          [],
      reactionCounts: Map<String, int>.from(json['reactionCounts'] ?? {}),
      commentCount: json['commentCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
