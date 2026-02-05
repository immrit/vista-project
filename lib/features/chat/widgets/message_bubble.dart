import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../../../model/message_model.dart';
import '../../../provider/provider.dart';
import 'package:Vista/utils/time_utils.dart';
import '../../../services/telegram_read_receipt_service.dart';
import '../theme/chat_theme.dart';

/// حباب پیام با پشتیبانی از:
/// - تنظیم اندازه فونت از تنظیمات
/// - آیکون retry برای پیام‌های ناموفق
/// - انیمیشن‌های زیبا
class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;
  final MessageModel? previousMessage;
  final MessageModel? nextMessage;
  final Function(MessageModel)? onLongPress;
  final Function(MessageModel)? onTap;
  final Function(MessageModel)? onRetry; // ✅ callback برای retry

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.previousMessage,
    this.nextMessage,
    this.onLongPress,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ✅ خواندن تنظیمات فونت از Provider
    final fontSize = ref.watch(messageFontSizeProvider);

    final chatTheme = context.chatTheme;
    final previous = previousMessage;
    final next = nextMessage;

    final bool isFirstInGroup = previous == null ||
        !TimeUtils.isInSameGroup(
          message.createdAt,
          previous.createdAt,
          message.senderId,
          previous.senderId,
        );

    final bool isLastInGroup = next == null ||
        !TimeUtils.isInSameGroup(
          next.createdAt,
          message.createdAt,
          next.senderId,
          message.senderId,
        );

    // TelegramX-style bubble corners (merged corners are sharper)
    final BorderRadius borderRadius = chatTheme.bubbleBorderRadius(
      isMe: isMe,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
    );

    // Color Logic
    final Color bubbleColor = isMe
        ? theme.primaryColor
        : (isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF));

    final Color textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    final Color timestampColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    // ✅ بررسی وضعیت پیام
    final isFailed = message.isFailed == true;
    final isPending = message.isPending;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ✅ آیکون Retry برای پیام‌های ناموفق (سمت چپ حباب)
            if (isFailed && isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: _buildRetryButton(context),
              ),

            // حباب اصلی
            Flexible(
              child: InkWell(
                onLongPress:
                    onLongPress != null ? () => onLongPress!(message) : null,
                onTap: onTap != null ? () => onTap!(message) : null,
                borderRadius: borderRadius,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? bubbleColor.withValues(alpha: 0.6)
                        : bubbleColor,
                    borderRadius: borderRadius,
                    // ✅ حاشیه قرمز برای پیام‌های ناموفق
                    border: isFailed
                        ? Border.all(
                            color: Colors.red.withValues(alpha: 0.5), width: 1)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 10,
                          bottom: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Content with dynamic font size
                            _buildContent(context, textColor, fontSize),
                          ],
                        ),
                      ),

                      // Timestamp Overlay
                      Positioned(
                        bottom: 6,
                        right: isMe ? 8 : null,
                        left: isMe ? null : 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ✅ نمایش خطا اگر پیام ناموفق بود
                            if (isFailed) ...[
                              Icon(
                                Icons.error_outline,
                                size: 12,
                                color: Colors.red[400],
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              TimeUtils.formatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: timestampColor,
                              ),
                            ),
                            if (isMe && !isFailed) ...[
                              const SizedBox(width: 4),
                              if (isMe && !isFailed) ...[
                                const SizedBox(width: 4),
                                _buildStatusWidget(timestampColor),
                              ],
                            ],
                          ],
                        ),
                      ),

                      // ✅ نوار پیشرفت آپلود
                      if (isPending && message.uploadProgress != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft: borderRadius.bottomLeft,
                              bottomRight: borderRadius.bottomRight,
                            ),
                            child: LinearProgressIndicator(
                              value: message.uploadProgress,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withValues(alpha: 0.5),
                              ),
                              minHeight: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ دکمه Retry
  Widget _buildRetryButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRetry != null ? () => onRetry!(message) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.refresh,
            size: 18,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  /// ✅ ویجت وضعیت پیام با استفاده از ValueNotifier
  Widget _buildStatusWidget(Color color) {
    return ValueListenableBuilder<MessageDeliveryStatus>(
      valueListenable: message.statusNotifier,
      builder: (context, status, child) {
        if (status == MessageDeliveryStatus.pending) {
          return Icon(Icons.access_time, size: 12, color: color);
        }

        // determine if seen based on status
        final isSeen = status == MessageDeliveryStatus.read;

        return Icon(
          isSeen ? Icons.done_all : Icons.check,
          size: 12,
          color: isSeen ? Colors.blue[300] : color,
        );
      },
    );
  }

  /// ✅ محتوای پیام با اندازه فونت داینامیک
  Widget _buildContent(BuildContext context, Color textColor, double fontSize) {
    // 1. Image
    if (message.attachmentType == 'image' ||
        (message.localImagePath != null &&
            message.localImagePath!.isNotEmpty)) {
      return _buildImage(context);
    }

    // 2. Text with dynamic font size
    return Text(
      message.content,
      style: TextStyle(
        fontSize: fontSize, // ✅ فونت داینامیک از تنظیمات
        color: textColor,
        height: 1.4,
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    bool hasLocal = message.localImagePath != null &&
        File(message.localImagePath!).existsSync();

    Widget imageWidget;
    if (hasLocal) {
      imageWidget =
          Image.file(File(message.localImagePath!), fit: BoxFit.cover);
    } else if (message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: message.attachmentUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[300]),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      );
    } else {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: imageWidget,
      ),
    );
  }
}
