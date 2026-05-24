// lib/features/chat/models/message_reaction.dart
//
// مدل‌های واکنش به پیام - الهام از ویستا
//

/// انواع واکنش‌های از پیش تعریف شده
class ReactionType {
  static const thumbsUp = '👍';
  static const heart = '❤️';
  static const laughing = '😂';
  static const surprised = '😮';
  static const sad = '😢';
  static const fire = '🔥';
  static const clap = '👏';
  static const thinking = '🤔';
  static const party = '🎉';
  static const eyes = '👀';

  /// لیست تمام واکنش‌های پیش‌فرض
  static const List<String> defaults = [
    thumbsUp,
    heart,
    laughing,
    surprised,
    sad,
    fire,
    clap,
    thinking,
    party,
    eyes,
  ];
}

/// مدل واکنش یک کاربر به پیام
class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String emoji;
  final DateTime createdAt;

  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'کاربر',
      userAvatar: json['user_avatar'] as String?,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MessageReaction copyWith({
    String? id,
    String? messageId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? emoji,
    DateTime? createdAt,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// خلاصه واکنش‌ها به یک پیام (grouped by emoji)
class ReactionSummary {
  final String emoji;
  final int count;
  final List<MessageReaction> reactions;
  final bool hasCurrentUser;

  const ReactionSummary({
    required this.emoji,
    required this.count,
    required this.reactions,
    required this.hasCurrentUser,
  });

  /// گروه‌بندی واکنش‌ها به ایموجی
  static List<ReactionSummary> groupReactions(
    List<MessageReaction> reactions,
    String currentUserId,
  ) {
    final Map<String, List<MessageReaction>> grouped = {};

    for (final reaction in reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    return grouped.entries.map((entry) {
      final hasCurrentUser = entry.value.any((r) => r.userId == currentUserId);
      return ReactionSummary(
        emoji: entry.key,
        count: entry.value.length,
        reactions: entry.value,
        hasCurrentUser: hasCurrentUser,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count)); // مرتب‌سازی براساس تعداد
  }
}
