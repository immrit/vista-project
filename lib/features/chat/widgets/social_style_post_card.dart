// lib/features/chat/widgets/social_style_post_card.dart
//
// کارت پست به سبک ویستا/تردز برای چت
//
// این ویجت برای نمایش پست‌های اشتراک‌گذاری شده در چت استفاده میشه
// طراحی مشابه Social و Threads

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';
import '../utils/chat_text_direction.dart';
import '../../../utils/compat_extensions.dart';
import 'modern_message_status.dart';
import '../../../services/modern_read_receipt_service.dart';
import 'improved_animated_message_bubble.dart' show MessageStatus;
import '../../../widgets/verification_badge_icon.dart';
import '../../../utils/verification_badge_utils.dart';

class SocialStylePostCard extends StatefulWidget {
  final String postId;
  final String authorName;
  final String? authorAvatar;
  final String? authorUsername;
  final String content;
  final List<String>? mediaUrls;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final VoidCallback onTap;
  final VoidCallback onViewPost;
  final VoidCallback? onShare;
  final VoidCallback? onLongPress;
  final bool isMine;
  final DateTime sentAt;
  final bool isVerified;
  final String? verificationType;
  final String? role;
  final List<String>? hashtags;
  final MessageStatus? status; // وضعیت پیام

  const SocialStylePostCard({
    super.key,
    required this.postId,
    required this.authorName,
    this.authorAvatar,
    this.authorUsername,
    required this.content,
    this.mediaUrls,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.onTap,
    required this.onViewPost,
    this.onShare,
    this.onLongPress,
    required this.isMine,
    required this.sentAt,
    this.isVerified = false,
    this.verificationType,
    this.role,
    this.hashtags,
    this.status,
  });

  @override
  State<SocialStylePostCard> createState() => _SocialStylePostCardState();
}

