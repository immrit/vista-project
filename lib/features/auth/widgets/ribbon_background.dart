import 'dart:ui';
import 'package:flutter/material.dart';

class RibbonBackground extends StatelessWidget {
  const RibbonBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define palette based on theme (Monochrome but with depth)
    final bgColors = isDark
        ? [
            const Color(0xFF000000), // Base
            const Color(0xFF1A1A1A), // Spot 1
            const Color(0xFF121212), // Spot 2
          ]
        : [
            const Color(0xFFFFFFFF), // Base
            const Color(0xFFF5F5F7), // Spot 1
            const Color(0xFFEBEBF0), // Spot 2
          ];

    return Stack(
      children: [
        // Base Layer
        Container(color: bgColors[0]),

        // Orb 1 - Top Left
        Positioned(
          top: -100,
          left: -100,
          child: _BlurredOrb(
            color: bgColors[1],
            size: 400,
          ),
        ),

        // Orb 2 - Bottom Right
        Positioned(
          bottom: -50,
          right: -100,
          child: _BlurredOrb(
            color: bgColors[2],
            size: 500,
          ),
        ),

        // Orb 3 - Center Right-ish (Accent)
        Positioned(
          top: 200,
          right: -50,
          child: _BlurredOrb(
            color: isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE),
            size: 300,
          ),
        ),

        // Subtle Pattern Overlay (Optional - adds texture)
        // Using a CustomPainter for a very subtle grid or noise could go here
        // For now, let's stick to the soft gradient which is very premium
      ],
    );
  }
}

class _BlurredOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurredOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
