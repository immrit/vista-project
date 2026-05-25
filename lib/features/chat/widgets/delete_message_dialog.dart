// lib/features/chat/widgets/delete_message_dialog.dart
//
// دیالوگ حذف پیام (ویستا استایل)
//

import 'package:flutter/material.dart';

/// نتیجه دیالوگ حذف
class DeleteMessageResult {
  final bool confirmed;
  final bool deleteForEveryone;

  const DeleteMessageResult({
    required this.confirmed,
    this.deleteForEveryone = false,
  });

  static const cancelled = DeleteMessageResult(confirmed: false);
}

/// دیالوگ حذف پیام با گزینه Delete for Everyone
class DeleteMessageDialog extends StatefulWidget {
  final bool isMyMessage;
  final int messageCount;

  const DeleteMessageDialog({
    super.key,
    required this.isMyMessage,
    this.messageCount = 1,
  });

  /// نمایش دیالوگ و دریافت نتیجه
  static Future<DeleteMessageResult> show(
    BuildContext context, {
    required bool isMyMessage,
    int messageCount = 1,
  }) async {
    final result = await showDialog<DeleteMessageResult>(
      context: context,
      builder: (context) => DeleteMessageDialog(
        isMyMessage: isMyMessage,
        messageCount: messageCount,
      ),
    );
    return result ?? DeleteMessageResult.cancelled;
  }

  @override
  State<DeleteMessageDialog> createState() => _DeleteMessageDialogState();
}

class _DeleteMessageDialogState extends State<DeleteMessageDialog> {
  bool _deleteForEveryone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final messageText =
        widget.messageCount == 1 ? 'این پیام' : '${widget.messageCount} پیام';

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.delete_outline,
            color: Colors.red.shade400,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'حذف پیام',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'آیا از حذف $messageText مطمئن هستید؟',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          if (widget.isMyMessage) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CheckboxListTile(
                value: _deleteForEveryone,
                onChanged: (value) {
                  setState(() {
                    _deleteForEveryone = value ?? false;
                  });
                },
                title: const Text(
                  'حذف برای همه',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'پیام برای طرف مقابل هم حذف می‌شود',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                activeColor: Colors.red.shade400,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(DeleteMessageResult.cancelled);
          },
          child: Text(
            'انصراف',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(DeleteMessageResult(
              confirmed: true,
              deleteForEveryone: _deleteForEveryone,
            ));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}
