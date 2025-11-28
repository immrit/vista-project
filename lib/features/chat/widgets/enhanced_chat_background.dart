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
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/wallpaper_cache_service.dart';

/// Enhanced Chat Background با الهام از تلگرام
class EnhancedChatBackground extends StatefulWidget {
  final Widget child;
  final bool enablePattern;
  final bool enableBlur;
  final double blurIntensity;

  const EnhancedChatBackground({
    super.key,
    required this.child,
    this.enablePattern = true,
    this.enableBlur = false,
    this.blurIntensity = 3.0,
  });

  @override
  State<EnhancedChatBackground> createState() => _EnhancedChatBackgroundState();
}

class _EnhancedChatBackgroundState extends State<EnhancedChatBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _wallpaperLoaded = false;
  String? _wallpaperUrl;
  bool _hasLoadedWallpaper = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // بارگذاری والپیپر فقط یکبار بعد از آماده شدن context
    if (!_hasLoadedWallpaper) {
      _hasLoadedWallpaper = true;
      _loadWallpaper();
    }
  }

  Future<void> _loadWallpaper() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = WallpaperCacheService.getWallpaperUrl(isDark);

    if (mounted) {
      setState(() {
        _wallpaperUrl = url;
        _wallpaperLoaded = true;
      });

      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        if (_wallpaperLoaded && _wallpaperUrl != null)
          FadeTransition(
            opacity: _fadeAnimation,
            child: CachedNetworkImage(
              imageUrl: _wallpaperUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // 4️⃣ Pattern Overlay (مثل تلگرام - نقش‌های ظریف)
        if (widget.enablePattern)
          Opacity(
            opacity: isDark ? 0.03 : 0.05,
            child: _buildDefaultPattern(isDark),
          ),

        // 5️⃣ Blur Effect (فقط در dark mode مثل تلگرام)
        if (widget.enableBlur && isDark)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurIntensity,
                sigmaY: widget.blurIntensity,
              ),
              child: Container(
                color: Colors.black.withOpacity(0.1),
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
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.1),
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
