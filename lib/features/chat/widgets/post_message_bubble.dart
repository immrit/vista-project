// lib/features/chat/widgets/post_message_bubble.dart
//
// نمایش پست‌های شبکه اجتماعی در چت (مثل اینستاگرام/X)
//

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';

class PostMessageBubble extends StatelessWidget {
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
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final hasMedia = mediaUrls != null && mediaUrls!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(
          left: isMine ? 60 : 12,
          right: isMine ? 12 : 60,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? theme.myBubbleColor
              : theme.otherBubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.sendButtonColor.withOpacity(0.1),
                    backgroundImage: authorAvatar != null
                        ? CachedNetworkImageProvider(authorAvatar!)
                        : null,
                    child: authorAvatar == null
                        ? Text(
                            authorName[0].toUpperCase(),
                            style: TextStyle(
                              color: theme.sendButtonColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            color: isMine
                                ? theme.myBubbleTextColor
                                : theme.otherBubbleTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (authorUsername != null)
                          Text(
                            '@$authorUsername',
                            style: TextStyle(
                              color: isMine
                                  ? theme.myBubbleTextColor.withOpacity(0.8)
                                  : theme.secondaryTextColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.article_outlined,
                    size: 16,
                    color: isMine
                        ? theme.myBubbleTextColor.withOpacity(0.7)
                        : theme.secondaryTextColor,
                  ),
                ],
              ),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 1,
              color: theme.dividerColor.withOpacity(0.3),
            ),

            // Post Content
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  content,
                  style: TextStyle(
                    color: isMine
                        ? theme.myBubbleTextColor
                        : theme.otherBubbleTextColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Media (اگر داشت)
            if (hasMedia)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _PostMediaPreview(
                  mediaUrls: mediaUrls!,
                  theme: theme,
                ),
              ),

            // Post Stats Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: isMine
                        ? theme.myBubbleTextColor.withOpacity(0.7)
                        : theme.secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(likesCount),
                    style: TextStyle(
                      color: isMine
                          ? theme.myBubbleTextColor.withOpacity(0.7)
                          : theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isMine
                        ? theme.myBubbleTextColor.withOpacity(0.7)
                        : theme.secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(commentsCount),
                    style: TextStyle(
                      color: isMine
                          ? theme.myBubbleTextColor.withOpacity(0.7)
                          : theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      color: isMine
                          ? theme.myBubbleTextColor.withOpacity(0.7)
                          : theme.secondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Tap to view indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withOpacity(0.15)
                    : theme.sendButtonColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'برای مشاهده پست ضربه بزنید',
                    style: TextStyle(
                      color: isMine
                          ? theme.myBubbleTextColor
                          : theme.sendButtonColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isMine
                        ? theme.myBubbleTextColor
                        : theme.sendButtonColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}

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
      borderRadius: BorderRadius.circular(8),
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
            child: const Icon(Icons.error_outline),
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
      height: 150,
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
      height: 150,
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
      height: 150,
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
                          color: Colors.black54,
                          child: Center(
                            child: Text(
                              '+$remaining',
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

