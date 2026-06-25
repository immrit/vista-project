// lib/features/chat/theme/chat_theme.dart
//
// سیستم تم چت - هماهنگ با تم اصلی برنامه
//
// ویژگی‌ها:
// ✅ هماهنگی کامل با دارک/لایت مود
// ✅ رنگ‌های سفارشی برای حباب‌های پیام
// ✅ گرادینت‌ها و shadow های حرفه‌ای
// ✅ انیمیشن‌های روان
//

import 'package:flutter/material.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// تم چت
class ChatTheme {
  final bool isDark;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 رنگ‌های اصلی
  // ═══════════════════════════════════════════════════════════════════════════

  /// رنگ پس‌زمینه صفحه
  final Color backgroundColor;

  /// رنگ AppBar
  final Color appBarColor;

  /// رنگ متن اصلی
  final Color textColor;

  /// رنگ متن ثانویه
  final Color secondaryTextColor;

  /// رنگ تقسیم‌کننده
  final Color dividerColor;

  // ═══════════════════════════════════════════════════════════════════════════
  // 💬 رنگ‌های حباب پیام
  // ═══════════════════════════════════════════════════════════════════════════

  /// رنگ حباب پیام من
  final Color myBubbleColor;

  /// گرادینت حباب پیام من
  final Gradient? myBubbleGradient;

  /// رنگ متن پیام من
  final Color myBubbleTextColor;

  /// رنگ حباب پیام دیگران
  final Color otherBubbleColor;

  /// رنگ متن پیام دیگران
  final Color otherBubbleTextColor;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 رنگ‌های وضعیت
  // ═══════════════════════════════════════════════════════════════════════════

  /// رنگ آنلاین
  final Color onlineColor;

  /// رنگ آفلاین
  final Color offlineColor;

  /// رنگ در حال تایپ
  final Color typingColor;

  /// رنگ pending
  final Color pendingColor;

  /// رنگ ارسال شده
  final Color sentColor;

  /// رنگ خطا
  final Color errorColor;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📝 رنگ‌های Input
  // ═══════════════════════════════════════════════════════════════════════════

  /// رنگ پس‌زمینه input
  final Color inputBackgroundColor;

  /// رنگ border input
  final Color inputBorderColor;

  /// رنگ hint text
  final Color inputHintColor;

  /// رنگ دکمه ارسال
  final Color sendButtonColor;

  /// رنگ آیکون‌ها
  final Color iconColor;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 Shadow ها
  // ═══════════════════════════════════════════════════════════════════════════

  /// سایه حباب پیام من
  final BoxShadow? myBubbleShadow;

  /// سایه حباب پیام دیگران
  final BoxShadow? otherBubbleShadow;

  /// سایه input
  final BoxShadow? inputShadow;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📐 فواصل و اندازه‌ها
  // ═══════════════════════════════════════════════════════════════════════════

  /// شعاع گوشه حباب
  final double bubbleRadius;

  /// شعاع گوشه‌ی ادغام‌شده (برای پیام‌های گروه‌بندی شده)
  final double bubbleMergedRadius;

  /// پدینگ داخلی حباب
  final EdgeInsets bubblePadding;

  /// فاصله بین پیام‌ها
  final double messageSpacing;

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏱️ مدت زمان انیمیشن‌ها
  // ═══════════════════════════════════════════════════════════════════════════

  /// مدت انیمیشن ظاهر شدن پیام
  final Duration messageAppearDuration;

  /// مدت انیمیشن تایپینگ
  final Duration typingAnimationDuration;

  /// مدت انیمیشن فید
  final Duration fadeDuration;

  const ChatTheme({
    required this.isDark,
    required this.backgroundColor,
    required this.appBarColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    required this.myBubbleColor,
    this.myBubbleGradient,
    required this.myBubbleTextColor,
    required this.otherBubbleColor,
    required this.otherBubbleTextColor,
    required this.onlineColor,
    required this.offlineColor,
    required this.typingColor,
    required this.pendingColor,
    required this.sentColor,
    required this.errorColor,
    required this.inputBackgroundColor,
    required this.inputBorderColor,
    required this.inputHintColor,
    required this.sendButtonColor,
    required this.iconColor,
    this.myBubbleShadow,
    this.otherBubbleShadow,
    this.inputShadow,
    this.bubbleRadius = 18,
    this.bubbleMergedRadius = 6,
    this.bubblePadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.messageSpacing = 2,
    this.messageAppearDuration = const Duration(milliseconds: 300),
    this.typingAnimationDuration = const Duration(milliseconds: 600),
    this.fadeDuration = const Duration(milliseconds: 200),
  });

