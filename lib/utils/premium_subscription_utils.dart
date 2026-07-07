import 'package:shamsi_date/shamsi_date.dart';

/// کمک‌تابع‌های اشتراک ویستا پریمیوم (روز باقی‌مانده، تمدید).
class PremiumSubscriptionUtils {
  static DateTime? parseExpiresAt(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final raw = profile['subscription_expires_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static int? daysRemaining(Map<String, dynamic>? profile, {DateTime? now}) {
    final fromApi = profile?['premium_days_remaining'];
    if (fromApi is int && fromApi > 0) return fromApi;
    if (fromApi is num && fromApi > 0) return fromApi.round();

    final expires = parseExpiresAt(profile);
    if (expires == null) return null;

    final clock = now ?? DateTime.now();
    if (!expires.isAfter(clock)) return null;

    final hours = expires.difference(clock).inHours;
    final days = (hours / 24).ceil();
    return days < 1 ? 1 : days;
  }

  /// Single source of truth for "does this account have premium privileges",
  /// aligned with UserModel.hasPremiumPrivileges so the pricing page and the
  /// feed never disagree:
  ///   - blue/gold/black verification ticks = permanent privileges (no expiry)
  ///   - role == 'premium' = subscription, expiry-gated by daysRemaining
  static bool isPremiumActive(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final verification = profile['verification_type']?.toString();
    const permanentTicks = {'blueTick', 'goldTick', 'blackTick'};
    if (permanentTicks.contains(verification)) return true;

    if (profile['role']?.toString() == 'premium') {
      final days = daysRemaining(profile);
      return days != null && days > 0;
    }
    return false;
  }

  /// برچسب فارسی برای نمایش در تنظیمات / صفحه پریمیوم.
  static String remainingLabel(Map<String, dynamic>? profile) {
    final days = daysRemaining(profile);
    if (days == null || days <= 0) {
      return 'اشتراک منقضی شده — برای ادامه تمدید کنید';
    }
    if (days == 1) return '۱ روز تا پایان پریمیوم';
    return '${_faDigits(days)} روز تا پایان پریمیوم';
  }

  static String extendHintForPlan(String planTitle) {
    return 'با خرید پلن $planTitle، مدت به روزهای باقی‌مانده اضافه می‌شود.';
  }

  static String formatExpiryDate(Map<String, dynamic>? profile) {
    final expires = parseExpiresAt(profile);
    if (expires == null) return '';
    // Jalali + Persian digits to match the fully-RTL premium page (was
    // Gregorian YYYY/MM/DD).
    final j = Jalali.fromDateTime(expires);
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    final hh = expires.hour.toString().padLeft(2, '0');
    final mm = expires.minute.toString().padLeft(2, '0');
    return _faDigitsStr('${j.year}/$m/$d $hh:$mm');
  }

  static String _faDigitsStr(String s) {
    const map = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return s.split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : map[i];
    }).join();
  }

  static String _faDigits(int n) {
    const map = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i == null ? c : map[i];
    }).join();
  }
}
