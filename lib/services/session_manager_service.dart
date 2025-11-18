import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../model/session_model.dart';
import '../security/logging_utility.dart';
import '../security/security.dart';
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

      // ✅ گرفتن IP و Location
      logInfo('📡 [registerSession] Fetching IP and location...');
      final ipAddress = await _getIPWithTimeout();
      final locationData = await _getCurrentLocation();

      logInfo('📱 [registerSession] IP Address: $ipAddress');
      logInfo('🌍 [registerSession] Location Data: $locationData');

      logInfo('📝 [registerSession] ثبت نشست جدید...');

      // ثبت در دیتابیس
      final sessionData = {
        'id': sessionId,
        'user_id': userId,
        'session_token': _sessionToken,
        'device_info': deviceInfo.toJson(),
        'is_active': true,
        'app_version': packageInfo.version,
        'platform': _getPlatformName(),
        'ip_address': ipAddress,
        'location': locationData['location'],
        'location_city': locationData['location_city'],
        'location_country': locationData['location_country'],
        'location_region': locationData['location_region'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'last_activity': DateTime.now().toUtc().toIso8601String(),
      };

      logInfo(
          '📤 [registerSession] Registering session with data: ${json.encode(sessionData)}');

      final response = await _supabase
          .from('active_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSessionId = response['id'] as String;
      _sessionToken = response['session_token'] as String;

      // ذخیره محلی
      await _saveSession();

      logInfo(
          '✅ [registerSession] Session registered successfully with location: $_currentSessionId');

      // شروع ردیابی و Realtime
      _startActivityTracking();
      _setupRealtimeListener();
      _startSessionMonitoring();

      _isRegistering = false;
      return _currentSessionId;
    } catch (e, stackTrace) {
      logInfo('❌ [registerSession] خطا در ثبت نشست: $e');
      logInfo('📚 [registerSession] Stack trace: $stackTrace');
      _currentSessionId = null;
      _sessionToken = null;
      _isRegistering = false;
      return null;
    }
  }

  Future<bool> _verifySession() async {
    if (_currentSessionId == null) return false;

    try {
      // استفاده از RPC function برای بررسی امنیتی با timeout
      final response = await _supabase.rpc('verify_active_session', params: {
        'session_id': _currentSessionId,
      }).timeout(
        const Duration(seconds: 2),
        onTimeout: () => true, // در صورت timeout، session را معتبر در نظر بگیر
      );

      return response == true;
    } catch (e) {
      logInfo('❌ خطا در بررسی نشست: $e');
      // در صورت خطا، session را معتبر در نظر بگیر تا کاربر منتظر نماند
      return true;
    }
  }

  /// اطمینان از ثبت نشست فعال (برای استفاده در Middleware)
  /// این متد بهینه شده تا سریع‌تر اجرا شود و کاربر منتظر نماند
  Future<bool> ensureSessionRegistered() async {
    final currentSession = _supabase.auth.currentSession;
    if (currentSession == null) {
      return false;
    }

    // اگر نشست محلی داریم، فقط بررسی سریع انجام بده
    if (_currentSessionId != null) {
      // بررسی اعتبار نشست با timeout کوتاه
      try {
        final isValid = await _verifySession();
        if (!isValid) {
          // در صورت نامعتبر بودن، در پس‌زمینه terminate کن
          Future.microtask(() => _terminateLocal('نشست شما غیرفعال شده است'));
          return false;
        }
        // آپدیت موقعیت و IP در پس‌زمینه (غیرمسدودکننده)
        updateLocationAndIP();
        return true;
      } catch (e) {
        // در صورت خطا، session را معتبر در نظر بگیر
        return true;
      }
    }

    // اگر نشست محلی نداریم، ثبت کن (اما با timeout)
    try {
      final sessionId = await registerSession().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      if (sessionId == null) {
        // در صورت خطا، session را معتبر در نظر بگیر تا کاربر منتظر نماند
        // terminate در پس‌زمینه انجام می‌شود
        Future.microtask(() => _terminateLocal('نشست ثبت نشد'));
        return false;
      }

      // آپدیت موقعیت و IP در پس‌زمینه (غیرمسدودکننده)
      updateLocationAndIP();
      return true;
    } catch (e) {
      // در صورت خطا، session را معتبر در نظر بگیر
      return true;
    }
  }

  /// آپدیت موقعیت مکانی و IP آدرس در profiles و active_sessions
  /// این متد به صورت کاملاً غیرمسدودکننده در پس‌زمینه اجرا می‌شود
  void updateLocationAndIP() {
    // اجرای غیرمسدودکننده در پس‌زمینه
    Future.microtask(() async {
      try {
        logInfo('🔄 [updateLocationAndIP] Starting...');

        final user = _supabase.auth.currentUser;
        if (user == null) {
          logInfo(
              '❌ [updateLocationAndIP] User is null, cannot update location');
          return;
        }

        if (_currentSessionId == null) {
          logInfo(
              '❌ [updateLocationAndIP] Session not registered (_currentSessionId is null)');
          return;
        }

        if (_sessionToken == null || _sessionToken!.isEmpty) {
          logInfo('❌ [updateLocationAndIP] Session token is empty!');
          return;
        }

        logInfo(
            '✅ [updateLocationAndIP] User authenticated, fetching IP and location...');

        // گرفتن IP
        logInfo('📡 [updateLocationAndIP] Fetching IP address...');
        final ipAddress = await _getIPWithTimeout();
        logInfo('📱 [updateLocationAndIP] IP Address received: $ipAddress');

        // گرفتن Location
        logInfo('🌍 [updateLocationAndIP] Fetching location data...');
        final locationData = await _getCurrentLocation();
        logInfo(
            '📍 [updateLocationAndIP] Location Data received: $locationData');

        // آپدیت در دیتابیس به صورت موازی
        final updateFutures = <Future>[];

        // آپدیت profiles
        if (locationData['location'] != null || ipAddress != null) {
          final updateData = <String, dynamic>{};
          if (locationData['location'] != null) {
            updateData['last_location'] = locationData['location'];
          }
          if (ipAddress != null) {
            updateData['last_ip'] = ipAddress;
          }

          logInfo(
              '📤 [updateLocationAndIP] Updating profiles with: $updateData');

          updateFutures.add(
            _supabase
                .from('profiles')
                .update(updateData)
                .eq('id', user.id)
                .timeout(const Duration(seconds: 5))
                .then((_) {
              logInfo('✅ [updateLocationAndIP] Profiles updated successfully');
              return null;
            }).catchError((e) {
              logInfo('❌ [updateLocationAndIP] Error updating profiles: $e');
              return null;
            }),
          );
        }

        // آپدیت active_sessions
        if (locationData.isNotEmpty || ipAddress != null) {
          final sessionUpdateData = <String, dynamic>{
            'last_activity': DateTime.now().toUtc().toIso8601String(),
          };

          if (ipAddress != null) {
            sessionUpdateData['ip_address'] = ipAddress;
          }

          // ✅ اضافه کردن فیلدهای location
          if (locationData['location_city'] != null) {
            sessionUpdateData['location_city'] = locationData['location_city'];
          }
          if (locationData['location_country'] != null) {
            sessionUpdateData['location_country'] =
                locationData['location_country'];
          }
          if (locationData['location_region'] != null) {
            sessionUpdateData['location_region'] =
                locationData['location_region'];
          }
          if (locationData['location'] != null) {
            sessionUpdateData['location'] = locationData['location'];
          }

          logInfo(
              '📤 [updateLocationAndIP] Updating session with: ${json.encode(sessionUpdateData)}');

          updateFutures.add(
            _supabase
                .from('active_sessions')
                .update(sessionUpdateData)
                .eq('id', _currentSessionId!)
                .timeout(const Duration(seconds: 5))
                .then((result) {
              logInfo(
                  '✅ [updateLocationAndIP] Database update successful! Result: $result');
              return null;
            }).catchError((e) {
              logInfo('❌ [updateLocationAndIP] Error updating session: $e');
              return null;
            }),
          );
        } else {
          logInfo('⚠️ [updateLocationAndIP] No location or IP data to update');
        }

        // اجرای موازی آپدیت‌ها
        await Future.wait(updateFutures, eagerError: false);
        logInfo('✅ [updateLocationAndIP] All updates completed');
      } catch (e, stackTrace) {
        logInfo('❌ [updateLocationAndIP] Exception: $e');
        logInfo('📚 [updateLocationAndIP] Stack trace: $stackTrace');
      }
    });
  }

  /// دریافت IP با timeout
  Future<String?> _getIPWithTimeout() async {
    try {
      logInfo('📡 [_getIPWithTimeout] Fetching IP address...');
      final ip = await getIpAddress().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          logInfo('⏱️ [_getIPWithTimeout] Request timeout!');
          throw TimeoutException('IP address fetch timeout');
        },
      );
      logInfo('✅ [_getIPWithTimeout] IP address received: $ip');
      return ip;
    } on TimeoutException {
      logInfo('⏱️ [_getIPWithTimeout] TimeoutException caught');
      return null;
    } catch (e, stackTrace) {
      logInfo('❌ [_getIPWithTimeout] Exception: $e');
      logInfo('📚 [_getIPWithTimeout] Stack: $stackTrace');
      return null;
    }
  }

  /// دریافت موقعیت مکانی از طریق IP API
  /// ابتدا از ipapi.co استفاده می‌کند، در صورت خطا از ip-api.com استفاده می‌کند
  Future<Map<String, dynamic>> _getCurrentLocation() async {
    logInfo('🌍 [_getCurrentLocation] Starting...');

    // تلاش اول: استفاده از ipapi.co
    try {
      logInfo('📡 [_getCurrentLocation] Trying ipapi.co...');
      final result = await _getLocationFromIpApiCo();
      if (result != null) {
        logInfo(
            '✅ [_getCurrentLocation] Successfully got location from ipapi.co');
        return result;
      }
    } catch (e) {
      logInfo('⚠️ [_getCurrentLocation] ipapi.co failed: $e');
    }

    // تلاش دوم: استفاده از ip-api.com (fallback)
    try {
      logInfo('📡 [_getCurrentLocation] Trying ip-api.com as fallback...');
      final result = await _getLocationFromIpApiCom();
      if (result != null) {
        logInfo(
            '✅ [_getCurrentLocation] Successfully got location from ip-api.com');
        return result;
      }
    } catch (e) {
      logInfo('⚠️ [_getCurrentLocation] ip-api.com also failed: $e');
    }

    logInfo(
        '❌ [_getCurrentLocation] All location APIs failed, returning empty data');
    return _getEmptyLocationData();
  }

  /// دریافت location از ipapi.co
  Future<Map<String, dynamic>?> _getLocationFromIpApiCo() async {
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logInfo('⏱️ [_getLocationFromIpApiCo] Request timeout!');
          throw TimeoutException('Location API timeout');
        },
      );

      logInfo(
          '📨 [_getLocationFromIpApiCo] Response status: ${response.statusCode}');
      logInfo('📨 [_getLocationFromIpApiCo] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // چک کردن اگر API محدودیت داشت
        if (data['error'] == true) {
          logInfo('❌ [_getLocationFromIpApiCo] API Error: ${data['reason']}');
          return null;
        }

        final city = data['city']?.toString();
        final country = data['country_name']?.toString();
        final region = data['region']?.toString();
        final latitude = data['latitude']?.toString();
        final longitude = data['longitude']?.toString();

        logInfo(
            '✅ [_getLocationFromIpApiCo] Parsed: city=$city, country=$country, region=$region');

        // ساخت location object به صورت JSON
        Map<String, dynamic>? locationObject;
        if (city != null ||
            country != null ||
            (latitude != null && longitude != null)) {
          locationObject = {
            'city': city,
            'country': country,
            'latitude': latitude != null ? double.tryParse(latitude) : null,
            'longitude': longitude != null ? double.tryParse(longitude) : null,
          };
        }

        return {
          'location_city': city,
          'location_country': country,
          'location_region': region,
          'location': locationObject,
        };
      } else {
        logInfo(
            '❌ [_getLocationFromIpApiCo] Bad status code: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      logInfo('❌ [_getLocationFromIpApiCo] Exception: $e');
      logInfo('📚 [_getLocationFromIpApiCo] Stack: $stackTrace');
      return null;
    }
  }

  /// دریافت location از ip-api.com (fallback)
  Future<Map<String, dynamic>?> _getLocationFromIpApiCom() async {
    try {
      final response = await http
          .get(
        Uri.parse(
            'http://ip-api.com/json/?fields=status,message,city,country,regionName,lat,lon'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logInfo('⏱️ [_getLocationFromIpApiCom] Request timeout!');
          throw TimeoutException('Location API timeout');
        },
      );

      logInfo(
          '📨 [_getLocationFromIpApiCom] Response status: ${response.statusCode}');
      logInfo('📨 [_getLocationFromIpApiCom] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          final city = data['city']?.toString();
          final country = data['country']?.toString();
          final region = data['regionName']?.toString();
          final lat = data['lat']?.toString();
          final lon = data['lon']?.toString();

          logInfo(
              '✅ [_getLocationFromIpApiCom] Parsed: city=$city, country=$country, region=$region');

          // ساخت location object به صورت JSON
          Map<String, dynamic>? locationObject;
          if (city != null || country != null || (lat != null && lon != null)) {
            locationObject = {
              'city': city,
              'country': country,
              'latitude': lat != null ? double.tryParse(lat) : null,
              'longitude': lon != null ? double.tryParse(lon) : null,
            };
          }

          return {
            'location_city': city,
            'location_country': country,
            'location_region': region,
            'location': locationObject,
          };
        } else {
          logInfo(
              '❌ [_getLocationFromIpApiCom] API returned fail: ${data['message']}');
          return null;
        }
      } else {
        logInfo(
            '❌ [_getLocationFromIpApiCom] Bad status code: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      logInfo('❌ [_getLocationFromIpApiCom] Exception: $e');
      logInfo('📚 [_getLocationFromIpApiCom] Stack: $stackTrace');
      return null;
    }
  }

  /// Helper method برای برگرداندن داده‌های خالی location
  Map<String, dynamic> _getEmptyLocationData() {
    return {
      'location_city': null,
      'location_country': null,
      'location_region': null,
      'location': null,
    };
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

  Stream<List<SessionModel>> watchActiveSessions() async* {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    try {
      // ابتدا داده‌های اولیه را از getActiveSessions بگیر
      logInfo('📡 [watchActiveSessions] Loading initial sessions...');
      final initialSessions = await getActiveSessions();
      logInfo(
          '✅ [watchActiveSessions] Loaded ${initialSessions.length} initial sessions');
      yield initialSessions;

      // سپس stream را subscribe کن با error handling
      final stream = _supabase
          .from('active_sessions')
          .stream(primaryKey: ['id']).handleError((error, stackTrace) {
        logInfo('❌ [watchActiveSessions] Stream error: $error');
        logInfo('📚 [watchActiveSessions] Stack: $stackTrace');
      });

      await for (final data in stream) {
        try {
          // فیلتر کردن داده‌ها بر اساس user_id و is_active
          final filtered = data.where((json) {
            return json['user_id'] == user.id && json['is_active'] == true;
          }).toList();

          // مرتب‌سازی بر اساس last_activity
          filtered.sort((a, b) {
            try {
              final aTime = DateTime.parse(a['last_activity'] as String);
              final bTime = DateTime.parse(b['last_activity'] as String);
              return bTime.compareTo(aTime);
            } catch (e) {
              logInfo('⚠️ [watchActiveSessions] Error parsing date: $e');
              return 0;
            }
          });

          final sessions = filtered
              .map((json) {
                try {
                  return SessionModel.fromJson(json);
                } catch (e) {
                  logInfo('⚠️ [watchActiveSessions] Error parsing session: $e');
                  return null;
                }
              })
              .whereType<SessionModel>()
              .toList();

          logInfo(
              '📡 [watchActiveSessions] Stream update: ${sessions.length} sessions');
          yield sessions;
        } catch (e) {
          logInfo('❌ [watchActiveSessions] Error processing stream data: $e');
          // در صورت خطا، دوباره از getActiveSessions استفاده کن
          try {
            final fallbackSessions = await getActiveSessions();
            yield fallbackSessions;
          } catch (fallbackError) {
            logInfo('❌ [watchActiveSessions] Fallback failed: $fallbackError');
            yield [];
          }
        }
      }
    } catch (e, stackTrace) {
      logInfo('❌ [watchActiveSessions] Initial load error: $e');
      logInfo('📚 [watchActiveSessions] Stack: $stackTrace');
      // در صورت خطا در بارگذاری اولیه، یک بار دیگر تلاش کن
      try {
        final fallbackSessions = await getActiveSessions();
        yield fallbackSessions;
      } catch (fallbackError) {
        logInfo(
            '❌ [watchActiveSessions] Final fallback failed: $fallbackError');
        yield [];
      }
    }
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
          final daysSinceCreation = DateTime.now().difference(createdAt).inDays;
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
              .update({'is_active': false}).eq('id', _currentSessionId!);
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
          deviceModel: iosInfo.model.isNotEmpty ? iosInfo.model : 'iPhone',
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