class _SocialStylePostCardState extends State<SocialStylePostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
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

  // Extract hashtags from content
  List<String> get _extractedHashtags {
    if (widget.hashtags != null && widget.hashtags!.isNotEmpty) {
      return widget.hashtags!;
    }
    final hashtagRegExp = RegExp(r'#\w+');
    return hashtagRegExp
        .allMatches(widget.content)
        .map((match) => match.group(0)!)
        .toList();
  }

  // Get content without hashtags for cleaner display
  String get _cleanContent {
    String content = widget.content;
    for (final hashtag in _extractedHashtags) {
      content = content.replaceAll(hashtag, '').trim();
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final hasMedia = widget.mediaUrls != null && widget.mediaUrls!.isNotEmpty;
    final hashtags = _extractedHashtags;
    final cardBackgroundColor =
        widget.isMine ? theme.myBubbleColor : theme.otherBubbleColor;
    final cardGradient = widget.isMine ? theme.myBubbleGradient : null;
    final cardBorderColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.16)
        : theme.otherBubbleTextColor.withValues(alpha: 0.12);
    final cardShadow = widget.isMine ? theme.myBubbleShadow : theme.otherBubbleShadow;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
        },
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: widget.isMine ? 15 : 9,
            end: widget.isMine ? 9 : 15,
            bottom: 4,
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: widget.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // کارت پست
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                decoration: BoxDecoration(
                  color: cardGradient == null ? cardBackgroundColor : null,
                  gradient: cardGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1,
                  ),
                  boxShadow: cardShadow != null
                      ? [cardShadow]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: theme.isDark ? 0.26 : 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // هدر پست
                      _buildPostHeader(theme),

                      // محتوای متنی
                      if (_cleanContent.isNotEmpty) _buildPostContent(theme),

                      // هشتگ‌ها
                      if (hashtags.isNotEmpty) _buildHashtags(theme, hashtags),

                      // مدیا
                      if (hasMedia) _buildMediaSection(theme),

                      // آمار و اکشن‌ها + زمان ارسال
                      _buildEngagementSection(theme),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// هدر پست (مشابه ویستا)
  Widget _buildPostHeader(ChatTheme theme) {
    final primaryTextColor =
        widget.isMine ? theme.myBubbleTextColor : theme.otherBubbleTextColor;
    final secondaryTextColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.78)
        : theme.secondaryTextColor;
    final avatarInnerBackgroundColor =
        widget.isMine ? theme.myBubbleColor : theme.otherBubbleColor;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // آواتار با حاشیه گرادیانت
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.pink.shade400,
                  Colors.orange.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarInnerBackgroundColor,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor:
                    theme.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                backgroundImage: widget.authorAvatar != null &&
                        widget.authorAvatar!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.authorAvatar!)
                    : null,
                child: widget.authorAvatar == null ||
                        widget.authorAvatar!.isEmpty
                    ? Text(
                        widget.authorName.isNotEmpty
                            ? widget.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // نام و نام کاربری
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.authorName,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // تیک تأیید
                    if (_resolvedBadgeType !=
                        ResolvedVerificationBadgeType.none)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _buildVerificationBadge(),
                      ),
                  ],
                ),
                if (widget.authorUsername != null)
                  Text(
                    '@${widget.authorUsername}',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // تاریخ پست
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.createdAt.toRelativeTime(),
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ResolvedVerificationBadgeType get _resolvedBadgeType =>
      resolveVerificationBadgeType(
        isVerified: widget.isVerified,
        verificationType: widget.verificationType,
        role: widget.role,
      );

  /// نشان تأیید
  Widget _buildVerificationBadge() {
    return VerificationBadgeIcon(
      isVerified: widget.isVerified,
      verificationType: widget.verificationType,
      role: widget.role,
      size: 16,
    );
  }

  /// محتوای متنی پست
  Widget _buildPostContent(ChatTheme theme) {
    final primaryTextColor =
        widget.isMine ? theme.myBubbleTextColor : theme.otherBubbleTextColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Text(
        _cleanContent,
        style: TextStyle(
          color: primaryTextColor,
          fontSize: 14,
          height: 1.5,
        ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        textDirection: resolveChatTextDirection(_cleanContent),
      ),
    );
  }

  /// هشتگ‌ها
  Widget _buildHashtags(ChatTheme theme, List<String> hashtags) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: hashtags.take(5).map((hashtag) {
          return Text(
            hashtag,
            style: TextStyle(
              color: Colors.blue.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// بخش مدیا
  Widget _buildMediaSection(ChatTheme theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: _PostMediaGrid(
        mediaUrls: widget.mediaUrls!,
        theme: theme,
      ),
    );
  }

  /// بخش انگیجمنت (لایک، کامنت، شیر)
  Widget _buildEngagementSection(ChatTheme theme) {
    final dividerColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.16)
        : theme.otherBubbleTextColor.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // لایک
                  _buildEngagementItem(
                    icon: Icons.favorite_rounded,
                    count: widget.likesCount,
                    color: Colors.red.shade400,
                    theme: theme,
                  ),
                  const SizedBox(width: 16),

                  // کامنت
                  _buildEngagementItem(
                    icon: Icons.chat_bubble_rounded,
                    count: widget.commentsCount,
                    color: theme.secondaryTextColor,
                    theme: theme,
                  ),
                ],
              ),

              // دکمه مشاهده پست
              _buildViewPostButton(theme),
            ],
          ),

          // زمان ارسال پیام و وضعیت (داخل حباب)
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.sentAt.toFixedTimeLabel(),
                style: TextStyle(
                  color: widget.isMine
                      ? theme.myBubbleTextColor.withValues(alpha: 0.7)
                      : theme.secondaryTextColor.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // نمایش وضعیت برای پیام‌های ارسالی
              if (widget.isMine && widget.status != null) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(theme),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementItem({
    required IconData icon,
    required int count,
    required Color color,
    required ChatTheme theme,
  }) {
    final countTextColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.82)
        : theme.otherBubbleTextColor.withValues(alpha: 0.72);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: countTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildViewPostButton(ChatTheme theme) {
    final buttonBackgroundColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.12)
        : theme.otherBubbleTextColor.withValues(alpha: 0.10);
    final buttonTextColor = widget.isMine
        ? theme.myBubbleTextColor.withValues(alpha: 0.9)
        : theme.otherBubbleTextColor.withValues(alpha: 0.78);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onViewPost,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: buttonTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                'مشاهده پست',
                style: TextStyle(
                  color: buttonTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ChatTheme theme) {
    if (widget.status == null) return const SizedBox.shrink();

    // تبدیل MessageStatus به MessageDeliveryStatus
    final deliveryStatus = _convertToDeliveryStatus(widget.status!);

    return ModernMessageStatus(
      status: deliveryStatus,
      size: 12, // کوچک‌تر و ظریف‌تر
      customColor: deliveryStatus == MessageDeliveryStatus.read
          ? MessageStatusColors.read
          : theme.myBubbleTextColor.withValues(alpha: 0.7),
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

  String _formatCount(int count) {
    if (count < 1000) return count.toString().toPersianDigit();
    if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}K'.toPersianDigit();
    }
    if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(0)}K'.toPersianDigit();
    }
    return '${(count / 1000000).toStringAsFixed(1)}M'.toPersianDigit();
  }
}

