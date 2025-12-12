// lib/features/chat/widgets/message_context_menu.dart
//
// منوی Context برای پیام‌ها (با Reaction و Forward)
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'message_reactions_widget.dart';
import 'forward_message_sheet.dart';
import '../theme/chat_theme.dart';

class MessageContextMenu extends ConsumerWidget {
  final String messageId;
  final String content;
  final bool isMine;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onInfo;

  const MessageContextMenu({
    super.key,
    required this.messageId,
    required this.content,
    required this.isMine,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.onInfo,
  });

  static Future<void> show(
    BuildContext context, {
    required String messageId,
    required String content,
    required bool isMine,
    VoidCallback? onReply,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onCopy,
    VoidCallback? onInfo,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageContextMenu(
        messageId: messageId,
        content: content,
        isMine: isMine,
        onReply: onReply,
        onEdit: onEdit,
        onDelete: onDelete,
        onCopy: onCopy,
        onInfo: onInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.chatTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Quick Reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                '👍',
                '❤️',
                '😂',
                '😮',
                '😢',
                '🔥',
                '+'
              ].map((emoji) {
                if (emoji == '+') {
                  return _QuickReactionButton(
                    emoji: emoji,
                    onTap: () async {
                      Navigator.pop(context);
                      await ReactionPickerSheet.show(
                        context,
                        messageId: messageId,
                      );
                    },
                  );
                }

                return _QuickReactionButton(
                  emoji: emoji,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await ref.read(messageReactionsServiceProvider).toggleReaction(
                      messageId: messageId,
                      emoji: emoji,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // Actions
          _ContextMenuItem(
            icon: Icons.reply_rounded,
            label: 'پاسخ',
            onTap: () {
              Navigator.pop(context);
              onReply?.call();
            },
          ),

          _ContextMenuItem(
            icon: Icons.forward_rounded,
            label: 'فوروارد',
            onTap: () async {
              Navigator.pop(context);
              await ForwardMessageSheet.show(
                context,
                messageIds: [messageId],
              );
            },
          ),

          if (content.isNotEmpty)
            _ContextMenuItem(
              icon: Icons.copy_rounded,
              label: 'کپی',
              onTap: () {
                Navigator.pop(context);
                onCopy?.call();
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('متن کپی شد'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

          if (isMine)
            _ContextMenuItem(
              icon: Icons.edit_rounded,
              label: 'ویرایش',
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),

          _ContextMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'اطلاعات',
            onTap: () {
              Navigator.pop(context);
              onInfo?.call();
            },
          ),

          if (isMine)
            _ContextMenuItem(
              icon: Icons.delete_outline_rounded,
              label: 'حذف',
              color: theme.errorColor,
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _QuickReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _QuickReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.inputBackgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        child: Center(
          child: emoji == '+'
              ? Icon(
                  Icons.add_rounded,
                  color: theme.secondaryTextColor,
                  size: 20,
                )
              : Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
        ),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final itemColor = color ?? theme.textColor;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        label,
        style: TextStyle(color: itemColor),
      ),
      onTap: onTap,
    );
  }
}




















