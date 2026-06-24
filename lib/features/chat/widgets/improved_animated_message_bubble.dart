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
import 'modern_message_status.dart';
import 'gif_message_bubble.dart';
import 'media_message_bubble.dart';
import 'file_message_bubble.dart';
import 'full_screen_image_viewer.dart';
import '../../../services/modern_read_receipt_service.dart';
import '../../../model/message_model.dart';
import '../utils/story_reply_media_utils.dart';
import '../utils/chat_image_dimensions.dart';
import '../utils/chat_media_bubble_layout.dart';
import '../utils/chat_text_direction.dart';
import 'story_reply_thumbnail.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../performance/chat_performance_profile.dart';
import '../performance/motion_tokens.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/modern_emoji_text.dart';
import 'reaction_reactor_avatar_stack.dart';
import 'chat_text_bubble_layout.dart';

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
  final List<ReactionReactorInfo> reactors;
  final bool isMyReaction;

  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.userIds,
    this.reactors = const [],
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
  final VoidCallback? onReactionDetailTap;

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
  final bool showReactionAvatars;

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
  final bool isEdited;

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
    this.onReactionDetailTap,
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
    this.showReactionAvatars = false,
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
    this.isEdited = false,
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

  // Nullable — only allocated when entry animation is needed (new incoming messages).
  // Static/historical messages skip controller creation entirely, saving ~4 objects
  // per item on initial render (96+ items = 384+ fewer allocations).
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  late String _formattedTime;

  String _currentContent = "";
  bool _isDecrypting = false;

  bool _staticPresentation = false;

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

    final uniqueId = widget.messageId;
    bool shouldAnimate = widget.animate;

    if (shouldAnimate) {
      if (widget.isMe) {
        if (widget.status != MessageStatus.pending) shouldAnimate = false;
      } else {
        if (_shownMessages.contains(uniqueId)) shouldAnimate = false;
      }
      if (shouldAnimate) {
        final isRecent = DateTime.now().difference(widget.time).inSeconds < 60;
        if (!isRecent) shouldAnimate = false;
      }
    }

    _shownMessages.add(uniqueId);

    if (shouldAnimate) {
      _setupAnimations();
      Future.delayed(Duration(milliseconds: widget.index * 30), () {
        if (mounted) _controller!.forward();
      });
    } else {
      _staticPresentation = true;
      // No controller needed — skip 4 object allocations per static bubble.
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

    final ctrl = _controller!;

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: ctrl,
      curve: switch (widget.effectsLevel) {
        ChatEffectsLevel.low => const Interval(0.0, 0.3, curve: Curves.linear),
        ChatEffectsLevel.medium =>
          const Interval(0.0, 0.4, curve: Curves.easeOut),
        ChatEffectsLevel.high =>
          const Interval(0.0, 0.45, curve: Curves.easeOut),
      },
    ));

    // Telegram X style: subtle 8% vertical slide (not the old 90% banner effect)
    final slideBegin =
        widget.isMe ? const Offset(0.05, 0.05) : const Offset(0, 0.08);
    _slideAnimation = Tween<Offset>(
      begin: slideBegin,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: ctrl,
      curve: switch (widget.effectsLevel) {
        ChatEffectsLevel.low => const Interval(0.0, 0.5, curve: Curves.linear),
        ChatEffectsLevel.medium =>
          const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
        ChatEffectsLevel.high =>
          const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      },
    ));
    // NOTE: no scale animation. Scaling a bubble scales its text, and Impeller
    // (GLES backend here) re-rasterizes glyphs at every intermediate scale →
    // CreateGlyphAtlas thrash, which the entry trace showed dominating raster.
    // Fade + a tiny slide read the same but are cheap (slide is a pure translate).
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.chatTheme;

    // No RepaintBoundary here: each list row is already wrapped in one by
    // ChatMessageListView (the bubble is never a standalone scroll child on the
    // hot path), so an inner boundary only adds a redundant GPU layer per row.
    if (_staticPresentation || _controller == null) {
      return _buildInteractiveBubble(theme);
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: _buildInteractiveBubble(theme),
      ),
    );
  }

  Widget _buildInteractiveBubble(ChatTheme theme) {
    const edgeInset = 6.0;
    const oppositeInset = 12.0;

    return GestureDetector(
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
        child: _buildBubbleBody(theme),
      ),
    );
  }

  Widget _buildBubbleBody(ChatTheme theme) {
    // Column fills full viewport width (from ListView constraint).
    // crossAxisAlignment.end/start anchors the bubble to the correct screen edge.
    final canonicalType = _canonicalAttachmentType();
    // image/video/document/voice/audio fill the max-width box naturally —
    // IntrinsicWidth's 2-pass layout is only needed for variable-width text bubbles.
    final needsIntrinsicWidth = canonicalType != 'image' &&
        canonicalType != 'video' &&
        canonicalType != 'document' &&
        canonicalType != 'voice' &&
        canonicalType != 'audio';

    // Fast path: a pure text bubble (no reply/forward/sender/story/shared-post
    // sections, no reactions, real text). Such bubbles are the bulk of a busy
    // chat, and they were the only ones paying IntrinsicWidth's double paragraph
    // layout. ChatTextBubbleLayout shrink-wraps to max(text, footer) in a single
    // pass — visually identical, so no IntrinsicWidth needed here.
    final usePlainTextLayout = _isPlainTextBubble(canonicalType);

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      child: usePlainTextLayout
          ? _buildPlainTextContainer(theme)
          : _buildMessageBubble(theme),
    );

    if (needsIntrinsicWidth && !usePlainTextLayout) {
      bubble = IntrinsicWidth(child: bubble);
    }

    Widget child = Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          child: bubble,
        ),
      ],
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
    final mediaUrl = _resolvedMediaUrl();
    final isMedia = (canonicalType == 'image' || canonicalType == 'video') &&
        mediaUrl != null;
    final storyReply = _effectiveStoryReplyData();
    final sharedPostReply =
        storyReply == null ? _effectiveSharedPostReplyData() : null;

    return Container(
      clipBehavior: isMedia ? Clip.hardEdge : Clip.none,
      decoration: _messageBoxDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_shouldShowSenderName())
            _buildSenderName(theme, widget.senderName!.trim()),
          if (widget.isForwarded) _buildForwardHeader(theme),
          if (storyReply != null) _buildStoryReplySection(theme, storyReply),
          if (sharedPostReply != null)
            _buildSharedPostReplySection(theme, sharedPostReply),
          if (storyReply == null &&
              sharedPostReply == null &&
              widget.replyToContent != null)
            _buildReplySection(theme),
          _buildContent(theme),
          if (widget.reactions.isNotEmpty && !_handlesReactionsInternally())
            _buildReactionsSection(theme),
        ],
      ),
    );
  }

  BoxDecoration _messageBoxDecoration(ChatTheme theme) {
    return BoxDecoration(
      color: widget.isMe && theme.myBubbleGradient == null
          ? theme.myBubbleColor
          : (widget.isMe ? null : theme.otherBubbleColor),
      gradient: widget.isMe ? theme.myBubbleGradient : null,
      borderRadius: _getBorderRadius(theme),
    );
  }

  /// True when the bubble is plain text only — eligible for the single-pass
  /// [ChatTextBubbleLayout] instead of `IntrinsicWidth`. Any extra section
  /// (reply/forward/sender/story/shared-post/reactions/media/decrypting) keeps
  /// the original `IntrinsicWidth` path so its layout is untouched.
  bool _isPlainTextBubble(String canonicalType) {
    final isTextType = canonicalType != 'image' &&
        canonicalType != 'video' &&
        canonicalType != 'document' &&
        canonicalType != 'voice' &&
        canonicalType != 'audio';
    if (!isTextType) return false;
    if (_isDecrypting) return false;
    if (_shouldShowSenderName()) return false;
    if (widget.isForwarded) return false;
    if (widget.reactions.isNotEmpty) return false;
    if (widget.replyToContent != null) return false;
    if (widget.message?.storyReplyData != null) return false;
    if (widget.message?.isUploading ?? false) return false;
    if (widget.message?.isFailed ?? false) return false;
    // Excludes "media unavailable" placeholders (known media type, no url).
    if (_isKnownMediaType(canonicalType)) return false;
    return _displayCaption().isNotEmpty;
  }

  /// Pure-text bubble body: same decoration/padding/text/footer as the general
  /// path, but the inner `Column(stretch)[text, gap, footerRow]` is replaced by
  /// [ChatTextBubbleLayout] so the paragraph is laid out only once.
  Widget _buildPlainTextContainer(ChatTheme theme) {
    final caption = _displayCaption();
    final contentDirection = resolveChatTextDirection(caption);
    return Container(
      decoration: _messageBoxDecoration(theme),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
        child: ChatTextBubbleLayout(
          textDirection: contentDirection,
          gap: 2,
          text: Directionality(
            textDirection: contentDirection,
            child: _buildCaptionRichText(theme, caption, contentDirection),
          ),
          // Plain-text path has no reactions (guarded), so the footer is just the
          // timestamp + tick at its natural (min) width — ChatTextBubbleLayout
          // pins it to the reading-direction end, matching the old spaceBetween row.
          footer: _buildTimeAndStatus(theme),
        ),
      ),
    );
  }

  Widget _buildCaptionRichText(
    ChatTheme theme,
    String caption,
    TextDirection contentDirection,
  ) {
    return ModernEmojiRichText(
      text: caption,
      useModernEmoji: EmojiRenderPolicy.useModernEmojiRenderer(),
      textDirection: contentDirection,
      textAlign: TextAlign.start,
      baseStyle: TextStyle(
        color:
            widget.isMe ? theme.myBubbleTextColor : theme.otherBubbleTextColor,
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
        NavigationHelper.navigateToUserProfile(context, username);
      },
      onHashtagTap: (tag) {
        NavigationHelper.navigateToHashtagPosts(context, tag);
      },
      onLinkTap: widget.onLinkTap,
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
      textDirection: kChatLayoutTextDirection,
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

  SharedPostData? _effectiveSharedPostReplyData() {
    return SharedPostData.tryParse(widget.replyToContent);
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
    final replyContentDirection =
        resolveChatTextDirection(widget.replyToContent);
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
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPostReplySection(
      ChatTheme theme, SharedPostData postData) {
    final author = postData.postAuthorName.trim().isNotEmpty
        ? postData.postAuthorName.trim()
        : (postData.postAuthorUsername.trim().isNotEmpty
            ? postData.postAuthorUsername.trim()
            : 'کاربر');
    final content = postData.postContent.trim();
    final secondaryText = content.isNotEmpty ? content : 'پست ارسالی';
    final textDirection = resolveChatTextDirection(content);

    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: BorderDirectional(
            start: BorderSide(
              color: theme.sendButtonColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSharedPostReplyThumbnail(theme, postData),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dynamic_feed_rounded,
                        size: 13,
                        color: theme.sendButtonColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'پست ارسالی',
                          textDirection: kChatLayoutTextDirection,
                          style: TextStyle(
                            color: theme.sendButtonColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    author,
                    textDirection: kChatLayoutTextDirection,
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor.withValues(alpha: 0.78)
                          : theme.otherBubbleTextColor.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Directionality(
                    textDirection: textDirection,
                    child: Text(
                      secondaryText,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: widget.isMe
                            ? theme.myBubbleTextColor.withValues(alpha: 0.72)
                            : theme.otherBubbleTextColor
                                .withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPostReplyThumbnail(
    ChatTheme theme,
    SharedPostData postData,
  ) {
    final imageUrl = postData.postImageUrl?.trim() ?? '';
    final hasVideo = postData.postVideoUrl?.trim().isNotEmpty ?? false;
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        hasVideo ? Icons.play_arrow_rounded : Icons.dynamic_feed_rounded,
        color: theme.sendButtonColor.withValues(alpha: 0.8),
        size: 22,
      ),
    );

    if (imageUrl.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            imageUrl,
            width: 48,
            height: 48,
            cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
            cacheHeight: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return placeholder;
            },
          ),
          if (hasVideo)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
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
                    textDirection:
                        resolveChatTextDirection(effectiveHeaderText),
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
                    textDirection:
                        resolveChatTextDirection(effectiveSecondaryText),
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
                      textDirection: resolveChatTextDirection(answerPreview),
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
    final mediaUrl = _resolvedMediaUrl();
    final caption = _displayCaption();
    final isLocalPendingUpload = (widget.message?.isUploading ?? false) &&
        mediaUrl == null &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalPendingUpload) {
      return _buildUploadingLocalAttachment(theme);
    }

    final isLocalFailedUpload = (widget.message?.isFailed ?? false) &&
        mediaUrl == null &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalFailedUpload) {
      return _buildFailedLocalAttachment(theme);
    }

    if ((widget.attachmentType == 'gif' ||
            widget.message?.messageType == 'gif') &&
        mediaUrl != null) {
      if (widget.message != null) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: GifMessageBubble(message: widget.message!),
        );
      }
    }

    // 2. Voice message
    if ((canonicalType == 'audio' || canonicalType == 'voice') &&
        mediaUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceMessageBubble(
            messageId: widget.messageId,
            audioUrl: mediaUrl,
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
            caption: caption,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: _buildBottomRow(theme),
          ),
        ],
      );
    }

    // 3. Image & Video message (Updated)
    if ((canonicalType == 'image' || canonicalType == 'video') &&
        mediaUrl != null) {
      final isVideo = canonicalType == 'video';

      return MediaMessageBubble(
        message: widget.message,
        mediaUrl: mediaUrl,
        mediaType: isVideo ? MediaType.video : MediaType.image,
        isMe: widget.isMe,
        time: widget.time,
        isSecretMode: widget.isSecretMode,
        caption: caption.isNotEmpty ? caption : null,
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
    if (mediaUrl != null &&
        (canonicalType == 'document' || canonicalType == 'unknown')) {
      final resolvedFileName = (widget.attachmentFileName?.trim().isNotEmpty ??
              false)
          ? widget.attachmentFileName!.trim()
          : ((widget.message?.attachmentFileName?.trim().isNotEmpty ?? false)
              ? widget.message!.attachmentFileName!.trim()
              : 'File');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FileMessageBubble(
            messageId: widget.messageId,
            fileUrl: mediaUrl,
            fileName: resolvedFileName,
            fileSizeBytes: widget.message?.attachmentSizeBytes,
            localFilePath: widget.message?.localFilePath,
            caption: caption.isNotEmpty ? caption : null,
            isMe: widget.isMe,
            time: widget.time,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: _buildBottomRow(theme),
          ),
        ],
      );
    }

    if (_isKnownMediaType(canonicalType) && mediaUrl == null) {
      return _buildUnavailableMediaAttachment(theme, canonicalType);
    }

    final contentDirection = resolveChatTextDirection(caption);

    // Text-only: overlay timestamp at bottom-right (Telegram X inline style)
    final textWidget = Directionality(
      textDirection: contentDirection,
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
          : caption.isNotEmpty
              ? ModernEmojiRichText(
                  text: caption,
                  useModernEmoji: EmojiRenderPolicy.useModernEmojiRenderer(),
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
                    NavigationHelper.navigateToUserProfile(context, username);
                  },
                  onHashtagTap: (tag) {
                    NavigationHelper.navigateToHashtagPosts(context, tag);
                  },
                  onLinkTap: widget.onLinkTap,
                )
              : const SizedBox.shrink(),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          textWidget,
          const SizedBox(height: 2),
          _buildBottomRow(theme),
        ],
      ),
    );
  }

  String? _resolvedMediaUrl() {
    final fromMessage = widget.message?.resolvedMediaUrl;
    if (fromMessage != null && fromMessage.isNotEmpty) return fromMessage;
    final prop = widget.attachmentUrl?.trim();
    if (prop != null && prop.isNotEmpty) return prop;
    return null;
  }

  String _displayCaption() {
    if (widget.message?.hasMediaPlaceholderContent == true) return '';
    return widget.message?.displayContent ?? _currentContent;
  }

  bool _isKnownMediaType(String canonicalType) {
    return canonicalType == 'image' ||
        canonicalType == 'video' ||
        canonicalType == 'audio' ||
        canonicalType == 'voice' ||
        canonicalType == 'document';
  }

  Widget _buildUnavailableMediaAttachment(ChatTheme theme, String type) {
    final label = switch (type) {
      'image' => 'تصویر در دسترس نیست',
      'video' => 'ویدیو در دسترس نیست',
      'audio' || 'voice' => 'پیام صوتی در دسترس نیست',
      'document' => 'فایل در دسترس نیست',
      _ => 'پیوست در دسترس نیست',
    };
    final icon = switch (type) {
      'image' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      'audio' || 'voice' => Icons.mic_none_outlined,
      'document' => Icons.insert_drive_file_outlined,
      _ => Icons.attachment_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: widget.isMe
                    ? theme.myBubbleTextColor.withValues(alpha: 0.7)
                    : theme.otherBubbleTextColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: widget.isMe
                      ? theme.myBubbleTextColor.withValues(alpha: 0.85)
                      : theme.otherBubbleTextColor.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildBottomRow(theme),
        ],
      ),
    );
  }

  String _canonicalAttachmentType() {
    final raw = (widget.message?.attachmentType ??
            widget.message?.messageType ??
            widget.attachmentType ??
            '')
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
    final url = widget.message?.resolvedMediaUrl ?? widget.attachmentUrl ?? '';
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

    return FutureBuilder<SizeInt?>(
      future: ChatImageDimensions.resolve(
        cacheKey: 'upload_${widget.messageId}',
        localPath: localPath,
      ),
      builder: (context, snapshot) {
        final screenSize = MediaQuery.sizeOf(context);
        final displaySize = ChatMediaBubbleLayout.computeBubblePhotoSize(
          screenWidth: screenSize.width,
          screenHeight: screenSize.height,
          imageWidth: snapshot.data?.width,
          imageHeight: snapshot.data?.height,
          bubbleMaxWidth: screenSize.width * 0.75,
          useFullWidth: true,
        );
        final decodeWidth =
            (displaySize.width * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(120, 1600);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasLocalImage)
                      Image.file(
                        localFile,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: decodeWidth,
                      )
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
              child: _buildBottomRow(theme),
            ),
          ],
        );
      },
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
          _buildBottomRow(theme),
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
        builder: (context, deliveryStatus, _) {
          return _buildTimeAndStatusRow(theme, deliveryStatus);
        },
      );
    }

    final deliveryStatus = _convertToDeliveryStatus(widget.status);
    return _buildTimeAndStatusRow(theme, deliveryStatus);
  }

  Widget _buildTimeAndStatusRow(
    ChatTheme theme,
    MessageDeliveryStatus deliveryStatus,
  ) {
    final showEdited = widget.isEdited || (widget.message?.isEdited ?? false);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showEdited)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 10,
                    color: widget.isMe
                        ? theme.myBubbleTextColor.withValues(alpha: 0.55)
                        : theme.otherBubbleTextColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'ویرایش شده',
                    style: TextStyle(
                      color: widget.isMe
                          ? theme.myBubbleTextColor.withValues(alpha: 0.55)
                          : theme.otherBubbleTextColor.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
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
      ),
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
      child: ModernMessageStatus(
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

  /// Convert old local status enum to delivery status used by Modern ticks.
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

  Widget _buildBottomRow(ChatTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.reactions.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: _buildReactionsWrap(theme),
            ),
          )
        else
          const SizedBox(width: 0),
        _buildTimeAndStatus(theme),
      ],
    );
  }

  Widget _buildReactionsWrap(ChatTheme theme) {
    final reactionsKey = widget.reactions
        .map((reaction) =>
            '${reaction.emoji}:${reaction.count}:${reaction.isMyReaction}')
        .join('|');

    return AnimatedSwitcher(
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
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onReactionDetailTap?.call();
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              scale: reaction.isMyReaction ? 1.06 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    Text(reaction.emoji, style: const TextStyle(fontSize: 12)),
                    if (widget.showReactionAvatars &&
                        reaction.reactors.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      ReactionReactorAvatarStack(
                        reactors: reaction.reactors,
                        theme: theme,
                      ),
                    ] else if (reaction.count > 1) ...[
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Text(
                          reaction.count.toString().toPersianDigit(),
                          key: ValueKey('${reaction.emoji}:${reaction.count}'),
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isMe
                                ? theme.myBubbleTextColor.withValues(alpha: 0.7)
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
    );
  }

  Widget _buildReactionsSection(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: _buildReactionsWrap(theme),
    );
  }

  bool _handlesReactionsInternally() {
    final mediaUrl = _resolvedMediaUrl();
    final isLocalPendingUpload = (widget.message?.isUploading ?? false) &&
        mediaUrl == null &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalPendingUpload) return true;

    final isLocalFailedUpload = (widget.message?.isFailed ?? false) &&
        mediaUrl == null &&
        ((widget.message?.localFilePath?.isNotEmpty ?? false) ||
            (widget.message?.localImagePath?.isNotEmpty ?? false));
    if (isLocalFailedUpload) return true;

    final canonicalType = _canonicalAttachmentType();
    if ((widget.attachmentType == 'gif' ||
            widget.message?.messageType == 'gif') &&
        mediaUrl != null) {
      return false;
    }

    if ((canonicalType == 'audio' || canonicalType == 'voice') &&
        mediaUrl != null) {
      return true;
    }

    if ((canonicalType == 'image' || canonicalType == 'video') &&
        mediaUrl != null) {
      return false;
    }

    if (mediaUrl != null &&
        (canonicalType == 'document' || canonicalType == 'unknown')) {
      return true;
    }

    if (_isKnownMediaType(canonicalType) && mediaUrl == null) {
      return true;
    }

    return true;
  }
}
