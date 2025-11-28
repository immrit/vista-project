// lib/features/chat/widgets/animated_message_bubble.dart
//
// حباب پیام با انیمیشن‌های حرفه‌ای - نسخه کامل
//
// ویژگی‌ها:
// ✅ انیمیشن ظاهر شدن روان
// ✅ انیمیشن فشردن و رها کردن
// ✅ گرادینت و سایه زیبا
// ✅ نمایش وضعیت ارسال با انیمیشن
// ✅ پشتیبانی از Reactions
// ✅ پشتیبانی از Voice Message
// ✅ پشتیبانی از Image/Video
// ✅ پشتیبانی از File
// ✅ پشتیبانی از Link Preview
// ✅ نشان edited برای پیام‌های ویرایش شده
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import 'voice_message_bubble.dart';
import 'media_message_bubble.dart';
import 'file_message_bubble.dart';
import 'link_preview_bubble.dart';

/// نوع محتوای پیام
enum MessageContentType {
  text,
  voice,
  image,
  video,
  file,
  link,
}

class AnimatedMessageBubble extends StatefulWidget {
  final String messageId;
  final String content;
  final bool isMe;
  final DateTime time;
  
  // نوع محتوا
  final MessageContentType contentType;
  
  // وضعیت پیام
  final MessageStatus status;
  
  // Attachment (برای voice, image, video, file)
  final String? attachmentUrl;
  final String? attachmentFileName;
  final int? attachmentDuration; // برای voice/video
  final int? attachmentSize; // سایز فایل
  final List<double>? waveformData; // برای voice
  final String? thumbnailUrl; // برای video
  
  // Link Preview
  final LinkPreviewData? linkPreview;
  
  // Reply
  final String? replyToContent;
  final String? replyToSenderName;
  final String? replyToMessageId;
  final VoidCallback? onReplyTap;
  
  // Edit
  final bool isEdited;
  
  // Forward
  final bool isForwarded;
  final String? forwardedFromName;
  
  // Reactions
  final List<MessageReaction> reactions;
  final VoidCallback? onReactionTap;
  final Function(String emoji)? onAddReaction;
  
  // Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  
  // انیمیشن
  final bool animate;
  final int index;
  
  // فاصله از پیام قبلی (برای گروه‌بندی)
  final bool isFirstInGroup;
  final bool isLastInGroup;
  
  // Highlight (برای جستجو)
  final String? highlightQuery;

  const AnimatedMessageBubble({
    super.key,
    required this.messageId,
    required this.content,
    required this.isMe,
    required this.time,
    this.contentType = MessageContentType.text,
    this.status = MessageStatus.sent,
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentDuration,
    this.attachmentSize,
    this.waveformData,
    this.thumbnailUrl,
    this.linkPreview,
    this.replyToContent,
    this.replyToSenderName,
    this.replyToMessageId,
    this.onReplyTap,
    this.isEdited = false,
    this.isForwarded = false,
    this.forwardedFromName,
    this.reactions = const [],
    this.onReactionTap,
    this.onAddReaction,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.animate = true,
    this.index = 0,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.highlightQuery,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // انیمیشن scale با bounce effect
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    // انیمیشن slide
    _slideAnimation = Tween<double>(
      begin: widget.isMe ? 50.0 : -50.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // انیمیشن fade
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // شروع انیمیشن با تاخیر بر اساس index
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              alignment: widget.isMe 
                  ? Alignment.centerRight 
                  : Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: _buildBubble(theme),
    );
  }

  Widget _buildBubble(ChatTheme theme) {
    // فاصله متفاوت بر اساس گروه‌بندی
    final verticalPadding = widget.isLastInGroup ? 6.0 : 2.0;
    
    return Padding(
      padding: EdgeInsets.only(
        top: widget.isFirstInGroup ? 4 : 1,
        bottom: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: widget.isMe 
            ? MainAxisAlignment.end  // پیام من → راست
            : MainAxisAlignment.start, // پیام دیگران → چپ
        children: [
          // فاصله سمت چپ برای پیام من
          if (widget.isMe) const SizedBox(width: 60),
          
          // حباب پیام
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: widget.isMe ? 0 : 12,
                right: widget.isMe ? 12 : 0,
              ),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // حباب اصلی
                  GestureDetector(
                    onTap: () {
                      widget.onTap?.call();
                      HapticFeedback.selectionClick();
                    },
                    onLongPress: () {
                      setState(() => _isPressed = true);
                      HapticFeedback.mediumImpact();
                      widget.onLongPress?.call();
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) setState(() => _isPressed = false);
                      });
                    },
                    onDoubleTap: () {
                      HapticFeedback.lightImpact();
                      widget.onDoubleTap?.call();
                      _showQuickReaction(context);
                    },
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) => setState(() => _isPressed = false),
                    onTapCancel: () => setState(() => _isPressed = false),
                    child: AnimatedScale(
                      scale: _isPressed ? 0.97 : 1.0,
                      duration: const Duration(milliseconds: 80),
                      curve: Curves.easeOut,
                      child: _buildBubbleContent(theme),
                    ),
                  ),
                  
