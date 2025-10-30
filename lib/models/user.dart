class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? bio;
  final String? status;
  final String? createdAt;
  final String?
  friendStatus; // For search results: 'friends', 'pending_sent', 'pending_received', 'none'

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.backgroundUrl,
    this.bio,
    this.status,
    this.createdAt,
    this.friendStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'] ?? '',
      backgroundUrl: json['backgroundUrl'] ?? '',
      bio: json['bio'] ?? '',
      status: json['status'] ?? 'available',
      createdAt: json['createdAt'],
      friendStatus: json['friendStatus'],
    );
  }
}
