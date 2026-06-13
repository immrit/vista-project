// lib/features/chat/widgets/gif_message_bubble.dart
//
// ویجت نمایش GIF در چت - مشابه ویستا
//
// ویژگی‌ها:
// ✅ نمایش GIF با CachedNetworkImage
// ✅ برچسب GIF در گوشه
// ✅ زمان و وضعیت روی تصویر
// ✅ Loading و Error State

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../model/message_model.dart';

class GifMessageBubble extends StatelessWidget {
  final MessageModel message;

  const GifMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // ابعاد پیش‌فرض اگر در دیتابیس نداریم (بهتر است بعداً ابعاد را هم ذخیره کنید)
    const double defaultWidth = 200;
    const double defaultHeight = 150;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16), // گردی گوشه‌ها مثل ویستا
      child: Stack(
        children: [
          // تصویر گیف
          CachedNetworkImage(
            imageUrl: message.attachmentUrl ?? '',
            width: defaultWidth,
            height: defaultHeight,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: defaultWidth,
              height: defaultHeight,
              color: Colors.grey.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: defaultWidth,
              height: defaultHeight,
              color: Colors.grey.withValues(alpha: 0.2),
              child: const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 32,
              ),
            ),
          ),

          // برچسب GIF در گوشه (مثل ویستا)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gif,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 2),
                  Text(
                    'GIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // زمان و تیک (روی تصویر، پایین سمت راست)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (message.isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isReadByPeer
                          ? Icons.done_all
                          : (message.isDelivered ? Icons.done_all : Icons.done),
                      size: 12,
                      color:
                          message.isReadByPeer ? Colors.blueAccent : Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
