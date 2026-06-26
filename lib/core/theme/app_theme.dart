import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:Vista/utils/vista_motion.dart';

/// ─── Spacing scale (4pt grid) ─────────────────────────────────────────────
/// مقادیر قدیمی (xs/sm/md/lg/xl/xxl/xxs) دست‌نخورده ماندند؛ فقط steps گمشده
/// (none/ms=12/ml=20/xxxl=64) اضافه شد تا scale کامل و بدون پرش شود.
class AppSpacing {
  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double ms = 12.0; // most-common gap (بود گمشده)
  static const double md = 16.0;
  static const double ml = 20.0; // (بود گمشده)
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// ─── Radius scale ─────────────────────────────────────────────────────────
/// «زبان گوشه» واحد. قبلاً ۲۰+ مقدار پراکنده و حتی تمِ خودش ناهماهنگ بود
/// (button 12 / input 14 / card 16). حالا input هم‌تراز button.
class AppRadius {
  static const double xs = 8.0;
  static const double sm = 12.0; // button + input
  static const double md = 16.0; // card
  static const double lg = 20.0; // chip + dialog
  static const double xl = 24.0; // bottom-sheet
  static const double xxl = 28.0;
  static const double pill = 999.0;
}

/// ─── Elevation / shadow tokens ────────────────────────────────────────────
/// سه پله‌ی عمقِ آماده تا ۱۶۶ سایه‌ی دستیِ پراکنده به یک مقیاس برسند.
class AppElevation {
  /// e1 — کارت‌ها
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// e2 — منو / sheet / popover
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// e3 — dialog / FAB / overlayهای شناور
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

/// ─── Glass tokens ─────────────────────────────────────────────────────────
/// مقادیر blur به‌صورت توکن تا سایت‌های BackdropFilter یک‌جا کنترل شوند.
/// ⚠️ Perf: blur پشت محتوای اسکرول‌شونده = jank رستر؛ از sigma بزرگ روی لیست‌ها پرهیز.
class AppGlass {
  static const double blurSigma = 18.0; // overlay/nav ثابت
  static const double blurSigmaLight = 10.0; // عناصر کوچک/سبک
  static const Color backgroundLight = AppColors.glassBackgroundLight;
  static const Color backgroundDark = AppColors.glassBackgroundDark;
  static const Color borderLight = AppColors.glassBorderLight;
  static const Color borderDark = AppColors.glassBorderDark;
}

/// ─── رنگ‌های اصلی برند Vista ───────────────────────────────────────────────
class AppColors {
  // Primary Brand Gradient — Indigo → Violet
  static const Color primaryStart = Color(0xFF6366F1); // Indigo 500
  static const Color primaryEnd = Color(0xFF8B5CF6); // Violet 500
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color secondary = Color(0xFF8B5CF6); // Violet 500

  // Accent — برای highlights و CTAs (نقش M3: tertiary)
  static const Color accent = Color(0xFFEC4899); // Pink 500

  // ── Glass Morphism Colors ───────────────────────────────────────────────────
  static const Color glassBackgroundLight = Color(0x99FFFFFF); // 60% white
  static const Color glassBorderLight = Color(0x4DFFFFFF); // 30% white
  static const Color glassBackgroundDark =
      Color(0xEB1C1C2E); // 92% dark indigo (Telegram X dark input)
  static const Color glassBorderDark = Color(0x33FFFFFF); // 20% white

  // ── Light Mode ──────────────────────────────────────────────────────────────
  static const Color lightBackground =
      Color(0xFFF8F9FF); // کمی آبی-بنفش، نه خالص سفید
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF3F4FF); // کارت‌های ثانویه
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF0F1117);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  // a11y: قبلاً 0xFF9CA3AF بود → ۲.۵:۱ روی پس‌زمینه (رد WCAG AA). تیره‌تر شد
  // تا برای متنِ کمکی/لیبلِ غیرفعال خواناتر شود (هنوز واضحاً سبک‌تر از secondary).
  static const Color lightTextTertiary = Color(0xFF707787);

  // ── Dark Mode ───────────────────────────────────────────────────────────────
  static const Color darkBackground =
      Color(0xFF09090F); // تقریباً سیاه با رنگ بنفش
  static const Color darkSurface = Color(0xFF13131E); // Surface اصلی
  static const Color darkSurfaceVariant = Color(0xFF1C1C2E); // کارت‌ها
  static const Color darkElevated = Color(0xFF252540); // Elevated surface
  static const Color darkBorder = Color(0xFF2A2A45); // Border ها
  static const Color darkTextPrimary =
      Color(0xFFF0F0FF); // کمی آبی‌تر از خالص سفید
  static const Color darkTextSecondary = Color(0xFF8B8BAD);
  // a11y: کمی روشن‌تر شد (بود 0xFF5A5A7A) برای خوانایی بهتر روی پس‌زمینه‌ی تیره.
  static const Color darkTextTertiary = Color(0xFF6E6E92);

