// lib/features/chat/widgets/post_message_bubble.dart
//
// نمایش پست‌های شبکه اجتماعی در چت با تاریخ دقیق و قابلیت forward
//

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;
import '../theme/chat_theme.dart';

class PostMessageBubble extends StatefulWidget {
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
  final VoidCallback? onForward;
  final bool isMine;

  const PostMessageBubble({
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
    this.onForward,
    required this.isMine,
  });

  @override
  State<PostMessageBubble> createState() => _PostMessageBubbleState();
}

class _PostMessageBubbleState extends State<PostMessageBubble> {
  bool _showAbsoluteTime = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final hasMedia = widget.mediaUrls != null && widget.mediaUrls!.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.only(
          left: widget.isMine ? 60 : 12,
          right: widget.isMine ? 12 : 60,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: widget.isMine ? theme.myBubbleColor : theme.otherBubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Author Info
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
                            fontSize: 15,
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
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Post Type Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.sendButtonColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.article_rounded,
                      size: 18,
                      color: theme.sendButtonColor,
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: theme.dividerColor.withOpacity(0.15),
            ),

            // Post Content
            if (widget.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text(
                  '${widget.content}\u200F',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: widget.isMine
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor,
                    fontSize: 14.5,
                    height: 1.5,
                    fontFamily: 'Vazir',
                    fontFamilyFallback: const [
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                      'Noto Color Emoji',
                    ],
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Media (اگر داشت)
            if (hasMedia)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _PostMediaPreview(
                  mediaUrls: widget.mediaUrls!,
                  theme: theme,
                ),
              ),

            // Post Stats & Time Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // Likes
                  Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: Colors.red.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(widget.likesCount),
                    style: TextStyle(
                      color: widget.isMine
                          ? theme.myBubbleTextColor.withOpacity(0.8)
                          : theme.secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comments
                  Icon(
                    Icons.chat_bubble_rounded,
                    size: 16,
                    color: theme.sendButtonColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(widget.commentsCount),
                    style: TextStyle(
                      color: widget.isMine
                          ? theme.myBubbleTextColor.withOpacity(0.8)
                          : theme.secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Timestamp (Toggleable)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAbsoluteTime = !_showAbsoluteTime;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isMine
                            ? Colors.white.withOpacity(0.15)
                            : theme.dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: widget.isMine
                                ? theme.myBubbleTextColor.withOpacity(0.7)
                                : theme.secondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showAbsoluteTime
                                ? _formatAbsoluteTime(widget.createdAt)
                                : _formatRelativeTime(widget.createdAt),
                            style: TextStyle(
                              color: widget.isMine
                                  ? theme.myBubbleTextColor.withOpacity(0.8)
                                  : theme.secondaryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMine
                    ? Colors.white.withOpacity(0.1)
                    : theme.sendButtonColor.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  // View Post Button
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.visibility_rounded,
                      label: 'مشاهده پست',
                      onTap: widget.onTap,
                      color: widget.isMine
                          ? theme.myBubbleTextColor
                          : theme.sendButtonColor,
                      isMine: widget.isMine,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Forward Button
                  if (widget.onForward != null)
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'ارسال',
                        onTap: widget.onForward!,
                        color: widget.isMine
                            ? theme.myBubbleTextColor
                            : theme.sendButtonColor,
                        isMine: widget.isMine,
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

  /// فرمت شمارش (مثلا 1.2K, 3.5M)
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  }

  /// فرمت زمان نسبی (چند دقیقه پیش، چند ساعت پیش، ...)
  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'همین الان';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    if (diff.inDays == 1) return 'دیروز';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks هفته پیش';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ماه پیش';
    }
    final years = (diff.inDays / 365).floor();
    return '$years سال پیش';
  }

  /// فرمت زمان دقیق (تاریخ و ساعت)
  String _formatAbsoluteTime(DateTime time) {
    final formatter = intl.DateFormat('yyyy/MM/dd - HH:mm');
    return formatter.format(time);
  }
}

/// دکمه اکشن (مشاهده/ارسال)
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isMine;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------
// Media Preview Widgets
// -------------------------------

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
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
            child: const Icon(Icons.broken_image_outlined, size: 40),
          ),
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
          const SizedBox(width: 3),
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
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _MediaTile(url: urls[1])),
                const SizedBox(height: 3),
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
                const SizedBox(width: 3),
                Expanded(child: _MediaTile(url: urls[1])),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _MediaTile(url: urls[2])),
                const SizedBox(width: 3),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MediaTile(url: urls[3]),
                      if (remaining > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+$remaining',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
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
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image_outlined, size: 24),
        ),
      ),
    );
  }
}
