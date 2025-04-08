// lib/utils/time_utils.dart
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  static String formatMessageTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      return timeago.format(time, locale: 'fa');
    } else {
      return '${time.year}/${time.month}/${time.day}';
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
