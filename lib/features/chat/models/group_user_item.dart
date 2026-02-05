class GroupUserItem {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int messageCount;
  final String? conversationId;

  const GroupUserItem({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.messageCount = 0,
    this.conversationId,
  });

  String get displayName {
    if (username.isNotEmpty) return username;
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    return 'کاربر';
  }
}
