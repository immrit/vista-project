import '../features/auth/providers/auth_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// CurrentUserService — منبع واحد برای آیدی کاربر فعلی
///
/// جایگزین مستقیم `legacy auth.auth.currentUser?.id`
/// بدون هیچ وابستگی به legacy auth.
/// ═══════════════════════════════════════════════════════════════
class CurrentUserService {
  static final CurrentUserService _instance = CurrentUserService._internal();
  factory CurrentUserService() => _instance;
  static CurrentUserService get instance => _instance;
  CurrentUserService._internal();

  // ─── In-memory cache ───
  static String? _cachedUserId;

  /// آیدی کاربر فعلی از cache (sync, بدون انتظار)
  static String? get cachedUserId => _cachedUserId;

  /// تنظیم cache آیدی کاربر (بعد از لاگین/رفرش)
  static void setCachedUserId(String? userId) {
    _cachedUserId = userId;
  }

  /// پاک کردن cache (بعد از لاگ‌اوت)
  static void clearCache() {
    _cachedUserId = null;
  }

  /// دریافت آیدی کاربر — اول cache، بعد SecureStorage
  ///
  /// این متد async است و از TokenStorage می‌خواند.
  /// برای موارد فوری از [cachedUserId] استفاده کن.
  Future<String?> resolveUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId;
    }

    // اگر cache خالی بود از SecureStorage بخوان
    final stored = await TokenStorage.getUserId();
    if (stored != null && stored.isNotEmpty) {
      _cachedUserId = stored;
    }
    return _cachedUserId;
  }
}
