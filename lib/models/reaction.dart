class Reaction {
  final String userId;
  final String type;

  Reaction({required this.userId, required this.type});

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(userId: json['userId'], type: json['type']);
  }
}
