// lib/features/chat/widgets/enhanced_chat_background.dart
//
// بک‌گراند چت با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ والپیپر کش شده با Fade transition
// ✅ Pattern overlay (مثل تلگرام)
// ✅ Blur effect برای dark mode
// ✅ حالت تم روشن و تاریک
// ✅ Smooth animations
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../services/wallpaper_cache_service.dart';
import '../../../provider/settings_providers.dart';

/// Enhanced Chat Background با الهام از تلگرام
/// این ویجت به صورت خودکار تنظیمات بلور را از provider می‌خواند
/// و در هر دو تم روشن و تاریک (به جز تم مشکی مطلق) بلور را اعمال می‌کند
class EnhancedChatBackground extends ConsumerStatefulWidget {
  final Widget child;
  final bool enablePattern;

  /// اگر null باشد، از تنظیمات کاربر استفاده می‌شود
  /// اگر مقدار مشخص شود، آن مقدار استفاده می‌شود (برای override)
  final bool? forceEnableBlur;
  final double blurIntensity;

  const EnhancedChatBackground({
    super.key,
    required this.child,
    this.enablePattern = true,
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

    // تشخیص تم مشکی مطلق (AMOLED/Pure Black)
    // در تم مشکی مطلق، scaffoldBackgroundColor معمولاً 0xFF000000 است
    final isPitchBlack = theme.scaffoldBackgroundColor.value == 0xFF000000;

    // خواندن تنظیمات کاربر از provider
    final userSettingEnabled = ref.watch(chatBlurBackgroundProvider);

    // منطق نهایی اعمال بلور:
    // 1. اگر forceEnableBlur داده شده، از آن استفاده کن، وگرنه از تنظیمات کاربر
    // 2. حتماً نباید تم مشکی مطلق باشد (برای حفظ سیاهی مطلق در AMOLED)
    // ✅ حذف شرط isDark - بلور در هر دو تم روشن و تاریک اعمال می‌شود
    final shouldApplyBlur =
        (widget.forceEnableBlur ?? userSettingEnabled) && !isPitchBlack;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1️⃣ Base Color (فوری نمایش داده می‌شود)
        Container(
          color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFDFE5E9),
        ),

        // 2️⃣ Local Asset Wallpaper (بدون تاخیر)
        Image.asset(
          WallpaperCacheService.getLocalWallpaperAsset(isDark),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),

        // 3️⃣ Network Wallpaper با Fade Animation (مثل تلگرام)
        // حذف شد - فقط از تصویر محلی استفاده می‌کنیم

        // 4️⃣ Pattern Overlay (مثل تلگرام - نقش‌های ظریف)
        if (widget.enablePattern)
          Opacity(
            opacity: isDark ? 0.03 : 0.05,
            child: _buildDefaultPattern(isDark),
          ),

        // 5️⃣ Blur Effect (با رعایت شرط‌ها: تنظیمات + نه تم مشکی)
        // ✅ بلور در هر دو تم روشن و تاریک اعمال می‌شود
        if (shouldApplyBlur)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurIntensity,
                sigmaY: widget.blurIntensity,
              ),
              child: Container(
                // رنگ لایه رویی بلور - متناسب با تم
                color: isDark
                    ? Colors.black.withOpacity(0.1)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
          ),

        // 6️⃣ Gradient Overlay (برای خوانایی بهتر - مثل تلگرام)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.15),
                    ]
                  : [
                      Colors.white
                          .withOpacity(0.2), // کمی شفافیت بیشتر برای تم روشن
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.2),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // 7️⃣ محتوای اصلی
        widget.child,
      ],
    );
  }

  /// Pattern پیش‌فرض اگر تصویر pattern نباشد
  Widget _buildDefaultPattern(bool isDark) {
    return CustomPaint(
      painter: _TelegramPatternPainter(isDark: isDark),
      size: Size.infinite,
    );
  }
}

/// Pattern Painter (شبیه نقش‌های تلگرام)
class _TelegramPatternPainter extends CustomPainter {
  final bool isDark;

  _TelegramPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // خطوط مورب (مثل تلگرام)
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        // Pattern فقط برای پیام‌های ارسالی در تلگرام
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
      ..color = Colors.white.withOpacity(0.1)
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
