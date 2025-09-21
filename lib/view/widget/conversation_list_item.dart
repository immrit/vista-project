import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../model/conversation_model.dart';
import '../util/time_utils.dart';

/// ویجت برای نمایش یک آیتم مکالمه با اطلاعات کاربر
class ConversationListItem extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationListItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تشخیص نام و آواتار کاربر دیگر
    String displayName = 'در حال بارگذاری...';
    String? avatarUrl;

    // اگر اطلاعات کاربر در conversation موجود است
    if (conversation.otherUserName?.isNotEmpty == true) {
      displayName = conversation.otherUserName!;
      avatarUrl = conversation.otherUserAvatar;
    } else if (conversation.participants.isNotEmpty) {
      // اگر اطلاعات مستقیم موجود نیست، از participants استفاده کن
      for (final participant in conversation.participants) {
        // فرض می‌کنیم در آینده profile info در participant خواهد بود
        displayName = 'کاربر ${participant.userId.substring(0, 8)}';
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAvatar(displayName, avatarUrl),
        title: Text(
          displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: conversation.unreadCount > 0
                ? FontWeight.bold
                : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: conversation.lastMessage != null
            ? Text(
                conversation.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation.lastMessageTime != null)
              Text(
                TimeUtils.formatMessageTime(conversation.lastMessageTime!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            if (conversation.unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildAvatar(String displayName, String? avatarUrl) {
    if (avatarUrl?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: avatarUrl.isEmpty
            ? Text(displayName.isNotEmpty ? displayName[0] : 'U')
            : null,
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
