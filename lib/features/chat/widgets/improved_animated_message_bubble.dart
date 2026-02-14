// lib/features/chat/widgets/improved_animated_message_bubble.dart
//
// حباب پ�Oا�. با �?�.ا�Oش ز�.ا�? ثابت �^ ش�?ا�^ر ب�?ب�^د �Oافت�?
//

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../utils/rich_text_parser.dart';
import '../../../utils/navigation_helper.dart';

/// �^ضع�Oت پ�Oا�.
enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

/// �^اک�?ش پ�Oا�.
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
  final void Function(StoryReplyData data)? onStoryReplyTap;

  // Reactions
  final List<MessageReaction> reactions;
  final Function(String emoji)? onAddReaction;

  // Interactions
  final void Function(BuildContext context, MessageModel message)? onTap;
  final void Function(BuildContext context, MessageModel message)? onLongPress;
  final VoidCallback? onDoubleTap;
  final Function(String)? onLinkTap;

  // Animation
  final bool animate;
  final int index;

  // Group display
  final String? senderName;
  final bool showSenderNameInBubble;
  final bool compactWithAvatar;

  // Grouping
  final bool isFirstInGroup;
  final bool isLastInGroup;

  // Attachments
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final int? duration; // برا�O voice messages

  // Forwarding
  final bool isForwarded;
  final String? forwardedFrom;
  final VoidCallback? onRetryUpload;

  // �o. MessageModel برا�O دسترس�O ب�? statusNotifier
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
    this.onStoryReplyTap,
    this.reactions = const [],
    this.onAddReaction,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onLinkTap,
    this.animate = true,
    this.index = 0,
    this.senderName,
    this.showSenderNameInBubble = false,
    this.compactWithAvatar = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.duration,
    this.isForwarded = false,
    this.forwardedFrom,
    this.onRetryUpload,
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

  // �Y'^ اضاف�? کرد�? �.�?ط�, KeepAlive
  @override
  bool get wantKeepAlive {
    // ف�,ط در ا�O�? شرا�Oط �^�Oجت را در حافظ�? �?گ�? دار:
    // ۱. اگر �^�Oس در حا�" پخش است (با�Oد از سر�^�Oس پ�"�Oر �?ک ش�^د - در �.راح�" بعد اضاف�? �.�O�?Oک�?�O�.)
    // ۲. اگر �^�Oد�O�^ در حا�" پخش است
    // ۳. �Oا اگر در حا�" آپ�"�^د است

    // فع�"ا برا�O آپ�"�^د �^ �.د�Oا�?ا�O در حا�" پخش true بر�.�O�?Oگردا�?�O�.
    final isUploading = widget.message?.isUploading ?? false;
    // ا�O�?جا بعدا شرط isPlayingAudio را اضاف�? �.�O�?Oک�?�O�.
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
    super.build(
        context); // �Y'^ حت�.ا ا�O�? را صدا بز�? برا�O AutomaticKeepAliveClientMixin
    final theme = context.chatTheme;
    const edgeInset = 1.0;
    const oppositeInset = 30.0;

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
                  left: widget.isMe
                      ? oppositeInset
                      : (widget.compactWithAvatar ? 6 : edgeInset),
                  right: widget.isMe ? edgeInset : oppositeInset,
                  bottom: widget.isLastInGroup ? 4 : 1.5,
                  top: widget.isFirstInGroup ? 4 : 1.5,
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
    final canonicalType = _canonicalAttachmentType();
    // تشخ�Oص �.�Oد�O�. ک�? آ�Oا پ�Oا�. �.د�Oا (عکس/�^�Oد�O�^) �?ست �Oا �?�?
    final isMedia = (canonicalType == 'image' || canonicalType == 'video') &&
        widget.attachmentUrl != null;

    return Container(
      // برا�O �.د�Oا�O ClipRRect ر�^ اع�.ا�" �.�Oک�?�O�. تا گ�^ش�?�?O�?ا گرد بش�?
      clipBehavior: isMedia ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: widget.isMe ? theme.myBubbleColor : theme.otherBubbleColor,
        borderRadius: _getBorderRadius(theme),
        // �o. سا�O�? حذف شد برا�O پرف�^ر�.�?س
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shouldShowSenderName())
            _buildSenderName(theme, widget.senderName!.trim()),
          if (widget.isForwarded) _buildForwardHeader(theme),
          if (widget.message?.storyReplyData != null)
            _buildStoryReplySection(theme),
          if (widget.replyToContent != null) _buildReplySection(theme),

          // �.حت�^ا�O اص�"�O
          _buildContent(theme),

          // برا�O �.د�Oا�O ر�O�?Oاکش�?�?O�?ا ر�^ ر�^�O عکس �?�?د�" �.�Oک�?�O�. �Oا پا�O�O�?ش (ت�"گرا�. پا�O�O�?ش �.�Oذار�?)
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

  bool _shouldShowSenderName() {
    if (widget.isMe || !widget.showSenderNameInBubble) return false;
    final name = widget.senderName?.trim();
    return name != null && name.isNotEmpty;
  }

  Widget _buildSenderName(ChatTheme theme, String name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Text(
        name,
        style: TextStyle(
          color: theme.sendButtonColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(ChatTheme theme) {
    return theme.bubbleBorderRadius(
      isMe: widget.isMe,
      isFirstInGroup: widget.isFirstInGroup,
      isLastInGroup: widget.isLastInGroup,
    );
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
          mainAxisSize: MainAxisSize.min, // �o. رفع خطا�O Overflow
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

  Widget _buildStoryReplySection(ChatTheme theme) {
    final storyData = widget.message?.storyReplyData;
    if (storyData == null) return const SizedBox.shrink();

    final isExpired = _isStoryReplyExpired(storyData);
    final headerText = widget.isMe
        ? 'پاسخ ب�? است�^ر�O ${storyData.storyOwnerUsername}'
        : 'پاسخ ب�? است�^ر�O ش�.ا';
    final secondaryText = isExpired
        ? 'است�^ر�O �.�?�,ض�O شد�?'
        : (storyData.storyMediaType == 'video' ? '�^�Oد�O�^' : 'تص�^�Oر');

    return GestureDetector(
      onTap: widget.onStoryReplyTap != null
          ? () => widget.onStoryReplyTap!(storyData)
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            right: BorderSide(
              color: theme.sendButtonColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStoryReplyThumbnail(theme, storyData, isExpired),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headerText,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: theme.sendButtonColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secondaryText,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor.withOpacity(0.7)
                          : theme.otherBubbleTextColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryReplyThumbnail(
      ChatTheme theme, StoryReplyData data, bool isExpired) {
    final hasThumbnail = data.storyThumbnailUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          if (hasThumbnail)
            CachedNetworkImage(
              imageUrl: data.storyThumbnailUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 56,
                height: 56,
                color: theme.dividerColor.withOpacity(0.2),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 56,
                height: 56,
                color: theme.dividerColor.withOpacity(0.2),
                child: Icon(
                  data.storyMediaType == 'video' ? Icons.videocam : Icons.image,
                  color: theme.dividerColor.withOpacity(0.6),
                  size: 24,
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              color: theme.dividerColor.withOpacity(0.2),
              child: Icon(
                data.storyMediaType == 'video' ? Icons.videocam : Icons.image,
                color: theme.dividerColor.withOpacity(0.6),
                size: 24,
              ),
            ),
          if (data.storyMediaType == 'video')
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          if (isExpired)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Icon(
                    Icons.schedule,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isStoryReplyExpired(StoryReplyData data) {
    final expiresAt = data.storyCreatedAt.add(const Duration(hours: 24));
    return DateTime.now().isAfter(expiresAt);
  }

  Widget _buildContent(ChatTheme theme) {
    final canonicalType = _canonicalAttachmentType();
    final isLocalPendingUpload = (widget.message?.isUploading ?? false) &&
        (widget.message?.attachmentUrl == null ||
            widget.message!.attachmentUrl!.isEmpty) &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalPendingUpload) {
      return _buildUploadingLocalAttachment(theme);
    }

    final isLocalFailedUpload = (widget.message?.isFailed ?? false) &&
        (widget.message?.attachmentUrl == null ||
            widget.message!.attachmentUrl!.isEmpty) &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalFailedUpload) {
      return _buildFailedLocalAttachment(theme);
    }

    // 1. �?�.ا�Oش GIF �o. اضاف�? شد�?
    if ((widget.attachmentType == 'gif' ||
            widget.message?.messageType == 'gif') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      // ا�O�?جا �.ط�.ئ�? �.�O�?Oش�^�O�. ک�? آبجکت �.س�Oج دار�O�.
      if (widget.message != null) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: GifMessageBubble(message: widget.message!),
        );
      }
    }

    // 2. Voice message
    if ((canonicalType == 'audio' || canonicalType == 'voice') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceMessageBubble(
            messageId: widget.messageId,
            audioUrl: widget.attachmentUrl!,
            localFilePath: widget.message?.localFilePath,
            durationSeconds: widget.duration,
            isMe: widget.isMe,
            time: widget.time,
            senderName: widget.senderName,
            senderAvatarUrl: widget.message?.senderAvatar,
            conversationId: widget.message?.conversationId,
            attachmentType: canonicalType,
            audioTitle: widget.message?.audioTitle,
            audioArtist: widget.message?.audioArtist,
            audioAlbum: widget.message?.audioAlbum,
            caption: widget.content,
          ),
          // ز�.ا�? �^ ت�Oک داخ�" حباب - ف�,ط ا�O�? �,س�.ت با ValueListenableBuilder rebuild �.�Oش�?
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: _buildTimeAndStatus(theme),
          ),
        ],
      );
    }

    // 3. Image & Video message (Updated)
    if ((canonicalType == 'image' || canonicalType == 'video') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
      final isVideo = canonicalType == 'video';

      // �o. تغ�O�Oر �.�?�.: �.د�Oا باب�" ر�^ �.ست�,�O�. بر�.�O�?Oگرد�^�?�O�. بد�^�? پد�O�?گ اضاف�?
      return MediaMessageBubble(
        message: widget
            .message, // پاس داد�? ک�" �.د�" پ�Oا�. برا�O دسترس�O ب�? �^ضع�Oت�?O�?ا
        mediaUrl: widget.attachmentUrl!,
        mediaType: isVideo ? MediaType.video : MediaType.image,
        isMe: widget.isMe,
        time: widget.time,
        caption: widget.content.isNotEmpty ? widget.content : null,
        videoDuration: isVideo ? widget.duration : null,
        // پاس داد�? �^ضع�Oت آپ�"�^د
        isUploading: widget.status == MessageStatus.pending ||
            (widget.message?.isUploading ?? false),
      );
    }

    // 4. File message (Fallback for other attachment types)
    if (widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty &&
        (canonicalType == 'document' || canonicalType == 'unknown')) {
      return FileMessageBubble(
        messageId: widget.messageId,
        fileUrl: widget.attachmentUrl!,
        fileName: widget.attachmentFileName ?? 'File',
        fileSizeBytes: widget.message?.attachmentSizeBytes,
        localFilePath: widget.message?.localFilePath,
        isMe: widget.isMe,
        time: widget.time,
      );
    }

    // Text message - با ساعت inline در پا�O�O�? س�.ت �?پ
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // �.حت�^ا�O �.ت�?�O
          Flexible(
            child: widget.content.isNotEmpty
                ? RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    text: RichTextParser.buildRichText(
                      text: '${widget.content}\u200F',
                      baseStyle: TextStyle(
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
                      linkColor: Colors.blueAccent,
                      mentionColor: Colors.blueAccent,
                      hashtagColor: Colors.blueAccent,
                      onMentionTap: (username) {
                        NavigationHelper.navigateToUserProfile(
                            context, username);
                      },
                      onHashtagTap: (tag) {
                        NavigationHelper.navigateToHashtagPosts(context, tag);
                      },
                      onLinkTap: widget.onLinkTap,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          // �o. ز�.ا�? �^ ت�Oک - ف�,ط ا�O�? �,س�.ت rebuild �.�Oش�?
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  String _canonicalAttachmentType() {
    final raw = (widget.message?.attachmentType ?? widget.attachmentType ?? '')
        .trim()
        .toLowerCase();
    if (raw.isEmpty) return 'unknown';

    if (raw == 'image') return 'image';
    if (raw == 'video') return 'video';
    if (raw == 'voice') return 'voice';
    if (raw == 'audio') return 'audio';
    if (raw == 'document' || raw == 'pdf' || raw == 'file') {
      return 'document';
    }
    if (raw.startsWith('image/')) return 'image';
    if (raw.startsWith('audio/')) return 'audio';
    if (raw.startsWith('video/')) return 'video';

    return 'unknown';
  }

  Widget _buildUploadingLocalAttachment(ChatTheme theme) {
    final rawProgress = widget.message?.uploadProgress ?? 0.0;
    final progress = (rawProgress.isFinite ? rawProgress : 0.0).clamp(0.0, 1.0);
    final fileName = widget.message?.attachmentFileName ??
        widget.message?.localFilePath?.split('/').last ??
        'File';
    final pct = (progress * 100).toStringAsFixed(0);
    final canonicalType = _canonicalAttachmentType();

    if (canonicalType == 'audio' || canonicalType == 'voice') {
      return _buildUploadingAudioAttachment(theme, progress, pct, fileName);
    }

    return _buildUploadingDocumentAttachment(theme, progress, pct, fileName);
  }

  Widget _buildUploadingDocumentAttachment(
    ChatTheme theme,
    double progress,
    String pct,
    String fileName,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUploadProgressCircle(
                theme: theme,
                progress: progress,
                size: 44,
                strokeWidth: 2.8,
                centerLabel: '$pct%',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Uploading • $pct%',
            style: TextStyle(
              color: widget.isMe
                  ? theme.myBubbleTextColor.withOpacity(0.8)
                  : theme.otherBubbleTextColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor.withOpacity(0.9)
                    : theme.otherBubbleTextColor.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  Widget _buildUploadingAudioAttachment(
    ChatTheme theme,
    double progress,
    String pct,
    String fileName,
  ) {
    final title = (widget.message?.audioTitle?.trim().isNotEmpty ?? false)
        ? widget.message!.audioTitle!.trim()
        : fileName;
    final artist = widget.message?.audioArtist?.trim();
    final waveformBars = List<double>.generate(
      26,
      (i) => 0.35 + ((i % 5) * 0.12),
      growable: false,
    );
    final activeBars = (progress * waveformBars.length).floor();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildUploadProgressCircle(
                theme: theme,
                progress: progress,
                size: 40,
                strokeWidth: 2.8,
                centerLabel: '$pct%',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.isMe
                            ? theme.myBubbleTextColor
                            : theme.otherBubbleTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (artist != null && artist.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isMe
                              ? theme.myBubbleTextColor.withOpacity(0.75)
                              : theme.otherBubbleTextColor.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(waveformBars.length, (i) {
                final isActive = i < activeBars;
                final barColor = isActive
                    ? theme.sendButtonColor
                    : (widget.isMe
                        ? theme.myBubbleTextColor.withOpacity(0.22)
                        : theme.otherBubbleTextColor.withOpacity(0.22));
                return Container(
                  width: 3,
                  height: 8 + (waveformBars[i] * 8),
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Uploading audio • $pct%',
            style: TextStyle(
              color: widget.isMe
                  ? theme.myBubbleTextColor.withOpacity(0.8)
                  : theme.otherBubbleTextColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor.withOpacity(0.9)
                    : theme.otherBubbleTextColor.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  Widget _buildUploadProgressCircle({
    required ChatTheme theme,
    required double progress,
    required double size,
    required double strokeWidth,
    required String centerLabel,
  }) {
    final ringColor = widget.isMe ? Colors.white : theme.sendButtonColor;
    final trackColor = ringColor.withOpacity(0.22);
    final labelColor = widget.isMe
        ? theme.myBubbleTextColor
        : theme.otherBubbleTextColor.withOpacity(0.9);
    final normalizedProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: normalizedProgress,
            strokeWidth: strokeWidth,
            color: ringColor,
            backgroundColor: trackColor,
          ),
          Text(
            centerLabel,
            style: TextStyle(
              color: labelColor,
              fontSize: size * 0.24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedLocalAttachment(ChatTheme theme) {
    final fileName = widget.message?.attachmentFileName ??
        widget.message?.localFilePath?.split('/').last ??
        'File';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: theme.errorColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.message?.errorMessage ?? 'آپ�"�^د ا�?جا�. �?شد',
            style: TextStyle(
              color: theme.errorColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.onRetryUpload != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onRetryUpload,
              style: TextButton.styleFrom(
                foregroundColor: theme.sendButtonColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('ت�"اش �.جدد'),
            ),
          ],
          const SizedBox(height: 6),
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  // �o. Build time and status - ف�,ط ا�O�? �,س�.ت rebuild �.�Oش�?
  Widget _buildTimeAndStatus(ChatTheme theme) {
    // �o. اگر message �.�^ج�^د باش�?�O از ValueListenableBuilder استفاد�? ک�?
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

    // Fallback ب�? ر�^ش �,د�O�.�O
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

  /// تبد�O�" MessageStatus ب�? MessageDeliveryStatus
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
