class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userDisplayName;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userDisplayName,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      postId: json['postId'] ?? '',
      userId: json['userId'] ?? '',
      userDisplayName: json['userDisplayName'] ?? '',
      userAvatarUrl: json['userAvatarUrl'],
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
