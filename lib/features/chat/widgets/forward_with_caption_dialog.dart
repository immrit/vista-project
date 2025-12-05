// lib/features/chat/widgets/forward_with_caption_dialog.dart
//
// دیالوگ فوروارد با امکان افزودن کپشن
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_forward_service.dart';
import '../theme/chat_theme.dart';

final messageForwardServiceProvider = Provider((ref) {
  return MessageForwardService();
});

class ForwardWithCaptionDialog extends ConsumerStatefulWidget {
  final List<String> messageIds;
  final String targetConversationId;
  final String targetName;

  const ForwardWithCaptionDialog({
    super.key,
    required this.messageIds,
    required this.targetConversationId,
    required this.targetName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<String> messageIds,
    required String targetConversationId,
    required String targetName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ForwardWithCaptionDialog(
        messageIds: messageIds,
        targetConversationId: targetConversationId,
        targetName: targetName,
      ),
    );
  }

  @override
  ConsumerState<ForwardWithCaptionDialog> createState() =>
      _ForwardWithCaptionDialogState();
}

class _ForwardWithCaptionDialogState
    extends ConsumerState<ForwardWithCaptionDialog> {
  final _captionController = TextEditingController();
  bool _isForwarding = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _forward() async {
    setState(() => _isForwarding = true);

    try {
      final service = ref.read(messageForwardServiceProvider);
      final result = await service.forwardWithCaption(
        messageIds: widget.messageIds,
        targetConversationId: widget.targetConversationId,
        caption: _captionController.text,
      );

      if (mounted) {
        if (result.isSuccess) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پیام با موفقیت فوروارد شد'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isForwarding = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isForwarding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Dialog(
      backgroundColor: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.forward_rounded,
                  color: theme.sendButtonColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فوروارد به',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.targetName,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Caption Input
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                hintText: 'افزودن کپشن (اختیاری)...',
                hintStyle: TextStyle(color: theme.secondaryTextColor),
                filled: true,
                fillColor: theme.inputBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isForwarding
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    'لغو',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isForwarding ? null : _forward,
                  icon: _isForwarding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('فوروارد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.sendButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}









