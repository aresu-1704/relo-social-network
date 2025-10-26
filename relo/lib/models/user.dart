class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? bio;
  final String? status;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.backgroundUrl,
    this.bio,
    this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      backgroundUrl: json['backgroundUrl'],
      bio: json['bio'],
      status: json['status'],
    );
  }
}
