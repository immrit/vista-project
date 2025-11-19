import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../model/message_model.dart';

/// ✅ Custom Message Bubble Widget - طراحی مدرن با هدف performance بالا
/// استفاده از LeafRenderObjectWidget برای performance بهتر
class ModernMessageBubble extends LeafRenderObjectWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onTap;
  final TextStyle? textStyle;
  final Color? bubbleColor;
  final Color? textColor;

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
    this.textStyle,
    this.bubbleColor,
    this.textColor,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderMessageBubble(
      message: message,
      isMe: isMe,
      onTap: onTap,
      textStyle: textStyle ?? DefaultTextStyle.of(context).style,
      themeData: Theme.of(context),
      bubbleColor: bubbleColor,
      textColor: textColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMessageBubble renderObject,
  ) {
    renderObject
      ..message = message
      ..isMe = isMe
      ..onTap = onTap
      ..textStyle = textStyle ?? DefaultTextStyle.of(context).style
      ..themeData = Theme.of(context)
      ..bubbleColor = bubbleColor
      ..textColor = textColor;
  }
}

/// ✅ Custom RenderObject - مثل Canvas Drawing تلگرام
/// صفر Inflation overhead، صفر measure/layout pass اضافی
class RenderMessageBubble extends RenderBox {
  MessageModel _message;
  bool _isMe;
  VoidCallback? _onTap;
  TextStyle _textStyle;
  ThemeData _themeData;
  Color? _bubbleColor;
  Color? _textColor;

  // ✅ Text Layout Cache - برای جلوگیری از recalculation
  TextPainter? _textPainter;
  TextPainter? _timePainter;

  // ✅ Paint objects - reusable
  final Paint _bubblePaint = Paint();

  RenderMessageBubble({
    required MessageModel message,
    required bool isMe,
    VoidCallback? onTap,
    required TextStyle textStyle,
    required ThemeData themeData,
    Color? bubbleColor,
    Color? textColor,
  })  : _message = message,
        _isMe = isMe,
        _onTap = onTap,
        _textStyle = textStyle,
        _themeData = themeData,
        _bubbleColor = bubbleColor,
        _textColor = textColor;

  // Getters & Setters
  MessageModel get message => _message;
  set message(MessageModel value) {
    if (_message == value) return;
    _message = value;
    _textPainter = null; // invalidate cache
    markNeedsLayout();
  }

  bool get isMe => _isMe;
  set isMe(bool value) {
    if (_isMe == value) return;
    _isMe = value;
    markNeedsPaint();
  }

  VoidCallback? get onTap => _onTap;
  set onTap(VoidCallback? value) {
    _onTap = value;
  }

  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    _textPainter = null;
    markNeedsLayout();
  }

  ThemeData get themeData => _themeData;
  set themeData(ThemeData value) {
    if (_themeData == value) return;
    _themeData = value;
    markNeedsPaint();
  }

  Color? get bubbleColor => _bubbleColor;
  set bubbleColor(Color? value) {
    if (_bubbleColor == value) return;
    _bubbleColor = value;
    markNeedsPaint();
  }

  Color? get textColor => _textColor;
  set textColor(Color? value) {
    if (_textColor == value) return;
    _textColor = value;
    _textPainter = null;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    // ✅ محاسبه Layout فقط یکبار
    _textPainter ??= TextPainter(
      text: TextSpan(
        text: _message.content,
        style: _textStyle.copyWith(
          color: _textColor ??
              (_isMe ? Colors.white : _themeData.textTheme.bodyLarge?.color),
          fontSize: 15,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: null,
    );

    _timePainter ??= TextPainter(
      text: TextSpan(
        text: _formatTime(_message.createdAt),
        style: TextStyle(
          color: _isMe ? Colors.white70 : Colors.black54,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    // Layout text
    final maxWidth = constraints.maxWidth * 0.75;
    _textPainter!.layout(maxWidth: maxWidth - 32);
    _timePainter!.layout();

    // محاسبه سایز نهایی
    final bubbleWidth = _textPainter!.width + 32;
    final bubbleHeight = _textPainter!.height + 40;

    size = constraints.constrain(Size(bubbleWidth, bubbleHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    // ✅ ترسیم Background Bubble
    _bubblePaint.color = _bubbleColor ??
        (_isMe
            ? _themeData.primaryColor
            : _themeData.cardColor);

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      const Radius.circular(16),
    );
    canvas.drawRRect(bubbleRect, _bubblePaint);

    // ✅ ترسیم Text
    canvas.save();
    canvas.translate(offset.dx + 16, offset.dy + 10);
    _textPainter!.paint(canvas, Offset.zero);
    canvas.restore();

    // ✅ ترسیم Time
    canvas.save();
    canvas.translate(
      offset.dx + size.width - _timePainter!.width - 16,
      offset.dy + size.height - 20,
    );
    _timePainter!.paint(canvas, Offset.zero);
    canvas.restore();

    // ✅ ترسیم Status Icon (if outgoing)
    if (_isMe) {
      _drawStatusIcon(canvas, offset);
    }
  }

  void _drawStatusIcon(Canvas canvas, Offset offset) {
    final iconPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final iconOffset = Offset(
      offset.dx + size.width - 30,
      offset.dy + size.height - 18,
    );

    // Draw checkmark
    final path = Path()
      ..moveTo(iconOffset.dx, iconOffset.dy + 4)
      ..lineTo(iconOffset.dx + 3, iconOffset.dy + 7)
      ..lineTo(iconOffset.dx + 8, iconOffset.dy + 2);

    canvas.drawPath(path, iconPaint);

    // اگر پیام دیده شده، checkmark دوم
    if (_message.isSeen) {
      final secondPath = Path()
        ..moveTo(iconOffset.dx + 4, iconOffset.dy + 4)
        ..lineTo(iconOffset.dx + 7, iconOffset.dy + 7)
        ..lineTo(iconOffset.dx + 12, iconOffset.dy + 2);

      canvas.drawPath(secondPath, iconPaint);
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _onTap?.call();
    }
  }
}

