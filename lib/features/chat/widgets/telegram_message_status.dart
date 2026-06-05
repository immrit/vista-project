// lib/features/chat/widgets/telegram_message_status.dart
//
// ویجت نمایش وضعیت پیام - کاملاً مشابه ویستا
// اصلاح شده: رفع مشکل پرش با استفاده از CustomPainter برای تمام وضعیت‌ها

import 'package:flutter/material.dart';
import '../../../services/telegram_read_receipt_service.dart';

/// رنگ‌های تیک
class MessageStatusColors {
  static const Color pending = Color(0xFF9E9E9E); // خاکستری روشن
  static const Color sent = Color(0xFF9E9E9E); // خاکستری
  static const Color delivered = Color(0xFF9E9E9E); // خاکستری
  static const Color read = Color(0xFF4FC3F7); // آبی روشن (مثل ویستا)
  static const Color failed = Color(0xFFE57373); // قرمز
}

/// ویجت تیک پیام با انیمیشن - بهینه شده مثل ویستا
///
/// ویژگی‌های کلیدی برای جلوگیری از پرش:
/// 1. استفاده از CustomPainter برای تمام وضعیت‌ها (ساعت، تیک، خطا)
/// 2. AnimatedSwitcher با duration کوتاه (150ms)
/// 3. SizedBox با عرض ثابت برای جلوگیری از layout shift
/// 4. RepaintBoundary برای ایزوله کردن rebuild
/// 5. layoutBuilder با Stack برای تراز دقیق
class TelegramMessageStatus extends StatefulWidget {
  final MessageDeliveryStatus status;
  final double size;
  final Color? customColor;

  const TelegramMessageStatus({
    super.key,
    required this.status,
    this.size = 16,
    this.customColor,
  });

  @override
  State<TelegramMessageStatus> createState() => _TelegramMessageStatusState();
}

class _TelegramMessageStatusState extends State<TelegramMessageStatus> {
  Color _getStatusColor() {
    if (widget.customColor != null) return widget.customColor!;

    switch (widget.status) {
      case MessageDeliveryStatus.pending:
        return MessageStatusColors.pending;
      case MessageDeliveryStatus.sent:
        return MessageStatusColors.sent;
      case MessageDeliveryStatus.delivered:
        return MessageStatusColors.delivered;
      case MessageDeliveryStatus.read:
        return MessageStatusColors.read;
      case MessageDeliveryStatus.failed:
        return MessageStatusColors.failed;
    }
  }

