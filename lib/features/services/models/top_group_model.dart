class TopGroup {
  final String id;
  final String name;
  final String? image;
  final int score;
  final int memberCount;
  final int premiumCount;
  final int verifiedCount;

  TopGroup({
    required this.id,
    required this.name,
    this.image,
    required this.score,
    required this.memberCount,
    required this.premiumCount,
    required this.verifiedCount,
  });

  factory TopGroup.fromJson(Map<String, dynamic> json) {
    return TopGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'],
      score: json['score'] ?? 0,
      memberCount: json['member_count'] ?? 0,
      premiumCount: json['premium_count'] ?? 0,
      verifiedCount: json['verified_count'] ?? 0,
    );
  }
}
