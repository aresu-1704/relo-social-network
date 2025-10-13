class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  // Placeholder for avatar, as it's not in the API response.
  // We can use a default icon or a generative avatar based on the name.
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
    );
  }
}