  @override
  Widget build(BuildContext context) {
    // نکته مهم: استفاده از RepaintBoundary برای ایزوله کردن انیمیشن
    // این باعث می‌شود فقط این widget rebuild شود، نه کل bubble
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size * 1.25, // ✅ عرض ثابت - جلوگیری از پرش
        height: widget.size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          // ✅ کلید موفقیت: Stack به جای Column
          // همه children رو روی هم می‌ذاره و جلوی layout shift رو می‌گیره
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center, // ✅ تراز وسط - جلوگیری از پرش
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            // ✅ فقط opacity - هیچ scale یا position change نداریم
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _buildStatusContent(),
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    final color = _getStatusColor();
    final size = widget.size;
    final strokeWidth = size * 0.10; // ضخامت قلم یکسان برای همه

    // کلید منحصر به فرد برای AnimatedSwitcher
    final key = ValueKey<MessageDeliveryStatus>(widget.status);

    if (widget.status == MessageDeliveryStatus.failed) {
      return SizedBox(
        key: key,
        width: widget.size * 1.25,
        height: size,
        child: Center(
          child: Icon(
            Icons.refresh_rounded,
            size: size,
            color: MessageStatusColors.failed,
          ),
        ),
      );
    }

    // تمام وضعیت‌ها داخل یک کانتینر با سایز دقیقاً یکسان قرار می‌گیرند
    // تا هیچ تغییر لایه‌ای (Layout Shift) رخ ندهد.
    return SizedBox(
      key: key,
      width: widget.size * 1.25,
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(widget.size * 1.25, size),
          painter: _StatusPainter(
            status: widget.status,
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

/// یک Painter واحد برای تمام وضعیت‌ها
/// این تکنیک در ویستا استفاده می‌شود تا مختصات رسم همواره ثابت باشد
class _StatusPainter extends CustomPainter {
  final MessageDeliveryStatus status;
  final Color color;
  final double strokeWidth;

  _StatusPainter({
    required this.status,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // محاسبه مختصات مرکزی برای اینکه ساعت و تیک دقیقاً هم‌مرکز باشند
    // در ویستا تیک‌ها کمی سمت راست‌تر هستند، اما ساعت باید وسط باشد.
    // ما یک افست پایه در نظر می‌گیریم.

    // سایز مبنا (ارتفاع ویجت)
    final s = size.height;

    switch (status) {
      case MessageDeliveryStatus.pending:
        _drawClock(canvas, size, paint, s);
        break;
      case MessageDeliveryStatus.sent:
        _drawSingleCheck(canvas, size, paint, s);
        break;
      case MessageDeliveryStatus.delivered:
      case MessageDeliveryStatus.read:
        _drawDoubleCheck(canvas, size, paint, s);
        break;
      case MessageDeliveryStatus.failed:
        _drawFailed(canvas, size, paint, s);
        break;
    }
  }

  void _drawClock(Canvas canvas, Size size, Paint paint, double s) {
    // رسم دایره ساعت - دقیقاً در همان محدوده ای که تیک قرار میگیرد
    // استفاده از شعاع کمی کوچکتر تا با سایز تیک همخوانی بصری داشته باشد
    final radius = (s / 2) * 0.8;

    // مرکز دایره. برای تراز بودن با تیک تکی، کمی به سمت چپ کانتینر متمایل می‌کنیم
    // یا دقیقا وسط کانتینر مربعی فرضی سمت چپ
    final centerX = size.height / 2; // مربع سمت چپ
    final centerY = size.height / 2;

    // 1. دایره
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // 2. عقربه ساعت (ساعت 3)
    // لاین کوتاه
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX + (radius * 0.5), centerY),
      paint..strokeWidth = strokeWidth * 0.8, // عقربه‌ها کمی نازک‌تر
    );

    // 3. عقربه دقیقه (ساعت 12)
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX, centerY - (radius * 0.6)),
      paint,
    );
  }

  void _drawSingleCheck(Canvas canvas, Size size, Paint paint, double s) {
    final path = Path();

    // مقیاس‌دهی مختصات بر اساس ارتفاع (s)
    // مختصات دقیق برای تیک (شبیه ویستا)
    // شروع تیک
    final startX = s * 0.25;
    final startY = s * 0.55;

    // نقطه پایین تیک
    final midX = s * 0.45;
    final midY = s * 0.75;

    // نقطه پایان تیک
    final endX = s * 0.80;
    final endY = s * 0.30;

    path.moveTo(startX, startY);
    path.lineTo(midX, midY);
    path.lineTo(endX, endY);

    canvas.drawPath(path, paint);
  }

  void _drawDoubleCheck(Canvas canvas, Size size, Paint paint, double s) {
    // تیک عقب (کامل) + تیک جلو (کامل) با فاصله مناسب تا همیشه واضح دیده شوند.
    final back = Path()
      ..moveTo(s * 0.10, s * 0.56)
      ..lineTo(s * 0.28, s * 0.74)
      ..lineTo(s * 0.56, s * 0.36);

    final front = Path()
      ..moveTo(s * 0.34, s * 0.56)
      ..lineTo(s * 0.52, s * 0.74)
      ..lineTo(s * 0.86, s * 0.30);

    canvas.drawPath(back, paint);
    canvas.drawPath(front, paint);
  }

  void _drawFailed(Canvas canvas, Size size, Paint paint, double s) {
    final centerX = size.height / 2;
    final centerY = size.height / 2;
    final radius = (s / 2) * 0.8;

    paint.color = MessageStatusColors.failed;
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // علامت تعجب
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY - 2), 1.5, paint);
    canvas.drawCircle(Offset(centerX, centerY + 4), 1.5, paint);
  }

  @override
  bool shouldRepaint(covariant _StatusPainter oldDelegate) {
    return oldDelegate.status != status ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// ویجت ترکیبی زمان و وضعیت
class MessageTimeAndStatus extends StatelessWidget {
  final DateTime time;
  final MessageDeliveryStatus status;
  final bool isMe;
  final bool isEdited;
  final Color? textColor;
  final double fontSize;

  const MessageTimeAndStatus({
    super.key,
    required this.time,
    required this.status,
    required this.isMe,
    this.isEdited = false,
    this.textColor,
    this.fontSize = 11,
  });

  String _formatTime() {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final color = textColor ??
        (isMe
            ? Colors.white.withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.5));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.end, // تراز پایین برای هماهنگی بهتر
      children: [
        if (isEdited)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(
              'ویرایش شده',
              style: TextStyle(
                color: color,
                fontSize: fontSize - 2, // کمی کوچک‌تر
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Text(
          _formatTime(),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            height: 1.2,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(
                bottom: 2), // تنظیم دقیق برای هم‌ترازی با متن
            child: TelegramMessageStatus(
              status: status,
              size: fontSize + 2,
              customColor: status == MessageDeliveryStatus.read
                  ? MessageStatusColors.read
                  : color,
            ),
          ),
        ],
      ],
    );
  }
}

