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
    } else {
      // اگر اطلاعات کاربر موجود نیست، منتظر enrichment بمان
      displayName = 'در حال بارگذاری...';
      avatarUrl = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(displayName, avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            TimeUtils.formatMessageTime(
                                conversation.lastMessageTime!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: conversation.formattedLastMessage != null
                              ? Text(
                                  conversation.formattedLastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: conversation.unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String displayName, String? avatarUrl) {
    if (avatarUrl?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: avatarUrl.isEmpty
            ? Text(displayName.isNotEmpty ? displayName[0] : 'U')
            : null,
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
