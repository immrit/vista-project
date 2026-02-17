import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import 'verification_badge_icon.dart';
import '../utils/verification_badge_utils.dart';

class SharedPostCardWidget extends StatelessWidget {
  final String messageContent;
  final String? attachmentUrl;
  final String? attachmentType;

  const SharedPostCardWidget({
    super.key,
    required this.messageContent,
    this.attachmentUrl,
    this.attachmentType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToPost(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر پست (نام کاربری، آواتار، نشان تایید)
              _buildPostHeader(theme),

              // محتوای پست (متن)
              _buildPostContent(theme),

              // رسانه (تصویر یا ویدیو)
              if (attachmentUrl != null && attachmentUrl!.isNotEmpty)
                _buildPostMedia(theme),

              // فوتر پست
              _buildPostFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader(ThemeData theme) {
    final username = _extractUsername();
    final avatarUrl = _extractAvatarUrl();
    final verificationType = _extractVerificationType();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // آواتار کاربر
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // اطلاعات کاربر
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // نشان تایید
                    if (parseVerificationBadgeType(verificationType) !=
                        ResolvedVerificationBadgeType.none)
                      _buildVerificationBadge(verificationType),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'پست اشتراکی',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // دکمه مشاهده پست
          Icon(
            Icons.open_in_new,
            size: 16,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(ThemeData theme) {
    final content = _extractPostContent();
    if (content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: theme.textTheme.bodyLarge?.color,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPostMedia(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              // تصویر یا ویدیو
              if (attachmentType == 'image' && attachmentUrl != null)
                CachedNetworkImage(
                  imageUrl: attachmentUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 32),
                    ),
                  ),
                )
              else if (attachmentType == 'video' && attachmentUrl != null)
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline,
                            size: 48, color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'ویدیو',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
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

  Widget _buildPostFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility,
            size: 14,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'مشاهده در Vista',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            _extractPostId().isNotEmpty
                ? '#${_extractPostId().substring(0, 8)}'
                : '',
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(String verificationType) {
    return VerificationBadgeIcon(
      isVerified: verificationType != 'none',
      verificationType: verificationType,
      size: 14,
    );
  }

  String _extractUsername() {
    final lines = messageContent.split('\n');
    for (final line in lines) {
      if (line.contains('📝 پست از')) {
        final match = RegExp(r'📝 پست از (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? 'کاربر';
        }
      }
    }
    return 'کاربر';
  }

  String? _extractAvatarUrl() {
    final lines = messageContent.split('\n');
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

  String _extractVerificationType() {
    final lines = messageContent.split('\n');
    for (final line in lines) {
      if (line.contains('✅ تایید:')) {
        final match = RegExp(r'✅ تایید: (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? 'none';
        }
      }
    }
    return 'none';
  }

  String _extractPostContent() {
    final lines = messageContent.split('\n');
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

  String _extractPostId() {
    final lines = messageContent.split('\n');
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

  bool _containsUrl(String text) {
    final urlRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)?[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(text);
  }

  bool _containsVistaLink(String text) {
    return text.contains('vista') ||
        text.contains('post/') ||
        text.contains('مشاهده در Vista');
  }

  void _navigateToPost(BuildContext context) {
    final postId = _extractPostId();

    if (postId.isNotEmpty) {
      // همه پست‌های اشتراکی به صفحه جزئیات پست می‌روند
      // صفحه جزئیات پست باید ویدیوها را هم پخش کند
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailsPage(postId: postId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شناسه پست یافت نشد')),
      );
    }
  }
}
