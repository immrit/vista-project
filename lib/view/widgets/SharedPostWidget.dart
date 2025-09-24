import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screen/PublicPosts/PostDetailPage.dart';
import 'ReelsScreen.dart';

class SharedPostWidget extends StatefulWidget {
  final String messageContent;
  final String? attachmentUrl;
  final String? attachmentType;

  const SharedPostWidget({
    super.key,
    required this.messageContent,
    this.attachmentUrl,
    this.attachmentType,
  });

  @override
  State<SharedPostWidget> createState() => _SharedPostWidgetState();
}

class _SharedPostWidgetState extends State<SharedPostWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: _buildInstagramStylePostCard(theme),
          ),
        );
      },
    );
  }

  Widget _buildInstagramStylePostCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openPostInApp,
          onTapDown: (_) => _animationController.reverse(),
          onTapUp: (_) => _animationController.forward(),
          onTapCancel: () => _animationController.forward(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر پست
              _buildPostHeader(theme),

              // محتوای پست (تصویر، ویدیو یا متن)
              _buildPostContent(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader(ThemeData theme) {
    final username = _extractUsername();
    final avatarUrl = _extractAvatarUrl();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // آواتار کاربر
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.blue[400]!,
                  Colors.purple[400]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // نام کاربری
          Expanded(
            child: Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),

          // آیکون بیشتر
          Icon(
            Icons.more_horiz,
            size: 20,
            color: theme.iconTheme.color,
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(ThemeData theme) {
    final postContent = _extractPostContent();
    final hasImage = widget.attachmentType == 'image' &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty;
    final hasVideo = widget.attachmentType == 'video' &&
        widget.attachmentUrl != null &&
        widget.attachmentUrl!.isNotEmpty;
    final hasText = postContent.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // متن پست (اگر وجود دارد)
        if (hasText)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              postContent,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),

        // رسانه (تصویر یا ویدیو)
        if (hasImage || hasVideo) _buildPostMedia(theme),
      ],
    );
  }

  Widget _buildPostMedia(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              // تصویر یا ویدیو
              if (widget.attachmentUrl != null &&
                  widget.attachmentUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: _buildThumbnailUrl(widget.attachmentUrl!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 32),
                  ),
                )
              else
                Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 32),
                  ),
                ),

              // آیکون نوع رسانه
              if (widget.attachmentType == 'video')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildThumbnailUrl(String url) {
    // Supabase Transform API (fast, low-cost) if path matches
    if (url.contains('/storage/v1/object/public/')) {
      return '${url.replaceFirst('/object/public/', '/render/image/public/')}${url.contains('?') ? '&' : '?'}width=300&quality=60';
    }
    // Generic CDNs that accept width/quality query params
    if (url.contains('coffevista') ||
        url.contains('arvan') ||
        url.contains('cdn')) {
      return '$url${url.contains('?') ? '&' : '?'}w=300&q=60';
    }
    // Fallback: return original (data usage will be higher). Consider adding a proxy later.
    return url;
  }

  void _openPostInApp() {
    final postId = _extractPostId();
    if (postId.isNotEmpty) {
      if (widget.attachmentType == 'video') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReelsScreen(
              posts: [],
              initialIndex: 0,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(
              postId: postId,
            ),
          ),
        );
      }
    }
  }

  String _extractUsername() {
    final lines = widget.messageContent.split('\n');
    for (final line in lines) {
      if (line.contains('📝 پست از')) {
        final match = RegExp(r'📝 پست از (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }
    }
    return '';
  }

  String? _extractAvatarUrl() {
    final lines = widget.messageContent.split('\n');
    for (final line in lines) {
      if (line.contains('🖼️ آواتار:')) {
        final match = RegExp(r'🖼️ آواتار: (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1);
        }
      }
    }
    return null;
  }

  String _extractPostContent() {
    final lines = widget.messageContent.split('\n');
    final contentLines = <String>[];

    // پیدا کردن خط آواتار
    int avatarLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('🖼️ آواتار:')) {
        avatarLineIndex = i;
        break;
      }
    }

    // پیدا کردن محتوای پست بعد از آواتار
    for (int i = avatarLineIndex + 1; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('🖼️') ||
          line.startsWith('🎥') ||
          line.startsWith('🏷️') ||
          line.startsWith('🔗')) {
        break;
      }

      // اگر خط خالی نیست و metadata نیست، احتمالاً محتوای پست است
      if (line.trim().isNotEmpty) {
        contentLines.add(line);
      }
    }

    return contentLines.join('\n').trim();
  }

  String _extractPostId() {
    final lines = widget.messageContent.split('\n');
    for (final line in lines) {
      if (line.contains('🔗 مشاهده در Vista:')) {
        final match = RegExp(r'post/(.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? '';
        }
      }
    }
    return '';
  }
}
