import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../model/session_model.dart';
import '../security/logging_utility.dart';
import 'location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManagerService {
  static final SessionManagerService _instance =
      SessionManagerService._internal();

  factory SessionManagerService() => _instance;

  SessionManagerService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? _currentSessionId;
  String? _sessionToken;
  Timer? _activityTimer;
  Timer? _sessionMonitorTimer;
  RealtimeChannel? _sessionChannel;

  bool _isInitialized = false;
  bool _isRegistering = false; // جلوگیری از ثبت همزمان
  bool _isTerminating = false; // جلوگیری از terminate همزمان

  Function()? onSessionTerminated;

  String? get currentSessionId => _currentSessionId;
  bool get isSessionActive => _currentSessionId != null;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logInfo('🔧 Initializing Session Manager...');

      // بارگذاری نشست قبلی
      await _loadSavedSession();

      // بررسی اعتبار نشست موجود
      if (_currentSessionId != null) {
        final isValid = await _verifySession();
        if (!isValid) {
          logInfo('⚠️ نشست ذخیره شده معتبر نیست');
          await _clearSavedSession();
        } else {
          logInfo('✅ نشست موجود معتبر است: $_currentSessionId');
          // شروع ردیابی فعالیت
          _startActivityTracking();
          _setupRealtimeListener();
          _startSessionMonitoring();
        }
      }

      _isInitialized = true;
      logInfo('✅ Session Manager initialized');
    } catch (e) {
      logInfo('❌ Error initializing Session Manager: $e');
    }
  }

  Future<String?> registerSession() async {
    // جلوگیری از ثبت همزمان
    if (_isRegistering) {
      logInfo('⚠️ ثبت نشست در حال انجام است...');
      return _currentSessionId;
    }

    // اگر نشست فعال معتبر داریم، از ثبت مجدد جلوگیری کن
    if (_currentSessionId != null) {
      final isValid = await _verifySession();
      if (isValid) {
        logInfo('✅ نشست فعال معتبر موجود است: $_currentSessionId');
        return _currentSessionId;
      }
    }

    _isRegistering = true;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logInfo('❌ کاربر وارد نشده است');
        _isRegistering = false;
        return null;
      }

      // تولید توکن و شناسه یکتا
      _sessionToken = const Uuid().v4();
      final sessionId = const Uuid().v4();

      // دریافت اطلاعات دستگاه
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();

      // دریافت موقعیت مکانی (اختیاری - در صورت خطا ادامه می‌دهد)
      Map<String, dynamic>? locationData;
      try {
        locationData = await LocationService().getCurrentLocation();
      } catch (e) {
        logInfo('⚠️ Failed to get location: $e');
      }

      logInfo('📝 ثبت نشست جدید...');

      // ثبت در دیتابیس
      final response = await _supabase.from('active_sessions').insert({
        'id': sessionId,
        'user_id': userId,
        'session_token': _sessionToken,
        'device_info': deviceInfo.toJson(),
        'is_active': true,
        'app_version': packageInfo.version,
        'platform': _getPlatformName(),
        'ip_address': null,
        'location': locationData,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'last_activity': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      _currentSessionId = response['id'] as String;
      _sessionToken = response['session_token'] as String;

      // ذخیره محلی
      await _saveSession();

      logInfo('✅ نشست جدید ثبت شد: $_currentSessionId');

      // شروع ردیابی و Realtime
      _startActivityTracking();
      _setupRealtimeListener();
      _startSessionMonitoring();

      _isRegistering = false;
      return _currentSessionId;
    } catch (e) {
      logInfo('❌ خطا در ثبت نشست: $e');
      _currentSessionId = null;
      _sessionToken = null;
      _isRegistering = false;
      return null;
    }
  }

  Future<bool> _verifySession() async {
    if (_currentSessionId == null) return false;

    try {
      // استفاده از RPC function برای بررسی امنیتی
      final response = await _supabase.rpc('verify_active_session', params: {
        'session_id': _currentSessionId,
      });

      return response == true;
    } catch (e) {
      logInfo('❌ خطا در بررسی نشست: $e');
      return false;
    }
  }

  /// اطمینان از ثبت نشست فعال (برای استفاده در Middleware)
  Future<bool> ensureSessionRegistered() async {
    final currentSession = _supabase.auth.currentSession;
    if (currentSession == null) {
      logInfo('❌ نشست Supabase معتبر یافت نشد');
      await _terminateLocal('نشست معتبر یافت نشد');
      return false;
    }

    // اگر نشست محلی نداریم، سعی کن ثبت کن
    if (_currentSessionId == null) {
      logInfo('⚠️ نشست محلی یافت نشد - تلاش برای ثبت...');
      final sessionId = await registerSession();
      if (sessionId == null) {
        await _terminateLocal('نشست ثبت نشد');
        return false;
      }
      return true;
    }

    // بررسی اعتبار نشست با RPC
    final isValid = await _verifySession();
    if (!isValid) {
      logInfo('❌ نشست معتبر نیست - خاتمه محلی');
      await _terminateLocal('نشست شما غیرفعال شده است');
      return false;
    }

    return true;
  }

  void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _updateActivity(),
    );
  }

  Future<void> _updateActivity() async {
    if (_currentSessionId == null) return;

    try {
      await _supabase
          .from('active_sessions')
          .update({
            'last_activity': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _currentSessionId!)
          .eq('is_active', true);
    } catch (e) {
      logInfo('❌ خطا در به‌روزرسانی فعالیت: $e');
    }
  }

  void _setupRealtimeListener() {
    if (_currentSessionId == null) return;

    try {
      _sessionChannel?.unsubscribe();

      _sessionChannel = _supabase
          .channel('session:$_currentSessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'active_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: _currentSessionId,
            ),
            callback: (payload) {
              final newData = payload.newRecord;
              if (newData['is_active'] == false) {
                logInfo('⚠️ نشست توسط کاربر دیگر خاتمه یافت (Realtime)');
                _handleSessionTermination();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'active_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: _currentSessionId,
            ),
            callback: (payload) {
              logInfo('⚠️ نشست حذف شد (Realtime)');
              _handleSessionTermination();
            },
          )
          .subscribe();

      logInfo('✅ Realtime listener راه‌اندازی شد');
    } catch (e) {
      logInfo('❌ خطا در راه‌اندازی Realtime: $e');
    }
  }

  /// شروع Monitoring دوره‌ای نشست (هر 30 ثانیه)
  void _startSessionMonitoring() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_isTerminating) return; // اگر در حال terminate است، بررسی نکن
        
        try {
          final stillValid = await ensureSessionRegistered();
          if (!stillValid) {
            _sessionMonitorTimer?.cancel();
          }
        } catch (e) {
          logInfo('⚠️ خطا در monitoring نشست: $e');
        }
      },
    );
  }

  Future<void> _handleSessionTermination() async {
    if (_isTerminating) {
      logInfo('⚠️ Session termination already in progress');
      return;
    }

    _isTerminating = true;
    logInfo('🔴 خاتمه نشست فعلی...');

    // متوقف کردن تایمرها و کانال‌ها
    _activityTimer?.cancel();
    _sessionMonitorTimer?.cancel();
    _sessionChannel?.unsubscribe();

    // پاک کردن داده‌های محلی
    await _clearSavedSession();

    _currentSessionId = null;
    _sessionToken = null;

    // خروج از Supabase
    try {
      await _supabase.auth.signOut();
      logInfo('✅ خروج از Supabase انجام شد');
    } catch (e) {
      logInfo('⚠️ خطا در خروج از حساب: $e');
    }

    // اجرای callback
    if (onSessionTerminated != null) {
      try {
        onSessionTerminated!();
      } catch (e) {
        logInfo('❌ خطا در اجرای callback: $e');
      }
    }

    _isTerminating = false;
  }

  /// خاتمه محلی نشست (بدون خروج از Supabase)
  Future<void> _terminateLocal(String reason) async {
    if (_isTerminating) return;

    _isTerminating = true;
    logInfo('🔴 خاتمه محلی نشست: $reason');

    // متوقف کردن تایمرها و کانال‌ها
    _activityTimer?.cancel();
    _sessionMonitorTimer?.cancel();
    _sessionChannel?.unsubscribe();

    // پاک کردن داده‌های محلی
    await _clearSavedSession();

    _currentSessionId = null;
    _sessionToken = null;

    // خروج از Supabase
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      logInfo('⚠️ خطا در خروج از حساب: $e');
    }

    // اجرای callback
    if (onSessionTerminated != null) {
      try {
        onSessionTerminated!();
      } catch (e) {
        logInfo('❌ خطا در اجرای callback: $e');
      }
    }

    _isTerminating = false;
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_id', _currentSessionId ?? '');
      await prefs.setString('session_token', _sessionToken ?? '');
    } catch (e) {
      logInfo('❌ خطا در ذخیره نشست: $e');
    }
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSessionId = prefs.getString('session_id');
      _sessionToken = prefs.getString('session_token');

      if (_currentSessionId != null && _currentSessionId!.isEmpty) {
        _currentSessionId = null;
      }
      if (_sessionToken != null && _sessionToken!.isEmpty) {
        _sessionToken = null;
      }
    } catch (e) {
      logInfo('❌ خطا در بارگذاری نشست: $e');
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_id');
      await prefs.remove('session_token');
    } catch (e) {
      logInfo('❌ خطا در پاک کردن نشست: $e');
    }
  }

  Future<List<SessionModel>> getActiveSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('active_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_activity', ascending: false);

      return (response as List)
          .map((json) => SessionModel.fromJson(json))
          .toList();
    } catch (e) {
      logInfo('❌ خطا در دریافت نشست‌ها: $e');
      return [];
    }
  }

  Stream<List<SessionModel>> watchActiveSessions() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _supabase
        .from('active_sessions')
        .stream(primaryKey: ['id'])
        .map((data) {
          // فیلتر کردن داده‌ها بر اساس user_id و is_active
          final filtered = data.where((json) {
            return json['user_id'] == user.id && json['is_active'] == true;
          }).toList();

          // مرتب‌سازی بر اساس last_activity
          filtered.sort((a, b) {
            final aTime = DateTime.parse(a['last_activity'] as String);
            final bTime = DateTime.parse(b['last_activity'] as String);
            return bTime.compareTo(aTime);
          });

          return filtered.map((json) => SessionModel.fromJson(json)).toList();
        });
  }

  /// بررسی اینکه آیا نشست فعلی 10 روز قدمت دارد یا نه
  /// اگر کمتر از 10 روز باشد، فقط می‌تواند نشست‌های جدیدتر را حذف کند
  Future<bool> canTerminateOtherSessions() async {
    if (_currentSessionId == null) return false;

    try {
      final response = await _supabase
          .from('active_sessions')
          .select('created_at')
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return false;

      final createdAt = DateTime.parse(response['created_at'] as String);
      final daysSinceCreation = DateTime.now().difference(createdAt).inDays;

      logInfo('🔍 نشست فعلی $daysSinceCreation روز قدمت دارد');

      // حتی اگر کمتر از 10 روز باشد، می‌تواند نشست‌های جدیدتر را حذف کند
      // پس همیشه true برمی‌گردانیم (اما در terminate_session بررسی می‌شود)
      return true;
    } catch (e) {
      logInfo('❌ خطا در بررسی قدمت نشست: $e');
      return false;
    }
  }

  /// بررسی اینکه آیا می‌تواند یک نشست خاص را حذف کند
  Future<bool> canTerminateSession(String targetSessionId) async {
    if (_currentSessionId == null) return false;

    try {
      // دریافت اطلاعات نشست فعلی
      final currentResponse = await _supabase
          .from('active_sessions')
          .select('created_at')
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .maybeSingle();

      if (currentResponse == null) return false;

      final currentCreatedAt =
          DateTime.parse(currentResponse['created_at'] as String);
      final daysSinceCreation =
          DateTime.now().difference(currentCreatedAt).inDays;

      // اگر نشست فعلی 10 روز یا بیشتر قدمت دارد، می‌تواند همه را حذف کند
      if (daysSinceCreation >= 10) return true;

      // دریافت اطلاعات نشست مورد نظر
      final targetResponse = await _supabase
          .from('active_sessions')
          .select('created_at')
          .eq('id', targetSessionId)
          .eq('is_active', true)
          .maybeSingle();

      if (targetResponse == null) return false;

      final targetCreatedAt =
          DateTime.parse(targetResponse['created_at'] as String);

      // فقط می‌تواند نشست‌های جدیدتر از خودش را حذف کند
      // نشست جدیدتر = created_at بزرگتر = تاریخ ایجاد بعدتر
      return targetCreatedAt.isAfter(currentCreatedAt);
    } catch (e) {
      logInfo('❌ خطا در بررسی امکان حذف نشست: $e');
      return false;
    }
  }

  /// دریافت تعداد روزهای باقیمانده تا امکان حذف
  Future<int> getRemainingDaysToTerminate() async {
    if (_currentSessionId == null) return 10;

    try {
      final response = await _supabase
          .from('active_sessions')
          .select('created_at')
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return 10;

      final createdAt = DateTime.parse(response['created_at'] as String);
      final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
      final remainingDays = 10 - daysSinceCreation;

      return remainingDays > 0 ? remainingDays : 0;
    } catch (e) {
      logInfo('❌ خطا در محاسبه روزهای باقیمانده: $e');
      return 10;
    }
  }

  /// خاتمه یک نشست خاص (با بررسی امنیتی)
  Future<TerminateSessionResult> terminateSession(String sessionId) async {
    try {
      // بررسی اینکه آیا می‌تواند این نشست خاص را حذف کند
      final canTerminateThis = await canTerminateSession(sessionId);

      if (!canTerminateThis) {
        // بررسی قدمت نشست فعلی
        final response = await _supabase
            .from('active_sessions')
            .select('created_at')
            .eq('id', _currentSessionId!)
            .eq('is_active', true)
            .maybeSingle();

        if (response != null) {
          final createdAt = DateTime.parse(response['created_at'] as String);
          final daysSinceCreation =
              DateTime.now().difference(createdAt).inDays;
          final remainingDays = 10 - daysSinceCreation;

          return TerminateSessionResult(
            success: false,
            errorMessage: daysSinceCreation >= 10
                ? 'شما نمی‌توانید این نشست را حذف کنید.'
                : 'شما نمی‌توانید نشست‌های قدیمی‌تر از خود را حذف کنید. برای حذف نشست‌های قدیمی، باید $remainingDays روز دیگر صبر کنید.',
            remainingDays: remainingDays > 0 ? remainingDays : null,
          );
        }
      }

      // استفاده از RPC function برای امنیت بیشتر
      await _supabase.rpc('terminate_session', params: {
        'session_id': sessionId,
        'terminating_session_id': _currentSessionId,
      });

      logInfo('✅ نشست خاتمه یافت: $sessionId');
      return TerminateSessionResult(success: true);
    } catch (e) {
      logInfo('❌ خطا در خاتمه نشست: $e');
      String errorMessage = 'خطا در خاتمه نشست';
      if (e.toString().contains('روز دیگر') ||
          e.toString().contains('قدیمی‌تر')) {
        errorMessage = e.toString();
      }
      return TerminateSessionResult(
        success: false,
        errorMessage: errorMessage,
      );
    }
  }

  /// خاتمه همه نشست‌ها به جز نشست فعلی (با بررسی امنیتی)
  Future<TerminateSessionResult> terminateOtherSessions() async {
    try {
      // بررسی اینکه آیا نشست فعلی 10 روز قدمت دارد
      final canTerminate = await canTerminateOtherSessions();

      if (!canTerminate) {
        final remainingDays = await getRemainingDaysToTerminate();
        return TerminateSessionResult(
          success: false,
          errorMessage:
              'برای حذف نشست‌های دیگر، باید $remainingDays روز دیگر صبر کنید.',
          remainingDays: remainingDays,
        );
      }

      await _supabase.rpc('terminate_other_sessions', params: {
        'current_session_id': _currentSessionId,
      });

      logInfo('✅ سایر نشست‌ها خاتمه یافتند');
      return TerminateSessionResult(success: true);
    } catch (e) {
      logInfo('❌ خطا در خاتمه سایر نشست‌ها: $e');
      String errorMessage = 'خطا در خاتمه نشست‌ها';
      if (e.toString().contains('روز دیگر')) {
        errorMessage = e.toString();
      }
      return TerminateSessionResult(
        success: false,
        errorMessage: errorMessage,
      );
    }
  }

  // خروج کاربر توسط خودش
  Future<void> userLogout() async {
    try {
      logInfo('👤 خروج کاربر...');

      if (_currentSessionId != null) {
        // خاتمه نشست فعلی
        try {
          await _supabase
              .from('active_sessions')
              .update({'is_active': false})
              .eq('id', _currentSessionId!);
          logInfo('✅ نشست غیرفعال شد: $_currentSessionId');
        } catch (e) {
          logInfo('⚠️ خطا در غیرفعال کردن نشست: $e');
        }
      }

      // پاک کردن داده‌های محلی
      await _clearSavedSession();

      // متوقف کردن تایمرها
      _activityTimer?.cancel();
      _sessionChannel?.unsubscribe();

      _currentSessionId = null;
      _sessionToken = null;

      // خروج از Supabase
      await _supabase.auth.signOut();

      logInfo('✅ کاربر با موفقیت خارج شد');
    } catch (e) {
      logInfo('❌ خطا در خروج کاربر: $e');
    }
  }

  Future<SessionDeviceInfo> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return SessionDeviceInfo(
          deviceName: androidInfo.brand.isNotEmpty
              ? androidInfo.brand
              : 'Android Device',
          deviceModel: '${androidInfo.manufacturer} ${androidInfo.model}',
          osVersion: 'Android ${androidInfo.version.release}',
          targetPlatform: TargetPlatform.android,
          deviceId: androidInfo.id,
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return SessionDeviceInfo(
          deviceName: iosInfo.name.isNotEmpty ? iosInfo.name : 'iOS Device',
          deviceModel:
              iosInfo.model.isNotEmpty ? iosInfo.model : 'iPhone',
          osVersion: 'iOS ${iosInfo.systemVersion}',
          targetPlatform: TargetPlatform.iOS,
          deviceId: iosInfo.identifierForVendor,
        );
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        return SessionDeviceInfo(
          deviceName: windowsInfo.computerName,
          deviceModel: 'Windows PC',
          osVersion: 'Windows',
          targetPlatform: TargetPlatform.windows,
        );
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        return SessionDeviceInfo(
          deviceName: macInfo.computerName,
          deviceModel: macInfo.model,
          osVersion: 'macOS',
          targetPlatform: TargetPlatform.macOS,
        );
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        return SessionDeviceInfo(
          deviceName: linuxInfo.name,
          deviceModel: 'Linux',
          osVersion: 'Linux',
          targetPlatform: TargetPlatform.linux,
        );
      }
    } catch (e) {
      logInfo('خطا در دریافت اطلاعات دستگاه: $e');
    }

    return SessionDeviceInfo(
      deviceName: 'Unknown',
      deviceModel: 'Unknown',
      osVersion: 'Unknown',
      targetPlatform: defaultTargetPlatform,
    );
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  void dispose() {
    _activityTimer?.cancel();
    _sessionMonitorTimer?.cancel();
    _sessionChannel?.unsubscribe();
    onSessionTerminated = null;
  }
}

/// کلاس نتیجه برای عملیات خاتمه نشست
class TerminateSessionResult {
  final bool success;
  final String? errorMessage;
  final int? remainingDays;

  TerminateSessionResult({
    required this.success,
    this.errorMessage,
    this.remainingDays,
  });
}
