import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/security_cache.dart';

/// سرویس مدیریت نشست‌های فعال در دیتابیس
class ActiveSessionsService {
  static const String _tableName = 'active_sessions';

  /// ایجاد نشست جدید برای کاربر
  static Future<Map<String, dynamic>> createLoginSession(
    String userId, {
    String? sessionToken,
    String? refreshTokenHash,
    String? loginMethod = 'password',
  }) async {
    try {
      developer.log('=== CREATING LOGIN SESSION START ===',
          name: 'ActiveSessionsService');
      developer.log('Creating login session for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول و دسترسی
      await _validateTableAccess();

      // تولید توکن نشست اگر ارائه نشده باشد
      final token = sessionToken ??
          'login_${DateTime.now().millisecondsSinceEpoch}_${userId}_${DateTime.now().microsecond}';

      // دریافت اطلاعات دستگاه
      final deviceInfo = await _getDeviceInfo();
      developer.log('Device info: $deviceInfo', name: 'ActiveSessionsService');

      // دریافت نسخه واقعی اپ
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      developer.log('App version: $appVersion', name: 'ActiveSessionsService');

      // دریافت اطلاعات موقعیت (IP و لوکیشن)
      final locationInfo = await _getLocationInfo();
      developer.log('Location info: $locationInfo',
          name: 'ActiveSessionsService');

      // پاک کردن نشست‌های قدیمی و منقضی شده
      await cleanupExpiredAndOldSessions(userId);

      // غیرفعال کردن نشست‌های قبلی کاربر
      await _deactivatePreviousSessions(userId);

      // اطمینان از اینکه فقط یک نشست فعلی وجود دارد
      await _ensureOnlyOneCurrentSession(userId);

      // ایجاد نشست جدید با استفاده از RPC function
      final sessionData = await _createSessionViaRPC(
        userId: userId,
        token: token,
        refreshTokenHash: refreshTokenHash,
        deviceInfo: deviceInfo,
        appVersion: appVersion,
        loginMethod: loginMethod ?? 'password',
        locationInfo: locationInfo,
        packageInfo: packageInfo,
      );

      developer.log('Session created successfully: ${sessionData['id']}',
          name: 'ActiveSessionsService');
      developer.log('Session token: $token', name: 'ActiveSessionsService');

      // پاک کردن کش نشست‌ها برای اطمینان از نمایش صحیح
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('=== CREATING LOGIN SESSION END ===',
          name: 'ActiveSessionsService');

      return sessionData;
    } catch (e) {
      developer.log('Error creating login session: $e',
          name: 'ActiveSessionsService');

      // تلاش برای ایجاد نشست با روش جایگزین
      try {
        developer.log('Trying alternative session creation method...',
            name: 'ActiveSessionsService');
        return await _createSessionAlternative(
            userId, sessionToken, refreshTokenHash, loginMethod);
      } catch (fallbackError) {
        developer.log('Alternative method also failed: $fallbackError',
            name: 'ActiveSessionsService');
        rethrow;
      }
    }
  }

  /// ایجاد نشست با استفاده از RPC function
  static Future<Map<String, dynamic>> _createSessionViaRPC({
    required String userId,
    required String token,
    String? refreshTokenHash,
    required Map<String, String> deviceInfo,
    required String appVersion,
    required String loginMethod,
    required Map<String, dynamic> locationInfo,
    required PackageInfo packageInfo,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // استفاده از RPC function برای ایجاد نشست
      final result = await supabase.rpc('create_user_session', params: {
        'p_user_id': userId,
        'p_session_token': token,
        'p_device_type': deviceInfo['device_type'],
        'p_device_name': deviceInfo['device_name'],
        'p_os_name': deviceInfo['os_name'],
        'p_os_version': deviceInfo['os_version'],
        'p_app_version': appVersion,
        'p_ip_address': locationInfo['ip_address'],
        'p_location': locationInfo['location'],
        'p_browser_info': 'Mobile App',
        'p_platform': deviceInfo['platform'],
        'p_is_trusted': true,
        'p_login_method': loginMethod,
        'p_session_metadata': {
          'created_via': 'mobile_app',
          'device_id': deviceInfo['device_id'],
          'app_build': packageInfo.buildNumber,
          'app_version': packageInfo.version,
          'app_package': packageInfo.packageName,
          'ip_address': locationInfo['ip_address'],
          'location_data': locationInfo['location'],
        },
      });

      // دریافت نشست ایجاد شده
      final session =
          await supabase.from(_tableName).select().eq('id', result).single();

      return session;
    } catch (e) {
      developer.log('RPC method failed: $e', name: 'ActiveSessionsService');
      rethrow;
    }
  }

  /// روش جایگزین برای ایجاد نشست
  static Future<Map<String, dynamic>> _createSessionAlternative(
    String userId,
    String? sessionToken,
    String? refreshTokenHash,
    String? loginMethod,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // تولید توکن نشست
      final token = sessionToken ??
          'alt_${DateTime.now().millisecondsSinceEpoch}_${userId}_${DateTime.now().microsecond}';

      // دریافت اطلاعات دستگاه
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final locationInfo = await _getLocationInfo();

      // ایجاد نشست با داده‌های ساده‌تر
      final sessionData = {
        'user_id': userId,
        'session_token': token,
        'refresh_token_hash': refreshTokenHash,
        'device_type': deviceInfo['device_type'] ?? 'mobile',
        'device_name': deviceInfo['device_name'] ?? 'Unknown Device',
        'os_name': deviceInfo['os_name'] ?? 'Unknown OS',
        'os_version': deviceInfo['os_version'] ?? 'Unknown',
        'app_version': appVersion,
        'platform': deviceInfo['platform'] ?? 'unknown',
        'login_method': loginMethod ?? 'password',
        'is_current': true,
        'is_trusted': true,
        'last_activity': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'ip_address': locationInfo['ip_address'] ?? 'unknown',
        'location': locationInfo['location'] ?? {},
        'session_metadata': {
          'created_via': 'mobile_app_alternative',
          'device_id': deviceInfo['device_id'] ?? 'unknown',
          'app_build': packageInfo.buildNumber,
          'app_version': packageInfo.version,
          'app_package': packageInfo.packageName,
        },
      };

      // حذف فیلدهای null
      sessionData.removeWhere((key, value) => value == null);

      final response =
          await supabase.from(_tableName).insert(sessionData).select().single();

      return response;
    } catch (e) {
      developer.log('Alternative method failed: $e',
          name: 'ActiveSessionsService');
      rethrow;
    }
  }

