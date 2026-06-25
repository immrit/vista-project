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
import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/compat_extensions.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/modern_emoji_text.dart';
import '../models/message_reaction.dart' as reaction_models;

/// صفحه اطلاعات پیام
class MessageInfoScreen extends StatelessWidget {
  final MessageModel message;
  final String currentUserId;
  final List<reaction_models.MessageReaction> reactions;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.currentUserId,
    this.reactions = const [],
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
            _buildMessagePreview(context, theme, isDark),
            const SizedBox(height: 8),
            _buildTimestamps(context, theme, isDark),
            if (reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildReactions(context, theme, isDark),
            ],
            const SizedBox(height: 8),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: theme.primaryColor.withValues(alpha: 0.1),
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
              color: isMe
                  ? theme.primaryColor.withValues(alpha: 0.1)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: ModernEmojiText(
              message.content.isNotEmpty
                  ? '${message.content}\u200F'
                  : '[${_getAttachmentTypeLabel(message.attachmentType)}]',
              useModernEmoji: EmojiRenderPolicy.useModernEmojiRenderer(),
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
            color: Colors.black.withValues(alpha: 0.05),
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
          _buildTimelineItem(
            context: context,
            icon: Icons.send_rounded,
            label: 'ارسال شده',
            time: message.createdAt,
            color: Colors.blue,
            isFirst: true,
          ),
          if (message.isDelivered)
            _buildTimelineItem(
              context: context,
              icon: Icons.done_all_rounded,
              label: 'تحویل داده شده',
              time: message.createdAt.add(const Duration(seconds: 1)),
              color: Colors.green,
            ),
          if (message.isSeen)
            _buildTimelineItem(
              context: context,
              icon: Icons.visibility_rounded,
              label: 'خوانده شده',
              time: message.createdAt.add(const Duration(seconds: 2)),
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
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
                      color: theme.hintColor.withValues(alpha: 0.7),
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
    final grouped = reaction_models.ReactionSummary.groupReactions(
      reactions,
      currentUserId,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Spacer(),
              Text(
                '${reactions.length.toString().toPersianDigit()} نفر',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...grouped.map((summary) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(summary.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        '${summary.count.toString().toPersianDigit()} نفر',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...summary.reactions.map(
                    (reaction) => _buildReactionUserRow(
                      context,
                      theme,
                      reaction,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReactionUserRow(
    BuildContext context,
    ThemeData theme,
    reaction_models.MessageReaction reaction,
  ) {
    final displayName = _reactionDisplayName(reaction);
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';
    final isMe = reaction.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withValues(alpha: 0.08),
            ),
            child: ClipOval(
              child:
                  reaction.userAvatar != null && reaction.userAvatar!.isNotEmpty
                      ? AvatarAssetUtils.image(
                          source: reaction.userAvatar,
                          fit: BoxFit.cover,
                          memCacheWidth: 72,
                          memCacheHeight: 72,
                          placeholder: _buildInitialAvatar(theme, initial),
                          fallback: _buildInitialAvatar(theme, initial),
                        )
                      : _buildInitialAvatar(theme, initial),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? 'شما' : displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Text(
            reaction.emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(ThemeData theme, String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  String _reactionDisplayName(reaction_models.MessageReaction reaction) {
    final name = reaction.userName.trim();
    if (name.isNotEmpty && name != 'کاربر') return name;
    return name.isNotEmpty ? name : 'کاربر';
  }

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
