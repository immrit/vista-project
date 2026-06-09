// lib/features/chat/widgets/improved_animated_message_bubble.dart

import 'package:flutter/material.dart';
import '../../../security/e2ee_service.dart' as import_e2ee;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';
import 'voice_message_bubble.dart';
import 'swipe_to_reply.dart';
import 'telegram_message_status.dart';
import 'gif_message_bubble.dart';
import 'media_message_bubble.dart';
import 'file_message_bubble.dart';
import 'full_screen_image_viewer.dart';
import '../../../services/telegram_read_receipt_service.dart';
import '../../../model/message_model.dart';
import '../utils/story_reply_media_utils.dart';
import '../utils/chat_text_direction.dart';
import 'story_reply_thumbnail.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../performance/chat_performance_profile.dart';
import '../performance/motion_tokens.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/telegram_emoji_text.dart';

/// Message delivery state for the bubble widget.
enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

/// Aggregated reaction model used by bubble UI.
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
  final VoidCallback? onSwipeToReply;
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
  final int? duration; // For voice messages
  final List<GalleryItem>? conversationGalleryItems;
  final int? initialGalleryIndex;
  final bool isSecretMode;

  // Forwarding
  final bool isForwarded;
  final String? forwardedFrom;
  final VoidCallback? onRetryUpload;
  final ChatEffectsLevel effectsLevel;

  // Optional full message model to use status notifier and richer metadata.
  final MessageModel? message;
  final String? recipientPublicKey;

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
    this.onSwipeToReply,
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
    this.conversationGalleryItems,
    this.initialGalleryIndex,
    this.isSecretMode = false,
    this.isForwarded = false,
    this.forwardedFrom,
    this.onRetryUpload,
    this.effectsLevel = ChatEffectsLevel.high,
    this.message,
    this.recipientPublicKey,
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
  late String _formattedTime;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  String _currentContent = "";
  bool _isDecrypting = false;

  @override
  bool get wantKeepAlive {
    final isUploading = widget.message?.isUploading ?? false;
    return isUploading;
  }

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
    _checkEncryption();
    _formattedTime = widget.time.toFixedTimeLabel();
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
    final entryDuration = MotionTokens.messageEntry(
      effectsLevel: widget.effectsLevel,
      profile: MotionProfile.balanced,
    );
    _controller = AnimationController(
      duration: entryDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: switch (widget.effectsLevel) {
        ChatEffectsLevel.low => const Interval(0.0, 0.3, curve: Curves.linear),
        ChatEffectsLevel.medium =>
          const Interval(0.0, 0.4, curve: Curves.easeOut),
        ChatEffectsLevel.high =>
          const Interval(0.0, 0.45, curve: Curves.easeOut),
      },
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.9),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: switch (widget.effectsLevel) {
        ChatEffectsLevel.low => const Interval(0.0, 0.5, curve: Curves.linear),
        ChatEffectsLevel.medium =>
          const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
        ChatEffectsLevel.high =>
          const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      },
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: switch (widget.effectsLevel) {
        ChatEffectsLevel.low => const Interval(0.0, 0.4, curve: Curves.linear),
        ChatEffectsLevel.medium =>
          const Interval(0.0, 0.65, curve: Curves.easeOut),
        ChatEffectsLevel.high =>
          const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      },
    ));
  }

  @override
  void didUpdateWidget(ImprovedAnimatedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      _currentContent = widget.content;
      _checkEncryption();
    }
    if (widget.time != oldWidget.time) {
      _formattedTime = widget.time.toFixedTimeLabel();
    }
  }

  void _checkEncryption() {
    if (_currentContent.startsWith('e2ee:v1:')) {
      if (widget.recipientPublicKey != null &&
          widget.recipientPublicKey!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isDecrypting = true;
          });
        }
        import_e2ee.E2EEService()
            .decryptMessage(_currentContent, widget.recipientPublicKey!)
            .then((decrypted) {
          if (mounted) {
            setState(() {
              _currentContent = decrypted;
              _isDecrypting = false;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _isDecrypting = false;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.chatTheme;
    // Keep bubbles close to the edge, with a tiny breathing room.
    const edgeInset = 4.0;
    const oppositeInset = 12.0;

    Widget child = RepaintBoundary(
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
                padding: EdgeInsetsDirectional.only(
                  start: widget.isMe
                      ? oppositeInset
                      : (widget.compactWithAvatar ? 6 : edgeInset),
                  end: widget.isMe ? edgeInset : oppositeInset,
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
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.82,
                            ),
                            child: _buildMessageBubble(theme),
                          ),
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

    if (widget.onSwipeToReply != null) {
      child = SwipeToReply(
        onReply: widget.onSwipeToReply!,
        isMe: widget.isMe,
        child: child,
      );
    }

    return child;
  }

  Widget _buildMessageBubble(ChatTheme theme) {
    final canonicalType = _canonicalAttachmentType();
    final isMedia = (canonicalType == 'image' || canonicalType == 'video') &&
        widget.attachmentUrl != null;
    final storyReply = _effectiveStoryReplyData();

    return Container(
      clipBehavior: isMedia ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: widget.isMe && theme.myBubbleGradient == null
            ? theme.myBubbleColor
            : (widget.isMe ? null : theme.otherBubbleColor),
        gradient: widget.isMe ? theme.myBubbleGradient : null,
        borderRadius: _getBorderRadius(theme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shouldShowSenderName())
            _buildSenderName(theme, widget.senderName!.trim()),
          if (widget.isForwarded) _buildForwardHeader(theme),
          if (storyReply != null) _buildStoryReplySection(theme, storyReply),
          if (storyReply == null && widget.replyToContent != null)
            _buildReplySection(theme),
          _buildContent(theme),
          if (widget.reactions.isNotEmpty) _buildReactionsSection(theme),
        ],
      ),
    );
  }

  Widget _buildForwardHeader(ChatTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsetsDirectional.only(start: 4),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: theme.sendButtonColor.withValues(alpha: 0.5),
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
              color: theme.sendButtonColor.withValues(alpha: 0.7),
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
      textDirection: Directionality.of(context),
    );
  }

  StoryReplyData? _effectiveStoryReplyData() {
    if (widget.message?.storyReplyData != null) {
      return widget.message!.storyReplyData;
    }
    return StoryReplyData.parseFromReplyFields(
      replyToMessageId: widget.replyToMessageId,
      replyToContent: widget.replyToContent,
      replyToSenderName: widget.replyToSenderName,
    );
  }

  Widget _buildReplySection(ChatTheme theme) {
    final replySender = widget.replyToSenderName ?? 'کاربر';
    final rawReplyTarget = widget.replyToMessageId?.trim() ?? '';
    final isSyntheticNoteReply = rawReplyTarget.startsWith('note:');
    final isSyntheticStoryReply = rawReplyTarget.startsWith('story:');
    final isNoteReply =
        isSyntheticNoteReply || replySender.trim().startsWith('یادداشت');
    final isStoryReply =
        isSyntheticStoryReply || replySender.trim().startsWith('استوری');
    final noteReplyChipColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.18)
        : theme.sendButtonColor.withValues(alpha: 0.14);
    final noteReplyChipTextColor =
        widget.isMe ? theme.myBubbleTextColor : theme.sendButtonColor;
    final replySenderColor = (isNoteReply || isStoryReply)
        ? (widget.isMe
            ? theme.myBubbleTextColor.withValues(alpha: 0.96)
            : theme.sendButtonColor)
        : theme.sendButtonColor;
    final replyContentDirection = resolveChatTextDirection(
      widget.replyToContent,
      fallback: Directionality.of(context),
    );
    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: BorderDirectional(
            start: BorderSide(
              color: theme.sendButtonColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNoteReply || isStoryReply) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: noteReplyChipColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStoryReply
                          ? Icons.auto_stories_outlined
                          : Icons.sticky_note_2_outlined,
                      size: 12,
                      color: noteReplyChipTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isStoryReply ? 'پاسخ به استوری' : 'پاسخ به یادداشت',
                      style: TextStyle(
                        color: noteReplyChipTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNoteReply && !isStoryReply) ...[
                  Icon(
                    Icons.reply_rounded,
                    size: 12,
                    color: theme.sendButtonColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  replySender,
                  style: TextStyle(
                    color: replySenderColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: replyContentDirection,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.replyToContent ?? '',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withValues(alpha: 0.8)
                        : theme.otherBubbleTextColor.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryReplySection(ChatTheme theme, StoryReplyData storyData) {
    final ownerUsername = storyData.storyOwnerUsername.trim().isNotEmpty
        ? storyData.storyOwnerUsername
        : 'کاربر';
    final isExpired = _isStoryReplyExpired(storyData);
    final isQuestionReply = storyData.replyKind == 'question';
    final headerText =
        widget.isMe ? 'پاسخ به استوری $ownerUsername' : 'پاسخ به استوری شما';
    final caption = storyData.storyCaption?.trim();
    final hasRealCaption = caption != null &&
        caption.isNotEmpty &&
        !StoryReplyMediaUtils.isGenericStoryLabel(caption);
    final secondaryText = isExpired
        ? 'استوری در دسترس نیست'
        : (hasRealCaption
            ? caption
            : (storyData.storyMediaType == 'video' ? 'ویدیو' : 'تصویر'));
    String effectiveHeaderText = headerText;
    String effectiveSecondaryText = secondaryText;
    final answerPreview = ((storyData.answerText?.trim().isNotEmpty ?? false)
            ? storyData.answerText!.trim()
            : _currentContent.trim())
        .trim();

    if (isQuestionReply) {
      effectiveHeaderText = widget.isMe
          ? 'پاسخ شما به سوال استوری $ownerUsername'
          : 'پاسخ به سوال استوری شما';
      if (!isExpired) {
        final question = storyData.questionText?.trim() ?? '';
        effectiveSecondaryText =
            question.isNotEmpty ? 'سوال: $question' : 'پاسخ به استیکر سوال';
      }
    }

    return GestureDetector(
      onTap: widget.onStoryReplyTap != null
          ? () => widget.onStoryReplyTap!(storyData)
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.05),
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
                    effectiveHeaderText,
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
                    effectiveSecondaryText,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor.withValues(alpha: 0.7)
                          : theme.otherBubbleTextColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isQuestionReply && answerPreview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      answerPreview,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: widget.isMe
                            ? theme.myBubbleTextColor.withValues(alpha: 0.8)
                            : theme.otherBubbleTextColor.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    if (isExpired) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.dividerColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.schedule,
          color: Colors.white70,
          size: 20,
        ),
      );
    }

    return StoryReplyThumbnail(
      data: data,
      placeholderColor: theme.dividerColor.withValues(alpha: 0.2),
      iconColor: theme.dividerColor.withValues(alpha: 0.6),
    );
  }

  bool _isStoryReplyExpired(StoryReplyData data) {
    final expiresAt = data.storyExpiresAt ??
        data.storyCreatedAt.add(
          Duration(hours: data.storyDurationHours ?? 24),
        );
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

    if ((widget.attachmentType == 'gif' ||
            widget.message?.messageType == 'gif') &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty) {
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
            caption: _currentContent,
          ),
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

      return MediaMessageBubble(
        message: widget.message,
        mediaUrl: widget.attachmentUrl!,
        mediaType: isVideo ? MediaType.video : MediaType.image,
        isMe: widget.isMe,
        time: widget.time,
        isSecretMode: widget.isSecretMode,
        caption: _currentContent.isNotEmpty ? _currentContent : null,
        videoDuration: isVideo ? widget.duration : null,
        isUploading: widget.status == MessageStatus.pending ||
            (widget.message?.isUploading ?? false),
        effectsLevel: widget.effectsLevel,
        allowHeavyEffects: widget.effectsLevel == ChatEffectsLevel.high,
        conversationGalleryItems: widget.conversationGalleryItems,
        initialGalleryIndex: widget.initialGalleryIndex,
      );
    }

    // 4. File message (Fallback for other attachment types)
    if (widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty &&
        (canonicalType == 'document' || canonicalType == 'unknown')) {
      final resolvedFileName = (widget.attachmentFileName?.trim().isNotEmpty ??
              false)
          ? widget.attachmentFileName!.trim()
          : ((widget.message?.attachmentFileName?.trim().isNotEmpty ?? false)
              ? widget.message!.attachmentFileName!.trim()
              : 'File');
      return FileMessageBubble(
        messageId: widget.messageId,
        fileUrl: widget.attachmentUrl!,
        fileName: resolvedFileName,
        fileSizeBytes: widget.message?.attachmentSizeBytes,
        localFilePath: widget.message?.localFilePath,
        caption: _currentContent.isNotEmpty ? _currentContent : null,
        isMe: widget.isMe,
        time: widget.time,
      );
    }

    final contentDirection = resolveChatTextDirection(
      _currentContent,
      fallback: Directionality.of(context),
    );

    return Directionality(
      textDirection: contentDirection,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: _isDecrypting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isMe
                                  ? theme.myBubbleTextColor
                                  : theme.otherBubbleTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'در حال رمزگشایی...',
                          style: TextStyle(
                            color: widget.isMe
                                ? theme.myBubbleTextColor
                                : theme.otherBubbleTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : _currentContent.isNotEmpty
                      ? TelegramEmojiRichText(
                          text: _currentContent,
                          useTelegramEmoji:
                              EmojiRenderPolicy.useTelegramEmojiRenderer(),
                          textDirection: contentDirection,
                          textAlign: TextAlign.start,
                          baseStyle: TextStyle(
                            color: widget.isMe
                                ? theme.myBubbleTextColor
                                : theme.otherBubbleTextColor,
                            fontSize: 14.5,
                            height: 1.5,
                            fontFamily: 'Vazirmatn',
                            fontFamilyFallback: const [
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                              'Noto Color Emoji',
                            ],
                          ),
                          linkColor: theme.sendButtonColor,
                          mentionColor: theme.sendButtonColor,
                          hashtagColor: theme.sendButtonColor,
                          onMentionTap: (username) {
                            NavigationHelper.navigateToUserProfile(
                                context, username);
                          },
                          onHashtagTap: (tag) {
                            NavigationHelper.navigateToHashtagPosts(
                                context, tag);
                          },
                          onLinkTap: widget.onLinkTap,
                        )
                      : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            _buildTimeAndStatus(theme),
          ],
        ),
      ),
    );
  }

  String _canonicalAttachmentType() {
    final raw = (widget.message?.attachmentType ?? widget.attachmentType ?? '')
        .trim()
        .toLowerCase();
    if (raw.isNotEmpty) {
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
    }

    final mime =
        (widget.message?.attachmentMimeType ?? '').trim().toLowerCase();
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('video/')) return 'video';

    final fileName = widget.message?.attachmentFileName ?? '';
    final url = widget.message?.attachmentUrl ?? widget.attachmentUrl ?? '';
    final ext = p
        .extension(fileName.isNotEmpty ? fileName : url)
        .replaceFirst('.', '')
        .toLowerCase();
    const imageExts = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
    };
    const audioExts = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'};
    const videoExts = {'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'};

    if (imageExts.contains(ext)) return 'image';
    if (audioExts.contains(ext)) return 'audio';
    if (videoExts.contains(ext)) return 'video';

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
    if (canonicalType == 'image') {
      return _buildUploadingImageAttachment(theme, progress, pct);
    }

    return _buildUploadingDocumentAttachment(theme, progress, pct, fileName);
  }

  Widget _buildUploadingImageAttachment(
    ChatTheme theme,
    double progress,
    String pct,
  ) {
    final localPath =
        widget.message?.localFilePath ?? widget.message?.localImagePath;
    final localFile =
        (localPath != null && localPath.isNotEmpty) ? File(localPath) : null;
    final hasLocalImage = localFile != null && localFile.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasLocalImage)
                  Image.file(localFile, fit: BoxFit.cover)
                else
                  Container(
                      color: theme.otherBubbleColor.withValues(alpha: 0.3)),
                Container(color: Colors.black.withValues(alpha: 0.22)),
                Center(
                  child: _buildUploadProgressCircle(
                    theme: theme,
                    progress: progress,
                    size: 54,
                    strokeWidth: 3,
                    centerLabel: '$pct%',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_currentContent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
              _currentContent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor
                    : theme.otherBubbleTextColor,
                fontSize: 13,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: _buildTimeAndStatus(theme),
        ),
      ],
    );
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
            'در حال آپلود - $pct%',
            style: TextStyle(
              color: widget.isMe
                  ? theme.myBubbleTextColor.withValues(alpha: 0.8)
                  : theme.otherBubbleTextColor.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentContent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor.withValues(alpha: 0.9)
                    : theme.otherBubbleTextColor.withValues(alpha: 0.9),
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
                              ? theme.myBubbleTextColor.withValues(alpha: 0.75)
                              : theme.otherBubbleTextColor
                                  .withValues(alpha: 0.75),
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
                        ? theme.myBubbleTextColor.withValues(alpha: 0.22)
                        : theme.otherBubbleTextColor.withValues(alpha: 0.22));
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
            'در حال آپلود صدا - $pct%',
            style: TextStyle(
              color: widget.isMe
                  ? theme.myBubbleTextColor.withValues(alpha: 0.8)
                  : theme.otherBubbleTextColor.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentContent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _currentContent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMe
                    ? theme.myBubbleTextColor.withValues(alpha: 0.9)
                    : theme.otherBubbleTextColor.withValues(alpha: 0.9),
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
    final trackColor = ringColor.withValues(alpha: 0.22);
    final labelColor = widget.isMe
        ? theme.myBubbleTextColor
        : theme.otherBubbleTextColor.withValues(alpha: 0.9);
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
            UserFriendlyErrorUtils.getUserFriendlyMessage(
              widget.message?.errorMessage ?? 'آپلود انجام نشد',
            ),
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
              label: const Text('تلاش مجدد'),
            ),
          ],
          const SizedBox(height: 6),
          _buildTimeAndStatus(theme),
        ],
      ),
    );
  }

  Widget _buildTimeAndStatus(ChatTheme theme) {
    if (widget.message != null) {
      return ValueListenableBuilder<MessageDeliveryStatus>(
        valueListenable: widget.message!.statusNotifier,
        builder: (context, status, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _formattedTime,
                style: TextStyle(
                  color: widget.isMe
                      ? theme.myBubbleTextColor.withValues(alpha: 0.7)
                      : theme.otherBubbleTextColor.withValues(alpha: 0.6),
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

    final deliveryStatus = _convertToDeliveryStatus(widget.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formattedTime,
          style: TextStyle(
            color: widget.isMe
                ? theme.myBubbleTextColor.withValues(alpha: 0.7)
                : theme.otherBubbleTextColor.withValues(alpha: 0.6),
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
    final statusIcon = AnimatedSwitcher(
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
            : theme.myBubbleTextColor.withValues(alpha: 0.7),
      ),
    );

    final canRetryFromStatusIcon = widget.isMe &&
        status == MessageDeliveryStatus.failed &&
        widget.onRetryUpload != null;
    if (!canRetryFromStatusIcon) return statusIcon;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onRetryUpload?.call();
      },
      child: statusIcon,
    );
  }

  /// Convert old local status enum to delivery status used by Telegram ticks.
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
    final reactionsKey = widget.reactions
        .map((reaction) =>
            '${reaction.emoji}:${reaction.count}:${reaction.isMyReaction}')
        .join('|');

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        child: Wrap(
          key: ValueKey(reactionsKey),
          spacing: 4,
          runSpacing: 4,
          children: widget.reactions.map((reaction) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onAddReaction?.call(reaction.emoji);
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                scale: reaction.isMyReaction ? 1.06 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: reaction.isMyReaction
                        ? theme.sendButtonColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: reaction.isMyReaction
                          ? theme.sendButtonColor
                          : theme.dividerColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(reaction.emoji,
                          style: const TextStyle(fontSize: 12)),
                      if (reaction.count > 1) ...[
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Text(
                            reaction.count.toString().toPersianDigit(),
                            key:
                                ValueKey('${reaction.emoji}:${reaction.count}'),
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isMe
                                  ? theme.myBubbleTextColor
                                      .withValues(alpha: 0.7)
                                  : theme.otherBubbleTextColor
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
