// lib/features/chat/widgets/improved_animated_message_bubble.dart
//
// حباب پیام با نمایش زمان ثابت و شناور بهبود یافته
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';

/// وضعیت پیام
enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

/// واکنش پیام
class MessageReaction {
  final String emoji;
  final int count;
  final List<String> userIds;
  final bool isMyReaction;

  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.userIds,
    required this.isMyReaction,
  });
}

class ImprovedAnimatedMessageBubble extends StatefulWidget {
  final String messageId;
  final String content;
  final bool isMe;
  final DateTime time;
  final MessageStatus status;

  // Reply
  final String? replyToContent;
  final String? replyToSenderName;
  final String? replyToMessageId;
  final VoidCallback? onReplyTap;

  // Reactions
  final List<MessageReaction> reactions;
  final Function(String emoji)? onAddReaction;

  // Interactions
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  // Animation
  final bool animate;
  final int index;

  // Grouping
  final bool isFirstInGroup;
  final bool isLastInGroup;

  // Attachments
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final int? duration; // برای voice messages

  const ImprovedAnimatedMessageBubble({
    super.key,
    required this.messageId,
    required this.content,
    required this.isMe,
    required this.time,
    required this.status,
    this.replyToContent,
    this.replyToSenderName,
    this.replyToMessageId,
    this.onReplyTap,
    this.reactions = const [],
    this.onAddReaction,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.animate = true,
    this.index = 0,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.duration,
  });

  @override
  State<ImprovedAnimatedMessageBubble> createState() =>
      _ImprovedAnimatedMessageBubbleState();
}

class _ImprovedAnimatedMessageBubbleState
    extends State<ImprovedAnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _showTime = false; // نمایش زمان ثابت

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (widget.animate) {
      Future.delayed(Duration(milliseconds: widget.index * 50), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = 1.0;
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isMe ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    // Wrap the whole interactive bubble in a RepaintBoundary to reduce
    // unnecessary repaints when the list is scrolling. This keeps the
    // existing animation structure intact but isolates renders.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () {
                // Toggle نمایش زمان
                setState(() => _showTime = !_showTime);
                HapticFeedback.selectionClick();
                widget.onTap?.call();
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                widget.onLongPress?.call();
              },
              onDoubleTap: widget.onDoubleTap,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.isMe ? 60 : 12,
                  right: widget.isMe ? 12 : 60,
                  bottom: widget.isLastInGroup ? 8 : 2,
                  top: widget.isFirstInGroup ? 8 : 2,
                ),
                child: Column(
                  crossAxisAlignment: widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // حباب اصلی پیام
                    Row(
                      mainAxisAlignment: widget.isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // زمان سمت چپ (برای پیام‌های دیگران)
                        if (!widget.isMe && _showTime)
                          _buildFixedTimeLabel(theme, isLeft: true),

                        // محتوای پیام
                        Flexible(
                          child: _buildMessageBubble(theme),
                        ),

                        // زمان سمت راست (برای پیام‌های خودم)
                        if (widget.isMe && _showTime)
                          _buildFixedTimeLabel(theme, isLeft: false),
                      ],
                    ),

                    // زمان پایین پیام (همیشه نمایش داده می‌شود - نسخه کوتاه)
                    if (widget.isLastInGroup)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 4,
                          left: widget.isMe ? 0 : 48,
                          right: widget.isMe ? 48 : 0,
                        ),
                        child: _buildBottomTimeLabel(theme),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// حباب پیام اصلی
  Widget _buildMessageBubble(ChatTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isMe ? theme.myBubbleColor : theme.otherBubbleColor,
        borderRadius: _getBorderRadius(),
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
          // Reply (اگر وجود داشت)
          if (widget.replyToContent != null) _buildReplySection(theme),

          // محتوای اصلی
          _buildContent(theme),

          // Reactions (اگر وجود داشت)
          if (widget.reactions.isNotEmpty) _buildReactionsSection(theme),
        ],
      ),
    );
  }

  /// محاسبه BorderRadius بر اساس موقعیت در گروه
  BorderRadius _getBorderRadius() {
    const radius = Radius.circular(18);
    const smallRadius = Radius.circular(4);

    if (widget.isMe) {
      return BorderRadius.only(
        topLeft: radius,
        topRight: widget.isFirstInGroup ? radius : smallRadius,
        bottomLeft: radius,
        bottomRight: widget.isLastInGroup ? radius : smallRadius,
      );
    } else {
      return BorderRadius.only(
        topLeft: widget.isFirstInGroup ? radius : smallRadius,
        topRight: radius,
        bottomLeft: widget.isLastInGroup ? radius : smallRadius,
        bottomRight: radius,
      );
    }
  }

  /// بخش Reply
  Widget _buildReplySection(ChatTheme theme) {
    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            right: BorderSide(
              color: theme.sendButtonColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.replyToSenderName ?? 'کاربر',
              style: TextStyle(
                color: theme.sendButtonColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.replyToContent ?? '',
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor.withOpacity(0.8)
                    : theme.otherBubbleTextColor.withOpacity(0.8),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// محتوای اصلی پیام
  Widget _buildContent(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // متن پیام
          if (widget.content.isNotEmpty)
            Text(
              widget.content,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor
                    : theme.otherBubbleTextColor,
                fontSize: 15,
                height: 1.4,
              ),
            ),

          // فاصله بین متن و وضعیت
          if (widget.content.isNotEmpty) const SizedBox(height: 4),

          // وضعیت و زمان درون حباب (فقط برای پیام‌های خودم)
          if (widget.isMe)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.time.toFixedTimeLabel(),
                  style: TextStyle(
                    color: theme.myBubbleTextColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                _buildStatusIcon(theme),
              ],
            ),
        ],
      ),
    );
  }

  /// آیکون وضعیت پیام
  Widget _buildStatusIcon(ChatTheme theme) {
    IconData icon;
    Color color = theme.myBubbleTextColor.withOpacity(0.7);

    switch (widget.status) {
      case MessageStatus.pending:
        icon = Icons.access_time_rounded;
        break;
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = theme.sendButtonColor;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = theme.errorColor;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }

  /// بخش Reactions
  Widget _buildReactionsSection(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: widget.reactions.map((reaction) {
          return GestureDetector(
            onTap: () => widget.onAddReaction?.call(reaction.emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: reaction.isMyReaction
                    ? theme.sendButtonColor.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reaction.isMyReaction
                      ? theme.sendButtonColor
                      : theme.dividerColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reaction.emoji, style: const TextStyle(fontSize: 12)),
                  if (reaction.count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      reaction.count.toString().toPersianDigit(),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isMe
                            ? theme.myBubbleTextColor
                            : theme.otherBubbleTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// نمایش زمان ثابت کنار پیام (وقتی tap می‌شود)
  Widget _buildFixedTimeLabel(ChatTheme theme, {required bool isLeft}) {
    return AnimatedOpacity(
      opacity: _showTime ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: EdgeInsets.only(
          left: isLeft ? 0 : 8,
          right: isLeft ? 8 : 0,
          bottom: 8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.time.toFullDateTimeLabel(),
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// نمایش زمان پایین پیام (همیشه نمایش داده می‌شود)
  Widget _buildBottomTimeLabel(ChatTheme theme) {
    return Text(
      widget.time.toFixedTimeLabel(),
      style: TextStyle(
        color: theme.secondaryTextColor.withOpacity(0.7),
        fontSize: 10,
      ),
    );
  }
}
