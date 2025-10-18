import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../services/instant_message_deletion.dart';

/// منوی پیام با Instant Deletion - نسخه بهبود یافته
void showInstantDeletionMessageMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset position,
  required MessageModel message,
  required bool isMyMessage,
  required VoidCallback onDeleted,
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback? onCopy,
}) {
  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 200,
      position.dy + 300,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        child: _InstantDeletionMessageMenu(
          ref: ref,
          message: message,
          isMyMessage: isMyMessage,
          onDeleted: onDeleted,
          onReply: onReply,
          onForward: onForward,
          onCopy: onCopy,
        ),
      ),
    ],
  );
}

/// Widget منوی پیام با access به WidgetRef
class _InstantDeletionMessageMenu extends StatelessWidget {
  final WidgetRef ref;
  final MessageModel message;
  final bool isMyMessage;
  final VoidCallback onDeleted;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;

  const _InstantDeletionMessageMenu({
    required this.ref,
    required this.message,
    required this.isMyMessage,
    required this.onDeleted,
    this.onReply,
    this.onForward,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // گزینه‌های عمومی
          if (onReply != null)
            _buildMenuItem(
              context: context,
              icon: Icons.reply,
              text: 'پاسخ',
              onTap: () {
                Navigator.of(context).pop();
                onReply?.call();
              },
            ),

          if (onForward != null)
            _buildMenuItem(
              context: context,
              icon: Icons.forward,
              text: 'بازارسال',
              onTap: () {
                Navigator.of(context).pop();
                onForward?.call();
              },
            ),

          if (onCopy != null && message.content.isNotEmpty)
            _buildMenuItem(
              context: context,
              icon: Icons.copy,
              text: 'کپی',
              onTap: () {
                Navigator.of(context).pop();
                onCopy?.call();
              },
            ),

          // خط جداکننده
          if (_hasNonDeleteOptions()) const Divider(height: 1),

          // گزینه‌های حذف با instant deletion
          _buildMenuItem(
            context: context,
            icon: Icons.delete_outline,
            text: 'حذف برای من',
            onTap: () => _handleInstantDeletion(context, false),
          ),

          if (isMyMessage)
            _buildMenuItem(
              context: context,
              icon: Icons.delete_forever,
              text: 'حذف برای همه',
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _handleInstantDeletion(context, true),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
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

  bool _hasNonDeleteOptions() {
    return onReply != null ||
        onForward != null ||
        (onCopy != null && message.content.isNotEmpty);
  }

  /// حذف فوری با optimistic update
  void _handleInstantDeletion(BuildContext context, bool forEveryone) {
    Navigator.of(context).pop();

    // ✨ INSTANT DELETION - بدون دیالوگ تأیید برای سرعت بیشتر
    showDeleteMessageDialog(
      context: context,
      message: message,
      isMyMessage: isMyMessage,
      onDeleted: onDeleted,
      ref: ref, // ref موجود است
    );
  }
}

/// Extension برای استفاده آسان‌تر در Consumer widgets
extension InstantDeletionMenuExtension on WidgetRef {
  void showInstantMessageMenu({
    required BuildContext context,
    required Offset position,
    required MessageModel message,
    required bool isMyMessage,
    required VoidCallback onDeleted,
    VoidCallback? onReply,
    VoidCallback? onForward,
    VoidCallback? onCopy,
  }) {
    showInstantDeletionMessageMenu(
      context: context,
      ref: this,
      position: position,
      message: message,
      isMyMessage: isMyMessage,
      onDeleted: onDeleted,
      onReply: onReply,
      onForward: onForward,
      onCopy: onCopy,
    );
  }
}
