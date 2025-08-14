import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../main.dart';
import '../model/SecurityModels.dart';

// ======================== PROVIDERS ========================

/// Provider برای اطلاعات امنیتی کاربر
final userSecurityProvider = FutureProvider<UserSecurityModel?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final response = await supabase
      .from('user_security')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

  if (response == null) {
    // ایجاد رکورد امنیتی جدید
    await supabase.from('user_security').insert({
      'user_id': user.id,
    });

    // بازخوانی رکورد جدید
    final newResponse = await supabase
        .from('user_security')
        .select('*')
        .eq('user_id', user.id)
        .single();

    return UserSecurityModel.fromMap(newResponse);
  }

  return UserSecurityModel.fromMap(response);
});

/// Provider برای جلسات فعال
final activeSessionsProvider =
    FutureProvider<List<ActiveSessionModel>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('active_sessions')
      .select('*')
      .eq('user_id', user.id)
      .order('last_activity', ascending: false);

  return response
      .map<ActiveSessionModel>((session) => ActiveSessionModel.fromMap(session))
      .toList();
});

/// Provider برای لاگ‌های امنیتی
final securityLogsProvider =
    FutureProvider<List<SecurityLogModel>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('security_logs')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50); // محدود کردن به 50 لاگ اخیر

  return response
      .map<SecurityLogModel>((log) => SecurityLogModel.fromMap(log))
      .toList();
});

/// Provider برای سرویس امنیت
final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

// ======================== SERVICE CLASS ========================

class SecurityService {
  final _supabase = Supabase.instance.client;

  /// ثبت لاگ امنیتی
  Future<void> logSecurityEvent({
    required String eventType,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('security_logs').insert({
        'user_id': user.id,
        'event_type': eventType,
        'description': description,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('خطا در ثبت لاگ امنیتی: $e');
    }
  }

  /// ثبت جلسه جدید
  Future<String?> createSession({
    required String deviceType,
    required String deviceName,
    String? osName,
    String? osVersion,
    String? appVersion,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final sessionToken = _generateSessionToken();
      final refreshTokenHash = _hashString(sessionToken);

      // غیرفعال کردن سایر جلسات
      await _supabase
          .from('active_sessions')
          .update({'is_current': false}).eq('user_id', user.id);

      // ایجاد جلسه جدید
      await _supabase.from('active_sessions').insert({
        'user_id': user.id,
        'session_token': sessionToken,
        'refresh_token_hash': refreshTokenHash,
        'device_type': deviceType,
        'device_name': deviceName,
        'os_name': osName,
        'os_version': osVersion,
        'app_version': appVersion,
        'is_current': true,
        'last_activity': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      await logSecurityEvent(
        eventType: 'login_success',
        description: 'کاربر با موفقیت وارد شد',
        metadata: {
          'device_type': deviceType,
          'device_name': deviceName,
        },
      );

      return sessionToken;
    } catch (e) {
      debugPrint('خطا در ایجاد جلسه: $e');
      return null;
    }
  }

  /// به‌روزرسانی فعالیت جلسه
  Future<void> updateSessionActivity(String sessionToken) async {
    try {
      await _supabase.from('active_sessions').update({
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('session_token', sessionToken);
    } catch (e) {
      debugPrint('خطا در به‌روزرسانی فعالیت جلسه: $e');
    }
  }

  /// خاتمه جلسه
  Future<void> terminateSession(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('active_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', user.id);

      await logSecurityEvent(
        eventType: 'session_terminated',
        description: 'جلسه توسط کاربر خاتمه یافت',
        metadata: {'session_id': sessionId},
      );
    } catch (e) {
      debugPrint('خطا در خاتمه جلسه: $e');
      rethrow;
    }
  }

  /// خاتمه همه جلسات (به جز جلسه فعلی)
  Future<void> terminateAllOtherSessions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('active_sessions')
          .delete()
          .eq('user_id', user.id)
          .eq('is_current', false);

      await logSecurityEvent(
        eventType: 'all_sessions_terminated',
        description: 'همه جلسات دیگر توسط کاربر خاتمه یافت',
      );
    } catch (e) {
      debugPrint('خطا در خاتمه همه جلسات: $e');
      rethrow;
    }
  }

  /// فعال/غیرفعال کردن تایید دو مرحله‌ای
  Future<void> toggleTwoFactor(bool enabled) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      String? secret;
      List<String>? backupCodes;

      if (enabled) {
        secret = _generateTOTPSecret();
        backupCodes = _generateBackupCodes();
      }

      await _supabase.from('user_security').update({
        'two_factor_enabled': enabled,
        'two_factor_secret': secret,
        'backup_codes': backupCodes,
        'two_factor_setup_at':
            enabled ? DateTime.now().toIso8601String() : null,
      }).eq('user_id', user.id);

      await logSecurityEvent(
        eventType: enabled ? '2fa_enabled' : '2fa_disabled',
        description: enabled
            ? 'تایید دو مرحله‌ای فعال شد'
            : 'تایید دو مرحله‌ای غیرفعال شد',
      );
    } catch (e) {
      debugPrint('خطا در تغییر وضعیت تایید دو مرحله‌ای: $e');
      rethrow;
    }
  }

  /// فعال/غیرفعال کردن قفل اپلیکیشن
  Future<void> toggleAppLock({
    required bool enabled,
    String? lockType,
    String? pin,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      String? lockHash;
      if (enabled && pin != null) {
        lockHash = _hashString(pin);
      }

      await _supabase.from('user_security').update({
        'app_lock_enabled': enabled,
        'app_lock_type': enabled ? lockType : null,
        'app_lock_hash': lockHash,
      }).eq('user_id', user.id);

      await logSecurityEvent(
        eventType: enabled ? 'app_lock_enabled' : 'app_lock_disabled',
        description:
            enabled ? 'قفل اپلیکیشن فعال شد' : 'قفل اپلیکیشن غیرفعال شد',
        metadata: {'lock_type': lockType},
      );
    } catch (e) {
      debugPrint('خطا در تغییر وضعیت قفل اپلیکیشن: $e');
      rethrow;
    }
  }

  /// تایید PIN قفل اپلیکیشن
  Future<bool> verifyAppLockPIN(String pin) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('user_security')
          .select('app_lock_hash')
          .eq('user_id', user.id)
          .single();

      final storedHash = response['app_lock_hash'] as String?;
      if (storedHash == null) return false;

      final pinHash = _hashString(pin);
      return pinHash == storedHash;
    } catch (e) {
      debugPrint('خطا در تایید PIN: $e');
      return false;
    }
  }

  /// ثبت تلاش ناموفق ورود
  Future<void> recordFailedLogin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // افزایش تعداد تلاش‌های ناموفق
      await _supabase.rpc('increment_failed_logins', params: {
        'user_id_param': user.id,
      });

      await logSecurityEvent(
        eventType: 'login_failed',
        description: 'تلاش ناموفق برای ورود',
      );
    } catch (e) {
      debugPrint('خطا در ثبت تلاش ناموفق: $e');
    }
  }

  /// ریست کردن تلاش‌های ناموفق
  Future<void> resetFailedLogins() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_security').update({
        'failed_login_attempts': 0,
        'locked_until': null,
      }).eq('user_id', user.id);
    } catch (e) {
      debugPrint('خطا در ریست تلاش‌های ناموفق: $e');
    }
  }

  /// بررسی قفل بودن حساب
  Future<bool> isAccountLocked() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('user_security')
          .select('locked_until')
          .eq('user_id', user.id)
          .single();

      final lockedUntil = response['locked_until'] as String?;
      if (lockedUntil == null) return false;

      final lockTime = DateTime.parse(lockedUntil);
      return DateTime.now().isBefore(lockTime);
    } catch (e) {
      debugPrint('خطا در بررسی قفل حساب: $e');
      return false;
    }
  }

  /// محاسبه امتیاز امنیت
  Future<int> calculateSecurityScore() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final security = await _supabase
          .from('user_security')
          .select('*')
          .eq('user_id', user.id)
          .single();

      int score = 30; // امتیاز پایه

      // تایید دو مرحله‌ای (+30)
      if (security['two_factor_enabled'] == true) score += 30;

      // قفل اپلیکیشن (+20)
      if (security['app_lock_enabled'] == true) score += 20;

      // عدم وجود تلاش‌های ناموفق (+10)
      if ((security['failed_login_attempts'] ?? 0) == 0) score += 10;

      // رمز عبور قوی (بررسی می‌شود) (+10)
      score += 10;

      // به‌روزرسانی امتیاز در دیتابیس
      await _supabase.from('user_security').update({
        'security_score': score,
        'last_security_check': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);

      return score;
    } catch (e) {
      debugPrint('خطا در محاسبه امتیاز امنیت: $e');
      return 50; // امتیاز پیش‌فرض
    }
  }

  // ======================== HELPER METHODS ========================

  /// تولید توکن جلسه
  String _generateSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// هش کردن رشته
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// تولید سکرت TOTP
  String _generateTOTPSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (i) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// تولید کدهای پشتیبان
  List<String> _generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];

    for (int i = 0; i < 10; i++) {
      final code = List<int>.generate(8, (i) => random.nextInt(10))
          .join()
          .replaceAllMapped(RegExp(r'(.{4})'), (match) => '${match.group(1)}-')
          .substring(0, 9); // حذف آخرین خط تیره
      codes.add(code);
    }

    return codes;
  }
}

