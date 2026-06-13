// Trimmed duplicate content removed. File contains a single implementation of the ModernX date utilities (Persian+English).
// lib/utils/modern_x_date_utils.dart
//
// 🎯 پیاده‌سازی دقیق سیستم تاریخ Modern-X
// مرجع: https://github.com/TGX-Android/Modern-X
//
// ویژگی‌ها:
// ✅ نمایش دقیق زمان (ساعت:دقیقه)
// ✅ نمایش تاریخ با فرمت‌های مختلف
// ✅ تبدیل خودکار به تاریخ نسبی
// ✅ پشتیبانی کامل از فارسی و انگلیسی
// ✅ Floating Date Header مثل Modern-X

import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// نوع فرمت تاریخ
enum ModernXDateFormat {
  /// فقط زمان: "14:30"
  timeOnly,

  /// امروز + زمان: "Today at 14:30"
  todayWithTime,

  /// دیروز + زمان: "Yesterday at 14:30"
  yesterdayWithTime,

  /// روز هفته + زمان: "Monday at 14:30"
  weekdayWithTime,

  /// تاریخ کوتاه + زمان: "17 May at 14:30"
  shortDateWithTime,

  /// تاریخ کامل + زمان: "17 May 2024 at 14:30"
  fullDateWithTime,

  /// فقط تاریخ کوتاه: "17 May"
  shortDateOnly,

  /// فقط تاریخ کامل: "17 May 2024"
  fullDateOnly,

  /// فقط ماه و سال: "May 2024"
  monthYear,
}

/// کلاس اصلی برای مدیریت تاریخ و زمان مثل Modern-X
class ModernXDateUtils {
  ModernXDateUtils._();

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌐 تنظیمات زبان
  // ═══════════════════════════════════════════════════════════════════════════

  static bool _usePersian = true;
  static bool _use24HourFormat = true;

  static void setLanguage({required bool usePersian}) {
    _usePersian = usePersian;
  }

