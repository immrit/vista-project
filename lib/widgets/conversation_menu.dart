import 'package:flutter/material.dart';
import '../services/instant_message_deletion.dart';

/// منوی گفتگو
class ConversationMenu extends StatelessWidget {
  final String conversationId;
  final String conversationTitle;
  final bool isGroupChat;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final VoidCallback onDeleted;
  final VoidCallback? onPin;
  final VoidCallback? onMute;
  final VoidCallback? onArchive;

  const ConversationMenu({
    super.key,
    required this.conversationId,
    required this.conversationTitle,
    required this.isGroupChat,
    required this.isPinned,
    required this.isMuted,
    required this.isArchived,
    required this.onDeleted,
    this.onPin,
    this.onMute,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // گزینه‌های مدیریت گفتگو
          if (onPin != null)
            _buildMenuItem(
              icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              text: isPinned ? 'برداشتن سنجاق' : 'سنجاق کردن',
              onTap: () {
                Navigator.of(context).pop();
                onPin?.call();
              },
            ),

          if (onMute != null)
            _buildMenuItem(
              icon: isMuted ? Icons.volume_up : Icons.volume_off,
              text: isMuted ? 'خروج از حالت بی‌صدا' : 'بی‌صدا کردن',
              onTap: () {
                Navigator.of(context).pop();
                onMute?.call();
              },
            ),

          if (onArchive != null)
            _buildMenuItem(
              icon: isArchived ? Icons.unarchive : Icons.archive,
              text: isArchived ? 'خروج از بایگانی' : 'بایگانی کردن',
              onTap: () {
                Navigator.of(context).pop();
                onArchive?.call();
              },
            ),

          // خط جداکننده
          const Divider(height: 1),

          // گزینه‌های حذف
          _buildMenuItem(
            icon: Icons.clear_all,
            text: 'پاک کردن تاریخچه',
            onTap: () => _handleClearHistory(context),
          ),

          _buildMenuItem(
            icon: Icons.delete_outline,
            text: isGroupChat ? 'ترک گروه' : 'حذف گفتگو',
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () => _handleDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleClearHistory(BuildContext context) {
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('پاک کردن تاریخچه'),
        content: Text(
            'آیا مطمئن هستید که می‌خواهید تاریخچه "$conversationTitle" را پاک کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showClearHistoryOptions(context);
            },
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('نوع پاک کردن'),
        content: const Text(
            'آیا می‌خواهید تاریخچه فقط برای خودتان پاک شود یا برای همه؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDeleteConversationDialog(
                context: context,
                conversationId: conversationId,
                conversationTitle: conversationTitle,
                isGroupChat: isGroupChat,
                onDeleted: onDeleted,
              );
            },
            child: const Text('فقط برای من'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showDeleteConversationDialog(
                context: context,
                conversationId: conversationId,
                conversationTitle: conversationTitle,
                isGroupChat: isGroupChat,
                onDeleted: onDeleted,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('برای همه'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(BuildContext context) {
    Navigator.of(context).pop();

    showDeleteConversationDialog(
      context: context,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      isGroupChat: isGroupChat,
      onDeleted: onDeleted,
    );
  }
}

/// نمایش منوی گفتگو در مکان مشخص
void showConversationMenu({
  required BuildContext context,
  required Offset position,
  required String conversationId,
  required String conversationTitle,
  required bool isGroupChat,
  required bool isPinned,
  required bool isMuted,
  required bool isArchived,
  required VoidCallback onDeleted,
  VoidCallback? onPin,
  VoidCallback? onMute,
  VoidCallback? onArchive,
}) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 250,
      position.dy + 400,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        child: ConversationMenu(
          conversationId: conversationId,
          conversationTitle: conversationTitle,
          isGroupChat: isGroupChat,
          isPinned: isPinned,
          isMuted: isMuted,
          isArchived: isArchived,
          onDeleted: onDeleted,
          onPin: onPin,
          onMute: onMute,
          onArchive: onArchive,
        ),
      ),
    ],
  );
}
