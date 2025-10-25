class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final bool isLiked;
  final List<Comment>? replies; // For nested comments

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    this.mediaUrls = const [],
    required this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? json['id'] ?? '',
      postId: json['postId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? json['user']?['displayName'] ?? 'Unknown',
      userAvatar: json['userAvatar'] ?? json['user']?['avatarUrl'],
      content: json['content'] ?? '',
      mediaUrls: json['mediaUrls'] != null 
          ? List<String>.from(json['mediaUrls'])
          : [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : null,
      likeCount: json['likeCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((r) => Comment.fromJson(r))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likeCount': likeCount,
      'isLiked': isLiked,
      'replies': replies?.map((r) => r.toJson()).toList(),
    };
  }
}
