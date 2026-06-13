import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/compat_extensions.dart';
import '../models/group_member_item.dart';
import '../../../provider/presence_provider.dart';
import '../theme/chat_theme.dart';

/// Isolated presence counter for group chat app bar — avoids rebuilding the
/// full chat screen when member presence streams update.
class ChatGroupPresenceSummary extends ConsumerWidget {
  const ChatGroupPresenceSummary({
    super.key,
    required this.members,
    required this.isLoadingMembers,
    required this.theme,
  });

  final List<GroupMemberItem> members;
  final bool isLoadingMembers;
  final ChatTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoadingMembers && members.isEmpty) {
      return Text(
        'در حال بررسی اعضا...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 12,
        ),
      );
    }

    if (members.isEmpty) {
      return Text(
        '۰ آنلاین، ۰ آفلاین',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 12,
        ),
      );
    }

    var onlineCount = 0;
    for (final member in members) {
      final presenceAsync =
          ref.watch(userPresenceStreamProvider(member.userId));
      final isAvailable = presenceAsync.maybeWhen(
        data: (state) =>
            state.isOnline ||
            state.isTyping ||
            state.isRecording ||
            state.isAway,
        orElse: () => false,
      );
      if (isAvailable) onlineCount++;
    }

    final offlineCount =
        (members.length - onlineCount).clamp(0, members.length).toInt();

    return Text(
      '$onlineCount آنلاین، $offlineCount آفلاین'.toPersianDigit(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.secondaryTextColor,
        fontSize: 12,
      ),
    );
  }
}
