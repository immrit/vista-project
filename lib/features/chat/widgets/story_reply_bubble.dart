import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../model/message_model.dart';

/// ویجت نمایش پیام پاسخ به استوری در چت
/// مشابه دایرکت اینستاگرام - تصویر کوچک استوری + متن پاسخ
class StoryReplyBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onTap;

  const StoryReplyBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final storyData = message.storyReplyData;
    if (storyData == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 12,
          right: isMe ? 12 : 60,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // هدر: پاسخ به استوری
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.reply,
                    size: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMe
                        ? 'پاسخ به استوری ${storyData.storyOwnerUsername}'
                        : 'پاسخ به استوری شما',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // باکس اصلی پیام
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? (isDark
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFF2196F3))
                    : (isDark ? const Color(0xFF2D2D2D) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // تصویر کوچک استوری
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: storyData.storyThumbnailUrl,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            child: Icon(
                              storyData.storyMediaType == 'video'
                                  ? Icons.videocam
                                  : Icons.image,
                              color: Colors.grey[500],
                              size: 40,
                            ),
                          ),
                        ),
                        // آیکون ویدیو اگر استوری ویدیو بود
                        if (storyData.storyMediaType == 'video')
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        // گرادینت برای خوانایی بهتر
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // متن پاسخ
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                      textDirection: TextDirection.rtl,
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
}