// ═══════════════════════════════════════════════════════════════
// 🖼️ POST MEDIA GRID
// ═══════════════════════════════════════════════════════════════

class _PostMediaGrid extends StatelessWidget {
  final List<String> mediaUrls;
  final ChatTheme theme;

  const _PostMediaGrid({
    required this.mediaUrls,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final count = mediaUrls.length;

    if (count == 1) {
      return _SingleMedia(url: mediaUrls[0], theme: theme);
    } else if (count == 2) {
      return _TwoMediaGrid(urls: mediaUrls, theme: theme);
    } else if (count == 3) {
      return _ThreeMediaGrid(urls: mediaUrls, theme: theme);
    } else {
      return _FourPlusMediaGrid(urls: mediaUrls, theme: theme);
    }
  }
}

class _SingleMedia extends StatelessWidget {
  final String url;
  final ChatTheme theme;

  const _SingleMedia({required this.url, required this.theme});

  bool get _isVideo {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.sendButtonColor,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
              child: Icon(
                Icons.image_not_supported_outlined,
                color: theme.secondaryTextColor,
                size: 40,
              ),
            ),
          ),
          if (_isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TwoMediaGrid extends StatelessWidget {
  final List<String> urls;
  final ChatTheme theme;

  const _TwoMediaGrid({required this.urls, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(child: _MediaTile(url: urls[0], theme: theme)),
          const SizedBox(width: 2),
          Expanded(child: _MediaTile(url: urls[1], theme: theme)),
        ],
      ),
    );
  }
}

class _ThreeMediaGrid extends StatelessWidget {
  final List<String> urls;
  final ChatTheme theme;

  const _ThreeMediaGrid({required this.urls, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _MediaTile(url: urls[0], theme: theme),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaTile(url: urls[1], theme: theme)),
                const SizedBox(height: 2),
                Expanded(child: _MediaTile(url: urls[2], theme: theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FourPlusMediaGrid extends StatelessWidget {
  final List<String> urls;
  final ChatTheme theme;

  const _FourPlusMediaGrid({required this.urls, required this.theme});

  @override
  Widget build(BuildContext context) {
    final remaining = urls.length - 4;

    return SizedBox(
      height: 150,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(url: urls[0], theme: theme)),
                const SizedBox(width: 2),
                Expanded(child: _MediaTile(url: urls[1], theme: theme)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(url: urls[2], theme: theme)),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaTile(url: urls[3], theme: theme),
                      if (remaining > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: Center(
                            child: Text(
                              '+${remaining.toString().toPersianDigit()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final String url;
  final ChatTheme theme;

  const _MediaTile({required this.url, required this.theme});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
        child: Icon(
          Icons.error_outline,
          size: 20,
          color: theme.secondaryTextColor,
        ),
      ),
    );
  }
}
