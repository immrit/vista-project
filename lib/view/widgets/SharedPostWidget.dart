import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:typed_data';
import 'dart:collection';
import 'package:video_compress/video_compress.dart';
import '../screen/PublicPosts/PostDetailPage.dart';
import 'ReelsScreen.dart';
import '../../DB/advanced_cache_system.dart';
import '../../model/publicPostModel.dart';
import '../../main.dart';

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
  // Simple in-memory LRU cache for video thumbnails (per app session)
  static final _videoThumbCache = _ThumbnailLruCache(capacity: 100);
  static final Map<String, Future<Uint8List?>> _inflightThumbnails = {};
  static final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();

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
    final isVideo = widget.attachmentType == 'video';
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
              // تصویر یا ویدیو (thumbnail برای ویدیو)
              if (widget.attachmentUrl != null &&
                  widget.attachmentUrl!.isNotEmpty)
                if (!isVideo)
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
                  FutureBuilder<Uint8List?>(
                    future: _getOrGenerateVideoThumbnail(widget.attachmentUrl!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      }
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.videocam, size: 32),
                        ),
                      );
                    },
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

  Future<Uint8List?> _getOrGenerateVideoThumbnail(String url) async {
    // 1) Check in-memory LRU (widget-level)
    final cached = _videoThumbCache.get(url);
    if (cached != null) return cached;

    // 2) Check app-wide persistent cache
    final persisted = _advancedCache.getVideoThumbnail(url);
    if (persisted != null) {
      _videoThumbCache.set(url, persisted);
      return persisted;
    }

    final inflight = _inflightThumbnails[url];
    if (inflight != null) return inflight;

    final future = _generateVideoThumbnail(url).then((bytes) {
      if (bytes != null) {
        _videoThumbCache.set(url, bytes);
        _advancedCache.cacheVideoThumbnail(url, bytes);
      }
      _inflightThumbnails.remove(url);
      return bytes;
    });

    _inflightThumbnails[url] = future;
    return future;
  }

  Future<Uint8List?> _generateVideoThumbnail(String url) async {
    try {
      final Uint8List? bytes =
          await VideoCompress.getByteThumbnail(url, quality: 60);
      return bytes;
    } catch (_) {
      return null;
    }
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

  void _openPostInApp() async {
    final postId = _extractPostId();
    if (postId.isNotEmpty) {
      if (widget.attachmentType == 'video') {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          // Fetch the post data from the server
          final response = await supabase.from('posts').select('''
                *,
                profiles!posts_user_id_fkey (
                  username,
                  avatar_url,
                  is_verified,
                  verification_type
                ),
                likes (
                  user_id
                ),
                comments (
                  id
                )
              ''').eq('id', postId).single();

          final currentUserId = supabase.auth.currentUser?.id;
          final postLikes = response['likes'] as List? ?? [];
          final comments = response['comments'] as List<dynamic>? ?? [];

          final post = PublicPostModel.fromMap({
            ...response,
            'like_count': postLikes.length,
            'is_liked':
                postLikes.any((like) => like['user_id'] == currentUserId),
            'username': response['profiles']['username'] ?? 'Unknown',
            'avatar_url': response['profiles']['avatar_url'] ?? '',
            'is_verified': response['profiles']['is_verified'] ?? false,
            'comment_count': comments.length,
            'verification_type': response['profiles']['verification_type'],
          });

          // Close loading dialog
          if (context.mounted) {
            Navigator.pop(context);
          }

          // Navigate to ReelsScreen with the actual post
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelsScreen(
                  posts: [post],
                  initialIndex: 0,
                ),
              ),
            );
          }
        } catch (e) {
          // Close loading dialog
          if (context.mounted) {
            Navigator.pop(context);
          }

          // Show error message
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطا در بارگذاری پست: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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

      // فیلتر کردن تمام لینک‌ها و metadata
      if (line.startsWith('🖼️') ||
          line.startsWith('🎥') ||
          line.startsWith('🏷️') ||
          line.startsWith('🔗') ||
          _containsUrl(line) ||
          _containsVistaLink(line)) {
        break;
      }

      // اگر خط خالی نیست و metadata نیست، احتمالاً محتوای پست است
      if (line.trim().isNotEmpty) {
        contentLines.add(line);
      }
    }

    return contentLines.join('\n').trim();
  }

  // بررسی وجود URL در متن
  bool _containsUrl(String text) {
    final urlRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)?[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(text);
  }

  // بررسی وجود لینک Vista
  bool _containsVistaLink(String text) {
    return text.contains('vista') ||
        text.contains('post/') ||
        text.contains('m مشاهده در Vista');
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

class _ThumbnailLruCache {
  final int capacity;
  final Map<String, Uint8List> _map = <String, Uint8List>{};
  final ListQueue<String> _order = ListQueue<String>();

  _ThumbnailLruCache({required this.capacity});

  Uint8List? get(String key) {
    final value = _map[key];
    if (value == null) return null;
    _order.remove(key);
    _order.addLast(key);
    return value;
  }

  void set(String key, Uint8List value) {
    if (_map.containsKey(key)) {
      _order.remove(key);
    }
    _map[key] = value;
    _order.addLast(key);
    if (_order.length > capacity) {
      final oldest = _order.removeFirst();
      _map.remove(oldest);
    }
  }
}
