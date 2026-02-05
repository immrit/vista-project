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

  /// شعاع گوشه‌های حباب مثل تلگرام (گوشه‌های ادغام‌شده تیزتر)
  BorderRadius bubbleBorderRadius({
    required bool isMe,
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final double baseRadius = bubbleRadius;
    final double mergedRadius = bubbleMergedRadius.clamp(0.0, baseRadius);
    final Radius r = Radius.circular(baseRadius);
    final Radius mr = Radius.circular(mergedRadius);
    final bool topMerged = !isFirstInGroup;
    final bool bottomMerged = !isLastInGroup;

    if (isMe) {
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
    final primary = primaryColor ?? const Color(0xFF6366F1); // Indigo

    return ChatTheme(
      isDark: false,
      backgroundColor: const Color(0xFFF8FAFC),
      appBarColor: Colors.white.withOpacity(0.95),
      textColor: const Color(0xFF1E293B),
      secondaryTextColor: const Color(0xFF64748B),
      dividerColor: const Color(0xFFE2E8F0),

      // حباب پیام من - گرادینت زیبا
      myBubbleColor: const Color(0xFFF5F5F5),
      myBubbleGradient: null, // غیرفعال کردن گرادینت برای رنگ یکنواخت
      myBubbleTextColor:
          Colors.black87, // تغییر رنگ متن به مشکی برای خوانایی بهتر

      // حباب پیام دیگران
      otherBubbleColor: Colors.white,
      otherBubbleTextColor: const Color(0xFF1E293B),

      // وضعیت‌ها
      onlineColor: const Color(0xFF22C55E),
      offlineColor: const Color(0xFF94A3B8),
      typingColor: const Color(0xFF3B82F6),
      pendingColor: const Color(0xFFF59E0B),
      sentColor: const Color(0xFF22C55E),
      errorColor: const Color(0xFFEF4444),

      // Input
      inputBackgroundColor: Colors.white,
      inputBorderColor: const Color(0xFFE2E8F0),
      inputHintColor: const Color(0xFF94A3B8),
      sendButtonColor: primary,
      iconColor: const Color(0xFF64748B),

      // سایه‌ها
      myBubbleShadow: BoxShadow(
        color: primary.withOpacity(0.08),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      otherBubbleShadow: BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      inputShadow: BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, -2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 Factory - تم تاریک
  // ═══════════════════════════════════════════════════════════════════════════

  factory ChatTheme.dark({Color? primaryColor}) {
    final primary = primaryColor ?? const Color(0xFF818CF8); // Lighter Indigo

    // ✅ در تم تاریک، اگر رنگ primary سفید یا خیلی روشن است، از آبی استاندارد استفاده می‌کنیم
    final sendButtonColor = (primary.computeLuminance() > 0.8)
        ? const Color(0xFF3390EC) // آبی استاندارد تلگرام
        : primary;

    return ChatTheme(
      isDark: true,
      backgroundColor: const Color(0xFF0F172A),
      appBarColor: const Color(0xFF1E293B).withOpacity(0.95),
      textColor: const Color(0xFFF1F5F9),
      secondaryTextColor: const Color(0xFF94A3B8),
      dividerColor: const Color(0xFF334155),

      // حباب پیام من
      myBubbleColor: const Color(0xFF1E1E1E),
      myBubbleGradient: null, // غیرفعال کردن gradient
      myBubbleTextColor: Colors.white,

      // حباب پیام دیگران
      otherBubbleColor: const Color(0xFF1E1E1E),
      otherBubbleTextColor: Colors.white,

      // وضعیت‌ها
      onlineColor: const Color(0xFF4ADE80),
      offlineColor: const Color(0xFF64748B),
      typingColor: const Color(0xFF60A5FA),
      pendingColor: const Color(0xFFFBBF24),
      sentColor: const Color(0xFF4ADE80),
      errorColor: const Color(0xFFF87171),

      // Input
      inputBackgroundColor: const Color(0xFF1E293B),
      inputBorderColor: const Color(0xFF334155),
      inputHintColor: const Color(0xFF64748B),
      sendButtonColor: sendButtonColor, // ✅ استفاده از رنگ اصلاح شده
      iconColor: const Color(0xFF94A3B8),

      // سایه‌ها
      myBubbleShadow: BoxShadow(
        color: primary.withOpacity(0.1),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      otherBubbleShadow: BoxShadow(
        color: Colors.black.withOpacity(0.15),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      inputShadow: BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 12,
        offset: const Offset(0, -2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 Factory - از تم Flutter
  // ═══════════════════════════════════════════════════════════════════════════

  factory ChatTheme.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    if (isDark) {
      return ChatTheme.dark(primaryColor: primaryColor);
    } else {
      return ChatTheme.light(primaryColor: primaryColor);
    }
  }
}

/// Extension برای دسترسی راحت به تم چت
extension ChatThemeExtension on BuildContext {
  /// دریافت تم چت از تم فعلی
  ChatTheme get chatTheme => ChatTheme.fromTheme(Theme.of(this));

  /// آیا دارک مود هست؟
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
