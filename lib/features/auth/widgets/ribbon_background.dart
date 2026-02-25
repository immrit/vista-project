import 'dart:ui';
import 'package:flutter/material.dart';

class RibbonBackground extends StatelessWidget {
  const RibbonBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceEffects =
        MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final orb1Size = (shortest * 0.9).clamp(260.0, 420.0);
        final orb2Size = (shortest * 1.1).clamp(320.0, 540.0);
        final orb3Size = (shortest * 0.7).clamp(220.0, 360.0);

        return RepaintBoundary(
          child: Stack(
            children: [
              // Base Layer
              Container(color: bgColors[0]),

              if (!reduceEffects)
                // Orb 1 - Top Left
                Positioned(
                  top: -orb1Size * 0.25,
                  left: -orb1Size * 0.25,
                  child: _BlurredOrb(
                    color: bgColors[1],
                    size: orb1Size,
                  ),
                ),

              if (!reduceEffects)
                // Orb 2 - Bottom Right
                Positioned(
                  bottom: -orb2Size * 0.2,
                  right: -orb2Size * 0.25,
                  child: _BlurredOrb(
                    color: bgColors[2],
                    size: orb2Size,
                  ),
                ),

              if (!reduceEffects)
                // Orb 3 - Center Right-ish (Accent)
                Positioned(
                  top: shortest * 0.35,
                  right: -orb3Size * 0.2,
                  child: _BlurredOrb(
                    color:
                        isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE),
                    size: orb3Size,
                  ),
                ),

              // Subtle Pattern Overlay (Optional - adds texture)
              // Using a CustomPainter for a very subtle grid or noise could go here
              // For now, let's stick to the soft gradient which is very premium
            ],
          ),
        );
      },
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
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
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