  static void set24HourFormat({required bool use24Hour}) {
    _use24HourFormat = use24Hour;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏰ نمایش زمان (Time Display)
  // ═══════════════════════════════════════════════════════════════════════════

  /// نمایش زمان دقیق (ساعت:دقیقه)
  /// مثل Modern-X: "14:30" یا "2:30 PM"
  static String formatTime(DateTime date) {
    if (_use24HourFormat) {
      return DateFormat('HH:mm').format(date);
    } else {
      return DateFormat('h:mm a').format(date);
    }
  }

  /// نمایش زمان با ثانیه
  /// مثل: "14:30:45"
  static String formatTimeWithSeconds(DateTime date) {
    if (_use24HourFormat) {
      return DateFormat('HH:mm:ss').format(date);
    } else {
      return DateFormat('h:mm:ss a').format(date);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📅 نمایش تاریخ (Date Display)
  // ═══════════════════════════════════════════════════════════════════════════

  /// نمایش تاریخ کوتاه
  /// مثل: "17 May" (انگلیسی) یا "۱۷ اردیبهشت" (فارسی)
  static String formatShortDate(DateTime date) {
    if (_usePersian) {
      return _formatPersianShortDate(date);
    } else {
      return DateFormat('d MMM').format(date);
    }
  }

  /// نمایش تاریخ کامل با سال
  /// مثل: "17 May 2024" (انگلیسی) یا "۱۷ اردیبهشت ۱۴۰۳" (فارسی)
  static String formatFullDate(DateTime date) {
    if (_usePersian) {
      return _formatPersianFullDate(date);
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  /// نمایش فقط ماه و سال
  /// مثل: "May 2024" (انگلیسی) یا "اردیبهشت ۱۴۰۳" (فارسی)
  static String formatMonthYear(DateTime date) {
    if (_usePersian) {
      return _formatPersianMonthYear(date);
    } else {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  /// نمایش نام روز هفته
  /// مثل: "Monday" (انگلیسی) یا "دوشنبه" (فارسی)
  static String formatWeekday(DateTime date) {
    if (_usePersian) {
      return _getPersianWeekday(date);
    } else {
      return DateFormat('EEEE').format(date);
    }
  }

  /// نمایش نام کوتاه روز هفته
  /// مثل: "Mon" (انگلیسی) یا "د" (فارسی)
  static String formatShortWeekday(DateTime date) {
    if (_usePersian) {
      return _getPersianShortWeekday(date);
    } else {
      return DateFormat('EEE').format(date);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 فرمت‌های ترکیبی (Combined Formats) - مثل Modern-X
  // ═══════════════════════════════════════════════════════════════════════════

  /// فرمت اصلی Modern-X برای نمایش تاریخ در پیام‌ها
  ///
  /// منطق:
  /// - اگر امروز باشه: "14:30"
  /// - اگر دیروز باشه: "Yesterday at 14:30"
  /// - اگر تا ۷ روز پیش باشه: "Monday at 14:30"
  /// - اگر امسال باشه: "17 May at 14:30"
  /// - اگر سال قبل باشه: "17 May 2023 at 14:30"
  static String formatMessageTimestamp(DateTime messageDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay =
        DateTime(messageDate.year, messageDate.month, messageDate.day);

    final difference = today.difference(messageDay).inDays;

    // امروز: فقط زمان
    if (difference == 0) {
      return formatTime(messageDate);
    }

    // دیروز
    if (difference == 1) {
      return formatWithTime(
        _usePersian ? 'دیروز' : 'Yesterday',
        messageDate,
      );
    }

    // تا ۷ روز پیش: روز هفته
    if (difference > 1 && difference < 7) {
      return formatWithTime(
        formatWeekday(messageDate),
        messageDate,
      );
    }

    // بعد از ۷ روز اما امسال: تاریخ کوتاه
    if (messageDate.year == now.year) {
      return formatWithTime(
        formatShortDate(messageDate),
        messageDate,
      );
    }

    // سال‌های قبل: تاریخ کامل
    return formatWithTime(
      formatFullDate(messageDate),
      messageDate,
    );
  }

  /// فرمت Floating Date Header (تاریخ شناور بالای لیست)
  ///
  /// مثل Modern-X:
  /// - امروز: "Today"
  /// - دیروز: "Yesterday"
  /// - تا ۷ روز پیش: "Monday, 15 May"
  /// - بیشتر: "May 2024"
  static String formatFloatingDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(targetDay).inDays;

    // امروز
    if (difference == 0) {
      return _usePersian ? 'امروز' : 'Today';
    }

    // دیروز
    if (difference == 1) {
      return _usePersian ? 'دیروز' : 'Yesterday';
    }

    // تا ۷ روز پیش: "Monday, 15 May"
    if (difference > 1 && difference < 7) {
      return '${formatWeekday(date)}, ${formatShortDate(date)}';
    }

    // بیشتر از ۷ روز: "May 2024"
    return formatMonthYear(date);
  }

  /// فرمت Date Divider (جداکننده تاریخ بین پیام‌ها)
  ///
  /// مثل Modern-X:
  /// - امروز: "Today"
  /// - دیروز: "Yesterday"
  /// - این هفته: "Monday"
  /// - امسال: "17 May"
  /// - سال قبل: "17 May 2023"
  static String formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(targetDay).inDays;

    // امروز
    if (difference == 0) {
      return _usePersian ? 'امروز' : 'Today';
    }

    // دیروز
    if (difference == 1) {
      return _usePersian ? 'دیروز' : 'Yesterday';
    }

    // تا ۷ روز پیش: روز هفته
    if (difference > 1 && difference < 7) {
      return formatWeekday(date);
    }

    // امسال: تاریخ کوتاه
    if (date.year == now.year) {
      return formatShortDate(date);
    }

    // سال‌های قبل: تاریخ کامل
    return formatFullDate(date);
  }

  /// فرمت Last Seen (آخرین بازدید)
  ///
  /// مثل Modern-X:
  /// - کمتر از ۱ دقیقه: "just now"
  /// - کمتر از ۱ ساعت: "5 minutes ago"
  /// - امروز: "today at 14:30"
  /// - دیروز: "yesterday at 14:30"
  /// - بیشتر: "17 May at 14:30"
  static String formatLastSeen(DateTime lastSeenDate) {
    final now = DateTime.now();
    final difference = now.difference(lastSeenDate);

    // همین الان
    if (difference.inSeconds < 60) {
      return _usePersian ? 'همین الان' : 'just now';
    }

    // دقیقه پیش
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (_usePersian) {
        return '$minutes دقیقه پیش';
      } else {
        return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
      }
    }

    // ساعت پیش (امروز)
    if (difference.inHours < 4) {
      final hours = difference.inHours;
      if (_usePersian) {
        return '$hours ساعت پیش';
      } else {
        return hours == 1 ? '1 hour ago' : '$hours hours ago';
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    final lastSeenDay =
        DateTime(lastSeenDate.year, lastSeenDate.month, lastSeenDate.day);
    final daysDifference = today.difference(lastSeenDay).inDays;

    // امروز
    if (daysDifference == 0) {
      return formatWithTime(
        _usePersian ? 'امروز' : 'today',
        lastSeenDate,
      );
    }

    // دیروز
    if (daysDifference == 1) {
      return formatWithTime(
        _usePersian ? 'دیروز' : 'yesterday',
        lastSeenDate,
      );
    }

    // بیشتر
    return formatMessageTimestamp(lastSeenDate);
  }

  /// فرمت Relative Time کوتاه (برای لیست چت‌ها)
  ///
  /// مثل Modern-X:
  /// - "5m" (۵ دقیقه پیش)
  /// - "2h" (۲ ساعت پیش)
  /// - "Yesterday" (دیروز)
  /// - "Mon" (دوشنبه)
  /// - "17 May" (۱۷ می)
  static String formatShortRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // دقیقه پیش
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    // ساعت پیش
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(targetDay).inDays;

    // دیروز
    if (daysDifference == 1) {
      return _usePersian ? 'دیروز' : 'Yesterday';
    }

    // تا ۷ روز پیش
    if (daysDifference > 1 && daysDifference < 7) {
      return formatShortWeekday(date);
    }

    // بیشتر
    return formatShortDate(date);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// ترکیب متن با زمان
  /// مثل: "Yesterday at 14:30"
  static String formatWithTime(String dateText, DateTime date) {
    if (_usePersian) {
      return '$dateText ساعت ${formatTime(date)}';
    } else {
      return '$dateText at ${formatTime(date)}';
    }
  }

  /// چک کردن اینکه آیا باید Date Divider نمایش داده بشه
  static bool shouldShowDateDivider(
      DateTime? currentDate, DateTime? previousDate) {
    if (previousDate == null) return true;

    final current =
        DateTime(currentDate!.year, currentDate.month, currentDate.day);
    final previous =
        DateTime(previousDate.year, previousDate.month, previousDate.day);

    return !current.isAtSameMomentAs(previous);
  }

  /// محاسبه زمان آپدیت بعدی Relative Date
  /// برای بهینه‌سازی: می‌گه بعد از چند میلی‌ثانیه باید دوباره آپدیت کنی
  static Duration? getNextUpdateDuration(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // تا ۱ دقیقه: هر ثانیه آپدیت
    if (difference.inSeconds < 60) {
      return const Duration(seconds: 1);
    }

    // تا ۱ ساعت: هر دقیقه آپدیت
    if (difference.inMinutes < 60) {
      return const Duration(minutes: 1);
    }

    // تا ۴ ساعت: هر ساعت آپدیت
    if (difference.inHours < 4) {
      return const Duration(hours: 1);
    }

    // بعد از ۴ ساعت: فردا صبح ساعت ۰۰:۰۰
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🇮🇷 Persian Date Formatters
  // ═══════════════════════════════════════════════════════════════════════════

  static String _formatPersianShortDate(DateTime date) {
    final j = date.toJalali();
    return '${_toPersianNumber(j.day)} ${_getPersianMonthName(j.month)}';
  }

  static String _formatPersianFullDate(DateTime date) {
    final j = date.toJalali();
    return '${_toPersianNumber(j.day)} ${_getPersianMonthName(j.month)} ${_toPersianNumber(j.year)}';
  }

  static String _formatPersianMonthYear(DateTime date) {
    final j = date.toJalali();
    return '${_getPersianMonthName(j.month)} ${_toPersianNumber(j.year)}';
  }

  static String _getPersianWeekday(DateTime date) {
    final weekdays = [
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
      'شنبه',
      'یکشنبه',
    ];
    return weekdays[date.weekday - 1];
  }

  static String _getPersianShortWeekday(DateTime date) {
    final shortWeekdays = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];
    return shortWeekdays[date.weekday - 1];
  }

  static String _getPersianMonthName(int month) {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return months[month - 1];
  }

  static String _toPersianNumber(int number) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return number.toString().split('').map((e) {
      final digit = int.tryParse(e);
      return digit != null ? persian[digit] : e;
    }).join();
  }
}

/// Extension برای راحتی استفاده
extension ModernXDateExtension on DateTime {
  /// نمایش تاریخ در پیام (مثل Modern-X)
  String toModernMessageFormat() =>
      ModernXDateUtils.formatMessageTimestamp(this);

  /// نمایش در Floating Header
  String toFloatingHeaderFormat() =>
      ModernXDateUtils.formatFloatingDateHeader(this);

  /// نمایش در Date Divider
  String toDateDividerFormat() => ModernXDateUtils.formatDateDivider(this);

  /// نمایش Last Seen
  String toLastSeenFormat() => ModernXDateUtils.formatLastSeen(this);

  /// نمایش کوتاه Relative
  String toShortRelativeFormat() =>
      ModernXDateUtils.formatShortRelativeTime(this);

  /// فقط زمان
  String toTimeFormat() => ModernXDateUtils.formatTime(this);

  /// چک کردن Divider
  bool shouldShowDividerFrom(DateTime? previousDate) =>
      ModernXDateUtils.shouldShowDateDivider(this, previousDate);
}
