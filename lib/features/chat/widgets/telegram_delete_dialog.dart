// lib/features/chat/widgets/telegram_delete_dialog.dart
//
// دیالوگ حذف پیام مشابه تلگرام با قابلیت Undo
//

import 'package:flutter/material.dart';
import '../../../model/message_model.dart';

/// نوع دیالوگ حذف
enum DeleteDialogType {
  singleMessage,
  entireChat,
}

/// کلاس اصلی دیالوگ حذف تلگرامی
class TelegramDeleteDialog {
  /// نمایش دیالوگ حذف (پیام یا چت)
  static Future<void> show({
    required BuildContext context,
    required DeleteDialogType type,
    required bool canDeleteForEveryone,
    VoidCallback? onDeleteForMe,
    VoidCallback? onDeleteForEveryone,
    // فقط برای singleMessage
    MessageModel? message,
    String? otherUserName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _TelegramDeleteDialogWidget(
        type: type,
        canDeleteForEveryone: canDeleteForEveryone,
        message: message,
        otherUserName: otherUserName ?? 'کاربر دیگر',
      ),
    );

    if (result != null && context.mounted) {
      if (result) {
        // حذف برای همه
        onDeleteForEveryone?.call();
      } else {
        // حذف برای من
        onDeleteForMe?.call();
      }
    }
  }
}

/// ویجت دیالوگ حذف با استایل تلگرام
class _TelegramDeleteDialogWidget extends StatelessWidget {
  final DeleteDialogType type;
  final bool canDeleteForEveryone;
  final MessageModel? message;
  final String otherUserName;

  const _TelegramDeleteDialogWidget({
    required this.type,
    required this.canDeleteForEveryone,
    this.message,
    required this.otherUserName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        type == DeleteDialogType.entireChat ? 'پاکسازی چت' : 'حذف پیام',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // گزینه حذف یک‌طرفه
          _buildMenuItem(
            context: context,
            icon: Icons.delete_outline,
            title: 'حذف برای من',
            subtitle: type == DeleteDialogType.entireChat
                ? 'تمام پیام‌ها فقط از لیست شما حذف می‌شود'
                : 'پیام فقط از لیست شما حذف می‌شود',
            onTap: () {
              Navigator.of(context).pop(false); // false = forMe
            },
            isDark: isDark,
          ),
          
          const SizedBox(height: 8),
          
          // گزینه حذف دوطرفه
          if (canDeleteForEveryone)
            _buildMenuItem(
              context: context,
              icon: Icons.delete_forever,
              title: 'حذف برای همه',
              subtitle: type == DeleteDialogType.entireChat
                  ? 'تمام پیام‌ها برای $otherUserName و شما حذف می‌شود'
                  : 'پیام برای $otherUserName و شما حذف می‌شود',
              onTap: () {
                Navigator.of(context).pop(true); // true = forEveryone
              },
              isDark: isDark,
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'انصراف',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Color? textColor,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: iconColor ?? (isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor ?? (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
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
}
