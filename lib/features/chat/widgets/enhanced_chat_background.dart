
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../provider/settings_providers.dart';

/// Enhanced Chat Background با الهام از ویستا
/// این ویجت به صورت خودکار تنظیمات بلور را از provider می‌خواند
/// و در هر دو تم روشن و تاریک (به جز تم مشکی مطلق) بلور را اعمال می‌کند
class EnhancedChatBackground extends ConsumerStatefulWidget {
  final Widget child;
  final bool enablePattern;
  final bool allowHeavyEffects;

  /// اگر null باشد، از تنظیمات کاربر استفاده می‌شود
  /// اگر مقدار مشخص شود، آن مقدار استفاده می‌شود (برای override)
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
  ConsumerState<EnhancedChatBackground> createState() =>
      _EnhancedChatBackgroundState();
}

class _EnhancedChatBackgroundState
    extends ConsumerState<EnhancedChatBackground> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceEffects = MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;

    // تشخیص تم مشکی مطلق (AMOLED/Pure Black)
    // در تم مشکی مطلق، scaffoldBackgroundColor معمولاً 0xFF000000 است
    final isPitchBlack = theme.scaffoldBackgroundColor.toARGB32() == 0xFF000000;

    // خواندن تنظیمات کاربر از provider
    final userSettingEnabled = ref.watch(chatBlurBackgroundProvider);

    // منطق نهایی اعمال بلور:
    // 1. اگر forceEnableBlur داده شده، از آن استفاده کن، وگرنه از تنظیمات کاربر
    // 2. حتماً نباید تم مشکی مطلق باشد (برای حفظ سیاهی مطلق در AMOLED)
    // ✅ حذف شرط isDark - بلور در هر دو تم روشن و تاریک اعمال می‌شود
    final shouldApplyBlur = (widget.forceEnableBlur ?? userSettingEnabled) &&
        !isPitchBlack &&
        widget.allowHeavyEffects;
    final effectiveBlur = widget.allowHeavyEffects
        ? widget.blurIntensity
        : widget.blurIntensity.clamp(0.0, 2.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1️⃣ Base Color (فوری نمایش داده می‌شود)
        Container(
          color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFDFE5E9),
        ),

        // 2️⃣ Vista Custom Doodle Wallpaper
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

        // 3️⃣ Blur Effect
        if (shouldApplyBlur && !reduceEffects)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: effectiveBlur,
                sigmaY: effectiveBlur,
              ),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

        // 4️⃣ محتوای اصلی
        widget.child,
      ],
    );
  }

}

/// Telegram-style Message Background Pattern
class TelegramMessagePattern extends StatelessWidget {
  final bool isMe;
  final Widget child;

  const TelegramMessagePattern({
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
