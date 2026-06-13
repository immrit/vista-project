import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

/// استیکر هشتگ با سه استایل مختلف (مشابه ویستا)
class HashtagStickerWidget extends StatelessWidget {
  final StoryElement element;
  final bool isEditable;

  const HashtagStickerWidget({
    super.key,
    required this.element,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    final data = element.interactionData ?? {};
    String hashtag = (data['hashtag'] ?? element.text).toString();

    // اطمینان از شروع با #
    if (!hashtag.startsWith('#')) hashtag = '#$hashtag';

    final int style = element.resolvedStyleIndex % 3;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _buildStyle(style, hashtag),
    );
  }

  Widget _buildStyle(int style, String hashtag) {
    final Key key = ValueKey<int>(style);
    switch (style) {
      case 1: // White Background + Rainbow Gradient Text
        return _buildWhiteRainbowStyle(key, hashtag);
      case 2: // Glass Effect
        return _buildGlassStyle(key, hashtag);
      case 0: // Social Gradient Background
      default:
        return _buildGradientStyle(key, hashtag);
    }
  }

  /// استایل ۰: پس‌زمینه گرادیان نارنجی-بنفش (ویستای)
  Widget _buildGradientStyle(Key key, String hashtag) {
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF58529), // Orange
            Color(0xFFDD2A7B), // Pink
            Color(0xFF8134AF), // Purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDD2A7B).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        hashtag,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          fontFamily: 'Vazir',
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// استایل ۱: پس‌زمینه سفید + متن رنگین‌کمانی (ShaderMask)
  Widget _buildWhiteRainbowStyle(Key key, String hashtag) {
    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [
              Color(0xFFFF0000), // Red
              Color(0xFFFF7F00), // Orange
              Color(0xFFFFFF00), // Yellow
              Color(0xFF00FF00), // Green
              Color(0xFF0000FF), // Blue
              Color(0xFF4B0082), // Indigo
              Color(0xFF9400D3), // Violet
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        child: Text(
          hashtag,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            fontFamily: 'Vazir',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// استایل ۲: شیشه‌ای (Glass Effect) با BackdropFilter
  Widget _buildGlassStyle(Key key, String hashtag) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            hashtag,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              fontFamily: 'Vazir',
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
