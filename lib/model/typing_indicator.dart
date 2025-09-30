/// مدل نشانگر تایپ کردن
class TypingIndicator {
  final String userId;
  final String userName;
  final String userAvatar;
  final DateTime startedAt;

  TypingIndicator({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.startedAt,
  });

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      userId: json['user_id'],
      userName: json['user_name'] ?? 'کاربر ناشناس',
      userAvatar: json['user_avatar'] ?? '',
      startedAt: DateTime.parse(json['started_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'started_at': startedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TypingIndicator(userId: $userId, userName: $userName, startedAt: $startedAt)';
  }
}

