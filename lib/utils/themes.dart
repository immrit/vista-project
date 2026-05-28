import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:Vista/core/theme/app_theme.dart';

// ─── Vista Page Transition ────────────────────────────────────────────────────
/// Smooth slide-from-right transition (مناسب RTL: از چپ می‌آید)
class VistaPageTransitionsBuilder extends PageTransitionsBuilder {
  const VistaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Fade + Slide (مشابه iOS ولی سریع‌تر)
    final tween = Tween<Offset>(
      begin: const Offset(0.08, 0), // ورود از راست (کوچک)
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));

    final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.0, 0.6)));

    final secondaryTween = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.04, 0), // صفحه قبل کمی به چپ می‌رود
    ).chain(CurveTween(curve: Curves.easeInCubic));

    return SlideTransition(
      position: secondaryAnimation.drive(secondaryTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      ),
    );
  }
}

const _vistaTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: VistaPageTransitionsBuilder(),
    TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: VistaPageTransitionsBuilder(),
    TargetPlatform.linux:   VistaPageTransitionsBuilder(),
    TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
  },
);

// ─── VistaThemes ─────────────────────────────────────────────────────────────
/// نقطه‌ی ورود اصلی تم — app_runner از اینجا استفاده می‌کند
class VistaThemes {
  static const String fontFamily = 'Vazirmatn'; // ✅ یکپارچه‌سازی فونت

  // ── رنگ‌های سازگار با قدیم ──────────────────────────────────────────────
  static const Color lightPrimary = AppColors.primary;
  static const Color darkPrimary  = AppColors.primary;
  static const Color lightBg      = AppColors.lightBackground;
  static const Color darkBg       = AppColors.darkBackground;
  static const Color darkSurface  = AppColors.darkSurface;

  // ── Light Theme ──────────────────────────────────────────────────────────
  static final ThemeData lightTheme = AppTheme.lightTheme.copyWith(
    pageTransitionsTheme: _vistaTransitions,
  );

  // ── Dark Theme ───────────────────────────────────────────────────────────
  static final ThemeData darkTheme = AppTheme.darkTheme.copyWith(
    pageTransitionsTheme: _vistaTransitions,
  );
}

// ─── VistaColors ─────────────────────────────────────────────────────────────
/// رنگ‌های کمکی برای سازگاری با کدهای قدیمی
class VistaColors {
  static const Color violetPrimary   = AppColors.primary;
  static const Color violetSecondary = AppColors.primaryEnd;
  static const Color textSecondaryLight = AppColors.lightTextSecondary;
  static const Color textSecondaryDark  = AppColors.darkTextSecondary;
  static const Color white           = Colors.white;
  static const Color accent          = AppColors.accent;
}
