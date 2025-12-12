// lib/features/chat/widgets/improved_animated_message_bubble.dart
//
// حباب پیام با نمایش زمان ثابت و شناور بهبود یافته
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';
import 'voice_message_bubble.dart';
import 'telegram_message_status.dart';
import '../../../services/telegram_read_receipt_service.dart';

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

  // Forwarding
  final bool isForwarded;
  final String? forwardedFrom;

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
    this.isForwarded = false,
    this.forwardedFrom,
  });

  @override
  State<ImprovedAnimatedMessageBubble> createState() =>
      _ImprovedAnimatedMessageBubbleState();
}

class _ImprovedAnimatedMessageBubbleState
    extends State<ImprovedAnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  static final Set<String> _shownMessages = {};

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    final uniqueId = widget.messageId;

    bool shouldAnimate = widget.animate;

    if (shouldAnimate) {
      if (widget.isMe) {
        if (widget.status != MessageStatus.pending) {
          shouldAnimate = false;
        }
      } else {
        if (_shownMessages.contains(uniqueId)) {
          shouldAnimate = false;
        }
      }

      final isRecent = DateTime.now().difference(widget.time).inSeconds < 60;
      if (!isRecent) {
        shouldAnimate = false;
      }
    }

    if (shouldAnimate) {
      _shownMessages.add(uniqueId);
      Future.delayed(Duration(milliseconds: widget.index * 30), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = 1.0;
      _shownMessages.add(uniqueId);
    }
  }

  void _setupAnimations() {
    // Faster animation for snappier optimistic message insertion
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Fade completes earlier to make the bubble visible quickly
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.9),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Slightly shorter slide interval to speed entry
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Use easeOutBack for a quick, pleasant pop
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
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

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () {
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
                    Row(
                      mainAxisAlignment: widget.isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: _buildMessageBubble(theme),
                        ),
                      ],
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
          if (widget.isForwarded) _buildForwardHeader(theme),
          if (widget.replyToContent != null) _buildReplySection(theme),
          _buildContent(theme),
          if (widget.reactions.isNotEmpty) _buildReactionsSection(theme),
        ],
      ),
    );
  }

  Widget _buildForwardHeader(ChatTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.sendButtonColor.withOpacity(0.5),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forwarded from',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: theme.sendButtonColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.forwardedFrom ?? 'Unknown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildContent(ChatTheme theme) {
    // Voice message
    if ((widget.attachmentType == 'audio' ||
            widget.attachmentType == 'voice') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceMessageBubble(
            messageId: widget.messageId,
            audioUrl: widget.attachmentUrl!,
            durationSeconds: widget.duration,
            isMe: widget.isMe,
            time: widget.time,
          ),
          // زمان و تیک داخل حباب
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  widget.time.toFixedTimeLabel(),
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withOpacity(0.7)
                        : theme.otherBubbleTextColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(theme),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Text message - با ساعت inline در پایین سمت چپ
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // محتوای متنی
          Flexible(
            child: widget.content.isNotEmpty
                ? Text(
                    widget.content,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor
                          : theme.otherBubbleTextColor,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          // زمان و تیک
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.time.toFixedTimeLabel(),
                style: TextStyle(
                  color: widget.isMe
                      ? theme.myBubbleTextColor.withOpacity(0.7)
                      : theme.otherBubbleTextColor.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 3), // فاصله کمتر برای ظرافت
                _buildStatusIcon(theme),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ChatTheme theme) {
    // ✅ استفاده از ویجت تیک حرفه‌ای تلگرام - ظریف و کوچک
    final deliveryStatus = _convertToDeliveryStatus(widget.status);
    
    return TelegramMessageStatus(
      status: deliveryStatus,
      size: 12, // کوچک‌تر برای ظرافت بیشتر
      customColor: deliveryStatus == MessageDeliveryStatus.read
          ? MessageStatusColors.read
          : theme.myBubbleTextColor.withOpacity(0.7),
    );
  }

  /// تبدیل MessageStatus به MessageDeliveryStatus
  MessageDeliveryStatus _convertToDeliveryStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return MessageDeliveryStatus.pending;
      case MessageStatus.sent:
        return MessageDeliveryStatus.sent;
      case MessageStatus.delivered:
        return MessageDeliveryStatus.delivered;
      case MessageStatus.read:
        return MessageDeliveryStatus.read;
      case MessageStatus.failed:
        return MessageDeliveryStatus.failed;
    }
  }

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
                            ? theme.myBubbleTextColor.withOpacity(0.7)
                            : theme.otherBubbleTextColor.withOpacity(0.7),
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

}
