// lib/features/chat/widgets/edit_message_dialog.dart
//
// دیالوگ ویرایش پیام - با الهام از تلگرام
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_actions_service.dart';
import '../theme/chat_theme.dart';
import '../../../utils/user_friendly_error_utils.dart';

class EditMessageDialog extends ConsumerStatefulWidget {
  final String messageId;
  final String currentContent;
  final VoidCallback? onSuccess;

  const EditMessageDialog({
    super.key,
    required this.messageId,
    required this.currentContent,
    this.onSuccess,
  });

  /// نمایش دیالوگ
  static Future<bool?> show(
    BuildContext context, {
    required String messageId,
    required String currentContent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => EditMessageDialog(
        messageId: messageId,
        currentContent: currentContent,
      ),
    );
  }

  @override
  ConsumerState<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends ConsumerState<EditMessageDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newContent = _controller.text.trim();
    
    if (newContent.isEmpty) {
      setState(() => _error = 'متن پیام نمی‌تواند خالی باشد');
      return;
    }
    
    if (newContent == widget.currentContent.trim()) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ref.read(messageActionsProvider).edit(
        messageId: widget.messageId,
        newContent: newContent,
      );

      if (mounted) {
        if (result.isSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isLoading = false;
            _error = result.error;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = UserFriendlyErrorUtils.getUserFriendlyMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return AlertDialog(
      backgroundColor: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.edit_rounded,
            color: theme.sendButtonColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'ویرایش پیام',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // فیلد ویرایش
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: 'متن جدید...',
              hintStyle: TextStyle(color: theme.secondaryTextColor),
              filled: true,
              fillColor: theme.inputBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.sendButtonColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),

          // خطا
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.errorColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // توضیح محدودیت زمانی
          const SizedBox(height: 8),
          Text(
            'می‌توانید پیام‌ها را تا ۴۸ ساعت بعد از ارسال ویرایش کنید.',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'انصراف',
            style: TextStyle(color: theme.secondaryTextColor),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.sendButtonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ذخیره'),
        ),
      ],
    );
  }
}

