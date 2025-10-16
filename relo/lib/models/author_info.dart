class AuthorInfo {
  final String displayName;
  final String? avatarUrl;

  AuthorInfo({required this.displayName, this.avatarUrl});

  factory AuthorInfo.fromJson(Map<String, dynamic> json) {
    return AuthorInfo(
      displayName: json['displayName'] ?? '',
      avatarUrl:
          json['avatarUrl'] ??
          'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
    );
  }
}
