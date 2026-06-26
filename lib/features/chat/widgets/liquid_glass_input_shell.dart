import 'package:flutter/material.dart';

// PERF history:
//  1) Originally an AnimationController.repeat(reverse:true) drove a "glass drift"
//     gradient → input bar repainted every frame even idle. Removed → Stateless.
//  2) A BackdropFilter remained for the frosted look. BackdropFilter re-applies its
//     blur on EVERY composited frame (it can't be cached), and the app-bar online
//     pulse (_pulseController.repeat()) forces a frame every vsync while the peer is
//     online — so the blur ran ~60×/sec forever. DevTools showed this as the chat's
//     steady ~24ms raster cost and the "stiff entry" culprit (all jank on the GPU
//     thread, build was ~1.5ms). Removed entirely: a near-opaque solid bar + a
//     static sheen is visually almost identical and essentially free to composite.
class LiquidGlassInputShell extends StatelessWidget {
  final Widget child;
  final bool reduceEffects;
  final bool isDark;
  final double blurSigma;
  final Color background;
  final Color borderColor;

  const LiquidGlassInputShell({
    super.key,
    required this.child,
    required this.reduceEffects,
    required this.isDark,
    required this.blurSigma,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Near-opaque fill replaces the BackdropFilter: without real-time blur a
          // translucent bar would show sharp messages through it, so keep alpha high.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: background.withValues(alpha: 0.95),
                // Dark mode: directional border — brighter top edge gives depth,
                // faint sides/bottom avoid the harsh white outline.
                border: isDark
                    ? Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 0.5,
                        ),
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 0.5,
                        ),
                        right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 0.5,
                        ),
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.04),
                          width: 0.5,
                        ),
                      )
                    : Border.all(
                        color: borderColor.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
              ),
            ),
          ),
          // Static glass sheen (no animation, no blur) — cheap, keeps the look.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.7, -1),
                    end: const Alignment(0.7, 1),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: isDark ? 0.02 : 0.05),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.2, 0.5, 0.8],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
