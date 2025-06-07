// f:\vista\lib\view\screen\chat\archived_conversations_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../model/conversation_model.dart';
import '../../../provider/chat_provider.dart';
import '../../util/const.dart';
import 'ChatScreen.dart';
import 'ChatConversationsScreen.dart'; // برای استفاده از UnifiedChatItem

class ArchivedConversationsScreen extends ConsumerWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conversationsAsync = ref.watch(cachedConversationsStreamProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'گفتگوهای بایگانی',
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: conversationsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: theme.primaryColor)),
        error: (error, stack) => Center(child: Text('خطا: $error')),
        data: (allConversations) {
          final archivedConversations = allConversations
              .where((conv) => conv.isArchived)
              .map(UnifiedChatItem.fromConversation)
              .toList();

          if (archivedConversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 64, color: theme.hintColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'هیچ گفتگوی بایگانی شده‌ای وجود ندارد.',
                    style: TextStyle(fontSize: 16, color: theme.hintColor),
                  ),
                ],
              ),
            );
          }

          // مرتب‌سازی بر اساس آخرین فعالیت
          archivedConversations.sort((a, b) {
            final aTime = a.lastActivity ?? DateTime(1970);
            final bTime = b.lastActivity ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: archivedConversations.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 82,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.3),
            ),
            itemBuilder: (context, index) {
              final item = archivedConversations[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (item.source is ConversationModel) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserName: (item.source as ConversationModel)
                                    .otherUserName ??
                                '',
                            otherUserAvatar: (item.source as ConversationModel)
                                    .otherUserAvatar ??
                                defaultAvatarUrl,
                            conversationId: item.id,
                            otherUserId: (item.source as ConversationModel)
                                    .otherUserId ??
                                '',
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    // اینجا می‌تونی گزینه‌هایی مثل "خروج از بایگانی" رو نمایش بدی
                    _showArchivedItemOptions(context, ref, item, theme);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _buildAvatar(theme, item),
                        const SizedBox(width: 12),
                        Expanded(child: _buildContent(theme, item)),
                        _buildTrailing(theme, item),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, UnifiedChatItem item) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: _buildAvatarImage(theme, item),
          ),
        ),
        if (item.isPinned) _buildPinnedIndicator(theme),
      ],
    );
  }

  Widget _buildAvatarImage(ThemeData theme, UnifiedChatItem item) {
    if (item.avatarUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: item.avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(theme, item),
        errorWidget: (context, url, error) => _buildDefaultAvatar(theme, item),
      );
    }
    return _buildDefaultAvatar(theme, item);
  }

  Widget _buildDefaultAvatar(ThemeData theme, UnifiedChatItem item) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: theme.colorScheme.secondary.withOpacity(0.1),
          child: Icon(
            Icons.person_rounded,
            color: theme.colorScheme.secondary,
            size: 28,
          ),
        );
      },
    );
  }

  Widget _buildPinnedIndicator(ThemeData theme) {
    return Positioned(
      left: 2,
      top: 2,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.scaffoldBackgroundColor,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.push_pin_rounded,
          size: 10,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, UnifiedChatItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.isMuted) ...[
              Icon(Icons.volume_off_rounded, size: 16, color: theme.hintColor),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      item.unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                  color: theme.textTheme.titleMedium?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (item.subtitle?.isNotEmpty ?? false)
          Text(
            item.subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: item.unreadCount > 0
                  ? theme.textTheme.bodyMedium?.color
                  : theme.hintColor,
              fontWeight:
                  item.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildTrailing(ThemeData theme, UnifiedChatItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.lastActivity != null)
          Text(
            _formatTime(item.lastActivity!),
            style: TextStyle(
              fontSize: 12,
              color:
                  item.unreadCount > 0 ? theme.primaryColor : theme.hintColor,
              fontWeight:
                  item.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        const SizedBox(height: 4),
        if (item.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(
              item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 6) return '${time.day}/${time.month}';
    if (difference.inDays > 0)
      return difference.inDays == 1 ? 'دیروز' : '${difference.inDays} روز پیش';
    if (difference.inHours > 0)
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (difference.inMinutes > 0) return '${difference.inMinutes} دقیقه پیش';
    return 'اکنون';
  }

  void _showArchivedItemOptions(BuildContext context, WidgetRef ref,
      UnifiedChatItem item, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                // Sheet Handle
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                item.title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading:
                    Icon(Icons.unarchive_outlined, color: theme.primaryColor),
                title: Text('خروج از بایگانی',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(messageNotifierProvider.notifier)
                      .toggleArchiveConversation(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('گفتگو از بایگانی خارج شد')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: theme.colorScheme.error),
                title: Text('حذف برای همیشه',
                    style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement permanent delete logic with confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('حذف برای همیشه (هنوز پیاده‌سازی نشده)')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