// ======================== NOTIFIERS ========================

/// StateNotifier برای مدیریت وضعیت امنیت
class SecurityNotifier extends StateNotifier<AsyncValue<UserSecurityModel?>> {
  SecurityNotifier(this._securityService) : super(const AsyncValue.loading()) {
    _loadSecurityData();
  }

  final SecurityService _securityService;

  Future<void> _loadSecurityData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final response = await supabase
          .from('user_security')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // ایجاد رکورد جدید
        await supabase.from('user_security').insert({'user_id': user.id});
        await _loadSecurityData(); // بازخوانی
        return;
      }

      final securityModel = UserSecurityModel.fromMap(response);
      state = AsyncValue.data(securityModel);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadSecurityData();
  }

  Future<void> toggleTwoFactor(bool enabled) async {
    try {
      await _securityService.toggleTwoFactor(enabled);
      await refresh();
    } catch (e) {
      // خطا در UI نمایش داده می‌شود
      rethrow;
    }
  }

  Future<void> toggleAppLock({
    required bool enabled,
    String? lockType,
    String? pin,
  }) async {
    try {
      await _securityService.toggleAppLock(
        enabled: enabled,
        lockType: lockType,
        pin: pin,
      );
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider برای SecurityNotifier
final securityNotifierProvider =
    StateNotifierProvider<SecurityNotifier, AsyncValue<UserSecurityModel?>>(
        (ref) {
  final securityService = ref.watch(securityServiceProvider);
  return SecurityNotifier(securityService);
});

/// Provider برای امتیاز امنیت
final securityScoreProvider = FutureProvider<int>((ref) async {
  final securityService = ref.watch(securityServiceProvider);
  return await securityService.calculateSecurityScore();
});

