import 'dart:ui';

import 'package:flutter/material.dart';

// PERF: قبلاً این Shell یک AnimationController.repeat(reverse:true) همیشه‌روشن داشت
// (drift گرادیانِ شیشه‌ای). یعنی نوار ورودی *حتی idle* در هر فریم repaint می‌شد +
// یک BackdropFilter که هم‌زمان با باز شدن کیبورد بار GPU را بالا می‌برد.
//
// راهکار: حذف کامل AnimationController و AnimatedBuilder → StatelessWidget. گرادیان
// sheen به یک highlight ثابت تبدیل شد (مثل نوار ورودی تلگرام، بدون انیمیشن دائمی).
// BackdropFilter همان یک instance ثابت می‌ماند و از قبل با reduceEffects گارد شده
// (حین اسکرول/کیبورد حذف می‌شود).
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
    if (reduceEffects) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: background.withValues(alpha: 0.95),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      );
    }

    final effectiveBlur = blurSigma.clamp(0.0, 14.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          if (effectiveBlur > 0)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: borderColor,
                  width: 0.5,
                ),
              ),
            ),
          ),
          // Highlight ثابت (بدون انیمیشن drift) — حس شیشه‌ای بدون repaint دائمی.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.7, -1),
                    end: const Alignment(0.7, 1),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(
                        alpha: isDark ? 0.02 : 0.05,
                      ),
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