  /// شعاع گوشه‌های حباب مثل ویستا (گوشه‌های ادغام‌شده تیزتر)
  BorderRadius bubbleBorderRadius({
    required bool isMe,
    required bool isFirstInGroup,
    required bool isLastInGroup,
    required TextDirection textDirection,
  }) {
    final double baseRadius = bubbleRadius;
    final double mergedRadius = bubbleMergedRadius.clamp(0.0, baseRadius);
    final Radius r = Radius.circular(baseRadius);
    final Radius mr = Radius.circular(mergedRadius);
    
    // In reverse ListView (index 0 = newest = bottom):
    // isFirstInGroup = true for the OLDEST message in group (visually at the TOP, no same-sender above).
    // isLastInGroup = true for the NEWEST message in group (visually at the BOTTOM, no same-sender below).

    final bool isVisuallyTop = isFirstInGroup && !isLastInGroup;
    final bool isVisuallyBottom = isLastInGroup; // single messages (both true) also get bottom style

    // Based on Telegram X design & user feedback:
    // - Visually Top: Top edge is fully rounded, bottom is merged.
    // - Visually Bottom: Top edge is merged, bottom is fully rounded.
    // - Middle & Single messages: Both top and bottom are merged (less rounded on the wall side).
    final bool topMerged = !isVisuallyTop;
    final bool bottomMerged = !isVisuallyBottom;
    
    final bool bubbleOnRight =
        textDirection == TextDirection.ltr ? isMe : !isMe;

    if (bubbleOnRight) {
      return BorderRadius.only(
        topLeft: r,
        topRight: topMerged ? mr : r,
        bottomLeft: r,
        bottomRight: bottomMerged ? mr : r,
      );
    } else {
      return BorderRadius.only(
        topLeft: topMerged ? mr : r,
        topRight: r,
        bottomLeft: bottomMerged ? mr : r,
        bottomRight: r,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 Factory - تم روشن
  // ═══════════════════════════════════════════════════════════════════════════

  factory ChatTheme.light({Color? primaryColor}) {
    // Sync with Vista Brand (AppColors)
    final accent = AppColors.primary; // Indigo
    final gradientEnd = AppColors.secondary; // Violet

    return ChatTheme(
      isDark: false,
      backgroundColor: const Color(0xFFFFFFFF),
      appBarColor: Colors.white.withValues(alpha: 0.95),
      textColor: const Color(0xFF000000),
      secondaryTextColor: const Color(0xFF64748B),
      dividerColor: const Color(0xFFE5E5E5),

      // حباب پیام من - Vista Brand Gradient
      myBubbleColor: accent,
      myBubbleGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, gradientEnd],
      ),
      myBubbleTextColor: Colors.white,

      // حباب پیام دیگران - سفید خالص با سایه ملایم برای تمایز بهتر
      otherBubbleColor: const Color(
          0xFFF1F5F9), // Slight gray for better contrast against white background
      otherBubbleTextColor: Colors.black,

      // وضعیت‌ها
      onlineColor: const Color(0xFF22C55E),
      offlineColor: const Color(0xFF94A3B8),
      typingColor: accent,
      pendingColor: const Color(0xFFF59E0B),
      sentColor: const Color(0xFF22C55E),
      errorColor: const Color(0xFFEF4444),

      // Input
      inputBackgroundColor: AppColors.glassBackgroundLight, // Glass effect
      inputBorderColor: AppColors.glassBorderLight,
      inputHintColor: const Color(0xFF94A3B8),
      sendButtonColor: accent,
      iconColor: const Color(0xFF64748B), // Slate 500

      // سایه‌ها
      myBubbleShadow: BoxShadow(
        color: accent.withValues(alpha: 0.15),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      // UX: 0.03 عملاً نامرئی بود؛ حباب دیگران روی پس‌زمینهٔ سفید «شناور» نمی‌شد.
      otherBubbleShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.07),
        blurRadius: 5,
        offset: const Offset(0, 1),
      ),
      inputShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, -2),
      ),
      messageAppearDuration: const Duration(milliseconds: 240),
      typingAnimationDuration: const Duration(milliseconds: 480),
      fadeDuration: const Duration(milliseconds: 160),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 Factory - تم تاریک
  // ═══════════════════════════════════════════════════════════════════════════