  // ── Semantic (single source — جفت light/dark) ────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successDark = Color(0xFF34D399); // Emerald 400 (روی تیره)
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningDark = Color(0xFFFBBF24); // Amber 400
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorDark = Color(0xFFF87171); // Red 400
  static const Color info = Color(0xFF3B82F6); // Blue 500
  // وضعیت آنلاین — یک منبع به‌جای سبزهای پراکنده‌ی چت
  static const Color online = Color(0xFF22C55E); // Green 500
  static const Color onlineDark = Color(0xFF4ADE80); // Green 400

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryStart, primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Chat colors
  static const Color myMessageBubble = Color(0xFF6366F1); // برند
  static const Color otherMessageBubble = Color(0xFF1C1C2E); // dark surface
  static const Color myMessageBubbleLight = Color(0xFFEEF2FF);
  static const Color otherMessageBubbleLight = Color(0xFFF3F4F6);
}

/// ─── Theme اصلی Vista ────────────────────────────────────────────────────────
class AppTheme {
  // ── فونت یکپارچه برای کل اپ ──────────────────────────────────────────────
  static const String _fontFamily = 'Vazirmatn';

  // ── tracking tokens (letter-spacing) ───────────────────────────────────────
  static const double _trackTight = -0.4; // تیترهای بزرگ
  static const double _trackSnug = -0.2; // تیترهای متوسط
  static const double _trackLabel = 0.2; // لیبل‌های کوچک

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  // ── ColorScheme از seed (palette کامل M3) ───────────────────────────────────
  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: AppColors.primary, // Indigo → کل tonal palette تولید می‌شود
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary, // Violet — انتهای گرادینت برند
      tertiary: AppColors.accent, // Pink — کامل‌کننده‌ی triad
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHighest:
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      error: isDark ? AppColors.errorDark : AppColors.error,
      outline: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      onPrimary: Colors.white,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant:
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      primaryContainer:
          isDark ? const Color(0xFF2E2E6E) : AppColors.primaryLight,
    );
  }

  // ── TextTheme مشترک (tracking + leading منسجم) ──────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w800, // VazirmatnExtraBold زنده می‌شود
        letterSpacing: _trackTight,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: _trackTight,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: _trackSnug,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: _trackSnug,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.normal,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.normal,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.normal,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: _trackLabel,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w500,
        letterSpacing: _trackLabel,
        color: secondary,
      ),
    ).apply(fontFamily: _fontFamily); // قفل Vazirmatn روی همه‌ی styleها
  }

  // ── سازنده‌ی واحدِ تم (پارامتری با brightness) ───────────────────────────────
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    // برندِ متن روی سطح روشن کم‌کنتراست بود (4.47:1)؛ در light از primaryDark
    // استفاده می‌کنیم (≈5.9:1، عبور از AA). در dark خود primary کنتراست کافی دارد.
    final brandText = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final dialogBg =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final sheetBg =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final snackBg = isDark ? AppColors.darkElevated : AppColors.darkSurface;
    final chipSelected =
        isDark ? const Color(0xFF2E2E6E) : AppColors.primaryLight;
    final cardBorderWidth = isDark ? 0.8 : 1.0;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: surface,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: background,
      colorScheme: _scheme(brightness),
      fontFamily: _fontFamily,

      // ── Micro-interactions: بازخورد لمسیِ برندی (به‌جای ink خاکستریِ پیش‌فرض) ──
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.primary.withValues(alpha: 0.10),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      hoverColor: AppColors.primary.withValues(alpha: 0.04),
      focusColor: AppColors.primary.withValues(alpha: 0.08),

      textTheme: _textTheme(textPrimary, textSecondary),

      appBarTheme: AppBarTheme(
        systemOverlayStyle: overlayStyle,
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: _trackSnug,
          color: textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border, width: cardBorderWidth),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textTertiary,
        selectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: TextStyle(color: textTertiary, fontFamily: _fontFamily),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
              color: isDark ? AppColors.errorDark : AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryDark, // a11y: متن سفید ~5.9:1
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          animationDuration: VistaMotion.durationFast, // 150ms — توکن موجود
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandText,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          animationDuration: VistaMotion.durationFast,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandText,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
          animationDuration: VistaMotion.durationFast,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: chipSelected,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          height: 1.5,
          color: textSecondary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        modalBackgroundColor: sheetBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),

      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.normal,
          fontSize: 15,
        ),
      ),

      iconTheme: IconThemeData(color: textPrimary, size: 24),

      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      ),
    );
  }
}
