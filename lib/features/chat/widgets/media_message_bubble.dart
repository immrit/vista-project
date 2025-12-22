// lib/features/chat/widgets/media_message_bubble.dart
//
// ویجت نمایش عکس/ویدیو در حباب پیام - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ Full Bleed (تمام صفحه در حباب)
// ✅ Blur Loading & Upload (بلور موقع آپلود)
// ✅ Smart Timestamp (کپسول شیشه‌ای روی عکس)
// ✅ Aspect Ratio دقیق
//

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/chat_theme.dart';
import '../../../model/message_model.dart';
import '../../../services/telegram_read_receipt_service.dart';
import 'telegram_message_status.dart';

/// نوع رسانه
enum MediaType { image, video, gif }

/// ویجت نمایش رسانه در حباب پیام
class MediaMessageBubble extends StatefulWidget {
  final MessageModel? message;
  final String mediaUrl;
  final String? thumbnailUrl;
  final MediaType mediaType;
  final bool isMe;
  final DateTime time;
  final String? caption;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final VoidCallback? onTap;
  final bool isUploading;

  const MediaMessageBubble({
    super.key,
    this.message,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.isMe,
    required this.time,
    this.caption,
    this.width,
    this.height,
    this.durationSeconds,
    this.onTap,
    this.isUploading = false,
  });

  @override
  State<MediaMessageBubble> createState() => _MediaMessageBubbleState();
}

class _MediaMessageBubbleState extends State<MediaMessageBubble> {
  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    // ۱. محاسبه سایز دقیق مثل تلگرام
    // تلگرام معمولا عرض رو فیکس میکنه و ارتفاع رو بر اساس Aspect Ratio تغییر میده
    final maxWidth = MediaQuery.of(context).size.width * 0.75; // ۷۵ درصد عرض صفحه
    final double aspectRatio = (widget.width != null && widget.height != null)
        ? widget.width! / widget.height!
        : 1.0; // پیش‌فرض مربع

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minWidth: 100,
          maxHeight: 450, // محدودیت ارتفاع برای عکس‌های خیلی دراز
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // بخش عکس/ویدیو
            Stack(
              children: [
                // ۱. خود عکس (با Aspect Ratio)
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: _buildMediaContent(theme),
                ),

                // ۲. اورلی‌های وضعیت (آپلود/دانلود/پلی)
                Positioned.fill(child: _buildOverlay(theme)),

                // ۳. بج زمان و وضعیت (روی عکس اگر کپشن نباشه)
                if (widget.caption == null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _buildTimestampPill(theme),
                  ),
              ],
            ),

            // بخش کپشن (اگر وجود داشته باشه)
            if (widget.caption != null)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 24), // پایین جای ساعت
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      widget.caption!,
                      style: TextStyle(
                        color: widget.isMe ? theme.myBubbleTextColor : theme.otherBubbleTextColor,
                        fontSize: 15,
                        fontFamily: 'Vazir',
                      ),
                    ),
                    // ساعت شناور روی متن کپشن (گوشه پایین راست)
                    Positioned(
                      bottom: -20,
                      right: 0,
                      child: _buildCaptionTimestamp(theme),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // نمایش محتوای عکس با هندلینگ فایل لوکال و شبکه
  Widget _buildMediaContent(ChatTheme theme) {
    final bool isLocal = !widget.mediaUrl.startsWith('http') && 
                         !widget.mediaUrl.startsWith('https');

    if (isLocal) {
      // 📂 حالت اول: نمایش فایل لوکال (زمانی که عکس را تازه انتخاب کردید و هنوز آپلود نشده)
      return Image.file(
        File(widget.mediaUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 800, // بهینه‌سازی مموری
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      // 🌐 حالت دوم: نمایش عکس از سرور (لینک اینترنتی)
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        fit: BoxFit.cover,
        memCacheHeight: 800, // بهینه‌سازی مموری
        placeholder: (context, url) => Container(
          color: theme.otherBubbleColor.withOpacity(0.3),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }

  // اورلی‌ها (آپلود، پلی ویدیو)
  Widget _buildOverlay(ChatTheme theme) {
    if (widget.isUploading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // ۱. افکت بلور روی عکس موقع آپلود (دقیقاً مثل تلگرام)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
          // ۲. لودر وسط
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        ],
      );
    }

    if (widget.mediaType == MediaType.video) {
      return Center(
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // بج زمان (کپسول شیشه‌ای روی عکس) - مخصوص حالت بدون کپشن
  Widget _buildTimestampPill(ChatTheme theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4), // رنگ دودی شیشه‌ای
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isMe) ...[
                _buildStatusIcon(),
                const SizedBox(width: 4),
              ],
              Text(
                _formatTime(widget.time),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بج زمان برای حالتی که کپشن داریم (تیره ساده بدون پس‌زمینه کپسولی)
  Widget _buildCaptionTimestamp(ChatTheme theme) {
    final color = widget.isMe
        ? theme.myBubbleTextColor.withOpacity(0.6)
        : theme.otherBubbleTextColor.withOpacity(0.6);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isMe) ...[
          _buildStatusIconForCaption(color),
          const SizedBox(width: 3),
        ],
        Text(
          _formatTime(widget.time),
          style: TextStyle(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon() {
    // از مدل پیام استفاده میکنیم اگه موجود باشه
    if (widget.message != null) {
      return ValueListenableBuilder<MessageDeliveryStatus>(
        valueListenable: widget.message!.statusNotifier,
        builder: (context, status, _) {
          return TelegramMessageStatus(
            status: status,
            size: 14,
            customColor: Colors.white,
          );
        },
      );
    }
    return const Icon(Icons.access_time, size: 12, color: Colors.white);
  }

  Widget _buildStatusIconForCaption(Color color) {
    // از مدل پیام استفاده میکنیم اگه موجود باشه
    if (widget.message != null) {
      return ValueListenableBuilder<MessageDeliveryStatus>(
        valueListenable: widget.message!.statusNotifier,
        builder: (context, status, _) {
          return TelegramMessageStatus(
            status: status,
            size: 14,
            customColor: color,
          );
        },
      );
    }
    return Icon(Icons.access_time, size: 12, color: color);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
