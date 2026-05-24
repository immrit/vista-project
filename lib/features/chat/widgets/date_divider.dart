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
    return BoxDecoration(
      color: theme.isDark
          ? Colors.black.withOpacity(0.5)
          : Colors.black.withOpacity(0.07),
      borderRadius: BorderRadius.circular(borderRadius),
    );
  }

  static TextStyle getTextStyle(ChatTheme theme) {
    return TextStyle(
      color: theme.isDark
          ? Colors.white.withOpacity(0.9)
          : theme.secondaryTextColor,
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

/// فرمت تاریخ شمسی - استفاده مشترک
String formatPersianDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);

  // تاریخ شمسی
  final jalali = Jalali.fromDateTime(date);

  if (dateOnly == today) {
    return 'امروز';
  } else if (dateOnly == yesterday) {
    return 'دیروز';
  } else if (now.difference(date).inDays < 7) {
    return _getPersianWeekday(date.weekday);
  } else if (date.year == now.year) {
    return '${jalali.day} ${_getPersianMonth(jalali.month)}';
  } else {
    return '${jalali.day} ${_getPersianMonth(jalali.month)} ${jalali.year}';
  }
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
