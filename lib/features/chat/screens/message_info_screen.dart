// lib/features/chat/screens/message_info_screen.dart
//
// اطلاعات دقیق پیام (الهام از ویستا)
//
// ویژگی‌ها:
// ✅ زمان ارسال/تحویل/خوانده شدن
// ✅ لیست خوانده‌شده توسط (برای گروه‌ها)
// ✅ تاریخچه ویرایش
// ✅ Reactions details
//

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../model/message_model.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/telegram_emoji_text.dart';

/// صفحه اطلاعات پیام
class MessageInfoScreen extends StatelessWidget {
  final MessageModel message;
  final String currentUserId;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('اطلاعات پیام'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // پیش‌نمایش پیام
            _buildMessagePreview(context, theme, isDark),

            const SizedBox(height: 8),

            // زمان‌بندی
            _buildTimestamps(context, theme, isDark),

            const SizedBox(height: 8),

            // واکنش‌ها
            if (message.reactions.isNotEmpty)
              _buildReactions(context, theme, isDark),

            const SizedBox(height: 8),

            // تاریخچه ویرایش
            // TODO: Add editedAt field to MessageModel
            // if (message.editedAt != null)
            //   _buildEditHistory(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview(
      BuildContext context, ThemeData theme, bool isDark) {
    final isMe = message.senderId == currentUserId;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isMe ? Icons.send_rounded : Icons.reply_rounded,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isMe ? 'پیام شما' : 'پیام دریافتی',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isMe ? theme.primaryColor.withOpacity(0.1) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            child: TelegramEmojiText(
              message.content.isNotEmpty
                  ? '${message.content}\u200F'
                  : '[${_getAttachmentTypeLabel(message.attachmentType)}]',
              useTelegramEmoji: EmojiRenderPolicy.useTelegramEmojiRenderer(),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: theme.textTheme.bodyLarge?.color,
                fontFamily: 'Vazir',
                fontFamilyFallback: const [
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                  'Noto Color Emoji',
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamps(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'زمان‌بندی',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ارسال شده
          _buildTimelineItem(
            context: context,
            icon: Icons.send_rounded,
            label: 'ارسال شده',
            time: message.createdAt,
            color: Colors.blue,
            isFirst: true,
          ),

          // تحویل داده شده
          if (message.isDelivered)
            _buildTimelineItem(
              context: context,
              icon: Icons.done_all_rounded,
              label: 'تحویل داده شده',
              time: message.createdAt.add(const Duration(
                  seconds: 1)), // TODO: Use deliveredAt when available
              color: Colors.green,
            ),

          // خوانده شده
          if (message.isSeen)
            _buildTimelineItem(
              context: context,
              icon: Icons.visibility_rounded,
              label: 'خوانده شده',
              time: message.createdAt.add(const Duration(
                  seconds: 2)), // TODO: Use seenAt when available
              color: Colors.purple,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required DateTime time,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        children: [
          // خط عمودی
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withOpacity(0.3),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // محتوا
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFullDateTime(time),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeago.format(time, locale: 'fa'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context, ThemeData theme, bool isDark) {
    final reactions = message.reactions;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_emotions_rounded,
                  color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'واکنش‌ها',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: reactions.entries.map((entry) {
              final emoji = entry.key;
              final users = entry.value as List;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${users.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // TODO: Uncomment when editedAt field is added to MessageModel
  // Widget _buildEditHistory(BuildContext context, ThemeData theme, bool isDark) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(Icons.history_rounded, color: theme.primaryColor, size: 20),
  //             const SizedBox(width: 8),
  //             Text(
  //               'تاریخچه ویرایش',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.w600,
  //                 color: theme.textTheme.titleLarge?.color,
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.orange.withOpacity(0.1),
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(
  //               color: Colors.orange.withOpacity(0.3),
  //             ),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(Icons.edit_rounded, color: Colors.orange, size: 18),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       'ویرایش شده',
  //                       style: TextStyle(
  //                         fontSize: 13,
  //                         fontWeight: FontWeight.w600,
  //                         color: theme.textTheme.titleLarge?.color,
  //                       ),
  //                     ),
  //                     Text(
  //                       _formatFullDateTime(message.editedAt!),
  //                       style: TextStyle(
  //                         fontSize: 12,
  //                         color: theme.hintColor,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  String _getAttachmentTypeLabel(String? type) {
    switch (type) {
      case 'image':
        return 'تصویر';
      case 'video':
        return 'ویدیو';
      case 'audio':
      case 'voice':
        return 'پیام صوتی';
      case 'document':
        return 'سند';
      case 'location':
        return 'مکان';
      case 'contact':
        return 'مخاطب';
      default:
        return 'فایل';
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    final jalali = Jalali.fromDateTime(dateTime);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '${jalali.formatter.wN} ${jalali.day} ${jalali.formatter.mN} ${jalali.year} - $hour:$minute';
  }
}
