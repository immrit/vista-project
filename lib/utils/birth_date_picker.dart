import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import 'time_utils.dart';

const _persianMonthNames = [
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

bool isPersianLocale(Locale locale) =>
    locale.languageCode == 'fa' || locale.languageCode == 'fa-IR';

/// تقویم شمسی برای فارسی؛ در غیر این صورت میلادی.
bool useJalaliCalendar(Locale locale) => locale.languageCode == 'fa';

/// ترجیح زبان اپ، در صورت نبود از locale ویجت.
Locale resolveBirthDateLocale(BuildContext context, Locale appLocale) {
  if (useJalaliCalendar(appLocale)) return appLocale;
  final contextLocale = Localizations.maybeLocaleOf(context);
  if (contextLocale != null && useJalaliCalendar(contextLocale)) {
    return contextLocale;
  }
  return appLocale;
}

/// Parses API/profile birth_date values (ISO, slash-separated Gregorian or Jalali).
DateTime? parseBirthDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final trimmed = value.trim();
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    // Legacy data may store Jalali dates like "1402-07-12".
    // DateTime.tryParse treats them as Gregorian year 1402, which causes
    // mixed/incorrect calendar rendering in profile forms.
    if (parsed.year >= 1700) {
      return parsed;
    }
  }

  final parts = trimmed.split(RegExp(r'[-/]'));
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  if (year < 1700) {
    try {
      return Jalali(year, month, day).toDateTime();
    } catch (_) {
      return null;
    }
  }

  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

String formatBirthDateForStorage(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatBirthDateForDisplay(DateTime date, Locale locale) {
  if (useJalaliCalendar(locale)) {
    final jalali = Jalali.fromDateTime(date);
    final year = TimeUtils.replaceEnglishdigits(jalali.year.toString());
    return '${jalali.day} ${_persianMonthNames[jalali.month - 1]} $year';
  }

  return DateFormat.yMMMd(locale.toString()).format(date);
}

DateTime _clampBirthDate(DateTime date, DateTime min, DateTime max) {
  if (date.isBefore(min)) return min;
  if (date.isAfter(max)) return max;
  return date;
}

/// Shows a Jalali picker for Persian and a Gregorian picker for other locales.
Future<DateTime?> pickBirthDate(
  BuildContext context, {
  required Locale locale,
  DateTime? initialDate,
  String? helpText,
  String? confirmText,
  String? cancelText,
}) async {
  final now = DateTime.now();
  final lastDate = DateTime(now.year - 13, now.month, now.day);
  final firstDate = DateTime(now.year - 100, now.month, now.day);
  final initial = _clampBirthDate(
    initialDate ?? DateTime(now.year - 18, now.month, now.day),
    firstDate,
    lastDate,
  );

  if (useJalaliCalendar(locale)) {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(initial),
      firstDate: Jalali.fromDateTime(firstDate),
      lastDate: Jalali.fromDateTime(lastDate),
      helpText: helpText ?? 'تاریخ تولد',
      confirmText: confirmText ?? 'تایید',
      cancelText: cancelText ?? 'انصراف',
      locale: const Locale('fa', 'IR'),
      textDirection: ui.TextDirection.rtl,
    );
    return picked?.toDateTime();
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: locale,
    helpText: helpText ?? 'Date of birth',
    confirmText: confirmText ?? 'OK',
    cancelText: cancelText ?? 'Cancel',
  );
}
