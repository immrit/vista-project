class GroupMemberItem {
  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isAdmin;
  final DateTime? joinedAt;

  const GroupMemberItem({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isAdmin = false,
    this.joinedAt,
  });

  String get displayName {
    if (username.isNotEmpty) return username;
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    return 'کاربر';
  }
}