  /// بررسی دسترسی به جدول
  static Future<void> _validateTableAccess() async {
    try {
      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_tableName).select('id').limit(1);
        developer.log('✅ جدول $_tableName موجود است',
            name: 'ActiveSessionsService');
      } catch (e) {
        developer.log('❌ جدول $_tableName موجود نیست: $e',
            name: 'ActiveSessionsService');
        throw Exception(
            'جدول نشست‌های فعال موجود نیست. لطفاً ابتدا فایل database_migrations.sql را در Supabase اجرا کنید.');
      }

      // بررسی RLS policies
      try {
        final policies = await supabase
            .from('pg_policies')
            .select('*')
            .eq('tablename', _tableName);

        developer.log(
            '📋 Found ${policies.length} RLS policies for $_tableName',
            name: 'ActiveSessionsService');

        if (policies.isEmpty) {
          developer.log('⚠️ No RLS policies found - this might cause issues',
              name: 'ActiveSessionsService');
        }
      } catch (e) {
        developer.log('⚠️ Could not check RLS policies: $e',
            name: 'ActiveSessionsService');
      }

      // بررسی foreign key constraints
      try {
        final constraints = await supabase
            .from('information_schema.table_constraints')
            .select('*')
            .eq('table_name', _tableName)
            .eq('constraint_type', 'FOREIGN KEY');

        developer.log('🔗 Found ${constraints.length} foreign key constraints',
            name: 'ActiveSessionsService');

        for (final constraint in constraints) {
          developer.log('   - ${constraint['constraint_name']}',
              name: 'ActiveSessionsService');
        }
      } catch (e) {
        developer.log('⚠️ Could not check foreign key constraints: $e',
            name: 'ActiveSessionsService');
      }
    } catch (e) {
      developer.log('Error validating table access: $e',
          name: 'ActiveSessionsService');
      rethrow;
    }
  }

  /// ترمینیت کامل نشست و خروج از حساب
  static Future<bool> terminateSessionCompletely(
      String sessionId, String userId) async {
    try {
      developer.log('=== TERMINATING SESSION COMPLETELY START ===',
          name: 'ActiveSessionsService');
      developer.log('Terminating session: $sessionId for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // استفاده از RPC function برای ترمینیت نشست
      try {
        final result = await supabase.rpc('terminate_session', params: {
          'p_session_id': sessionId,
          'p_user_id': userId,
        });

        if (result) {
          developer.log('Session terminated via RPC: $sessionId',
              name: 'ActiveSessionsService');
        } else {
          developer.log('Session not found for termination: $sessionId',
              name: 'ActiveSessionsService');
        }
      } catch (e) {
        developer.log('RPC termination failed, trying direct delete: $e',
            name: 'ActiveSessionsService');

        // روش جایگزین: حذف مستقیم
        final deleteResponse = await supabase
            .from(_tableName)
            .delete()
            .eq('id', sessionId)
            .eq('user_id', userId);

        if (deleteResponse.error != null) {
          developer.log(
              'Error deleting session: ${deleteResponse.error!.message}',
              name: 'ActiveSessionsService');
          return false;
        }
      }

      // بررسی اینکه آیا این نشست فعلی بود یا نه
      final currentSession = await getCurrentSession(userId);
      if (currentSession == null) {
        // اگر نشست فعلی وجود ندارد، آخرین نشست را به عنوان فعلی تنظیم کن
        await _setLastSessionAsCurrent(userId);
      }

      // پاک کردن نشست‌های منقضی شده
      await cleanupExpiredAndOldSessions(userId);

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('Session terminated completely: $sessionId',
          name: 'ActiveSessionsService');
      developer.log('=== TERMINATING SESSION COMPLETELY END ===',
          name: 'ActiveSessionsService');

      return true;
    } catch (e) {
      developer.log('Error terminating session completely: $e',
          name: 'ActiveSessionsService');
      return false;
    }
  }

  /// ترمینیت تمام نشست‌های غیر فعلی کاربر
  static Future<bool> terminateAllOtherSessions(String userId) async {
    try {
      developer.log('=== TERMINATING ALL OTHER SESSIONS START ===',
          name: 'ActiveSessionsService');
      developer.log('Terminating all other sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // استفاده از RPC function
      try {
        final result =
            await supabase.rpc('terminate_all_other_sessions', params: {
          'p_user_id': userId,
        });

        developer.log('Terminated $result other sessions via RPC',
            name: 'ActiveSessionsService');
      } catch (e) {
        developer.log('RPC method failed, using direct delete: $e',
            name: 'ActiveSessionsService');

        // روش جایگزین
        final deleteResponse = await supabase
            .from(_tableName)
            .delete()
            .eq('user_id', userId)
            .neq('is_current', true);

        if (deleteResponse.error != null) {
          developer.log(
              'Error deleting other sessions: ${deleteResponse.error!.message}',
              name: 'ActiveSessionsService');
          return false;
        }
      }

      developer.log('All other sessions terminated for user: $userId',
          name: 'ActiveSessionsService');

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('=== TERMINATING ALL OTHER SESSIONS END ===',
          name: 'ActiveSessionsService');

      return true;
    } catch (e) {
      developer.log('Error terminating all other sessions: $e',
          name: 'ActiveSessionsService');
      return false;
    }
  }

  /// تنظیم آخرین نشست به عنوان فعلی
  static Future<void> _setLastSessionAsCurrent(String userId) async {
    try {
      developer.log('Setting last session as current for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // دریافت آخرین نشست فعال
      final lastSession = await supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastSession != null) {
        // تنظیم آخرین نشست به عنوان فعلی
        await supabase
            .from(_tableName)
            .update({'is_current': true}).eq('id', lastSession['id']);

        // پاک کردن کش نشست‌ها
        SecurityCache.remove('sessions_$userId');
        developer.log('Cache invalidated for user: $userId',
            name: 'ActiveSessionsService');

        developer.log('Last session set as current: ${lastSession['id']}',
            name: 'ActiveSessionsService');
      } else {
        developer.log('No active sessions found for user: $userId',
            name: 'ActiveSessionsService');
      }
    } catch (e) {
      developer.log('Error setting last session as current: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// اطمینان از اینکه فقط یک نشست فعلی وجود دارد
  static Future<void> _ensureOnlyOneCurrentSession(String userId) async {
    try {
      developer.log('Ensuring only one current session for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // بررسی تعداد نشست‌های فعلی
      final currentSessions = await supabase
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('is_current', true);

      if (currentSessions.length > 1) {
        developer.log(
            'Found ${currentSessions.length} current sessions, deactivating extras',
            name: 'ActiveSessionsService');

        // غیرفعال کردن همه نشست‌های فعلی به جز آخرین
        final sessionIds = currentSessions.map((s) => s['id']).toList();
        if (sessionIds.isNotEmpty) {
          // نگه داشتن آخرین نشست و غیرفعال کردن بقیه
          final keepSessionId = sessionIds.last;
          sessionIds.remove(keepSessionId);

          if (sessionIds.isNotEmpty) {
            for (final sessionId in sessionIds) {
              await supabase
                  .from(_tableName)
                  .update({'is_current': false}).eq('id', sessionId);
            }

            developer.log(
                'Deactivated ${sessionIds.length} extra current sessions',
                name: 'ActiveSessionsService');
          }
        }
      }
    } catch (e) {
      developer.log('Error ensuring only one current session: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// غیرفعال کردن نشست‌های قبلی کاربر
  static Future<void> _deactivatePreviousSessions(String userId) async {
    try {
      developer.log('Deactivating previous sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // غیرفعال کردن تمام نشست‌های قبلی (نه فقط آنهایی که is_current = true)
      await supabase.from(_tableName).update({
        'is_current': false,
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('All previous sessions deactivated successfully',
          name: 'ActiveSessionsService');
    } catch (e) {
      developer.log('Error deactivating previous sessions: $e',
          name: 'ActiveSessionsService');
      // خطا را نادیده بگیر تا نشست جدید ایجاد شود
    }
  }

  /// پاک کردن نشست‌های منقضی شده و قدیمی
  static Future<void> cleanupExpiredAndOldSessions(String userId) async {
    try {
      developer.log('Cleaning up expired and old sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // حذف نشست‌های منقضی شده
      await supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .lt('expires_at', now.toIso8601String());

      // حذف نشست‌های قدیمی‌تر از 30 روز که غیرفعال هستند
      await supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .eq('is_current', false)
          .lt('created_at', thirtyDaysAgo.toIso8601String());

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('Expired and old sessions cleaned up successfully',
          name: 'ActiveSessionsService');
    } catch (e) {
      developer.log('Error cleaning up expired and old sessions: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// بررسی و پاک کردن نشست‌های نامعتبر
  static Future<void> cleanupInvalidSessions(String userId) async {
    try {
      developer.log('Cleaning up invalid sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;
      final now = DateTime.now();

      // حذف نشست‌هایی که بیش از 30 روز قدیمی هستند
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      await supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .lt('created_at', thirtyDaysAgo.toIso8601String());

      // حذف نشست‌های منقضی شده
      await supabase
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .lt('expires_at', now.toIso8601String());

      // اطمینان از اینکه فقط یک نشست فعلی وجود دارد
      await _ensureOnlyOneCurrentSession(userId);

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('Invalid sessions cleaned up for user: $userId',
          name: 'ActiveSessionsService');
    } catch (e) {
      developer.log('Error cleaning up invalid sessions: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// دریافت فقط نشست‌های واقعاً فعال کاربر
  static Future<List<Map<String, dynamic>>> getTrulyActiveSessions(
      String userId) async {
    try {
      developer.log('Getting truly active sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // فقط نشست‌هایی که is_current = true هستند یا در 24 ساعت گذشته فعالیت داشته‌اند
      final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));

      final response = await supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .or('is_current.eq.true,last_activity.gt.${oneDayAgo.toIso8601String()}')
          .order('last_activity', ascending: false);

      developer.log('Found ${response.length} truly active sessions',
          name: 'ActiveSessionsService');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Error getting truly active sessions: $e',
          name: 'ActiveSessionsService');
      return [];
    }
  }

  /// دریافت تمام نشست‌های فعال کاربر
  static Future<List<Map<String, dynamic>>> getUserActiveSessions(
      String userId) async {
    try {
      developer.log('Getting active sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_tableName).select('id').limit(1);
      } catch (e) {
        developer.log('❌ جدول $_tableName موجود نیست: $e',
            name: 'ActiveSessionsService');
        throw Exception(
            'جدول نشست‌های فعال موجود نیست. لطفاً ابتدا فایل database_migrations.sql را در Supabase اجرا کنید.');
      }

      final response = await supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      developer.log('Found ${response.length} active sessions',
          name: 'ActiveSessionsService');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Error getting user active sessions: $e',
          name: 'ActiveSessionsService');
      if (e.toString().contains('جدول نشست‌های فعال موجود نیست')) {
        rethrow; // خطای جدول را دوباره پرتاب کن
      }
      return [];
    }
  }

  /// دریافت نشست فعلی کاربر
  static Future<Map<String, dynamic>?> getCurrentSession(String userId) async {
    try {
      developer.log('Getting current session for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        await supabase.from(_tableName).select('id').limit(1);
      } catch (e) {
        developer.log('❌ جدول $_tableName موجود نیست: $e',
            name: 'ActiveSessionsService');
        throw Exception(
            'جدول نشست‌های فعال موجود نیست. لطفاً ابتدا فایل database_migrations.sql را در Supabase اجرا کنید.');
      }

      final response = await supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('is_current', true)
          .maybeSingle();

      if (response != null) {
        developer.log('Current session found: ${response['id']}',
            name: 'ActiveSessionsService');
      } else {
        developer.log('No current session found for user: $userId',
            name: 'ActiveSessionsService');
      }

      return response;
    } catch (e) {
      developer.log('Error getting current session: $e',
          name: 'ActiveSessionsService');
      if (e.toString().contains('جدول نشست‌های فعال موجود نیست')) {
        rethrow; // خطای جدول را دوباره پرتاب کن
      }
      return null;
    }
  }

  /// به‌روزرسانی آخرین فعالیت نشست
  static Future<void> updateSessionActivity(String sessionId) async {
    try {
      developer.log('Updating session activity: $sessionId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // ابتدا userId را دریافت کن
      final sessionResponse = await supabase
          .from(_tableName)
          .select('user_id')
          .eq('id', sessionId)
          .single();

      if (sessionResponse != null) {
        final userId = sessionResponse['user_id'];

        await supabase.from(_tableName).update({
          'last_activity': DateTime.now().toIso8601String(),
        }).eq('id', sessionId);

        // پاک کردن کش نشست‌ها
        SecurityCache.remove('sessions_$userId');
        developer.log('Cache invalidated for user: $userId',
            name: 'ActiveSessionsService');

        developer.log('Session activity updated successfully',
            name: 'ActiveSessionsService');
      }
    } catch (e) {
      developer.log('Error updating session activity: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// حذف نشست خاص
  static Future<bool> deleteSession(String sessionId) async {
    try {
      developer.log('Deleting session: $sessionId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // ابتدا userId را دریافت کن
      final sessionResponse = await supabase
          .from(_tableName)
          .select('user_id')
          .eq('id', sessionId)
          .single();

      if (sessionResponse != null) {
        final userId = sessionResponse['user_id'];

        final response =
            await supabase.from(_tableName).delete().eq('id', sessionId);

        if (response.error != null) {
          developer.log('Error deleting session: ${response.error!.message}',
              name: 'ActiveSessionsService');
          return false;
        }

        // پاک کردن کش نشست‌ها
        SecurityCache.remove('sessions_$userId');
        developer.log('Cache invalidated for user: $userId',
            name: 'ActiveSessionsService');

        developer.log('Session deleted successfully',
            name: 'ActiveSessionsService');
        return true;
      }

      return false;
    } catch (e) {
      developer.log('Error deleting session: $e',
          name: 'ActiveSessionsService');
      return false;
    }
  }

  /// حذف تمام نشست‌های کاربر
  static Future<bool> deleteAllUserSessions(String userId) async {
    try {
      developer.log('Deleting all sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // ابتدا بررسی کن که آیا جدول وجود دارد
      try {
        await supabase.from(_tableName).select('id').limit(1);
      } catch (e) {
        if (e
                .toString()
                .contains('relation "active_sessions" does not exist') ||
            e.toString().contains('table "active_sessions" does not exist')) {
          developer.log(
              'Active sessions table does not exist, skipping deletion',
              name: 'ActiveSessionsService');
          return true; // جدول وجود ندارد، پس عملیات موفق است
        }
        rethrow; // سایر خطاها را دوباره پرتاب کن
      }

      final response =
          await supabase.from(_tableName).delete().eq('user_id', userId);

      if (response.error != null) {
        developer.log(
            'Error deleting user sessions: ${response.error!.message}',
            name: 'ActiveSessionsService');
        return false;
      }

      // پاک کردن کش نشست‌ها
      SecurityCache.remove('sessions_$userId');
      developer.log('Cache invalidated for user: $userId',
          name: 'ActiveSessionsService');

      developer.log('All user sessions deleted successfully',
          name: 'ActiveSessionsService');
      return true;
    } catch (e) {
      developer.log('Error deleting user sessions: $e',
          name: 'ActiveSessionsService');
      return false;
    }
  }

  /// پاک کردن نشست‌های منقضی شده
  static Future<void> cleanupExpiredSessions() async {
    try {
      developer.log('Cleaning up expired sessions',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from(_tableName)
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());

      if (response.error != null) {
        developer.log(
            'Error cleaning up expired sessions: ${response.error!.message}',
            name: 'ActiveSessionsService');
        return;
      }

      developer.log('Expired sessions cleaned up successfully',
          name: 'ActiveSessionsService');
    } catch (e) {
      developer.log('Error cleaning up expired sessions: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// تمدید نشست فعلی
  static Future<void> refreshCurrentSession(String userId) async {
    try {
      developer.log('Refreshing current session for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      await supabase
          .from(_tableName)
          .update({
            'last_activity': DateTime.now().toIso8601String(),
            'expires_at':
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_current', true);

      developer.log('Current session refreshed successfully',
          name: 'ActiveSessionsService');
    } catch (e) {
      developer.log('Error refreshing current session: $e',
          name: 'ActiveSessionsService');
    }
  }

  /// دریافت اطلاعات دستگاه
  static Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final Map<String, String> info = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['platform'] = 'android';
        info['device_type'] = 'mobile';
        info['device_name'] = androidInfo.model;
        info['os_name'] = 'Android';
        info['os_version'] = androidInfo.version.release;
        info['device_id'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['platform'] = 'ios';
        info['device_type'] = 'mobile';
        info['device_name'] = iosInfo.model;
        info['os_name'] = 'iOS';
        info['os_version'] = iosInfo.systemVersion;
        info['device_id'] = iosInfo.identifierForVendor ?? 'unknown';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        info['platform'] = 'windows';
        info['device_type'] = 'desktop';
        info['device_name'] = windowsInfo.computerName;
        info['os_name'] = 'Windows';
        info['os_version'] = windowsInfo.buildNumber.toString();
        info['device_id'] = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macosInfo = await deviceInfo.macOsInfo;
        info['platform'] = 'macos';
        info['device_type'] = 'desktop';
        info['device_name'] = macosInfo.computerName;
        info['os_name'] = 'macOS';
        info['os_version'] = macosInfo.osRelease;
        info['device_id'] = macosInfo.systemGUID ?? 'unknown';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        info['platform'] = 'linux';
        info['device_type'] = 'desktop';
        info['device_name'] = linuxInfo.name;
        info['os_name'] = 'Linux';
        info['os_version'] = linuxInfo.version ?? 'unknown';
        info['device_id'] = linuxInfo.machineId ?? 'unknown';
      } else {
        info['platform'] = 'unknown';
        info['device_type'] = 'unknown';
        info['device_name'] = 'Unknown Device';
        info['os_name'] = 'Unknown OS';
        info['os_version'] = 'Unknown Version';
        info['device_id'] = 'unknown';
      }

      return info;
    } catch (e) {
      developer.log('Error getting device info: $e',
          name: 'ActiveSessionsService');
      return {
        'platform': 'unknown',
        'device_type': 'unknown',
        'device_name': 'Unknown Device',
        'os_name': 'Unknown OS',
        'os_version': 'Unknown Version',
        'device_id': 'unknown',
      };
    }
  }

  /// بررسی اعتبار نشست
  static Future<bool> isSessionValid(String sessionId) async {
    try {
      developer.log('Checking session validity: $sessionId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      final response = await supabase
          .from(_tableName)
          .select('expires_at, is_current')
          .eq('id', sessionId)
          .maybeSingle();

      if (response == null) {
        developer.log('Session not found: $sessionId',
            name: 'ActiveSessionsService');
        return false;
      }

      final expiresAt = DateTime.tryParse(response['expires_at'] ?? '');
      final isCurrent = response['is_current'] ?? false;

      if (expiresAt == null) {
        developer.log('Invalid expiry date for session: $sessionId',
            name: 'ActiveSessionsService');
        return false;
      }

      final isValid = DateTime.now().isBefore(expiresAt) && isCurrent;
      developer.log('Session validity: $isValid (expires at: $expiresAt)',
          name: 'ActiveSessionsService');

      return isValid;
    } catch (e) {
      developer.log('Error checking session validity: $e',
          name: 'ActiveSessionsService');
      return false;
    }
  }

  /// دریافت اطلاعات موقعیت و IP
  static Future<Map<String, dynamic>> _getLocationInfo() async {
    try {
      // در حال حاضر از سرویس رایگان IP geolocation استفاده می‌کنیم
      final response = await http.get(Uri.parse('http://ip-api.com/json/'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'ip_address': data['query'] ?? 'نامشخص',
          'location': {
            'city': data['city'] ?? '',
            'region': data['regionName'] ?? '',
            'country': data['country'] ?? '',
            'timezone': data['timezone'] ?? '',
            'isp': data['isp'] ?? '',
          },
        };
      }
    } catch (e) {
      developer.log('Error getting location info: $e',
          name: 'ActiveSessionsService');
    }

    // در صورت خطا، مقادیر پیش‌فرض برگردان
    return {
      'ip_address': 'نامشخص',
      'location': {
        'city': '',
        'region': '',
        'country': '',
        'timezone': '',
        'isp': '',
      },
    };
  }

  /// دریافت آمار نشست‌ها
  static Future<Map<String, dynamic>> getSessionStats(String userId) async {
    try {
      developer.log('Getting session stats for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // تعداد کل نشست‌ها
      final totalSessions = await supabase
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .count();

      // تعداد نشست‌های فعال
      final activeSessions = await supabase
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq('is_current', true)
          .count();

      // نشست‌های منقضی شده
      final expiredSessions = await supabase
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .lt('expires_at', DateTime.now().toIso8601String())
          .count();

      final stats = {
        'total_sessions': totalSessions.count,
        'active_sessions': activeSessions.count,
        'expired_sessions': expiredSessions.count,
        'last_updated': DateTime.now().toIso8601String(),
      };

      developer.log('Session stats: $stats', name: 'ActiveSessionsService');

      return stats;
    } catch (e) {
      developer.log('Error getting session stats: $e',
          name: 'ActiveSessionsService');
      return {
        'total_sessions': 0,
        'active_sessions': 0,
        'expired_sessions': 0,
        'last_updated': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }

  /// متد دیباگ برای بررسی وضعیت نشست‌ها
  static Future<Map<String, dynamic>> debugSessions(String userId) async {
    try {
      developer.log('=== DEBUG SESSIONS START ===',
          name: 'ActiveSessionsService');
      developer.log('Debugging sessions for user: $userId',
          name: 'ActiveSessionsService');

      final supabase = Supabase.instance.client;

      // بررسی وجود جدول
      try {
        final tableCheck =
            await supabase.from(_tableName).select('id').limit(1);
        developer.log('✅ جدول $_tableName موجود است',
            name: 'ActiveSessionsService');
      } catch (e) {
        developer.log('❌ خطا در دسترسی به جدول $_tableName: $e',
            name: 'ActiveSessionsService');
        return {'error': 'Table access error: $e'};
      }

      // بررسی تمام نشست‌های کاربر
      final allSessions =
          await supabase.from(_tableName).select('*').eq('user_id', userId);

      developer.log(
          '📊 تعداد کل نشست‌ها برای کاربر $userId: ${allSessions.length}',
          name: 'ActiveSessionsService');

      if (allSessions.isNotEmpty) {
        for (int i = 0; i < allSessions.length; i++) {
          final session = allSessions[i];
          developer.log('📋 نشست ${i + 1}:', name: 'ActiveSessionsService');
          developer.log('   - ID: ${session['id']}',
              name: 'ActiveSessionsService');
          developer.log('   - Session Token: ${session['session_token']}',
              name: 'ActiveSessionsService');
          developer.log('   - Is Current: ${session['is_current']}',
              name: 'ActiveSessionsService');
          developer.log('   - Created At: ${session['created_at']}',
              name: 'ActiveSessionsService');
          developer.log('   - Expires At: ${session['expires_at']}',
              name: 'ActiveSessionsService');
          developer.log('   - Last Activity: ${session['last_activity']}',
              name: 'ActiveSessionsService');
        }
      } else {
        developer.log('⚠️ هیچ نشستی برای کاربر $userId یافت نشد',
            name: 'ActiveSessionsService');
      }

      // بررسی نشست‌های فعلی
      final currentSessions = await supabase
          .from(_tableName)
          .select('*')
          .eq('user_id', userId)
          .eq('is_current', true);

      developer.log('🎯 تعداد نشست‌های فعلی: ${currentSessions.length}',
          name: 'ActiveSessionsService');

      // بررسی نشست‌های منقضی شده
      final now = DateTime.now();
      final expiredSessions = await supabase
          .from(_tableName)
          .select('*')
          .eq('user_id', userId)
          .lt('expires_at', now.toIso8601String());

      developer.log('⏰ تعداد نشست‌های منقضی شده: ${expiredSessions.length}',
          name: 'ActiveSessionsService');

      final debugInfo = {
        'table_exists': true,
        'total_sessions': allSessions.length,
        'current_sessions': currentSessions.length,
        'expired_sessions': expiredSessions.length,
        'user_id': userId,
        'timestamp': now.toIso8601String(),
        'sessions_details': allSessions
            .map((s) => {
                  'id': s['id'],
                  'session_token': s['session_token'],
                  'is_current': s['is_current'],
                  'created_at': s['created_at'],
                  'expires_at': s['expires_at'],
                  'last_activity': s['last_activity'],
                })
            .toList(),
      };

      developer.log('=== DEBUG SESSIONS END ===',
          name: 'ActiveSessionsService');
      return debugInfo;
    } catch (e) {
      developer.log('Error debugging sessions: $e',
          name: 'ActiveSessionsService');
      return {'error': e.toString()};
    }
  }
}
