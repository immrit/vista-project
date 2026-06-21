import 'package:flutter/material.dart';

class EnhancedChatBackground extends StatelessWidget {
  final Widget child;
  // allowHeavyEffects / forceEnableBlur / blurIntensity kept for call-site
  // compatibility but have no effect — BackdropFilter removed entirely.
  final bool enablePattern;
  final bool allowHeavyEffects;
  final bool? forceEnableBlur;
  final double blurIntensity;

  const EnhancedChatBackground({
    super.key,
    required this.child,
    this.enablePattern = true,
    this.allowHeavyEffects = true,
    this.forceEnableBlur,
    this.blurIntensity = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFDFE5E9),
        ),
        Image.asset(
          isDark
              ? 'assets/images/vista_custom_bg_dark.png'
              : 'assets/images/vista_custom_bg.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.2),
          colorBlendMode: isDark ? BlendMode.darken : BlendMode.lighten,
        ),
        child,
      ],
    );
  }
}

/// Modern-style Message Background Pattern
class ModernMessagePattern extends StatelessWidget {
  final bool isMe;
  final Widget child;

  const ModernMessagePattern({
    super.key,
    required this.isMe,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Pattern فقط برای پیام‌های ارسالی در ویستا
        if (isMe)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _MessagePatternPainter(isDark: isDark),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _MessagePatternPainter extends CustomPainter {
  final bool isDark;

  _MessagePatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    const spacing = 8.0;

    // نقش مورب ظریف
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