  factory ChatTheme.dark({Color? primaryColor}) {
    // Sync with Vista Brand (AppColors)
    final accent = AppColors.primary; // Indigo
    final gradientEnd = AppColors.secondary; // Violet

    return ChatTheme(
      isDark: true,
      // UX: lifted off pure-black. #000 + #1E1E1E gave a flat, low-contrast
      // "empty OLED" look; a slightly raised cool-charcoal background reads as
      // depth and lets other-bubbles separate cleanly.
      backgroundColor: const Color(0xFF0A0E13),
      appBarColor: const Color(0xFF0A0E13).withValues(alpha: 0.95),
      textColor: const Color(0xFFF1F5F9),
      secondaryTextColor: const Color(0xFF94A3B8),
      dividerColor: const Color(0xFF1E2630),

      // حباب پیام من - Vista Brand Gradient
      myBubbleColor: accent,
      myBubbleGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, gradientEnd],
      ),
      myBubbleTextColor: Colors.white,

      // حباب پیام دیگران - راهِ روشن‌تر/سردتر برای کنتراست مشخص با پس‌زمینه
      otherBubbleColor: const Color(0xFF1E2630),
      otherBubbleTextColor: Colors.white,

      // وضعیت‌ها
      onlineColor: const Color(0xFF4ADE80),
      offlineColor: const Color(0xFF64748B),
      typingColor: accent,
      pendingColor: const Color(0xFFFBBF24),
      sentColor: const Color(0xFF4ADE80),
      errorColor: const Color(0xFFF87171),

      // Input
      inputBackgroundColor: AppColors.glassBackgroundDark, // Glass effect
      inputBorderColor: AppColors.glassBorderDark,
      inputHintColor: const Color(0xFF64748B),
      sendButtonColor: accent,
      iconColor: const Color(0xFF94A3B8), // Slate 400

      // سایه‌ها — UX: سایهٔ سفیدِ قبلی روی حباب «من» هاله‌ی نوریِ غیرطبیعی می‌ساخت.
      // سایهٔ تیرهٔ ملایم طبیعی‌تر است و حباب را روی پس‌زمینه می‌نشاند.
      myBubbleShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
      otherBubbleShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
      inputShadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 12,
        offset: const Offset(0, -2),
      ),
      messageAppearDuration: const Duration(milliseconds: 240),
      typingAnimationDuration: const Duration(milliseconds: 480),
      fadeDuration: const Duration(milliseconds: 160),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 Factory - از تم Flutter
  // ═══════════════════════════════════════════════════════════════════════════

  // PERF: cache the two variants. fromTheme() is reached via the
  // `context.chatTheme` extension from every bubble/divider/row, many times per
  // frame during scroll. The factories ignore primaryColor (they pull from
  // AppColors directly), so the result is constant per brightness — building a
  // fresh object (≈25 Colors + a LinearGradient + 3 BoxShadows) each call was
  // pure GC churn. Now it's a map lookup.
  static ChatTheme? _cachedDark;
  static ChatTheme? _cachedLight;

  factory ChatTheme.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    if (isDark) {
      return _cachedDark ??= ChatTheme.dark();
    }
    return _cachedLight ??= ChatTheme.light();
  }
}

/// Extension برای دسترسی راحت به تم چت
extension ChatThemeExtension on BuildContext {
  /// دریافت تم چت از تم فعلی
  ChatTheme get chatTheme => ChatTheme.fromTheme(Theme.of(this));

  /// آیا دارک مود هست؟
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
