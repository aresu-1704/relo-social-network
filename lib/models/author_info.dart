class AuthorInfo {
  final String displayName;
  final String? avatarUrl;

  AuthorInfo({required this.displayName, this.avatarUrl});

  factory AuthorInfo.fromJson(Map<String, dynamic> json) {
    return AuthorInfo(
      displayName: json['displayName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? 'assets/none_images/avatar.jpg',
    );
  }
}
