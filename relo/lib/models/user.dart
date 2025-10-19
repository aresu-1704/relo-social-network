class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? bio;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.backgroundUrl,
    this.bio,
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
    );
  }
}
