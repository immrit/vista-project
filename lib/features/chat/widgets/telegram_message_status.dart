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
  static const Color pending = Color(0xFF9E9E9E);      // خاکستری روشن
  static const Color sent = Color(0xFF9E9E9E);         // خاکستری
  static const Color delivered = Color(0xFF9E9E9E);    // خاکستری
  static const Color read = Color(0xFF4FC3F7);         // آبی روشن (مثل تلگرام)
  static const Color failed = Color(0xFFE57373);       // قرمز
}

/// ویجت تیک پیام با انیمیشن
class TelegramMessageStatus extends StatefulWidget {
  final MessageDeliveryStatus status;
  final double size;
  final Color? customColor;
  final bool showAnimation;

  const TelegramMessageStatus({
    super.key,
    required this.status,
    this.size = 16,
    this.customColor,
    this.showAnimation = true,
  });

  @override
  State<TelegramMessageStatus> createState() => _TelegramMessageStatusState();
}

class _TelegramMessageStatusState extends State<TelegramMessageStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(TelegramMessageStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && widget.showAnimation) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.showAnimation ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.showAnimation ? _opacityAnimation.value : 1.0,
            child: _buildStatusIcon(),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    final color = _getStatusColor();
    final size = widget.size;

    switch (widget.status) {
      case MessageDeliveryStatus.pending:
        return _buildPendingIcon(color, size);
      case MessageDeliveryStatus.sent:
        return _buildSingleCheck(color, size);
      case MessageDeliveryStatus.delivered:
        return _buildDoubleCheck(color, size);
      case MessageDeliveryStatus.read:
        return _buildDoubleCheck(color, size);
      case MessageDeliveryStatus.failed:
        return _buildFailedIcon(color, size);
    }
  }

  /// آیکون در انتظار (ساعت)
  Widget _buildPendingIcon(Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.access_time_rounded,
        size: size * 0.9,
        color: color,
      ),
    );
  }

  /// یک تیک (ارسال شده)
  Widget _buildSingleCheck(Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SingleCheckPainter(color: color),
      ),
    );
  }

  /// دو تیک (تحویل/خوانده شده)
  Widget _buildDoubleCheck(Color color, double size) {
    return SizedBox(
      width: size * 1.3,
      height: size,
      child: CustomPaint(
        painter: _DoubleCheckPainter(color: color),
      ),
    );
  }

  /// آیکون خطا
  Widget _buildFailedIcon(Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Icons.error_outline_rounded,
        size: size * 0.9,
        color: color,
      ),
    );
  }
}

/// نقاش یک تیک
class _SingleCheckPainter extends CustomPainter {
  final Color color;

  _SingleCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // تیک از چپ به راست
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.7);
    path.lineTo(size.width * 0.8, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SingleCheckPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// نقاش دو تیک
class _DoubleCheckPainter extends CustomPainter {
  final Color color;

  _DoubleCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // تیک اول (عقب‌تر)
    final path1 = Path();
    path1.moveTo(size.width * 0.05, size.height * 0.5);
    path1.lineTo(size.width * 0.25, size.height * 0.7);
    path1.lineTo(size.width * 0.55, size.height * 0.3);
    canvas.drawPath(path1, paint);

    // تیک دوم (جلوتر)
    final path2 = Path();
    path2.moveTo(size.width * 0.35, size.height * 0.5);
    path2.lineTo(size.width * 0.55, size.height * 0.7);
    path2.lineTo(size.width * 0.95, size.height * 0.3);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _DoubleCheckPainter oldDelegate) {
    return oldDelegate.color != color;
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
            size: fontSize + 3,
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

