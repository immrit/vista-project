/// مدل ری‌اکشن به پیام‌ها مانند توییتر
class MessageReaction {
  final String id;
  final String messageId;
  final String conversationId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'],
      messageId: json['message_id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      emoji: json['emoji'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'conversation_id': conversationId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MessageReaction copyWith({
    String? id,
    String? messageId,
    String? conversationId,
    String? userId,
    String? emoji,
    DateTime? createdAt,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'MessageReaction(id: $id, messageId: $messageId, userId: $userId, emoji: $emoji)';
  }
}

/// مدل گروه‌بندی ری‌اکشن‌ها برای نمایش در UI
class ReactionGroup {
  final String emoji;
  final int count;
  final List<String> userIds;
  final bool isReactedByCurrentUser;

  ReactionGroup({
    required this.emoji,
    required this.count,
    required this.userIds,
    required this.isReactedByCurrentUser,
  });

  factory ReactionGroup.fromReactions(
      List<MessageReaction> reactions, String currentUserId) {
    final emojiGroups = <String, List<String>>{};

    for (final reaction in reactions) {
      emojiGroups[reaction.emoji] ??= [];
      emojiGroups[reaction.emoji]!.add(reaction.userId);
    }

    if (emojiGroups.isEmpty) {
      return ReactionGroup(
        emoji: '',
        count: 0,
        userIds: [],
        isReactedByCurrentUser: false,
      );
    }

    // مرتب‌سازی بر اساس تعداد ری‌اکشن‌ها
    final sortedEmojis = emojiGroups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final topEmoji = sortedEmojis.first;
    final userIds = topEmoji.value;
    final isReactedByCurrentUser = userIds.contains(currentUserId);

    return ReactionGroup(
      emoji: topEmoji.key,
      count: userIds.length,
      userIds: userIds,
      isReactedByCurrentUser: isReactedByCurrentUser,
    );
  }

  @override
  String toString() {
    return 'ReactionGroup(emoji: $emoji, count: $count, isReactedByCurrentUser: $isReactedByCurrentUser)';
  }
}

