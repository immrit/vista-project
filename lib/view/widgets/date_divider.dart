import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

class DateDivider extends StatelessWidget {
  final DateTime date;
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: FloatingDateChip(date: date),
    );
  }
}

class FloatingDateChip extends StatelessWidget {
  final DateTime date;

  const FloatingDateChip({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _formatDate(date),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final jalaliDate = Jalali.fromDateTime(date);
    final jalaliNow = Jalali.fromDateTime(now);

    // بررسی امروز
    if (jalaliNow.year == jalaliDate.year &&
        jalaliNow.month == jalaliDate.month &&
        jalaliNow.day == jalaliDate.day) {
      return "امروز";
    }

    // بررسی دیروز
    final yesterday = now.subtract(const Duration(days: 1));
    final jalaliYesterday = Jalali.fromDateTime(yesterday);
    if (jalaliYesterday.year == jalaliDate.year &&
        jalaliYesterday.month == jalaliDate.month &&
        jalaliYesterday.day == jalaliDate.day) {
      return "دیروز";
    }

    // نام ماه‌های شمسی
    const monthNames = [
      "",
      "فروردین",
      "اردیبهشت",
      "خرداد",
      "تیر",
      "مرداد",
      "شهریور",
      "مهر",
      "آبان",
      "آذر",
      "دی",
      "بهمن",
      "اسفند"
    ];

    // اگر سال متفاوت است، سال را نمایش بده
    if (jalaliNow.year != jalaliDate.year) {
      return "${jalaliDate.day} ${monthNames[jalaliDate.month]} ${jalaliDate.year}";
    }

    // اگر سال یکسان است، فقط روز و ماه را نمایش بده
    return "${jalaliDate.day} ${monthNames[jalaliDate.month]}";
  }
}
