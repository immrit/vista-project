// lib/features/chat/widgets/enhanced_post_message_bubble.dart
//
// نمایش پست‌های شبکه اجتماعی در چت با قابلیت Share
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';
import '../../../utils/compat_extensions.dart';

class EnhancedPostMessageBubble extends StatefulWidget {
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
  final VoidCallback? onShare; // ✅ دکمه Share اضافه شد
  final VoidCallback? onLongPress;
  final bool isMine;
  final DateTime sentAt; // زمان ارسال پست در چت

  const EnhancedPostMessageBubble({
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
  });

  @override
  State<EnhancedPostMessageBubble> createState() =>
      _EnhancedPostMessageBubbleState();
}

class _EnhancedPostMessageBubbleState extends State<EnhancedPostMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _showTime = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
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
    final hasMedia = widget.mediaUrls != null && widget.mediaUrls!.isNotEmpty;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          setState(() => _showTime = !_showTime);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.isMine ? 40 : 12,
            right: widget.isMine ? 12 : 40,
            bottom: 8,
            top: 4,
          ),
          child: Column(
            crossAxisAlignment: widget.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // حباب پست
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: widget.isMine
                      ? theme.myBubbleColor
                      : theme.otherBubbleColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Post Header
                    _buildPostHeader(theme),

                    // Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.dividerColor.withOpacity(0.2),
                    ),

                    // Post Content
                    if (widget.content.isNotEmpty) _buildPostContent(theme),

                    // Media
                    if (hasMedia) _buildMediaSection(theme),

                    // Post Stats
                    _buildPostStats(theme),

                    // Action Button
                    _buildActionButton(theme),
                  ],
                ),
              ),

              // زمان ارسال در چت
              if (_showTime)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AnimatedOpacity(
                    opacity: _showTime ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ارسال شده: ${widget.sentAt.toFullDateTimeLabel()}',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
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

  /// هدر پست (آواتار، نام، تاریخ)
  Widget _buildPostHeader(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // آواتار
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.sendButtonColor.withOpacity(0.1),
            backgroundImage: widget.authorAvatar != null
                ? CachedNetworkImageProvider(widget.authorAvatar!)
                : null,
            child: widget.authorAvatar == null
                ? Text(
                    widget.authorName[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.sendButtonColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // نام و نام کاربری
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.authorName,
                  style: TextStyle(
                    color: widget.isMine
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.authorUsername != null)
                  Text(
                    '@${widget.authorUsername}',
                    style: TextStyle(
                      color: widget.isMine
                          ? theme.myBubbleTextColor.withOpacity(0.7)
                          : theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // آیکون پست
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.isMine
                  ? Colors.white.withOpacity(0.15)
                  : theme.sendButtonColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.article_outlined,
              size: 16,
              color: widget.isMine
                  ? theme.myBubbleTextColor
                  : theme.sendButtonColor,
            ),
          ),
        ],
      ),
    );
  }

  /// محتوای پست
  Widget _buildPostContent(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Text(
        widget.content,
        style: TextStyle(
          color: widget.isMine
              ? theme.myBubbleTextColor
              : theme.otherBubbleTextColor,
          fontSize: 14,
          height: 1.5,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// بخش مدیا
  Widget _buildMediaSection(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _PostMediaPreview(
          mediaUrls: widget.mediaUrls!,
          theme: theme,
        ),
      ),
    );
  }

  /// آمار پست
  Widget _buildPostStats(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // لایک
          _buildStatItem(
            icon: Icons.favorite_rounded,
            count: widget.likesCount,
            theme: theme,
            color: Colors.red,
          ),
          const SizedBox(width: 16),

          // کامنت
          _buildStatItem(
            icon: Icons.chat_bubble_rounded,
            count: widget.commentsCount,
            theme: theme,
            color: Colors.blue,
          ),

          const Spacer(),

          // تاریخ پست
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: widget.isMine
                    ? theme.myBubbleTextColor.withOpacity(0.6)
                    : theme.secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.createdAt.toRelativeTime(),
                style: TextStyle(
                  color: widget.isMine
                      ? theme.myBubbleTextColor.withOpacity(0.7)
                      : theme.secondaryTextColor,
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

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required ChatTheme theme,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color.withOpacity(0.8),
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: widget.isMine
                ? theme.myBubbleTextColor.withOpacity(0.8)
                : theme.otherBubbleTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// دکمه عملیات (مشاهده و اشتراک‌گذاری)
  Widget _buildActionButton(ChatTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isMine
            ? Colors.white.withOpacity(0.1)
            : theme.sendButtonColor.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // دکمه مشاهده پست
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: widget.isMine
                            ? theme.myBubbleTextColor
                            : theme.sendButtonColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مشاهده پست',
                        style: TextStyle(
                          color: widget.isMine
                              ? theme.myBubbleTextColor
                              : theme.sendButtonColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // خط جداکننده
          Container(
            width: 1,
            height: 36,
            color: theme.dividerColor.withOpacity(0.2),
          ),

          // دکمه اشتراک‌گذاری
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onShare?.call();
                },
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        size: 16,
                        color: widget.isMine
                            ? theme.myBubbleTextColor
                            : theme.sendButtonColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ارسال به چت',
                        style: TextStyle(
                          color: widget.isMine
                              ? theme.myBubbleTextColor
                              : theme.sendButtonColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
// 🖼️ POST MEDIA PREVIEW
// ═══════════════════════════════════════════════════════════════

class _PostMediaPreview extends StatelessWidget {
  final List<String> mediaUrls;
  final ChatTheme theme;

  const _PostMediaPreview({
    required this.mediaUrls,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final count = mediaUrls.length;

    if (count == 1) {
      return _SingleMedia(url: mediaUrls[0]);
    } else if (count == 2) {
      return _TwoMediaGrid(urls: mediaUrls);
    } else if (count == 3) {
      return _ThreeMediaGrid(urls: mediaUrls);
    } else {
      return _FourPlusMediaGrid(urls: mediaUrls);
    }
  }
}

class _SingleMedia extends StatelessWidget {
  final String url;

  const _SingleMedia({required this.url});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline),
        ),
      ),
    );
  }
}

class _TwoMediaGrid extends StatelessWidget {
  final List<String> urls;

  const _TwoMediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(child: _MediaTile(url: urls[0])),
          const SizedBox(width: 2),
          Expanded(child: _MediaTile(url: urls[1])),
        ],
      ),
    );
  }
}

class _ThreeMediaGrid extends StatelessWidget {
  final List<String> urls;

  const _ThreeMediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _MediaTile(url: urls[0]),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaTile(url: urls[1])),
                const SizedBox(height: 2),
                Expanded(child: _MediaTile(url: urls[2])),
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

  const _FourPlusMediaGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    final remaining = urls.length - 4;

    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(url: urls[0])),
                const SizedBox(width: 2),
                Expanded(child: _MediaTile(url: urls[1])),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(url: urls[2])),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaTile(url: urls[3]),
                      if (remaining > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '+${remaining.toString().toPersianDigit()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
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

  const _MediaTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline, size: 20),
        ),
      ),
    );
  }
}
