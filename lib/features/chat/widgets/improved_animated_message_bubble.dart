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
import 'gif_message_bubble.dart';
import 'media_message_bubble.dart';
import 'file_message_bubble.dart';
import '../../../services/telegram_read_receipt_service.dart';
import '../../../model/message_model.dart';

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
  final void Function(BuildContext context, MessageModel message)? onTap;
  final void Function(BuildContext context, MessageModel message)? onLongPress;
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

  // ✅ MessageModel برای دسترسی به statusNotifier
  final MessageModel? message;

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
    this.message,
  });

  @override
  State<ImprovedAnimatedMessageBubble> createState() =>
      _ImprovedAnimatedMessageBubbleState();
}

class _ImprovedAnimatedMessageBubbleState
    extends State<ImprovedAnimatedMessageBubble>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static final Set<String> _shownMessages = {};

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // 👈 اضافه کردن منطق KeepAlive
  @override
  bool get wantKeepAlive {
    // فقط در این شرایط ویجت را در حافظه نگه دار:
    // ۱. اگر ویس در حال پخش است (باید از سرویس پلیر چک شود - در مراحل بعد اضافه می‌کنیم)
    // ۲. اگر ویدیو در حال پخش است
    // ۳. یا اگر در حال آپلود است
    
    // فعلا برای آپلود و مدیاهای در حال پخش true برمی‌گردانیم
    final isUploading = widget.message?.isUploading ?? false;
    // اینجا بعدا شرط isPlayingAudio را اضافه می‌کنیم
    return isUploading;
  }

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
    super.build(context); // 👈 حتما این را صدا بزن برای AutomaticKeepAliveClientMixin
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
                if (widget.onTap != null && widget.message != null) {
                  widget.onTap!(context, widget.message!);
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                if (widget.onLongPress != null && widget.message != null) {
                  widget.onLongPress!(context, widget.message!);
                }
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
          mainAxisSize: MainAxisSize.min, // ✅ رفع خطای Overflow
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
    // 1. نمایش GIF ✅ اضافه شده
    if ((widget.attachmentType == 'gif' ||
            widget.message?.messageType == 'gif') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      // اینجا مطمئن می‌شویم که آبجکت مسیج داریم
      if (widget.message != null) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: GifMessageBubble(message: widget.message!),
        );
      }
    }

    // 2. Voice message
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
          // زمان و تیک داخل حباب - فقط این قسمت با ValueListenableBuilder rebuild میشه
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: _buildTimeAndStatus(theme),
          ),
        ],
      );
    }

    // 3. Image & Video message
    if ((widget.attachmentType == 'image' ||
            widget.attachmentType == 'video' ||
            widget.message?.attachmentType == 'image' ||
            widget.message?.attachmentType == 'video') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      final isVideo = widget.attachmentType == 'video' ||
          widget.message?.attachmentType == 'video';

      return MediaMessageBubble(
        mediaUrl: widget.attachmentUrl!,
        mediaType: isVideo ? MediaType.video : MediaType.image,
        isMe: widget.isMe,
        time: widget.time,
        caption: widget.content.isNotEmpty ? widget.content : null,
        durationSeconds: widget.duration,
      );
    }

    // 4. File message (Fallback for other attachment types)
    if (widget.attachmentUrl != null && widget.attachmentUrl!.isNotEmpty) {
      return FileMessageBubble(
        fileUrl: widget.attachmentUrl!,
        fileName: widget.attachmentFileName ?? 'File',
        isMe: widget.isMe,
        time: widget.time,
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
                    '${widget.content}\u200F',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor
                          : theme.otherBubbleTextColor,
                      fontSize: 15,
                      height: 1.4,
                      fontFamily: 'Vazir',
                      fontFamilyFallback: const [
                        'Apple Color Emoji',
                        'Segoe UI Emoji',
                        'Noto Color Emoji',
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          // ✅ زمان و تیک - فقط این قسمت rebuild میشه
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  // ✅ Build time and status - فقط این قسمت rebuild میشه
  Widget _buildTimeAndStatus(ChatTheme theme) {
    // ✅ اگر message موجود باشه، از ValueListenableBuilder استفاده کن
    if (widget.message != null) {
      return ValueListenableBuilder<MessageDeliveryStatus>(
        valueListenable: widget.message!.statusNotifier,
        builder: (context, status, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
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
                const SizedBox(width: 3),
                _buildStatusIconFromDeliveryStatus(theme, status),
              ],
            ],
          );
        },
      );
    }

    // Fallback به روش قدیمی
    final deliveryStatus = _convertToDeliveryStatus(widget.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
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
          const SizedBox(width: 3),
          _buildStatusIconFromDeliveryStatus(theme, deliveryStatus),
        ],
      ],
    );
  }

  Widget _buildStatusIconFromDeliveryStatus(
      ChatTheme theme, MessageDeliveryStatus status) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: TelegramMessageStatus(
        key: ValueKey(status),
        status: status,
        size: 12,
        customColor: status == MessageDeliveryStatus.read
            ? MessageStatusColors.read
            : theme.myBubbleTextColor.withOpacity(0.7),
      ),
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
