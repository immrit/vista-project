/// مدل برای تنظیمات حریم خصوصی پیام‌ها
class MessagePrivacyModel {
  final String userId;
  final MessagePrivacyLevel level;
  final DateTime updatedAt;

  MessagePrivacyModel({
    required this.userId,
    required this.level,
    required this.updatedAt,
  });

  factory MessagePrivacyModel.fromJson(Map<String, dynamic> json) {
    return MessagePrivacyModel(
      userId: json['user_id'] as String,
      level: MessagePrivacyLevel.fromString(
          json['message_privacy'] as String? ?? 'everyone'),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'message_privacy': level.value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MessagePrivacyModel copyWith({
    String? userId,
    MessagePrivacyLevel? level,
    DateTime? updatedAt,
  }) {
    return MessagePrivacyModel(
      userId: userId ?? this.userId,
      level: level ?? this.level,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// سطوح حریم خصوصی پیام‌ها
enum MessagePrivacyLevel {
  nobody('nobody', 'هیچکس', 'فقط شما می‌توانید پیام ارسال کنید'),
  followers('followers', 'دنبال کنندگان',
      'فقط دنبال کنندگان شما می‌توانند پیام ارسال کنند'),
  everyone('everyone', 'همه', 'همه کاربران می‌توانند پیام ارسال کنند');

  const MessagePrivacyLevel(this.value, this.title, this.description);

  final String value;
  final String title;
  final String description;

  static MessagePrivacyLevel fromString(String value) {
    switch (value) {
      case 'nobody':
        return MessagePrivacyLevel.nobody;
      case 'followers':
        return MessagePrivacyLevel.followers;
      case 'everyone':
        return MessagePrivacyLevel.everyone;
      default:
        return MessagePrivacyLevel.everyone;
    }
  }

  static List<MessagePrivacyLevel> get allLevels => [
        MessagePrivacyLevel.nobody,
        MessagePrivacyLevel.followers,
        MessagePrivacyLevel.everyone,
      ];
}