/// ویجت نمایش اطلاعات خوانده شدن (برای صفحه info)
class ReadReceiptInfo extends StatelessWidget {
  final MessageStatusInfo statusInfo;
  final bool showIcons;

  const ReadReceiptInfo({
    super.key,
    required this.statusInfo,
    this.showIcons = true,
  });

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (diff.inDays == 0) {
      return 'امروز $time';
    } else if (diff.inDays == 1) {
      return 'دیروز $time';
    } else {
      final day = dateTime.day;
      final month = dateTime.month;
      return '$day/$month $time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ارسال شده
        _buildInfoRow(
          context,
          icon: Icons.check,
          label: 'ارسال شده',
          value: _formatDateTime(statusInfo.sentAt),
          color: MessageStatusColors.sent,
        ),
        const SizedBox(height: 8),
        // تحویل داده شده
        _buildInfoRow(
          context,
          icon: Icons.done_all,
          label: 'تحویل داده شده',
          value: _formatDateTime(statusInfo.deliveredAt),
          color: statusInfo.deliveredAt != null
              ? MessageStatusColors.delivered
              : theme.disabledColor,
        ),
        const SizedBox(height: 8),
        // خوانده شده
        _buildInfoRow(
          context,
          icon: Icons.done_all,
          label: 'خوانده شده',
          value: _formatDateTime(statusInfo.seenAt),
          color: statusInfo.seenAt != null
              ? MessageStatusColors.read
              : theme.disabledColor,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        if (showIcons) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// ✅ Status Icon ساده با transition نرم - بدون پرش
/// استفاده از Icon به جای CustomPaint (برای موارد ساده‌تر)
/// دقیقاً مثل ویستا
class SmoothStatusIcon extends StatelessWidget {
  final bool isPending;
  final bool isSeen;
  final bool isFailed;
  final Color? color;
  final double size;

  const SmoothStatusIcon({
    super.key,
    required this.isPending,
    required this.isSeen,
    required this.isFailed,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.white70;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          // ✅ فقط opacity - هیچ scale یا position change نداریم
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          // ✅ کلید موفقیت: Stack به جای Column
          // همه children رو روی هم می‌ذاره و جلوی layout shift رو می‌گیره
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: _buildIcon(iconColor),
      ),
    );
  }

  Widget _buildIcon(Color iconColor) {
    if (isFailed) {
      return Icon(
        Icons.error_outline,
        key: const ValueKey('failed'),
        size: size,
        color: Colors.red,
      );
    }

    if (isPending) {
      return Icon(
        Icons.access_time,
        key: const ValueKey('pending'),
        size: size,
        color: iconColor.withValues(alpha: 0.6),
      );
    }

    if (isSeen) {
      return Icon(
        Icons.done_all,
        key: const ValueKey('seen'),
        size: size,
        color: Colors.lightBlueAccent,
      );
    }

    return Icon(
      Icons.done,
      key: const ValueKey('sent'),
      size: size,
      color: iconColor,
    );
  }
}
