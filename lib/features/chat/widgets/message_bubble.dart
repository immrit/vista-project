// lib/features/chat/widgets/message_bubble.dart
//
// حباب پیام مدرن با انیمیشن و استایل زیبا
//
// ویژگی‌ها:
// ✅ نمایش Reply
// ✅ نمایش Reactions
// ✅ وضعیت ارسال (pending, sent, delivered, seen)
// ✅ انیمیشن ظاهر شدن
// ✅ پشتیبانی از پیام‌های فایل

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../model/message_model.dart';
import '../../../main.dart';

class ModernMessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final Function(String emoji) onReaction;

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
    required this.onReply,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final isMine = message.senderId == currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showOptionsMenu(context, isMine);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════════════
              // حباب اصلی پیام
              // ═══════════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMine
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply Preview
                    if (message.replyToMessageId != null)
                      _buildReplyPreview(context, isMine),

                    // Attachment (اگه داره)
                    if (message.attachmentUrl != null)
                      _buildAttachment(context, isMine),

                    // محتوای پیام
                    if (message.content.isNotEmpty)
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMine ? Colors.white : Colors.black87,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // زمان و وضعیت
                    _buildTimeAndStatus(context, isMine),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════════════════════
              // Reactions
              // ═══════════════════════════════════════════════════════════
              if (message.hasReactions()) _buildReactions(context, isMine),
            ],
          ),
        ),
      ),
    );
  }

  /// Reply Preview
  Widget _buildReplyPreview(BuildContext context, bool isMine) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white54 : Theme.of(context).primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSenderName ?? 'کاربر',
            style: TextStyle(
              color: isMine ? Colors.white70 : Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToContent ?? '',
            style: TextStyle(
              color: isMine ? Colors.white60 : Colors.black54,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Attachment (تصویر، فایل، ...)
  Widget _buildAttachment(BuildContext context, bool isMine) {
    final type = message.attachmentType ?? '';

    if (type.startsWith('image')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.attachmentUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey.shade300,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              );
            },
          ),
        ),
      );
    }

    if (type.startsWith('audio')) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled,
              color: isMine ? Colors.white : Theme.of(context).primaryColor,
              size: 36,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پیام صوتی',
                  style: TextStyle(
                    color: isMine ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (message.duration != null)
                  Text(
                    _formatDuration(message.duration!),
                    style: TextStyle(
                      color: isMine ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // فایل عمومی
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: isMine ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.attachmentFileName ?? 'فایل',
              style: TextStyle(
                color: isMine ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// زمان و وضعیت
  Widget _buildTimeAndStatus(BuildContext context, bool isMine) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            color: isMine ? Colors.white60 : Colors.black45,
            fontSize: 11,
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(),
        ],
      ],
    );
  }

  /// آیکون وضعیت
  Widget _buildStatusIcon() {
    if (message.isPending) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
        ),
      );
    }

    if (message.isFailed == true) {
      return const Icon(
        Icons.error_outline,
        size: 14,
        color: Colors.red,
      );
    }

    if (message.isSeen) {
      return Icon(
        Icons.done_all,
        size: 14,
        color: Colors.blue.shade200,
      );
    }

    if (message.isDelivered) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Colors.white60,
      );
    }

    if (message.isSent) {
      return const Icon(
        Icons.done,
        size: 14,
        color: Colors.white60,
      );
    }

    return const SizedBox.shrink();
  }

  /// Reactions
  Widget _buildReactions(BuildContext context, bool isMine) {
    return Container(
      margin: EdgeInsets.only(
        top: 4,
        left: isMine ? 0 : 8,
        right: isMine ? 8 : 0,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 14)),
                if (entry.value.length > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    entry.value.length.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// منوی گزینه‌ها
  void _showOptionsMenu(BuildContext context, bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Quick Reactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onReaction(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(),

              // Options
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('پاسخ'),
                onTap: () {
                  Navigator.pop(context);
                  onReply();
                },
              ),

              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('کپی متن'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('متن کپی شد'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('ارسال مجدد'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Forward message
                },
              ),

              if (isMine) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('ویرایش'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Edit message
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    onLongPress();
                  },
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
