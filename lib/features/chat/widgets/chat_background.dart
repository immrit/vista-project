// lib/features/chat/widgets/chat_background.dart
//
// بک‌گراند چت با والپیپر
//

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/wallpaper_cache_service.dart';
import '../theme/chat_theme.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;
  final bool useWallpaper;
  
  const ChatBackground({
    super.key,
    required this.child,
    this.useWallpaper = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final isDark = theme.isDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // لایه 1: رنگ پس‌زمینه
        Container(color: theme.backgroundColor),
        
        // لایه 2: پترن یا والپیپر
        if (useWallpaper)
          _buildWallpaper(isDark)
        else
          _buildPattern(theme),
        
        // لایه 3: Gradient overlay
        _buildGradientOverlay(theme),
        
        // لایه 4: محتوا
        child,
      ],
    );
  }

  Widget _buildWallpaper(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Local asset as immediate fallback
        Image.asset(
          WallpaperCacheService.getLocalWallpaperAsset(isDark),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackPattern(isDark);
          },
        ),
        
        // Network wallpaper with smooth transition
        FutureBuilder<String>(
          future: Future.value(
            WallpaperCacheService.getWallpaperUrl(isDark),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return CachedNetworkImage(
                imageUrl: snapshot.data!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 300),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildPattern(ChatTheme theme) {
    return CustomPaint(
      painter: ChatPatternPainter(
        color: theme.dividerColor.withOpacity(0.3),
        isDark: theme.isDark,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildFallbackPattern(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFE2E8F0),
                ],
        ),
      ),
      child: CustomPaint(
        painter: ChatPatternPainter(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          isDark: isDark,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildGradientOverlay(ChatTheme theme) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.backgroundColor.withOpacity(0.0),
              theme.backgroundColor.withOpacity(0.1),
            ],
            stops: const [0.8, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Painter برای پترن پس‌زمینه چت
class ChatPatternPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  
  ChatPatternPainter({
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 40.0;
    const dotRadius = 2.0;

    // الگوی نقطه‌ای ساده
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // جابجایی سطرهای فرد
        final offset = (y ~/ spacing) % 2 == 0 ? 0.0 : spacing / 2;
        canvas.drawCircle(
          Offset(x + offset, y),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChatPatternPainter oldDelegate) {
    return color != oldDelegate.color || isDark != oldDelegate.isDark;
  }
}

/// بک‌گراند ساده بدون والپیپر
class SimpleChatBackground extends StatelessWidget {
  final Widget child;
  
  const SimpleChatBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.isDark
              ? [
                  const Color(0xFF1A1F2E),
                  const Color(0xFF0D1117),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFEFF6FF),
                ],
        ),
      ),
      child: CustomPaint(
        painter: ChatPatternPainter(
          color: theme.dividerColor.withOpacity(0.15),
          isDark: theme.isDark,
        ),
        child: child,
      ),
    );
  }
}

