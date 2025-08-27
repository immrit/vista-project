import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'totp_service.dart';
import '../services/ActiveSessionsService.dart';

/// سرویس مدیریت احراز هویت دو مرحله‌ای ساده
/// کاربر خودش رمز 6 رقمی تعیین می‌کند
class Simple2FAService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // کلیدهای ذخیره‌سازی
  static const String _secretKey = '2fa_secret_key';
  static const String _userCodeKey = '2fa_user_code'; // کد تعیین شده توسط کاربر
  static const String _backupCodesKey = '2fa_backup_codes';
  static const String _isEnabledKey = '2fa_is_enabled';

  // کلیدهای جدید برای مدیریت نشست
  static const String _sessionVerifiedKey = '2fa_session_verified';
  static const String _sessionVerifiedAtKey = '2fa_session_verified_at';
  static const String _sessionExpiryKey = '2fa_session_expiry';
  static const String _activeSessionKey = '2fa_active_session_id';
  static const String _lastLoginTimeKey = '2fa_last_login_time';
  static const String _currentUserIdKey = '2fa_current_user_id';

  /// فعال‌سازی 2FA با کد تعیین شده توسط کاربر
  static Future<Map<String, dynamic>> enable2FA(
      String userId, String userCode) async {
    try {
      developer.log('Enabling 2FA for user: $userId', name: 'Simple2FAService');
      developer.log('User code: $userCode', name: 'Simple2FAService');

      // اعتبارسنجی کد کاربر
      if (!TOTPService.validateCode('', userCode)) {
        developer.log('Invalid user code format: $userCode',
            name: 'Simple2FAService');
        return {
          'success': false,
          'message': 'کد باید دقیقاً 6 رقم باشد',
        };
      }

      developer.log('User code validation passed', name: 'Simple2FAService');

      // تولید کدهای بکاپ
      final backupCodes = TOTPService.generateBackupCodes();
      developer.log('Generated ${backupCodes.length} backup codes',
          name: 'Simple2FAService');

      // تولید کلید مخفی (برای امنیت)
      final secretKey = TOTPService.generateSecretKey();
      developer.log('Generated secret key: ${secretKey.substring(0, 8)}...',
          name: 'Simple2FAService');

      // ذخیره در دیتابیس Supabase با استفاده از تابع
      final supabase = Supabase.instance.client;

      developer.log('Calling enable_2fa RPC function...',
          name: 'Simple2FAService');

      // استفاده از تابع enable_2fa
      final response = await supabase.rpc('enable_2fa', params: {
        'user_uuid': userId,
        'user_code_input': userCode,
        'secret_key_input': secretKey,
        'backup_codes_input': backupCodes,
      });

      developer.log('Database response: $response', name: 'Simple2FAService');
      developer.log('Response type: ${response.runtimeType}',
          name: 'Simple2FAService');

      if (response == null || response['success'] != true) {
        developer.log('RPC function failed or returned false success',
            name: 'Simple2FAService');
        throw Exception(
            'خطا در ذخیره تنظیمات 2FA: ${response?['message'] ?? 'Unknown error'}');
      }

      developer.log('RPC function succeeded, updating local storage...',
          name: 'Simple2FAService');

      // فقط پس از موفقیت در دیتابیس، حافظه محلی را به‌روزرسانی کن
      await _storage.write(key: _secretKey, value: secretKey);
      await _storage.write(key: _userCodeKey, value: userCode);
      await _storage.write(key: _backupCodesKey, value: backupCodes.join(','));
      await _storage.write(key: _isEnabledKey, value: 'true');

      developer.log('Local storage updated successfully',
          name: 'Simple2FAService');

      // بررسی مجدد وضعیت از دیتابیس
      final verificationStatus = await is2FAEnabled(userId);
      developer.log(
          'Verification: 2FA status after enabling: $verificationStatus',
          name: 'Simple2FAService');

      return {
        'success': true,
        'message': 'احراز هویت دو مرحله‌ای فعال شد',
        'backupCodes': backupCodes,
      };
    } catch (e) {
      developer.log('Error enabling 2FA: $e', name: 'Simple2FAService');
      // در صورت خطا، حافظه محلی را پاک کن
      await clearAll2FAData();
      return {
        'success': false,
        'message': 'خطا در فعال‌سازی: $e',
      };
    }
  }

  /// غیرفعال‌سازی 2FA
  static Future<Map<String, dynamic>> disable2FA(String userId) async {
    try {
      developer.log('Disabling 2FA for user: $userId',
          name: 'Simple2FAService');

      final supabase = Supabase.instance.client;

      // حذف از حافظه امن
      await _storage.delete(key: _secretKey);
      await _storage.delete(key: _userCodeKey);
      await _storage.delete(key: _backupCodesKey);
      await _storage.delete(key: _isEnabledKey);

      // غیرفعال کردن در دیتابیس با استفاده از تابع
      final response = await supabase.rpc('disable_2fa', params: {
        'user_uuid': userId,
      });

      developer.log('Disable 2FA response: $response',
          name: 'Simple2FAService');

      if (response == null || response['success'] != true) {
        throw Exception(
            'خطا در غیرفعال‌سازی: ${response?['message'] ?? 'Unknown error'}');
      }

      return {
        'success': true,
        'message': 'احراز هویت دو مرحله‌ای غیرفعال شد',
      };
    } catch (e) {
      developer.log('Error disabling 2FA: $e', name: 'Simple2FAService');
      return {
        'success': false,
        'message': 'خطا در غیرفعال‌سازی: $e',
      };
    }
  }

  /// بررسی وضعیت 2FA
  static Future<bool> is2FAEnabled(String userId) async {
    try {
      developer.log('Checking 2FA status for user: $userId',
          name: 'Simple2FAService');

      // همیشه ابتدا از دیتابیس بررسی کن (منبع اصلی حقیقت)
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_security')
          .select('two_factor_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        developer.log('No security record found for user: $userId',
            name: 'Simple2FAService');
        // پاک کردن حافظه محلی اگر رکورد در دیتابیس وجود ندارد
        await _storage.delete(key: _isEnabledKey);
        return false;
      }

      final isEnabledInDb = response['two_factor_enabled'] == true;
      developer.log('2FA status from database: $isEnabledInDb',
          name: 'Simple2FAService');

      // همگام‌سازی حافظه محلی با دیتابیس
      if (isEnabledInDb) {
        await _storage.write(key: _isEnabledKey, value: 'true');
      } else {
        await _storage.delete(key: _isEnabledKey);
      }

      return isEnabledInDb;
    } catch (e) {
      developer.log('Error checking 2FA status: $e', name: 'Simple2FAService');
      // در صورت خطا، حافظه محلی را پاک کن و false برگردان
      await _storage.delete(key: _isEnabledKey);
      return false;
    }
  }

  /// بررسی اینکه آیا نشست فعلی تایید 2FA شده یا نه
  static Future<bool> isSessionVerified(String userId) async {
    try {
      developer.log('=== IS SESSION VERIFIED START ===',
          name: 'Simple2FAService');
      developer.log('Checking if 2FA session is verified for user: $userId',
          name: 'Simple2FAService');

      // ابتدا از FlutterSecureStorage بررسی کن
      String? isVerified = await _storage.read(key: _sessionVerifiedKey);
      String? verifiedAt = await _storage.read(key: _sessionVerifiedAtKey);
      String? sessionExpiry = await _storage.read(key: _sessionExpiryKey);

      developer.log('FlutterSecureStorage check:', name: 'Simple2FAService');
      developer.log('  isVerified: $isVerified', name: 'Simple2FAService');
      developer.log('  verifiedAt: $verifiedAt', name: 'Simple2FAService');
      developer.log('  sessionExpiry: $sessionExpiry',
          name: 'Simple2FAService');

      // اگر در FlutterSecureStorage نبود، از SharedPreferences بررسی کن
      if (isVerified == null || verifiedAt == null || sessionExpiry == null) {
        developer.log(
            'Data not found in FlutterSecureStorage, checking SharedPreferences',
            name: 'Simple2FAService');

        final prefs = await SharedPreferences.getInstance();
        isVerified = prefs.getString('${_sessionVerifiedKey}_$userId');
        verifiedAt = prefs.getString('${_sessionVerifiedAtKey}_$userId');
        sessionExpiry = prefs.getString('${_sessionExpiryKey}_$userId');

        developer.log('SharedPreferences check:', name: 'Simple2FAService');
        developer.log('  isVerified: $isVerified', name: 'Simple2FAService');
        developer.log('  verifiedAt: $verifiedAt', name: 'Simple2FAService');
        developer.log('  sessionExpiry: $sessionExpiry',
            name: 'Simple2FAService');

        // اگر در SharedPreferences یافت شد، در FlutterSecureStorage هم ذخیره کن
        if (isVerified != null && verifiedAt != null && sessionExpiry != null) {
          developer.log(
              'Data found in SharedPreferences, restoring to FlutterSecureStorage',
              name: 'Simple2FAService');
          await _storage.write(key: _sessionVerifiedKey, value: isVerified);
          await _storage.write(key: _sessionVerifiedAtKey, value: verifiedAt);
          await _storage.write(key: _sessionExpiryKey, value: sessionExpiry);

          developer.log('Data restored to FlutterSecureStorage',
              name: 'Simple2FAService');
        }
      }

      if (isVerified != 'true' || verifiedAt == null || sessionExpiry == null) {
        developer.log('❌ No verified session found in any storage',
            name: 'Simple2FAService');
        developer.log('=== IS SESSION VERIFIED END (FALSE) ===',
            name: 'Simple2FAService');
        return false;
      }

      // بررسی انقضای نشست
      final expiryTime = DateTime.tryParse(sessionExpiry);
      if (expiryTime == null) {
        developer.log('❌ Invalid expiry time format: $sessionExpiry',
            name: 'Simple2FAService');
        developer.log(
            '=== IS SESSION VERIFIED END (FALSE - INVALID EXPIRY) ===',
            name: 'Simple2FAService');
        return false;
      }

      if (DateTime.now().isAfter(expiryTime)) {
        developer.log('❌ Session has expired, clearing verification data',
            name: 'Simple2FAService');
        await clearSessionVerification();
        developer.log('=== IS SESSION VERIFIED END (FALSE - EXPIRED) ===',
            name: 'Simple2FAService');
        return false;
      }

      developer.log('✅ Session is verified and not expired',
          name: 'Simple2FAService');
      developer.log('  Expires at: $expiryTime', name: 'Simple2FAService');
      developer.log('  Current time: ${DateTime.now()}',
          name: 'Simple2FAService');
      developer.log('=== IS SESSION VERIFIED END (TRUE) ===',
          name: 'Simple2FAService');
      return true;
    } catch (e) {
      developer.log('❌ Error checking session verification: $e',
          name: 'Simple2FAService');
      developer.log('=== IS SESSION VERIFIED END (ERROR) ===',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// علامت‌گذاری نشست فعلی به عنوان تایید شده
  static Future<void> markSessionAsVerified(String userId) async {
    try {
      developer.log('=== MARKING SESSION AS VERIFIED START ===',
          name: 'Simple2FAService');
      developer.log('Marking 2FA session as verified for user: $userId',
          name: 'Simple2FAService');

      // تنظیم زمان انقضای نشست (24 ساعت)
      final expiryTime = DateTime.now().add(const Duration(hours: 24));
      final now = DateTime.now();

      developer.log('Current time: $now', name: 'Simple2FAService');
      developer.log('Expiry time: $expiryTime', name: 'Simple2FAService');

      // ذخیره در FlutterSecureStorage
      developer.log('Writing to FlutterSecureStorage...',
          name: 'Simple2FAService');
      await _storage.write(key: _sessionVerifiedKey, value: 'true');
      await _storage.write(
          key: _sessionVerifiedAtKey, value: now.toIso8601String());
      await _storage.write(
          key: _sessionExpiryKey, value: expiryTime.toIso8601String());

      // ذخیره در SharedPreferences به عنوان پشتیبان
      developer.log('Writing to SharedPreferences...',
          name: 'Simple2FAService');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_sessionVerifiedKey}_$userId', 'true');
      await prefs.setString(
          '${_sessionVerifiedAtKey}_$userId', now.toIso8601String());
      await prefs.setString(
          '${_sessionExpiryKey}_$userId', expiryTime.toIso8601String());

      // ایجاد نشست فعال جدید در حافظه محلی
      final sessionId = await _createNewActiveSession(userId);
      developer.log('Created local active session: $sessionId',
          name: 'Simple2FAService');

      // ایجاد نشست فعال در دیتابیس
      try {
        final dbSession =
            await ActiveSessionsService.createLoginSession(userId);
        developer.log('Created database session: ${dbSession['id']}',
            name: 'Simple2FAService');
      } catch (e) {
        developer.log('Error creating database session: $e',
            name: 'Simple2FAService');
        // ادامه کار با نشست محلی
      }

      developer.log('Session marked as verified:', name: 'Simple2FAService');
      developer.log('  Verified at: $now', name: 'Simple2FAService');
      developer.log('  Expires at: $expiryTime', name: 'Simple2FAService');
      developer.log('  User ID: $userId', name: 'Simple2FAService');
      developer.log('  Active Session ID: $sessionId',
          name: 'Simple2FAService');

      // تایید ذخیره‌سازی
      developer.log('Verifying storage...', name: 'Simple2FAService');
      final verifyStorage = await _storage.read(key: _sessionVerifiedKey);
      final verifyPrefs = prefs.getString('${_sessionVerifiedKey}_$userId');
      developer.log('Storage verification:', name: 'Simple2FAService');
      developer.log('  FlutterSecureStorage: $verifyStorage',
          name: 'Simple2FAService');
      developer.log('  SharedPreferences: $verifyPrefs',
          name: 'Simple2FAService');

      // بررسی کامل ذخیره‌سازی
      final allStorageKeys = await _storage.readAll();
      developer.log('All FlutterSecureStorage keys: ${allStorageKeys.keys}',
          name: 'Simple2FAService');

      final allPrefsKeys = prefs.getKeys();
      developer.log('All SharedPreferences keys: $allPrefsKeys',
          name: 'Simple2FAService');

      developer.log('=== MARKING SESSION AS VERIFIED END ===',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error marking session as verified: $e',
          name: 'Simple2FAService');
      rethrow;
    }
  }

  /// ایجاد نشست فعال جدید برای کاربر
  static Future<String> _createNewActiveSession(String userId) async {
    try {
      // تولید شناسه نشست منحصر به فرد
      final sessionId =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

      // ذخیره شناسه نشست فعال
      await _storage.write(key: _activeSessionKey, value: sessionId);

      // ذخیره زمان آخرین ورود
      final loginTime = DateTime.now().toIso8601String();
      await _storage.write(key: _lastLoginTimeKey, value: loginTime);

      // ذخیره شناسه کاربر فعلی
      await _storage.write(key: _currentUserIdKey, value: userId);

      developer.log('Created new active session: $sessionId for user: $userId',
          name: 'Simple2FAService');

      return sessionId;
    } catch (e) {
      developer.log('Error creating new active session: $e',
          name: 'Simple2FAService');
      return '';
    }
  }

  /// پاک کردن اطلاعات تایید نشست
  static Future<void> clearSessionVerification() async {
    try {
      // پاک کردن از FlutterSecureStorage
      await _storage.delete(key: _sessionVerifiedKey);
      await _storage.delete(key: _sessionVerifiedAtKey);
      await _storage.delete(key: _sessionExpiryKey);
      await _storage.delete(key: _activeSessionKey);
      await _storage.delete(key: _lastLoginTimeKey);
      await _storage.delete(key: _currentUserIdKey);

      // پاک کردن از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await prefs.remove('${_sessionVerifiedKey}_$userId');
        await prefs.remove('${_sessionVerifiedAtKey}_$userId');
        await prefs.remove('${_sessionExpiryKey}_$userId');
      }

      // پاک کردن نشست‌های دیتابیس
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ActiveSessionsService.deleteAllUserSessions(userId);
          developer.log('Database sessions cleared for user: $userId',
              name: 'Simple2FAService');
        }
      } catch (e) {
        developer.log('Error clearing database sessions: $e',
            name: 'Simple2FAService');
      }

      developer.log(
          'Session verification data and active session cleared from all storage',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error clearing session verification: $e',
          name: 'Simple2FAService');
    }
  }

  /// پاک کردن اجباری اطلاعات تایید نشست (برای خروج از حساب)
  static Future<void> forceClearSessionVerification() async {
    try {
      developer.log('Force clearing session verification data',
          name: 'Simple2FAService');

      // پاک کردن از FlutterSecureStorage
      await _storage.delete(key: _sessionVerifiedKey);
      await _storage.delete(key: _sessionVerifiedAtKey);
      await _storage.delete(key: _sessionExpiryKey);
      await _storage.delete(key: _activeSessionKey);
      await _storage.delete(key: _lastLoginTimeKey);
      await _storage.delete(key: _currentUserIdKey);

      // پاک کردن از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await prefs.remove('${_sessionVerifiedKey}_$userId');
        await prefs.remove('${_sessionVerifiedAtKey}_$userId');
        await prefs.remove('${_sessionExpiryKey}_$userId');
      }

      // پاک کردن از تمام کلیدهای ممکن
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_sessionVerifiedKey) ||
            key.startsWith(_sessionVerifiedAtKey) ||
            key.startsWith(_sessionExpiryKey) ||
            key.startsWith(_activeSessionKey) ||
            key.startsWith(_lastLoginTimeKey) ||
            key.startsWith(_currentUserIdKey)) {
          await prefs.remove(key);
        }
      }

      // پاک کردن نشست‌های دیتابیس
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ActiveSessionsService.deleteAllUserSessions(userId);
          developer.log('Database sessions force cleared for user: $userId',
              name: 'Simple2FAService');
        }
      } catch (e) {
        // خطاهای مربوط به جدول موجود نبودن را نادیده بگیر
        if (e.toString().contains('جدول نشست‌های فعال موجود نیست') ||
            e
                .toString()
                .contains('relation "active_sessions" does not exist') ||
            e.toString().contains('table "active_sessions" does not exist')) {
          developer.log(
              'Active sessions table does not exist, skipping database cleanup',
              name: 'Simple2FAService');
        } else {
          developer.log('Error force clearing database sessions: $e',
              name: 'Simple2FAService');
        }
      }

      developer.log('Session verification data force cleared from all storage',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error force clearing session verification: $e',
          name: 'Simple2FAService');
    }
  }

  /// بررسی و پاک کردن خودکار نشست‌های منقضی شده
  static Future<void> cleanupExpiredSessions() async {
    try {
      developer.log('Cleaning up expired 2FA sessions',
          name: 'Simple2FAService');

      final verifiedAt = await _storage.read(key: _sessionVerifiedAtKey);
      final sessionExpiry = await _storage.read(key: _sessionExpiryKey);

      if (verifiedAt != null && sessionExpiry != null) {
        final expiryTime = DateTime.tryParse(sessionExpiry);
        if (expiryTime != null && DateTime.now().isAfter(expiryTime)) {
          developer.log('Found expired session, clearing verification data',
              name: 'Simple2FAService');
          await clearSessionVerification();
        }
      }
    } catch (e) {
      developer.log('Error cleaning up expired sessions: $e',
          name: 'Simple2FAService');
    }
  }

  /// آماده‌سازی برای ورود جدید کاربر
  static Future<void> prepareForNewLogin(String userId) async {
    try {
      developer.log('Preparing for new login for user: $userId',
          name: 'Simple2FAService');

      // پاک کردن نشست‌های قبلی کاربر
      await clearSessionVerification();

      // پاک کردن نشست‌های دیتابیس
      try {
        await ActiveSessionsService.deleteAllUserSessions(userId);
        developer.log('Database sessions cleared for new login',
            name: 'Simple2FAService');
      } catch (e) {
        developer.log('Error clearing database sessions for new login: $e',
            name: 'Simple2FAService');
      }

      developer.log('New login preparation completed for user: $userId',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error preparing for new login: $e',
          name: 'Simple2FAService');
    }
  }

  /// لیست تمام کلیدهای موجود در SharedPreferences
  static Future<List<String>> listAllSharedPreferencesKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      developer.log('All SharedPreferences keys: $allKeys',
          name: 'Simple2FAService');
      return allKeys;
    } catch (e) {
      developer.log('Error listing SharedPreferences keys: $e',
          name: 'Simple2FAService');
      return [];
    }
  }

  /// تست عملکرد SharedPreferences
  static Future<bool> testSharedPreferences() async {
    try {
      developer.log('Testing SharedPreferences...', name: 'Simple2FAService');

      final prefs = await SharedPreferences.getInstance();
      const testKey = 'test_shared_prefs_key';
      const testValue = 'test_shared_prefs_value';

      // تست نوشتن
      await prefs.setString(testKey, testValue);
      developer.log('SharedPreferences write test completed',
          name: 'Simple2FAService');

      // تست خواندن
      final readValue = prefs.getString(testKey);
      final isWorking = readValue == testValue;

      // پاک کردن تست
      await prefs.remove(testKey);

      developer.log('SharedPreferences test result: $isWorking',
          name: 'Simple2FAService');
      return isWorking;
    } catch (e) {
      developer.log('SharedPreferences test failed: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// تست عملکرد FlutterSecureStorage
  static Future<bool> testStorage() async {
    try {
      developer.log('Testing FlutterSecureStorage...',
          name: 'Simple2FAService');

      // تست نوشتن
      const testKey = 'test_key';
      const testValue = 'test_value';
      await _storage.write(key: testKey, value: testValue);

      // تست خواندن
      final readValue = await _storage.read(key: testKey);
      final isWorking = readValue == testValue;

      // پاک کردن تست
      await _storage.delete(key: testKey);

      developer.log('FlutterSecureStorage test result: $isWorking',
          name: 'Simple2FAService');
      return isWorking;
    } catch (e) {
      developer.log('FlutterSecureStorage test failed: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// متد debug برای بررسی وضعیت نشست
  static Future<Map<String, dynamic>> debugSessionStatus(String userId) async {
    try {
      developer.log('=== DEBUG SESSION STATUS ===', name: 'Simple2FAService');

      // بررسی FlutterSecureStorage
      final isVerified = await _storage.read(key: _sessionVerifiedKey);
      final verifiedAt = await _storage.read(key: _sessionVerifiedAtKey);
      final sessionExpiry = await _storage.read(key: _sessionExpiryKey);
      final is2FAEnabled = await _storage.read(key: _isEnabledKey);

      developer.log('FlutterSecureStorage:', name: 'Simple2FAService');
      developer.log('  Session Verified Key: $isVerified',
          name: 'Simple2FAService');
      developer.log('  Session Verified At: $verifiedAt',
          name: 'Simple2FAService');
      developer.log('  Session Expiry: $sessionExpiry',
          name: 'Simple2FAService');
      developer.log('  2FA Enabled Key: $is2FAEnabled',
          name: 'Simple2FAService');

      // بررسی SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final spIsVerified = prefs.getString('${_sessionVerifiedKey}_$userId');
      final spVerifiedAt = prefs.getString('${_sessionVerifiedAtKey}_$userId');
      final spSessionExpiry = prefs.getString('${_sessionExpiryKey}_$userId');

      developer.log('SharedPreferences:', name: 'Simple2FAService');
      developer.log('  Session Verified Key: $spIsVerified',
          name: 'Simple2FAService');
      developer.log('  Session Verified At: $spVerifiedAt',
          name: 'Simple2FAService');
      developer.log('  Session Expiry: $spSessionExpiry',
          name: 'Simple2FAService');

      // بررسی انقضای نشست
      DateTime? expiryTime;
      bool isExpired = false;
      if (sessionExpiry != null) {
        expiryTime = DateTime.tryParse(sessionExpiry);
        if (expiryTime != null) {
          isExpired = DateTime.now().isAfter(expiryTime);
          developer.log('Expiry Time: $expiryTime', name: 'Simple2FAService');
          developer.log('Is Expired: $isExpired', name: 'Simple2FAService');
        }
      }

      // بررسی وضعیت 2FA از دیتابیس
      final supabase = Supabase.instance.client;
      final dbResponse = await supabase
          .from('user_security')
          .select('two_factor_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      final db2FAEnabled = dbResponse?['two_factor_enabled'] ?? false;
      developer.log('Database 2FA Enabled: $db2FAEnabled',
          name: 'Simple2FAService');

      // بررسی Supabase session
      final supabaseSession = supabase.auth.currentSession;
      final supabaseExpiresAt = supabaseSession?.expiresAt;
      developer.log('Supabase Session:', name: 'Simple2FAService');
      developer.log('  Has Session: ${supabaseSession != null}',
          name: 'Simple2FAService');
      developer.log('  Expires At: $supabaseExpiresAt',
          name: 'Simple2FAService');

      // بررسی نتیجه نهایی
      final requiresVerification = await requires2FAVerification(userId);
      developer.log(
          'Final Result - Requires Verification: $requiresVerification',
          name: 'Simple2FAService');

      developer.log('=== END DEBUG ===', name: 'Simple2FAService');

      return {
        'flutter_secure_storage': {
          'session_verified': isVerified,
          'verified_at': verifiedAt,
          'session_expiry': sessionExpiry,
          '2fa_enabled': is2FAEnabled,
        },
        'shared_preferences': {
          'session_verified': spIsVerified,
          'verified_at': spVerifiedAt,
          'session_expiry': spSessionExpiry,
        },
        'database': {
          '2fa_enabled': db2FAEnabled,
        },
        'supabase_session': {
          'has_session': supabaseSession != null,
          'expires_at': supabaseExpiresAt,
        },
        'session_analysis': {
          'expiry_time': expiryTime?.toIso8601String(),
          'is_expired': isExpired,
          'requires_verification': requiresVerification,
        },
      };
    } catch (e) {
      developer.log('Error in debug session status: $e',
          name: 'Simple2FAService');
      return {'error': e.toString()};
    }
  }

  /// بررسی اینکه آیا کاربر هنوز احراز هویت شده یا نه
  static Future<bool> isUserAuthenticated() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final session = supabase.auth.currentSession;

      return user != null && session != null;
    } catch (e) {
      developer.log('Error checking user authentication: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// بررسی اعتبار نشست Supabase
  static Future<bool> isSupabaseSessionValid() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        developer.log('No Supabase session found', name: 'Simple2FAService');
        return false;
      }

      // بررسی انقضای نشست
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now();
        // تبدیل timestamp به DateTime
        final expiryDateTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);

        // بررسی اینکه آیا تاریخ انقضا معتبر است (نباید 1970 باشد)
        if (expiryDateTime.year < 2020) {
          developer.log(
              'Supabase session has invalid expiry date: $expiryDateTime, considering valid',
              name: 'Simple2FAService');
          return true; // اگر تاریخ انقضا نامعتبر است، نشست را معتبر در نظر بگیر
        }

        final isValid = now.isBefore(expiryDateTime);
        developer.log(
            'Supabase session expires at: $expiryDateTime, is valid: $isValid',
            name: 'Simple2FAService');
        return isValid;
      }

      // اگر expiresAt null باشد، نشست را معتبر در نظر بگیر
      developer.log('Supabase session has no expiry, considering valid',
          name: 'Simple2FAService');
      return true;
    } catch (e) {
      developer.log('Error checking Supabase session validity: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// بررسی نیاز به تایید 2FA برای نشست فعلی
  static Future<bool> requires2FAVerification(String userId) async {
    try {
      developer.log('🚨🚨🚨 REQUIRES 2FA VERIFICATION CALLED 🚨🚨🚨',
          name: 'Simple2FAService');
      developer.log('🚨🚨🚨 REQUIRES 2FA VERIFICATION CALLED 🚨🚨🚨',
          name: 'Simple2FAService');
      developer.log('🚨🚨🚨 REQUIRES 2FA VERIFICATION CALLED 🚨🚨🚨',
          name: 'Simple2FAService');
      developer.log('=== REQUIRES 2FA VERIFICATION START ===',
          name: 'Simple2FAService');
      developer.log(
          'Checking if 2FA verification is required for user: $userId',
          name: 'Simple2FAService');

      // ابتدا بررسی کن که آیا کاربر هنوز احراز هویت شده یا نه
      final isAuthenticated = await isUserAuthenticated();
      developer.log('User authenticated: $isAuthenticated',
          name: 'Simple2FAService');
      if (!isAuthenticated) {
        developer.log('User is not authenticated, verification required',
            name: 'Simple2FAService');
        return true;
      }

      // ابتدا بررسی کن که آیا 2FA فعال است
      final is2FAEnabled = await Simple2FAService.is2FAEnabled(userId);
      developer.log('2FA enabled: $is2FAEnabled', name: 'Simple2FAService');
      if (!is2FAEnabled) {
        developer.log('2FA is not enabled, no verification required',
            name: 'Simple2FAService');
        return false;
      }

      // بررسی اعتبار نشست Supabase
      final isSupabaseValid = await isSupabaseSessionValid();
      developer.log('Supabase session valid: $isSupabaseValid',
          name: 'Simple2FAService');
      if (!isSupabaseValid) {
        developer.log('Supabase session is not valid, verification required',
            name: 'Simple2FAService');
        return true;
      }

      // بررسی اینکه آیا نشست فعلی تایید شده یا نه
      final isSessionVerified =
          await Simple2FAService.isSessionVerified(userId);
      developer.log('Session already verified: $isSessionVerified',
          name: 'Simple2FAService');

      // اضافه کردن لاگ برای debug
      if (isSessionVerified) {
        developer.log('✅ Session is verified, should return false',
            name: 'Simple2FAService');
        developer.log('Session is already verified, no verification required',
            name: 'Simple2FAService');
        return false;
      } else {
        developer.log('❌ Session is NOT verified, continuing with logic...',
            name: 'Simple2FAService');
      }

      // اگر نشست تایید نشده، بررسی کن که آیا این اولین ورود است یا نه
      developer.log('Session not verified, checking if first time login...',
          name: 'Simple2FAService');
      // با استفاده از زمان آخرین ورود کاربر
      final shouldSkipFirstTime = await _shouldSkipFirstTime2FA(userId);
      developer.log('Should skip first time 2FA: $shouldSkipFirstTime',
          name: 'Simple2FAService');

      if (shouldSkipFirstTime) {
        developer.log('First time login detected, skipping 2FA verification',
            name: 'Simple2FAService');
        // علامت‌گذاری نشست به عنوان تایید شده
        await markSessionAsVerified(userId);
        developer.log('Session marked as verified for first time login',
            name: 'Simple2FAService');
        return false;
      }

      developer.log('2FA verification is required for this session',
          name: 'Simple2FAService');
      developer.log('=== REQUIRES 2FA VERIFICATION END ===',
          name: 'Simple2FAService');
      return true;
    } catch (e) {
      developer.log('Error checking 2FA verification requirement: $e',
          name: 'Simple2FAService');
      // در صورت خطا، تایید را الزامی در نظر بگیر
      return true;
    }
  }

  /// بررسی اینکه آیا باید 2FA را برای اولین ورود رد کرد یا نه
  static Future<bool> _shouldSkipFirstTime2FA(String userId) async {
    try {
      developer.log('=== CHECKING FIRST TIME 2FA ===',
          name: 'Simple2FAService');

      // بررسی از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastLoginKey = 'last_login_$userId';
      final lastLogin = prefs.getString(lastLoginKey);

      developer.log('Last login key: $lastLoginKey', name: 'Simple2FAService');
      developer.log('Last login value: $lastLogin', name: 'Simple2FAService');

      if (lastLogin == null) {
        // اولین ورود - ذخیره زمان ورود
        final now = DateTime.now();
        await prefs.setString(lastLoginKey, now.toIso8601String());
        developer.log('First login detected for user: $userId at $now',
            name: 'Simple2FAService');
        developer.log('=== FIRST TIME 2FA: SKIP ===', name: 'Simple2FAService');
        return true;
      }

      // بررسی اینکه آیا از آخرین ورود کمتر از 5 دقیقه گذشته یا نه
      final lastLoginTime = DateTime.tryParse(lastLogin);
      if (lastLoginTime != null) {
        final timeDiff = DateTime.now().difference(lastLoginTime);
        developer.log('Time since last login: ${timeDiff.inMinutes} minutes',
            name: 'Simple2FAService');

        if (timeDiff.inMinutes < 5) {
          developer.log(
              'Recent login detected (${timeDiff.inMinutes} minutes ago), skipping 2FA',
              name: 'Simple2FAService');
          developer.log('=== RECENT LOGIN: SKIP ===', name: 'Simple2FAService');
          return true;
        }
      }

      // به‌روزرسانی زمان آخرین ورود
      final now = DateTime.now();
      await prefs.setString(lastLoginKey, now.toIso8601String());
      developer.log('Updated last login time to: $now',
          name: 'Simple2FAService');
      developer.log('=== NOT FIRST TIME: REQUIRE 2FA ===',
          name: 'Simple2FAService');
      return false;
    } catch (e) {
      developer.log('Error checking first time 2FA: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// تمدید خودکار نشست 2FA در زمان ورود به برنامه
  static Future<void> autoExtend2FASession(String userId) async {
    try {
      developer.log('=== AUTO EXTEND 2FA SESSION START ===',
          name: 'Simple2FAService');
      developer.log('Auto-extending 2FA session for user: $userId',
          name: 'Simple2FAService');

      // بررسی اینکه آیا نشست فعلی تایید شده یا نه
      final isVerified = await isSessionVerified(userId);
      developer.log('Is session verified for auto-extend: $isVerified',
          name: 'Simple2FAService');

      if (!isVerified) {
        developer.log('No verified session to extend',
            name: 'Simple2FAService');
        developer.log('=== AUTO EXTEND 2FA SESSION END (NO SESSION) ===',
            name: 'Simple2FAService');
        return;
      }

      // تمدید نشست برای 24 ساعت دیگر
      final newExpiryTime = DateTime.now().add(const Duration(hours: 24));
      developer.log('Extending session to: $newExpiryTime',
          name: 'Simple2FAService');

      // به‌روزرسانی در FlutterSecureStorage
      await _storage.write(
          key: _sessionExpiryKey, value: newExpiryTime.toIso8601String());

      // به‌روزرسانی در SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_sessionExpiryKey}_$userId', newExpiryTime.toIso8601String());

      developer.log('2FA session auto-extended until: $newExpiryTime',
          name: 'Simple2FAService');

      // تایید تمدید
      final verifyExtend = await isSessionVerified(userId);
      developer.log('Session verification after extend: $verifyExtend',
          name: 'Simple2FAService');

      // بررسی مجدد از هر دو ذخیره‌سازی
      final storageVerified = await _storage.read(key: _sessionVerifiedKey);
      final prefs2 = await SharedPreferences.getInstance();
      final prefsVerified = prefs2.getString('${_sessionVerifiedKey}_$userId');

      developer.log('Final verification check:', name: 'Simple2FAService');
      developer.log('  FlutterSecureStorage: $storageVerified',
          name: 'Simple2FAService');
      developer.log('  SharedPreferences: $prefsVerified',
          name: 'Simple2FAService');

      developer.log('=== AUTO EXTEND 2FA SESSION END ===',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error auto-extending 2FA session: $e',
          name: 'Simple2FAService');
    }
  }

  /// تمدید نشست 2FA (برای کاربرانی که فعالانه از برنامه استفاده می‌کنند)
  static Future<void> extend2FASession(String userId) async {
    try {
      developer.log('Extending 2FA session for user: $userId',
          name: 'Simple2FAService');

      // بررسی اینکه آیا نشست فعلی تایید شده یا نه
      final isVerified = await isSessionVerified(userId);
      if (!isVerified) {
        developer.log('No verified session to extend',
            name: 'Simple2FAService');
        return;
      }

      // تمدید نشست برای 24 ساعت دیگر
      final newExpiryTime = DateTime.now().add(const Duration(hours: 24));

      // به‌روزرسانی در FlutterSecureStorage
      await _storage.write(
          key: _sessionExpiryKey, value: newExpiryTime.toIso8601String());

      // به‌روزرسانی در SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${_sessionExpiryKey}_$userId', newExpiryTime.toIso8601String());

      developer.log('2FA session extended until: $newExpiryTime',
          name: 'Simple2FAService');
    } catch (e) {
      developer.log('Error extending 2FA session: $e',
          name: 'Simple2FAService');
    }
  }

  /// بررسی وجود نشست 2FA معتبر (بدون وابستگی به Supabase session)
  static Future<bool> _hasValid2FASession(String userId) async {
    try {
      // بررسی از SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final isVerified = prefs.getString('${_sessionVerifiedKey}_$userId');
      final verifiedAt = prefs.getString('${_sessionVerifiedAtKey}_$userId');
      final sessionExpiry = prefs.getString('${_sessionExpiryKey}_$userId');

      if (isVerified != 'true' || verifiedAt == null || sessionExpiry == null) {
        return false;
      }

      // بررسی انقضای نشست
      final expiryTime = DateTime.tryParse(sessionExpiry);
      if (expiryTime == null || DateTime.now().isAfter(expiryTime)) {
        return false;
      }

      return true;
    } catch (e) {
      developer.log('Error checking valid 2FA session: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// بررسی مجدد وضعیت 2FA از دیتابیس (پاک کردن حافظه محلی)
  static Future<bool> refresh2FAStatus(String userId) async {
    try {
      developer.log('Refreshing 2FA status for user: $userId',
          name: 'Simple2FAService');

      // پاک کردن حافظه محلی برای اطمینان از دریافت داده‌های تازه
      await _storage.delete(key: _isEnabledKey);

      // بررسی مجدد از دیتابیس
      return await is2FAEnabled(userId);
    } catch (e) {
      developer.log('Error refreshing 2FA status: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// اعتبارسنجی کد 6 رقمی کاربر
  static Future<bool> validateUserCode(String userId, String code) async {
    try {
      developer.log('Validating user code for user: $userId, code: $code',
          name: 'Simple2FAService');

      // ابتدا از حافظه محلی دریافت کن
      String? userCode = await _storage.read(key: _userCodeKey);

      // اگر در حافظه محلی نبود، از دیتابیس دریافت کن
      if (userCode == null) {
        developer.log('User code not in local storage, fetching from database',
            name: 'Simple2FAService');

        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('user_security')
            .select('user_code')
            .eq('user_id', userId)
            .maybeSingle();

        if (response == null) {
          developer.log('No security record found for user: $userId',
              name: 'Simple2FAService');
          return false;
        }

        userCode = response['user_code'];
        developer.log(
            'Retrieved user code from database: ${userCode?.substring(0, 2)}...',
            name: 'Simple2FAService');

        // ذخیره در حافظه محلی
        if (userCode != null) {
          await _storage.write(key: _userCodeKey, value: userCode);
        }
      }

      // مقایسه کدها
      final isValid = userCode == code;
      developer.log('Code validation result: $isValid',
          name: 'Simple2FAService');
      return isValid;
    } catch (e) {
      developer.log('Error validating user code: $e', name: 'Simple2FAService');
      return false;
    }
  }

  /// اعتبارسنجی کد بکاپ
  static Future<bool> validateBackupCode(String userId, String code) async {
    try {
      developer.log('Validating backup code for user: $userId, code: $code',
          name: 'Simple2FAService');

      // ابتدا از حافظه محلی دریافت کن
      String? backupCodesStr = await _storage.read(key: _backupCodesKey);
      List<String> backupCodes = [];

      // اگر در حافظه محلی نبود، از دیتابیس دریافت کن
      if (backupCodesStr == null) {
        developer.log(
            'Backup codes not in local storage, fetching from database',
            name: 'Simple2FAService');

        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('user_security')
            .select('backup_codes')
            .eq('user_id', userId)
            .maybeSingle();

        if (response == null) {
          developer.log('No security record found for user: $userId',
              name: 'Simple2FAService');
          return false;
        }

        backupCodesStr = response['backup_codes'];
        developer.log('Retrieved backup codes from database',
            name: 'Simple2FAService');

        // ذخیره در حافظه محلی
        if (backupCodesStr != null) {
          await _storage.write(key: _backupCodesKey, value: backupCodesStr);
        }
      }

      backupCodes = backupCodesStr?.split(',') ?? [];
      developer.log('Available backup codes count: ${backupCodes.length}',
          name: 'Simple2FAService');

      // اعتبارسنجی کد
      if (TOTPService.validateBackupCode(backupCodes, code)) {
        developer.log('Backup code is valid, removing used code',
            name: 'Simple2FAService');

        // حذف کد استفاده شده
        final updatedCodes =
            TOTPService.removeUsedBackupCode(backupCodes, code);

        // به‌روزرسانی در حافظه محلی
        await _storage.write(
            key: _backupCodesKey, value: updatedCodes.join(','));

        // به‌روزرسانی در دیتابیس با استفاده از تابع
        final supabase = Supabase.instance.client;
        final response = await supabase.rpc('remove_used_backup_code', params: {
          'user_uuid': userId,
          'used_code': code,
        });

        developer.log('Backup code removal response: $response',
            name: 'Simple2FAService');
        return true;
      }

      developer.log('Backup code is invalid', name: 'Simple2FAService');
      return false;
    } catch (e) {
      developer.log('Error validating backup code: $e',
          name: 'Simple2FAService');
      return false;
    }
  }

  /// دریافت کدهای بکاپ
  static Future<List<String>> getBackupCodes(String userId) async {
    try {
      // ابتدا از حافظه محلی دریافت کن
      String? backupCodesStr = await _storage.read(key: _backupCodesKey);

      if (backupCodesStr != null) {
        return backupCodesStr.split(',');
      }

      // اگر در حافظه محلی نبود، از دیتابیس دریافت کن
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_security')
          .select('backup_codes')
          .eq('user_id', userId)
          .single();

      final codes = response['backup_codes'].split(',');

      // ذخیره در حافظه محلی
      await _storage.write(
          key: _backupCodesKey, value: response['backup_codes']);

      return codes;
    } catch (e) {
      print('خطا در دریافت کدهای بکاپ: $e');
      return [];
    }
  }

  /// تولید کدهای بکاپ جدید
  static Future<Map<String, dynamic>> regenerateBackupCodes(
      String userId) async {
    try {
      // تولید کدهای جدید
      final newBackupCodes = TOTPService.generateBackupCodes();

      // به‌روزرسانی در حافظه محلی
      await _storage.write(
          key: _backupCodesKey, value: newBackupCodes.join(','));

      // به‌روزرسانی در دیتابیس
      final supabase = Supabase.instance.client;
      final response = await supabase.from('user_security').update({
        'backup_codes': newBackupCodes.join(','),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      if (response.error != null) {
        throw Exception(
            'خطا در به‌روزرسانی کدهای بکاپ: ${response.error!.message}');
      }

      return {
        'success': true,
        'message': 'کدهای بکاپ جدید تولید شدند',
        'backupCodes': newBackupCodes,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در تولید کدهای بکاپ: $e',
      };
    }
  }

  /// دریافت کلید مخفی
  static Future<String?> getSecretKey(String userId) async {
    try {
      // ابتدا از حافظه محلی دریافت کن
      String? secretKey = await _storage.read(key: _secretKey);

      if (secretKey != null) return secretKey;

      // اگر در حافظه محلی نبود، از دیتابیس دریافت کن
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_security')
          .select('two_factor_secret')
          .eq('user_id', userId)
          .single();

      secretKey = response['two_factor_secret'];

      // ذخیره در حافظه محلی
      await _storage.write(key: _secretKey, value: secretKey);

      return secretKey;
    } catch (e) {
      print('خطا در دریافت کلید مخفی: $e');
      return null;
    }
  }

  /// دریافت کد تعیین شده توسط کاربر
  static Future<String?> getUserCode(String userId) async {
    try {
      // ابتدا از حافظه محلی دریافت کن
      String? userCode = await _storage.read(key: _userCodeKey);

      if (userCode != null) return userCode;

      // اگر در حافظه محلی نبود، از دیتابیس دریافت کن
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_security')
          .select('user_code')
          .eq('user_id', userId)
          .single();

      userCode = response['user_code'];

      // ذخیره در حافظه محلی
      await _storage.write(key: _userCodeKey, value: userCode);

      return userCode;
    } catch (e) {
      print('خطا در دریافت کد کاربر: $e');
      return null;
    }
  }

  /// تولید کد پیشنهادی
  static String getSuggestedCode() {
    return TOTPService.generateSuggestedCode();
  }

  /// پاک کردن تمام داده‌های 2FA
  static Future<void> clearAll2FAData() async {
    try {
      await _storage.delete(key: _secretKey);
      await _storage.delete(key: _userCodeKey);
      await _storage.delete(key: _backupCodesKey);
      await _storage.delete(key: _isEnabledKey);
      await clearSessionVerification();
    } catch (e) {
      print('خطا در پاک کردن داده‌های 2FA: $e');
    }
  }

  /// بررسی نیاز به تایید دو مرحله‌ای
  static Future<bool> requiresTwoFactorAuth(String userId) async {
    try {
      developer.log('=== CHECKING 2FA REQUIREMENT FOR USER: $userId ===',
          name: 'Simple2FAService');

      // بررسی فعال بودن 2FA
      final response = await Supabase.instance.client
          .from('user_security')
          .select('two_factor_enabled, two_factor_secret')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        developer.log('No security record found for user: $userId',
            name: 'Simple2FAService');
        return false;
      }

      final is2FAEnabled = response['two_factor_enabled'] ?? false;
      final has2FASecret = response['two_factor_secret'] != null;

      developer.log(
          '2FA Status - Enabled: $is2FAEnabled, Has Secret: $has2FASecret',
          name: 'Simple2FAService');

      if (!is2FAEnabled || !has2FASecret) {
        developer.log('2FA is not enabled - no verification needed',
            name: 'Simple2FAService');
        return false;
      }

      // بررسی نشست فعال فعلی
      final currentActiveSession = await _storage.read(key: _activeSessionKey);
      final lastLoginTime = await _storage.read(key: _lastLoginTimeKey);
      final currentUserId = await _storage.read(key: _currentUserIdKey);

      developer.log('Current Active Session: $currentActiveSession',
          name: 'Simple2FAService');
      developer.log('Last Login Time: $lastLoginTime',
          name: 'Simple2FAService');
      developer.log('Current User ID: $currentUserId',
          name: 'Simple2FAService');

      // اگر نشست فعال وجود ندارد، نیاز به تایید 2FA است
      if (currentActiveSession == null || currentActiveSession.isEmpty) {
        developer.log('No active session found - 2FA verification required',
            name: 'Simple2FAService');
        return true;
      }

      // بررسی اینکه آیا نشست فعلی متعلق به همین کاربر است
      if (currentUserId != userId) {
        developer.log(
            'Active session belongs to different user - 2FA verification required',
            name: 'Simple2FAService');
        return true;
      }

      // بررسی اینکه آیا نشست 2FA تایید شده است
      final is2FASessionVerified = await isSessionVerified(userId);
      developer.log('2FA Session Verified: $is2FASessionVerified',
          name: 'Simple2FAService');

      if (!is2FASessionVerified) {
        developer.log('2FA session not verified - 2FA verification required',
            name: 'Simple2FAService');
        return true;
      }

      // بررسی انقضای نشست
      final sessionExpiry =
          await _storage.read(key: '${_sessionExpiryKey}_$userId');
      if (sessionExpiry != null) {
        final expiryTime = DateTime.parse(sessionExpiry);
        final now = DateTime.now();

        if (now.isAfter(expiryTime)) {
          developer.log(
              'Session expired at $expiryTime - 2FA verification required',
              name: 'Simple2FAService');
          return true;
        }
      }

      developer.log(
          'User has valid active session with verified 2FA - no verification needed',
          name: 'Simple2FAService');
      return false;
    } catch (e) {
      developer.log('Error checking 2FA requirement: $e',
          name: 'Simple2FAService');
      return false;
    }
  }
}
