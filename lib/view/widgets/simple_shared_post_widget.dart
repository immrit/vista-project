import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SimpleSharedPostWidget extends StatelessWidget {
  final String messageContent;
  final String? attachmentUrl;
  final String? attachmentType;

  const SimpleSharedPostWidget({
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
          onTap: () {
            // Simple tap handling - could be expanded later
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('پست اشتراکی - قابلیت مشاهده به زودی اضافه می‌شود')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                if (attachmentUrl != null && attachmentType == 'image')
                  _buildImageAttachment(),
                if (attachmentUrl != null && attachmentType == 'video')
                  _buildVideoAttachment(),
                _buildContent(),
                const SizedBox(height: 8),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.share,
            size: 18,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _extractUsername(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'پست اشتراکی',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.open_in_new,
          size: 16,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildImageAttachment() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: attachmentUrl!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.image_not_supported),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoAttachment() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 48,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 8),
                Text(
                  'ویدیو',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final content = _extractPostContent();
    if (content.isEmpty) return const SizedBox.shrink();

    return Text(
      content,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(
          Icons.visibility,
          size: 14,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          'مشاهده در Vista',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Text(
          _extractPostId().isNotEmpty
              ? '#${_extractPostId().substring(0, 8)}'
              : '',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
            fontFamily: 'monospace',
          ),
        ),
      ],
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
        text.contains('m مشاهده در Vista');
  }
}
