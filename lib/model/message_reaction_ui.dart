class MessageReactionUI {
  final String emoji;
  final List<String> userIds;
  final bool hasCurrentUser;

  MessageReactionUI({
    required this.emoji,
    required this.userIds,
    required this.hasCurrentUser,
  });

  int get count => userIds.length;
}

















