// Compatibility extensions to restore older helper names used across the codebase.
// This file maps legacy extension/method names (toPersianDigit, toFullDateTimeLabel, etc.)
// to the newer ModernXDateUtils implementations so we don't have to refactor many files.

import 'modern_x_date_utils.dart';

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

/// Legacy DateTime helpers used across the UI. They map to ModernXDateUtils.
extension LegacyDateTimeLabels on DateTime {
  /// Full date + time label
  String toFullDateTimeLabel() {
    final date = ModernXDateUtils.formatFullDate(this);
    return ModernXDateUtils.formatWithTime(date, this);
  }

  /// Fixed time label (HH:mm or h:mm a depending on settings)
  String toFixedTimeLabel() => ModernXDateUtils.formatTime(this);

  /// Human friendly relative time (used in many message/post UI places)
  String toRelativeTime() => ModernXDateUtils.formatLastSeen(this);

  /// Date divider label
  String toDateDividerLabel() => ModernXDateUtils.formatDateDivider(this);

  /// Floating date header label
  String toFloatingDateLabel() =>
      ModernXDateUtils.formatFloatingDateHeader(this);
}

/// Top-level compatibility wrapper used by some widgets
bool shouldShowDateDivider(DateTime? currentDate, DateTime? previousDate) {
  return ModernXDateUtils.shouldShowDateDivider(currentDate, previousDate);
}
