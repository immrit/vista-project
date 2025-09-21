// lib/utils/time_utils.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shamsi_date/shamsi_date.dart';

class TimeUtils {
  // منطقه زمانی ایران (Tehran)
  static const tehranTimeZoneOffset = Duration(hours: 3, minutes: 30);

  // تبدیل زمان به منطقه زمانی ایران
  static DateTime toTehranTime(DateTime time) {
    return time.toUtc().add(tehranTimeZoneOffset);
  }

  // قالب‌بندی زمان برای نمایش ساعت
  static String formatTime(DateTime time) {
    final tehranTime = toTehranTime(time);
    return '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';
  }

  // قالب‌بندی تاریخ برای نمایش
  static String formatDate(DateTime time) {
    final tehranTime = toTehranTime(time);
    final jalaliFormatter = DateFormat('yyyy/MM/dd');
    return jalaliFormatter.format(tehranTime);
  }

  // قالب‌بندی زمان برای نمایش زمانی که چقدر از زمان گذشته است
  static String timeAgo(DateTime time) {
    final now = DateTime.now();
    final tehranTime = toTehranTime(time);
    final tehranNow = toTehranTime(now);
    final difference = tehranNow.difference(tehranTime);

    // اگر کمتر از 1 دقیقه گذشته باشد
    if (difference.inMinutes < 1) {
      return 'هم اکنون';
    }
    // اگر کمتر از 1 ساعت گذشته باشد
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }
    // اگر کمتر از 24 ساعت گذشته باشد
    else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    }
    // اگر کمتر از 7 روز گذشته باشد
    else if (difference.inDays < 7) {
      return timeago.format(tehranTime, locale: 'fa');
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

  // قالب‌بندی زمان آخرین بازدید
  static String formatLastSeen(DateTime? time) {
    if (time == null) return 'آنلاین نیست';

    final now = DateTime.now();
    final tehranTime = toTehranTime(time);
    final tehranNow = toTehranTime(now);
    final difference = tehranNow.difference(tehranTime);

    // آنلاین - کمتر از 2 دقیقه
    if (difference.inMinutes < 2) {
      return 'آنلاین';
    }
    // چند دقیقه پیش - کمتر از 60 دقیقه
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }
    // ساعت امروز - اگر امروز باشد
    else if (isToday(time)) {
      return 'امروز ساعت ${formatTime(time)}';
    }
    // دیروز با ساعت - اگر دیروز باشد
    else if (isYesterday(time)) {
      return 'دیروز ساعت ${formatTime(time)}';
    }
    // تاریخ کامل با ساعت - برای روزهای قبل‌تر
    else {
      return '${formatDate(time)} ساعت ${formatTime(time)}';
    }
  }

  // فرمت ساعت پیام (مثل تلگرام)
  static String formatMessageTime(DateTime messageTime) {
    final tehranTime = toTehranTime(messageTime);
    return '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';
  }

  // فرمت تاریخ برای جداکننده (مثل تلگرام)
  static String formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final tehranTime = toTehranTime(date);
    final tehranNow = toTehranTime(now);

    final jDate = Jalali.fromDateTime(tehranTime);
    final jNow = Jalali.fromDateTime(tehranNow);

    // امروز
    if (_isSameDay(tehranTime, tehranNow)) {
      return 'امروز';
    }

    // دیروز
    if (_isSameDay(tehranTime, tehranNow.subtract(const Duration(days: 1)))) {
      return 'دیروز';
    }

    // هفته جاری
    final daysDifference = tehranNow.difference(tehranTime).inDays;
    if (daysDifference < 7 && daysDifference > 0) {
      return _getPersianWeekDay(jDate.weekDay);
    }

    // سال جاری
    if (jDate.year == jNow.year) {
      return '${jDate.day.toString().padLeft(2, '0')} ${_getPersianMonth(jDate.month)}';
    }

    // سال‌های دیگر
    return '${jDate.day.toString().padLeft(2, '0')} ${_getPersianMonth(jDate.month)} ${jDate.year}';
  }

  // فرمت زمان در لیست گفتگوها (مثل تلگرام)
  static String formatConversationTime(DateTime messageTime) {
    final now = DateTime.now();
    final tehranTime = toTehranTime(messageTime);
    final tehranNow = toTehranTime(now);

    final jDate = Jalali.fromDateTime(tehranTime);
    final jNow = Jalali.fromDateTime(tehranNow);

    // امروز - فقط ساعت
    if (_isSameDay(tehranTime, tehranNow)) {
      return formatMessageTime(messageTime);
    }

    // دیروز
    if (_isSameDay(tehranTime, tehranNow.subtract(const Duration(days: 1)))) {
      return 'دیروز';
    }

    // هفته جاری
    final daysDifference = tehranNow.difference(tehranTime).inDays;
    if (daysDifference < 7 && daysDifference > 0) {
      return _getPersianWeekDay(jDate.weekDay);
    }

    // سال جاری
    if (jDate.year == jNow.year) {
      return '${jDate.day}/${jDate.month}';
    }

    // سال‌های دیگر
    return '${jDate.day}/${jDate.month}/${jDate.year}';
  }

  // تشخیص نیاز به نمایش جداکننده تاریخ
  static bool shouldShowDateDivider(
      DateTime currentMessage, DateTime? previousMessage) {
    if (previousMessage == null) return true;

    final currentTehran = toTehranTime(currentMessage);
    final previousTehran = toTehranTime(previousMessage);

    return !_isSameDay(currentTehran, previousTehran);
  }

  // محاسبه فاصله زمانی بین دو پیام (برای فاصله‌گذاری)
  static Duration getTimeDifference(
      DateTime currentMessage, DateTime? previousMessage) {
    if (previousMessage == null) return Duration.zero;

    final currentTehran = toTehranTime(currentMessage);
    final previousTehran = toTehranTime(previousMessage);

    return currentTehran.difference(previousTehran).abs();
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
  static bool _isSameDay(DateTime a, DateTime b) {
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
    // اگر پیام قبلی وجود ندارد
    if (previousMessageTime == null || previousSenderId == null) {
      return standardSpacing;
    }

    // اگر روز متفاوت است
    if (shouldShowDateDivider(currentMessageTime, previousMessageTime)) {
      return dayGapSpacing;
    }

    // اگر فرستنده متفاوت است
    if (currentSenderId != previousSenderId) {
      return standardSpacing;
    }

    // اگر زمان زیادی گذشته
    if (needsExtraSpacing(currentMessageTime, previousMessageTime)) {
      return timeGapSpacing;
    }

    // اگر در یک گروه هستند
    if (isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
        previousSenderId)) {
      return groupedSpacing;
    }

    return standardSpacing;
  }

  /// تشخیص نیاز به نمایش آواتار (مثل تلگرام)
  static bool shouldShowAvatar(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
    bool isMe,
  ) {
    // پیام‌های خودی همیشه آواتار ندارند
    if (isMe) return false;

    // اولین پیام همیشه آواتار دارد
    if (previousMessageTime == null || previousSenderId == null) {
      return true;
    }

    // اگر فرستنده متفاوت است
    if (currentSenderId != previousSenderId) {
      return true;
    }

    // اگر در یک گروه نیستند
    if (!isInSameGroup(currentMessageTime, previousMessageTime, currentSenderId,
        previousSenderId)) {
      return true;
    }

    return false;
  }

  /// تشخیص نیاز به نمایش نام فرستنده (در گروه‌ها)
  static bool shouldShowSenderName(
    DateTime currentMessageTime,
    DateTime? previousMessageTime,
    String currentSenderId,
    String? previousSenderId,
    bool isMe,
    bool isGroupChat,
  ) {
    // پیام‌های خودی یا چت‌های شخصی نام ندارند
    if (isMe || !isGroupChat) return false;

    // اولین پیام همیشه نام دارد
    if (previousMessageTime == null || previousSenderId == null) {
      return true;
    }

    // اگر فرستنده متفاوت است
    if (currentSenderId != previousSenderId) {
      return true;
    }

    // اگر در یک گروه نیستند
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

  /// محاسبه border radius برای bubble پیام (مثل تلگرام)
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
    final tehranTime = toTehranTime(dateTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateToCheck =
        DateTime(tehranTime.year, tehranTime.month, tehranTime.day);

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
    final now = DateTime.now();
    final tehranTime = toTehranTime(time);
    final tehranNow = toTehranTime(now);

    return tehranTime.year == tehranNow.year &&
        tehranTime.month == tehranNow.month &&
        tehranTime.day == tehranNow.day;
  }

  // بررسی اینکه آیا زمان در محدوده دیروز است
  static bool isYesterday(DateTime time) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final tehranTime = toTehranTime(time);
    final tehranYesterday = toTehranTime(yesterday);

    return tehranTime.year == tehranYesterday.year &&
        tehranTime.month == tehranYesterday.month &&
        tehranTime.day == tehranYesterday.day;
  }
}
