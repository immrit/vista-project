// lib/features/chat/widgets/instagram_style_post_card.dart
//
// کارت پست به سبک اینستاگرام/تردز برای چت
//
// این ویجت برای نمایش پست‌های اشتراک‌گذاری شده در چت استفاده میشه
// طراحی مشابه Instagram و Threads

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';

class InstagramStylePostCard extends StatefulWidget {
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
  final VoidCallback? onShare;
  final VoidCallback? onLongPress;
  final bool isMine;
  final DateTime sentAt;
  final String? verificationType;
  final List<String>? hashtags;

  const InstagramStylePostCard({
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
    this.onShare,
    this.onLongPress,
    required this.isMine,
    required this.sentAt,
    this.verificationType,
    this.hashtags,
  });

  @override
  State<InstagramStylePostCard> createState() => _InstagramStylePostCardState();
}

class _InstagramStylePostCardState extends State<InstagramStylePostCard>
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
          padding: EdgeInsets.only(
            left: widget.isMine ? 48 : 12,
            right: widget.isMine ? 12 : 48,
            bottom: 8,
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: widget.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // کارت پست
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(theme.isDark ? 0.3 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // هدر پست
                      _buildPostHeader(theme),

                      // محتوای متنی
                      if (_cleanContent.isNotEmpty)
                        _buildPostContent(theme),

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
            ],
          ),
        ),
      ),
    );
  }

  /// هدر پست (مشابه اینستاگرام)
  Widget _buildPostHeader(ChatTheme theme) {
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
                color: theme.isDark ? const Color(0xFF1E1E1E) : Colors.white,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
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
                          color: theme.isDark ? Colors.white : Colors.black87,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.authorName,
                        style: TextStyle(
                          color: theme.isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // تیک تأیید
                    if (widget.verificationType != null &&
                        widget.verificationType != 'none')
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
                      color: theme.secondaryTextColor,
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
                  color: theme.secondaryTextColor,
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

  /// نشان تأیید
  Widget _buildVerificationBadge() {
    Color badgeColor;
    switch (widget.verificationType) {
      case 'blueTick':
        badgeColor = Colors.blue;
        break;
      case 'goldTick':
        badgeColor = Colors.amber;
        break;
      case 'blackTick':
        badgeColor = Colors.black;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(
      Icons.verified,
      size: 16,
      color: badgeColor,
    );
  }

  /// محتوای متنی پست
  Widget _buildPostContent(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Text(
        _cleanContent,
        style: TextStyle(
          color: theme.isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          height: 1.5,
        ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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

              const Spacer(),

              // دکمه مشاهده پست
              _buildViewPostButton(theme),
            ],
          ),
          
          // زمان ارسال پیام (داخل حباب)
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 11,
                color: theme.secondaryTextColor.withOpacity(0.7),
              ),
              const SizedBox(width: 3),
              Text(
                widget.sentAt.toFixedTimeLabel(),
                style: TextStyle(
                  color: theme.secondaryTextColor.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: theme.isDark ? Colors.white70 : Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildViewPostButton(ChatTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: theme.isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                'مشاهده پست',
                style: TextStyle(
                  color: theme.isDark ? Colors.white70 : Colors.black54,
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
                  color: Colors.black.withOpacity(0.6),
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
                            color: Colors.black.withOpacity(0.6),
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

