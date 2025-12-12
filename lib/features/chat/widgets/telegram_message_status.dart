// lib/features/chat/widgets/telegram_message_status.dart
//
// ویجت نمایش وضعیت پیام - به سبک تلگرام
//
// ویژگی‌ها:
// ✅ انیمیشن روان بین وضعیت‌ها
// ✅ تیک‌های دقیق مثل تلگرام
// ✅ رنگ‌بندی صحیح (خاکستری/آبی)
// ✅ نمایش زمان خوانده شدن
//

import 'package:flutter/material.dart';
import '../../../services/telegram_read_receipt_service.dart';

/// رنگ‌های تیک
class MessageStatusColors {
  static const Color pending = Color(0xFF9E9E9E); // خاکستری روشن
  static const Color sent = Color(0xFF9E9E9E); // خاکستری
  static const Color delivered = Color(0xFF9E9E9E); // خاکستری
  static const Color read = Color(0xFF4FC3F7); // آبی روشن (مثل تلگرام)
  static const Color failed = Color(0xFFE57373); // قرمز
}

/// ویجت تیک پیام با انیمیشن
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
  // ✅ دیگر نیازی به AnimationController نیست - از AnimatedSwitcher استفاده می‌کنیم

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
    // ✅ Container با اندازه ثابت برای جلوگیری از پرش
    return SizedBox(
      width: widget.size * 1.25, // فضای کافی برای double check
      height: widget.size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          // Fade transition بدون تغییر اندازه
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _buildStatusIcon(),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = _getStatusColor();
    final size = widget.size;

    // ✅ استفاده از key برای AnimatedSwitcher
    Widget icon;
    switch (widget.status) {
      case MessageDeliveryStatus.pending:
        icon = _buildPendingIcon(color, size);
        break;
      case MessageDeliveryStatus.sent:
        icon = _buildSingleCheck(color, size);
        break;
      case MessageDeliveryStatus.delivered:
        icon = _buildDoubleCheck(color, size);
        break;
      case MessageDeliveryStatus.read:
        icon = _buildDoubleCheck(color, size);
        break;
      case MessageDeliveryStatus.failed:
        icon = _buildFailedIcon(color, size);
        break;
    }

    // ✅ Wrap در Center برای تراز وسط
    return Center(
      key: ValueKey(widget.status), // Key برای AnimatedSwitcher
      child: icon,
    );
  }

  /// آیکون در انتظار (ساعت)
  Widget _buildPendingIcon(Color color, double size) {
    // ✅ اندازه ثابت برای جلوگیری از پرش
    return SizedBox(
      width: widget.size * 1.25, // همان اندازه container
      height: size,
      child: Center(
        child: Icon(
          Icons.access_time_rounded,
          size: size * 0.85, // کمی کوچک‌تر برای ظرافت
          color: color,
        ),
      ),
    );
  }

  /// یک تیک (ارسال شده)
  Widget _buildSingleCheck(Color color, double size) {
    // ✅ اندازه ثابت برای جلوگیری از پرش
    return SizedBox(
      width: widget.size * 1.25, // همان اندازه container
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(size, size),
          painter: _SingleCheckPainter(color: color, size: size),
        ),
      ),
    );
  }

  /// دو تیک (تحویل/خوانده شده)
  Widget _buildDoubleCheck(Color color, double size) {
    // ✅ اندازه ثابت برای جلوگیری از پرش
    return SizedBox(
      width: widget.size * 1.25, // همان اندازه container
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(size * 1.25, size),
          painter: _DoubleCheckPainter(color: color, size: size),
        ),
      ),
    );
  }

  /// آیکون خطا
  Widget _buildFailedIcon(Color color, double size) {
    // ✅ اندازه ثابت برای جلوگیری از پرش
    return SizedBox(
      width: widget.size * 1.25, // همان اندازه container
      height: size,
      child: Center(
        child: Icon(
          Icons.error_outline_rounded,
          size: size * 0.85, // کمی کوچک‌تر برای ظرافت
          color: color,
        ),
      ),
    );
  }
}

/// نقاش یک تیک
class _SingleCheckPainter extends CustomPainter {
  final Color color;
  final double size;

  _SingleCheckPainter({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // استفاده از strokeWidth ثابت و ظریف‌تر (مثل تلگرام)
    final strokeWidth = size * 0.08; // نازک‌تر برای ظرافت بیشتر

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true; // برای کیفیت بهتر

    final path = Path();

    // تیک از چپ به راست - با منحنی ملایم‌تر
    path.moveTo(canvasSize.width * 0.15, canvasSize.height * 0.5);
    path.quadraticBezierTo(
      canvasSize.width * 0.3,
      canvasSize.height * 0.65,
      canvasSize.width * 0.45,
      canvasSize.height * 0.75,
    );
    path.quadraticBezierTo(
      canvasSize.width * 0.6,
      canvasSize.height * 0.5,
      canvasSize.width * 0.85,
      canvasSize.height * 0.25,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SingleCheckPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.size != size;
  }
}

/// نقاش دو تیک
class _DoubleCheckPainter extends CustomPainter {
  final Color color;
  final double size;

  _DoubleCheckPainter({required this.color, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // استفاده از strokeWidth ثابت و ظریف‌تر (مثل تلگرام)
    final strokeWidth = size * 0.08; // نازک‌تر برای ظرافت بیشتر

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true; // برای کیفیت بهتر

    // تیک اول (عقب‌تر) - با منحنی ملایم
    final path1 = Path();
    path1.moveTo(canvasSize.width * 0.02, canvasSize.height * 0.5);
    path1.quadraticBezierTo(
      canvasSize.width * 0.15,
      canvasSize.height * 0.65,
      canvasSize.width * 0.28,
      canvasSize.height * 0.75,
    );
    path1.quadraticBezierTo(
      canvasSize.width * 0.4,
      canvasSize.height * 0.5,
      canvasSize.width * 0.52,
      canvasSize.height * 0.3,
    );
    canvas.drawPath(path1, paint);

    // تیک دوم (جلوتر) - با منحنی ملایم
    final path2 = Path();
    path2.moveTo(canvasSize.width * 0.28, canvasSize.height * 0.5);
    path2.quadraticBezierTo(
      canvasSize.width * 0.4,
      canvasSize.height * 0.65,
      canvasSize.width * 0.52,
      canvasSize.height * 0.75,
    );
    path2.quadraticBezierTo(
      canvasSize.width * 0.65,
      canvasSize.height * 0.5,
      canvasSize.width * 0.98,
      canvasSize.height * 0.25,
    );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _DoubleCheckPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.size != size;
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
        (isMe ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // نشان ویرایش شده
        if (isEdited)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'ویرایش شده',
              style: TextStyle(
                color: color,
                fontSize: fontSize - 1,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        // زمان
        Text(
          _formatTime(),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
          ),
        ),
        // وضعیت (فقط برای پیام‌های خودم)
        if (isMe) ...[
          const SizedBox(width: 3),
          TelegramMessageStatus(
            status: status,
            size: fontSize + 1, // کوچک‌تر و ظریف‌تر
            customColor: status == MessageDeliveryStatus.read
                ? MessageStatusColors.read
                : color,
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
