import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:Vista/core/theme/app_theme.dart';

// ─── Vista Page Transition ────────────────────────────────────────────────────
// PERF: قبلاً VistaPageTransitionsBuilder یک FadeTransition روی کل صفحه‌ی غیرشفاف
// می‌گذاشت → Flutter مجبور به saveLayer (offscreen compositing) کل route در هر فریمِ
// گذار می‌شد = گران‌ترین کار GPU و علت اصلی «روان‌نبودن» انتقال.
//
// راهکار: استفاده از CupertinoPageTransitionsBuilder روی همه‌ی پلتفرم‌ها.
//  - بدون fade → بدون saveLayer (slide خالص، ارزان روی GPU).
//  - parallax صفحه‌ی قبل + سایه‌ی لبه (حس عمق مثل تلگرام).
//  - back-swipe از لبه (مثل تلگرام/iOS) — فقط از ~۲۰px لبه فعال می‌شود،
//    با swipe-to-reply وسط صفحه تداخل ندارد.
//  - Directionality-aware → در RTL خودکار از سمت درست وارد/خارج می‌شود.
const _vistaTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);

// ─── VistaThemes ─────────────────────────────────────────────────────────────
/// نقطه‌ی ورود اصلی تم — app_runner از اینجا استفاده می‌کند
class VistaThemes {
  static const String fontFamily = 'Vazirmatn'; // ✅ یکپارچه‌سازی فونت

  // ── رنگ‌های سازگار با قدیم ──────────────────────────────────────────────
  static const Color lightPrimary = AppColors.primary;
  static const Color darkPrimary = AppColors.primary;
  static const Color lightBg = AppColors.lightBackground;
  static const Color darkBg = AppColors.darkBackground;
  static const Color darkSurface = AppColors.darkSurface;

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
  static const Color violetPrimary = AppColors.primary;
  static const Color violetSecondary = AppColors.primaryEnd;
  static const Color textSecondaryLight = AppColors.lightTextSecondary;
  static const Color textSecondaryDark = AppColors.darkTextSecondary;
  static const Color white = Colors.white;
  static const Color accent = AppColors.accent;
}
