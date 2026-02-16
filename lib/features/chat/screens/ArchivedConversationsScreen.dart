import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/conversation_model.dart';
import '../../../features/chat/providers/chat_providers.dart';
// import '../../../provider/chat_provider.dart'; // Unused
import '../../../provider/optimized_conversations_provider.dart';
import '../../../features/chat/screens/modern_chat_screen.dart';
import '../../../utils/user_friendly_error_utils.dart';

/// صفحه نمایش گفتگوهای بایگانی شده
class ArchivedConversationsScreen extends ConsumerWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // ✅ استفاده از provider بهینه‌شده
    final state = ref.watch(optimizedConversationsProvider);

    // فیلتر کردن مکالمات بایگانی شده
    final archivedConversations =
        state.conversations.where((conv) => conv.isArchived).toList()
          ..sort((a, b) {
            final aTime = a.lastMessageTime ?? a.updatedAt;
            final bTime = b.lastMessageTime ?? b.updatedAt;
            return bTime.compareTo(aTime);
          });

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
      body: _buildBody(context, ref, theme, state, archivedConversations),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ConversationsState state,
    List<ConversationModel> archivedConversations,
  ) {
    // Loading state
    if (state.status == ConversationsStatus.loading ||
        state.status == ConversationsStatus.initial) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    // Error state
    if (state.status == ConversationsStatus.error &&
        archivedConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'خطا در بارگذاری',
              style: TextStyle(fontSize: 16, color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(optimizedConversationsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (archivedConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.archive_outlined,
                size: 48,
                color: theme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'هیچ گفتگوی بایگانی شده‌ای وجود ندارد',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'گفتگوهایی که بایگانی می‌کنید اینجا نمایش داده می‌شوند',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    // List of archived conversations
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(optimizedConversationsProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: archivedConversations.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 82,
          endIndent: 16,
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final conversation = archivedConversations[index];
          return _ArchivedConversationItem(
            conversation: conversation,
            onTap: () => _navigateToChat(context, conversation),
            onUnarchive: () =>
                _unarchiveConversation(context, ref, conversation),
            onDelete: () => _showDeleteConfirmation(context, ref, conversation),
          );
        },
      ),
    );
  }

  void _navigateToChat(BuildContext context, ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: conversation.id,
            otherUserName: conversation.otherUserName ?? 'VISTA USER',
            otherUserAvatar: conversation.otherUserAvatar,
            otherUserId: conversation.otherUserId ?? '',
            isGroup: conversation.isGroup,
          ),
        ),
      ),
    );
  }

  void _unarchiveConversation(
    BuildContext context,
    WidgetRef ref,
    ConversationModel conversation,
  ) async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.toggleArchiveConversation(conversation.id);

    if (context.mounted) {
      if (result.isSuccess) {
        UserFriendlyErrorUtils.showSuccessSnackBar(
          context,
          'گفتگو از بایگانی خارج شد',
        );
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          result.error ?? 'خروج از بایگانی انجام نشد',
        );
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ConversationModel conversation,
  ) {
    final theme = Theme.of(context);
    final displayName = conversation.otherUserName ?? 'VISTA USER';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('حذف برای همیشه'),
          ],
        ),
        content: Text(
          'آیا از حذف گفتگو با "$displayName" مطمئن هستید؟\nاین عمل قابل بازگشت نیست.',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('انصراف', style: TextStyle(color: theme.hintColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation(context, ref, conversation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation(
    BuildContext context,
    WidgetRef ref,
    ConversationModel conversation,
  ) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final result = await repo.deleteConversation(conversation.id);

      if (context.mounted) {
        if (result.isSuccess) {
          UserFriendlyErrorUtils.showSuccessSnackBar(
            context,
            'گفتگو با موفقیت حذف شد',
          );
        } else {
          UserFriendlyErrorUtils.showErrorSnackBar(
            context,
            result.error ?? 'حذف گفتگو انجام نشد',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }
}

/// ویجت آیتم مکالمه بایگانی شده
class _ArchivedConversationItem extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _ArchivedConversationItem({
    required this.conversation,
    required this.onTap,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptions(context, theme),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(theme),
              const SizedBox(width: 12),
              Expanded(child: _buildContent(theme)),
              _buildTrailing(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final displayName = _getDisplayName();

    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: conversation.otherUserAvatar?.isNotEmpty == true
                ? Image.network(
                    conversation.otherUserAvatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildDefaultAvatar(theme, displayName),
                  )
                : _buildDefaultAvatar(theme, displayName),
          ),
        ),
        // Archive indicator
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: theme.hintColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.archive_rounded,
              size: 10,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme, String displayName) {
    return Container(
      color: theme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final displayName = _getDisplayName();
    final lastMessage = _getLastMessage();
    final hasUnread = conversation.unreadCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (conversation.isMuted) ...[
              Icon(Icons.volume_off_rounded, size: 14, color: theme.hintColor),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                  color: theme.textTheme.titleMedium?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          lastMessage,
          style: TextStyle(
            fontSize: 13,
            color:
                hasUnread ? theme.textTheme.bodyMedium?.color : theme.hintColor,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    final hasUnread = conversation.unreadCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (conversation.lastMessageTime != null)
          Text(
            _formatTime(conversation.lastMessageTime!),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? theme.primaryColor : theme.hintColor,
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        const SizedBox(height: 4),
        if (hasUnread)
          Container(
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getDisplayName() {
    final name = conversation.otherUserName ?? '';
    if (name.isEmpty || name == 'کاربر' || name == 'کاربر ناشناس') {
      return 'VISTA USER';
    }
    return name;
  }

  String _getLastMessage() {
    final message =
        conversation.formattedLastMessage ?? conversation.lastMessage;
    if (message == null || message.isEmpty) {
      return 'پیام جدیدی ارسال کنید';
    }
    return message;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 6) {
      return '${time.day}/${time.month}';
    }
    if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'دیروز' : '${difference.inDays} روز';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showOptions(BuildContext context, ThemeData theme) {
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
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _getDisplayName(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              // Unarchive option
              _buildOptionTile(
                theme,
                icon: Icons.unarchive_rounded,
                title: 'خروج از بایگانی',
                onTap: () {
                  Navigator.pop(context);
                  onUnarchive();
                },
              ),
              // Delete option
              _buildOptionTile(
                theme,
                icon: Icons.delete_forever_rounded,
                title: 'حذف برای همیشه',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? theme.colorScheme.error : theme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? theme.colorScheme.error
                : theme.textTheme.titleMedium?.color,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
