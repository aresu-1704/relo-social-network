import 'author_info.dart';

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final AuthorInfo authorInfo;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorInfo,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? json['_id'] ?? '',
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorInfo: AuthorInfo.fromJson(json['authorInfo']),
      content: json['content'] ?? '',
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
