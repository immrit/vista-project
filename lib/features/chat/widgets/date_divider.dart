// lib/features/chat/widgets/date_divider.dart
//
// جداکننده تاریخ بین پیام‌ها - یکسان با FloatingDateHeader
//

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../theme/chat_theme.dart';

/// استایل مشترک برای چیپ تاریخ
class DateChipStyle {
  static const double borderRadius = 18;
  static const double horizontalPadding = 14;
  static const double verticalPadding = 7;
  static const double fontSize = 12;
  static const FontWeight fontWeight = FontWeight.w500;

  static BoxDecoration getDecoration(ChatTheme theme) {
    // PERF: blur حذف شد (زیر) → alpha بالاتر تا چیپ بدون BackdropFilter هم خوانا بماند.
    return BoxDecoration(
      color: theme.isDark
          ? Colors.black.withValues(alpha: 0.40)
          : Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static TextStyle getTextStyle(ChatTheme theme) {
    return TextStyle(
      color: theme.isDark ? Colors.white : Colors.black87,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }
}

class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    // PERF: BackdropFilter حذف شد — هر چیپ تاریخ داخل ListView یک saveLayer در هر
    // فریم می‌ساخت (بدون گارد perf، حتی حین اسکرول/low-tier). چیپ solid نیمه‌شفاف
    // عملاً از blur قابل‌تفکیک نیست ولی صدها برابر ارزان‌تر است (مثل تلگرام).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DateChipStyle.horizontalPadding,
            vertical: DateChipStyle.verticalPadding,
          ),
          decoration: DateChipStyle.getDecoration(theme),
          child: Text(
            formatPersianDate(date),
            style: DateChipStyle.getTextStyle(theme),
          ),
        ),
      ),
    );
  }
}

// PERF: cache formatted date strings. Each visible DateDivider rebuild called
// Jalali.fromDateTime (a non-trivial calendar conversion). Key includes the
// current day so relative labels ("امروز"/"دیروز") can't go stale across
// midnight while a chat stays open.
final Map<String, String> _persianDateCache = <String, String>{};

/// فرمت تاریخ شمسی - استفاده مشترک
String formatPersianDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);

  final cacheKey = '${today.millisecondsSinceEpoch}'
      '|${dateOnly.millisecondsSinceEpoch}';
  final cached = _persianDateCache[cacheKey];
  if (cached != null) return cached;

  final yesterday = today.subtract(const Duration(days: 1));
  final jalali = Jalali.fromDateTime(date);

  final String result;
  if (dateOnly == today) {
    result = 'امروز';
  } else if (dateOnly == yesterday) {
    result = 'دیروز';
  } else if (now.difference(date).inDays < 7) {
    result = _getPersianWeekday(date.weekday);
  } else if (date.year == now.year) {
    result = '${jalali.day} ${_getPersianMonth(jalali.month)}';
  } else {
    result = '${jalali.day} ${_getPersianMonth(jalali.month)} ${jalali.year}';
  }

  // Bound the cache: drop stale "today" keys from previous days.
  if (_persianDateCache.length > 64) _persianDateCache.clear();
  _persianDateCache[cacheKey] = result;
  return result;
}

String _getPersianWeekday(int weekday) {
  const weekdays = [
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];
  return weekdays[weekday - 1];
}

String _getPersianMonth(int month) {
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

/// آیا باید بین دو پیام Date Divider نشون بدیم؟
bool shouldShowDateDivider(DateTime current, DateTime? previous) {
  if (previous == null) return true;

  final currentDate = DateTime(current.year, current.month, current.day);
  final previousDate = DateTime(previous.year, previous.month, previous.day);

  return currentDate != previousDate;
}
