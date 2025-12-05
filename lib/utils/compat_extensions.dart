// Compatibility extensions to restore older helper names used across the codebase.
// This file maps legacy extension/method names (toPersianDigit, toFullDateTimeLabel, etc.)
// to the newer TelegramXDateUtils implementations so we don't have to refactor many files.

import 'telegram_x_date_utils.dart';

/// Convert western digits in a string to Persian digits
extension PersianDigitsString on String {
  String toPersianDigit() {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return replaceAllMapped(RegExp(r"\d"), (m) {
      final d = int.tryParse(m[0] ?? '0') ?? 0;
      return persian[d];
    });
  }
}

/// Legacy DateTime helpers used across the UI. They map to TelegramXDateUtils.
extension LegacyDateTimeLabels on DateTime {
  /// Full date + time label
  String toFullDateTimeLabel() {
    final date = TelegramXDateUtils.formatFullDate(this);
    return TelegramXDateUtils.formatWithTime(date, this);
  }

  /// Fixed time label (HH:mm or h:mm a depending on settings)
  String toFixedTimeLabel() => TelegramXDateUtils.formatTime(this);

  /// Human friendly relative time (used in many message/post UI places)
  String toRelativeTime() => TelegramXDateUtils.formatLastSeen(this);

  /// Date divider label
  String toDateDividerLabel() => TelegramXDateUtils.formatDateDivider(this);

  /// Floating date header label
  String toFloatingDateLabel() =>
      TelegramXDateUtils.formatFloatingDateHeader(this);
}

/// Top-level compatibility wrapper used by some widgets
bool shouldShowDateDivider(DateTime? currentDate, DateTime? previousDate) {
  return TelegramXDateUtils.shouldShowDateDivider(currentDate, previousDate);
}
