// lib/utils/time_utils.dart
import 'package:flutter/material.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:shamsi_date/shamsi_date.dart';

class TimeUtils {
  // منطقه زمانی ایران (Tehran)
  static const tehranTimeZoneOffset = Duration(hours: 3, minutes: 30);

  // تبدیل زمان به منطقه زمانی ایران
  static DateTime toTehranTime(DateTime time) {
    return time.toUtc().add(tehranTimeZoneOffset);
  }

  // تبدیل اعداد انگلیسی به فارسی
  static String replaceEnglishdigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], persian[i]);
    }
    return input;
  }

  // قالب‌بندی زمان برای نمایش ساعت - استفاده از زمان محلی گوشی
  static String formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return replaceEnglishdigits('$hour:$minute');
  }

  // قالب‌بندی تاریخ برای نمایش شمسی
  static String formatDate(DateTime time) {
    final localTime = time.toLocal();
    final jDate = Jalali.fromDateTime(localTime);
    final year = replaceEnglishdigits(jDate.year.toString());
    final month = replaceEnglishdigits(jDate.month.toString().padLeft(2, '0'));
    final day = replaceEnglishdigits(jDate.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }

  // قالب‌بندی زمان برای نمایش زمانی که چقدر از زمان گذشته است
  static String timeAgo(DateTime time) {
    final now = DateTime.now();
    final localTime = time.toLocal();
    final localNow = now.toLocal();
    final difference = localNow.difference(localTime);

    // اگر کمتر از 1 دقیقه گذشته باشد
    if (difference.inMinutes < 1) {
      return 'هم اکنون';
    }
    // اگر کمتر از 1 ساعت گذشته باشد
    else if (difference.inMinutes < 60) {
      return '${replaceEnglishdigits(difference.inMinutes.toString())} دقیقه پیش';
    }
    // اگر کمتر از 24 ساعت گذشته باشد
    else if (difference.inHours < 24) {
      return '${replaceEnglishdigits(difference.inHours.toString())} ساعت پیش';
    }
    // اگر کمتر از 7 روز گذشته باشد
    else if (difference.inDays < 7) {
      return timeago.format(localTime, locale: 'fa');
    }
    // در غیر این صورت نمایش تاریخ کامل
    else {
      return formatDate(time);
    }
  }

  // تبدیل زمان‌های ISO8601 به DateTime ایران
  static DateTime parseIsoTime(String isoString) {
    final utcTime = DateTime.parse(isoString);
    return toTehranTime(utcTime);
  }

  // قالب‌بندی زمان آخرین بازدید برای User Presence
  static String formatUserPresence(DateTime? time) {
    if (time == null) return 'آخرین بازدید به تازگی';

    final now = DateTime.now();
    final localTime = time.toLocal();
    final localNow = now.toLocal();
    final difference = localNow.difference(localTime);

    // آنلاین - کمتر از 1 دقیقه
    if (difference.inMinutes < 1) {
      return 'آنلاین';
    }

    final timeStr = formatTime(time);

    // امروز
    if (isToday(time)) {
      return 'آخرین بازدید امروز ساعت $timeStr';
    }

    // دیروز
    if (isYesterday(time)) {
      return 'آخرین بازدید دیروز ساعت $timeStr';
    }

    // تاریخ شمسی برای روزهای قبل
    final jDate = Jalali.fromDateTime(localTime);
    final monthName = _getPersianMonth(jDate.month);
    final dayStr = replaceEnglishdigits(jDate.day.toString());

    // اگر سال جاری است، سال را نمایش نده
    final jNow = Jalali.fromDateTime(localNow);
    if (jDate.year == jNow.year) {
      return 'آخرین بازدید $dayStr $monthName ساعت $timeStr';
    } else {
      final yearStr = replaceEnglishdigits(jDate.year.toString());
      return 'آخرین بازدید $dayStr $monthName $yearStr ساعت $timeStr';
    }
  }

  // بروزرسانی متد قدیمی برای استفاده از لاجیک جدید (Backward Compatibility)
  static String formatLastSeen(DateTime? time) {
    return formatUserPresence(time);
  }

  // فرمت ساعت پیام (مثل تلگرام) - با ارقام فارسی
  static String formatMessageTime(DateTime messageTime) {
    return formatTime(messageTime);
  }

  // فرمت تاریخ برای جداکننده (مثل تلگرام)
  static String formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final localTime = date.toLocal();
    final localNow = now.toLocal();

    final jDate = Jalali.fromDateTime(localTime);
    final jNow = Jalali.fromDateTime(localNow);

    // امروز
    if (isSameDay(localTime, localNow)) {
      return 'امروز';
    }

    // دیروز
    if (isSameDay(localTime, localNow.subtract(const Duration(days: 1)))) {
      return 'دیروز';
    }

    // هفته جاری
    final daysDifference = localNow.difference(localTime).inDays;
    if (daysDifference < 7 && daysDifference > 0) {
      return _getPersianWeekDay(jDate.weekDay);
    }

    // سال جاری
    if (jDate.year == jNow.year) {
      final dayStr = replaceEnglishdigits(jDate.day.toString().padLeft(2, '0'));
      return '$dayStr ${_getPersianMonth(jDate.month)}';
    }

    // سال‌های دیگر
    final dayStr = replaceEnglishdigits(jDate.day.toString().padLeft(2, '0'));
    final yearStr = replaceEnglishdigits(jDate.year.toString());
    return '$dayStr ${_getPersianMonth(jDate.month)} $yearStr';
  }

  // فرمت زمان در لیست گفتگوها (مثل تلگرام)
  static String formatConversationTime(DateTime messageTime) {
    final now = DateTime.now();
    final localTime = messageTime.toLocal();
    final localNow = now.toLocal();

    final jDate = Jalali.fromDateTime(localTime);
    final jNow = Jalali.fromDateTime(localNow);

    // امروز - فقط ساعت
    if (isSameDay(localTime, localNow)) {
      return formatMessageTime(messageTime);
    }

    // دیروز
    if (isSameDay(localTime, localNow.subtract(const Duration(days: 1)))) {
      return 'دیروز';
    }

    // هفته جاری
    final daysDifference = localNow.difference(localTime).inDays;
    if (daysDifference < 7 && daysDifference > 0) {
      return _getPersianWeekDay(jDate.weekDay);
    }

    // سال جاری - فقط روز و ماه
    if (jDate.year == jNow.year) {
      final dayStr = replaceEnglishdigits(jDate.day.toString());
      return '$dayStr ${_getPersianMonth(jDate.month)}';
    }

    // سال‌های دیگر - روز، ماه و سال
    final dayStr = replaceEnglishdigits(jDate.day.toString());
    final yearStr = replaceEnglishdigits(jDate.year.toString());
    return '$dayStr ${_getPersianMonth(jDate.month)} $yearStr';
  }

  // تشخیص نیاز به نمایش جداکننده تاریخ - استفاده از زمان محلی گوشی
  static bool shouldShowDateDivider(
      DateTime currentMessage, DateTime? previousMessage) {
    if (previousMessage == null) return true;

    final currentLocal = currentMessage.toLocal();
    final previousLocal = previousMessage.toLocal();

    return !isSameDay(currentLocal, previousLocal);
  }

  // محاسبه فاصله زمانی بین دو پیام (برای فاصله‌گذاری)
  static Duration getTimeDifference(
      DateTime currentMessage, DateTime? previousMessage) {
    if (previousMessage == null) return Duration.zero;

    final currentLocal = currentMessage.toLocal();
    final previousLocal = previousMessage.toLocal();

    return currentLocal.difference(previousLocal).abs();
  }

  // تشخیص نیاز به فاصله بیشتر بین پیام‌ها (مثل تلگرام)
  static bool needsExtraSpacing(
      DateTime currentMessage, DateTime? previousMessage) {
    if (previousMessage == null) return false;

    final timeDiff = getTimeDifference(currentMessage, previousMessage);

    // اگر بیش از 5 دقیقه فاصله باشد، فاصله بیشتری بده
    return timeDiff.inMinutes > 5;
  }

  // تشخیص گروه‌بندی پیام‌ها (برای حذف avatar تکراری)
  static bool isInSameGroup(
    DateTime currentMessage,
    DateTime? previousMessage,
    String currentSenderId,
    String? previousSenderId,
  ) {
    if (previousMessage == null || previousSenderId == null) return false;
    if (currentSenderId != previousSenderId) return false;

    final timeDiff = getTimeDifference(currentMessage, previousMessage);

    // اگر کمتر از 2 دقیقه فاصله باشد و فرستنده یکی باشد، در یک گروه هستند
    return timeDiff.inMinutes < 2;
  }

  // بررسی هم‌روز بودن
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // نام روزهای هفته به فارسی
  static String _getPersianWeekDay(int weekDay) {
    switch (weekDay) {
      case 1:
        return 'دوشنبه';
      case 2:
        return 'سه‌شنبه';
      case 3:
        return 'چهارشنبه';
      case 4:
        return 'پنج‌شنبه';
      case 5:
        return 'جمعه';
      case 6:
        return 'شنبه';
      case 7:
        return 'یکشنبه';
      default:
        return '';
    }
  }

  // نام ماه‌ها به فارسی
  static String _getPersianMonth(int month) {
    switch (month) {
      case 1:
        return 'فروردین';
      case 2:
        return 'اردیبهشت';
      case 3:
        return 'خرداد';
      case 4:
        return 'تیر';
      case 5:
        return 'مرداد';
      case 6:
        return 'شهریور';
      case 7:
        return 'مهر';
      case 8:
        return 'آبان';
      case 9:
        return 'آذر';
      case 10:
        return 'دی';
      case 11:
        return 'بهمن';
      case 12:
        return 'اسفند';
      default:
        return '';
    }
  }

  // ========== سیستم فاصله‌گذاری پیام‌ها (مثل تلگرام) ==========

  /// فاصله استانداد بین پیام‌ها
  static const double standardSpacing = 2.0;

  /// فاصله بین پیام‌های گروه‌بندی شده (از یک فرستنده)
  static const double groupedSpacing = 1.0;

  /// فاصله بین پیام‌های با زمان متفاوت
  static const double timeGapSpacing = 8.0;

  /// فاصله بین پیام‌های در روزهای مختلف
  static const double dayGapSpacing = 16.0;

  /// محاسبه فاصله بین دو پیام
  static double calculateMessageSpacing(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
  ) {
    if (previousMessageTime == null || previousSenderId == null) {
      return standardSpacing;
    }

    if (shouldShowDateDivider(currentMessageTime, previousMessageTime)) {
      return dayGapSpacing;
    }

    if (currentSenderId != previousSenderId) {
      return standardSpacing;
    }

    if (needsExtraSpacing(currentMessageTime, previousMessageTime)) {
      return timeGapSpacing;
    }

    if (isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
        previousSenderId)) {
      return groupedSpacing;
    }

    return standardSpacing;
  }

  /// تشخیص نیاز به نمایش آواتار
  static bool shouldShowAvatar(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
    bool isMe,
  ) {
    if (isMe) return false;

    if (previousMessageTime == null || previousSenderId == null) {
      return true;
    }

    if (currentSenderId != previousSenderId) {
      return true;
    }

    if (!isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
        previousSenderId)) {
      return true;
    }

    return false;
  }

  /// تشخیص نیاز به نمایش نام فرستنده
  static bool shouldShowSenderName(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
    bool isMe,
    bool isGroupChat,
  ) {
    if (isMe || !isGroupChat) return false;

    if (previousMessageTime == null || previousSenderId == null) {
      return true;
    }

    if (currentSenderId != previousSenderId) {
      return true;
    }

    if (!isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
        previousSenderId)) {
      return true;
    }

    return false;
  }

  /// محاسبه margin برای bubble پیام
  static EdgeInsets calculateBubbleMargin(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
    bool isMe,
  ) {
    final spacing = calculateMessageSpacing(
      currentMessageTime,
      previousMessageTime,
      currentSenderId,
      previousSenderId,
    );

    const double horizontalMargin = 12.0;

    return EdgeInsets.only(
      left: isMe ? 64.0 : horizontalMargin,
      right: isMe ? horizontalMargin : 64.0,
      top: spacing,
      bottom: 0,
    );
  }

  /// محاسبه border radius برای bubble پیام
  static BorderRadius calculateBubbleRadius(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    DateTime? nextMessageTime,
    String currentSenderId,
    String? previousSenderId,
    String? nextSenderId,
    bool isMe,
  ) {
    const double defaultRadius = 18.0;
    const double smallRadius = 4.0;

    bool isFirstInGroup = previousMessageTime == null ||
        previousSenderId != currentSenderId ||
        !isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
            previousSenderId);

    bool isLastInGroup = nextMessageTime == null ||
        nextSenderId != currentSenderId ||
        !isInSameGroup(nextMessageTime, currentMessageTime, nextSenderId ?? '',
            currentSenderId);

    if (isMe) {
      return BorderRadius.only(
        topLeft: const Radius.circular(defaultRadius),
        topRight: Radius.circular(isFirstInGroup ? defaultRadius : smallRadius),
        bottomLeft: const Radius.circular(defaultRadius),
        bottomRight:
            Radius.circular(isLastInGroup ? defaultRadius : smallRadius),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(isFirstInGroup ? defaultRadius : smallRadius),
        topRight: const Radius.circular(defaultRadius),
        bottomLeft:
            Radius.circular(isLastInGroup ? defaultRadius : smallRadius),
        bottomRight: const Radius.circular(defaultRadius),
      );
    }
  }

  // قالب‌بندی زمان برای نمایش در صفحه جستجو
  static String formatDateTimeForDisplay(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck =
        DateTime(localTime.year, localTime.month, localTime.day);

    if (dateToCheck == today) {
      return 'امروز ${formatTime(dateTime)}';
    } else if (dateToCheck == yesterday) {
      return 'دیروز ${formatTime(dateTime)}';
    } else {
      return '${formatDate(dateTime)} ${formatTime(dateTime)}';
    }
  }

  // بررسی اینکه آیا زمان در محدوده امروز است
  static bool isToday(DateTime time) {
    final now = DateTime.now().toLocal();
    final localTime = time.toLocal();

    return localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
  }

  // بررسی اینکه آیا زمان در محدوده دیروز است
  static bool isYesterday(DateTime time) {
    final now = DateTime.now().toLocal();
    final yesterday = now.subtract(const Duration(days: 1));
    final localTime = time.toLocal();

    return localTime.year == yesterday.year &&
        localTime.month == yesterday.month &&
        localTime.day == yesterday.day;
  }
}