                  // Reactions
                  if (widget.reactions.isNotEmpty)
                    _buildReactions(theme),
                ],
              ),
            ),
          ),
          
          // فاصله سمت راست برای پیام دیگران
          if (!widget.isMe) const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(ChatTheme theme) {
    // گوشه‌های متفاوت بر اساس موقعیت در گروه
    final topRadius = Radius.circular(theme.bubbleRadius);
    final bottomRadius = Radius.circular(theme.bubbleRadius);
    final smallRadius = const Radius.circular(6);
    
    final borderRadius = BorderRadius.only(
      topLeft: widget.isMe ? topRadius : (widget.isFirstInGroup ? topRadius : smallRadius),
      topRight: widget.isMe ? (widget.isFirstInGroup ? topRadius : smallRadius) : topRadius,
      bottomLeft: widget.isMe ? bottomRadius : (widget.isLastInGroup ? smallRadius : smallRadius),
      bottomRight: widget.isMe ? (widget.isLastInGroup ? smallRadius : smallRadius) : bottomRadius,
    );

    final bubbleDecoration = BoxDecoration(
      gradient: widget.isMe ? theme.myBubbleGradient : null,
      color: widget.isMe ? null : theme.otherBubbleColor,
      borderRadius: borderRadius,
      boxShadow: [
        if (widget.isMe && theme.myBubbleShadow != null)
          theme.myBubbleShadow!
        else if (!widget.isMe && theme.otherBubbleShadow != null)
          theme.otherBubbleShadow!,
      ],
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: bubbleDecoration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Forwarded header
            if (widget.isForwarded) _buildForwardedHeader(theme),
            
            // Reply preview
            if (widget.replyToContent != null) _buildReplyPreview(theme),
            
            // محتوای بر اساس نوع
            _buildContentByType(theme),
            
            // زمان و وضعیت (فقط برای text و link)
            if (widget.contentType == MessageContentType.text ||
                widget.contentType == MessageContentType.link)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                child: _buildTimeAndStatus(theme),
              ),
          ],
        ),
      ),
    );
  }
  
  /// ساخت محتوا بر اساس نوع پیام
  Widget _buildContentByType(ChatTheme theme) {
    switch (widget.contentType) {
      case MessageContentType.voice:
        return _buildVoiceContent(theme);
      
      case MessageContentType.image:
        return _buildImageContent(theme);
      
      case MessageContentType.video:
        return _buildVideoContent(theme);
      
      case MessageContentType.file:
        return _buildFileContent(theme);
      
      case MessageContentType.link:
        return _buildLinkContent(theme);
      
      case MessageContentType.text:
        return _buildTextContent(theme);
    }
  }
  
  /// محتوای متنی
  Widget _buildTextContent(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // متن با هایلایت
          if (widget.highlightQuery != null && widget.highlightQuery!.isNotEmpty)
            _buildHighlightedText(theme)
          else
            Text(
              widget.content,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor
                    : theme.otherBubbleTextColor,
                fontSize: 15,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
  
  /// متن با هایلایت جستجو
  Widget _buildHighlightedText(ChatTheme theme) {
    final query = widget.highlightQuery!.toLowerCase();
    final text = widget.content;
    final lowerText = text.toLowerCase();
    
    final List<TextSpan> spans = [];
    int start = 0;
    
    while (true) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withOpacity(0.6),
          fontWeight: FontWeight.w600,
        ),
      ));
      
      start = index + query.length;
    }
    
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: widget.isMe
              ? theme.myBubbleTextColor
              : theme.otherBubbleTextColor,
          fontSize: 15,
          height: 1.35,
        ),
        children: spans,
      ),
    );
  }
  
  /// محتوای صوتی (Voice Message)
  Widget _buildVoiceContent(ChatTheme theme) {
    return VoiceMessageBubble(
      audioUrl: widget.attachmentUrl ?? '',
      durationSeconds: widget.attachmentDuration,
      waveformData: widget.waveformData,
      isMe: widget.isMe,
      time: widget.time,
    );
  }
  
  /// محتوای تصویری
  Widget _buildImageContent(ChatTheme theme) {
    return MediaMessageBubble(
      mediaUrl: widget.attachmentUrl ?? '',
      mediaType: MediaType.image,
      isMe: widget.isMe,
      time: widget.time,
      caption: widget.content.isNotEmpty ? widget.content : null,
    );
  }
  
  /// محتوای ویدیویی
  Widget _buildVideoContent(ChatTheme theme) {
    return MediaMessageBubble(
      mediaUrl: widget.attachmentUrl ?? '',
      thumbnailUrl: widget.thumbnailUrl,
      mediaType: MediaType.video,
      isMe: widget.isMe,
      time: widget.time,
      durationSeconds: widget.attachmentDuration,
      caption: widget.content.isNotEmpty ? widget.content : null,
    );
  }
  
  /// محتوای فایل
  Widget _buildFileContent(ChatTheme theme) {
    return FileMessageBubble(
      fileUrl: widget.attachmentUrl ?? '',
      fileName: widget.attachmentFileName ?? 'فایل',
      fileSizeBytes: widget.attachmentSize,
      isMe: widget.isMe,
      time: widget.time,
    );
  }
  
  /// محتوای لینک با پیش‌نمایش
  Widget _buildLinkContent(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LinkPreviewBubble(
        messageContent: widget.content,
        previewData: widget.linkPreview,
        isMe: widget.isMe,
        time: widget.time,
      ),
    );
  }
  
  /// هدر Forwarded
  Widget _buildForwardedHeader(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withOpacity(0.1)
            : theme.dividerColor.withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply_rounded,
            size: 14,
            color: theme.typingColor,
          ),
          const SizedBox(width: 4),
          Text(
            'فوروارد شده',
            style: TextStyle(
              color: theme.typingColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.forwardedFromName != null) ...[
            Text(
              ' از ',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
              ),
            ),
            Flexible(
              child: Text(
                widget.forwardedFromName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.typingColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ChatTheme theme) {
    return GestureDetector(
      onTap: () {
        if (widget.onReplyTap != null) {
          HapticFeedback.lightImpact();
          widget.onReplyTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.15)
              : theme.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            right: BorderSide(
              color: theme.typingColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.replyToSenderName ?? 'پاسخ به',
              style: TextStyle(
                color: theme.typingColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.replyToContent!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (widget.isMe
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor)
                    .withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAndStatus(ChatTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // نشان ویرایش شده
        if (widget.isEdited) ...[
          Text(
            'ویرایش شده',
            style: TextStyle(
              color: (widget.isMe
                      ? theme.myBubbleTextColor
                      : theme.secondaryTextColor)
                  .withOpacity(0.6),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '•',
            style: TextStyle(
              color: (widget.isMe
                      ? theme.myBubbleTextColor
                      : theme.secondaryTextColor)
                  .withOpacity(0.5),
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
        ],
        
        // زمان
        Text(
          _formatTime(widget.time),
          style: TextStyle(
            color: (widget.isMe
                    ? theme.myBubbleTextColor
                    : theme.secondaryTextColor)
                .withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        
        // وضعیت ارسال
        if (widget.isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(theme),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(ChatTheme theme) {
    IconData icon;
    Color color;
    
    switch (widget.status) {
      case MessageStatus.pending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.myBubbleTextColor.withOpacity(0.7),
          ),
        );
      case MessageStatus.sent:
        icon = Icons.check;
        color = theme.myBubbleTextColor.withOpacity(0.7);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = theme.myBubbleTextColor.withOpacity(0.7);
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = theme.sentColor;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = theme.errorColor;
        break;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(icon, size: 14, color: color),
        );
      },
    );
  }

  Widget _buildReactions(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: widget.onReactionTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.reactions.take(5).map((r) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Text(
                      r.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
              if (widget.reactions.length > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${widget.reactions.fold<int>(0, (sum, r) => sum + r.count)}',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickReaction(BuildContext context) {
    // انیمیشن لایک سریع با دبل تپ
    if (widget.onAddReaction != null) {
      widget.onAddReaction!('❤️');
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📊 ENUMS & MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

class MessageReaction {
  final String emoji;
  final int count;
  final List<String> userIds;
  final bool isMyReaction;

  const MessageReaction({
    required this.emoji,
    this.count = 1,
    this.userIds = const [],
    this.isMyReaction = false,
  });
}

