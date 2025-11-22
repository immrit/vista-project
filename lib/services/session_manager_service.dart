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
  String? get currentSessionToken => _sessionToken;

  /// ✅ بررسی اینکه session ID در دیتابیس وجود دارد
  Future<bool> _verifySessionIdExists(String sessionId) async {
    try {
      final response = await _supabase
          .from('active_sessions')
          .select('id')
          .eq('id', sessionId)
          .eq('is_active', true)
          .maybeSingle();
      return response != null;
    } catch (e) {
      logInfo('⚠️ Error verifying session ID exists: $e');
      return false;
    }
  }

  /// ✅ پیدا کردن نشست فعلی از دیتابیس با استفاده از session token
  Future<String?> findCurrentSessionId() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logInfo('⚠️ User not authenticated, cannot find session');
        return _currentSessionId;
      }

      // 1. اول سعی کن با session token پیدا کن (دقیق‌ترین روش)
      if (_sessionToken != null && _sessionToken!.isNotEmpty) {
        final tokenResponse = await _supabase
            .from('active_sessions')
            .select('id, session_token')
            .eq('user_id', userId)
            .eq('session_token', _sessionToken!)
            .eq('is_active', true)
            .maybeSingle();

        if (tokenResponse != null) {
          final foundSessionId = tokenResponse['id'] as String;
          logInfo('✅ Found session by token: $foundSessionId');
          
          // اگر با currentSessionId متفاوت است، به‌روزرسانی کن
          if (foundSessionId != _currentSessionId) {
            logInfo('🔄 Updating session ID: $_currentSessionId -> $foundSessionId');
            _currentSessionId = foundSessionId;
            await _saveSession();
          }
          return foundSessionId;
        }
      }

      // 2. اگر با token پیدا نشد، از device ID استفاده کن
      final deviceInfo = await _getDeviceInfo();
      if (deviceInfo.deviceId != null && deviceInfo.deviceId!.isNotEmpty) {
        final deviceResponse = await _supabase
            .from('active_sessions')
            .select('id, device_info, last_activity')
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('last_activity', ascending: false)
            .limit(20);

        // پیدا کردن نشست با device ID و جدیدترین last_activity
        String? bestMatchSessionId;
        DateTime? bestMatchTime;

        for (final session in deviceResponse) {
          final sessionDeviceInfo = session['device_info'] as Map<String, dynamic>?;
          if (sessionDeviceInfo != null) {
            final sessionDeviceId = sessionDeviceInfo['device_id'] as String?;
            if (sessionDeviceId == deviceInfo.deviceId) {
              final lastActivityStr = session['last_activity'] as String?;
              if (lastActivityStr != null) {
                try {
                  final lastActivity = DateTime.parse(lastActivityStr);
                  if (bestMatchTime == null || lastActivity.isAfter(bestMatchTime)) {
                    bestMatchTime = lastActivity;
                    bestMatchSessionId = session['id'] as String;
                  }
                } catch (e) {
                  // اگر parse نشد، از این session استفاده کن
                  if (bestMatchSessionId == null) {
                    bestMatchSessionId = session['id'] as String;
                  }
                }
              } else {
                // اگر last_activity نداریم، از این session استفاده کن
                if (bestMatchSessionId == null) {
                  bestMatchSessionId = session['id'] as String;
                }
              }
            }
          }
        }

        if (bestMatchSessionId != null) {
          logInfo('✅ Found session by device ID: $bestMatchSessionId');
          _currentSessionId = bestMatchSessionId;
          await _saveSession();
          return bestMatchSessionId;
        }
      }

      // 3. اگر هیچکدام پیدا نشد، از currentSessionId استفاده کن (اگر معتبر است)
      if (_currentSessionId != null) {
        final isValid = await _verifySessionIdExists(_currentSessionId!);
        if (isValid) {
          return _currentSessionId;
        }
      }

      logInfo('⚠️ Could not find current session ID');
      return null;
    } catch (e) {
      logInfo('⚠️ Error finding current session ID: $e');
      return _currentSessionId;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logInfo('🔧 Initializing Session Manager...');

      // بارگذاری نشست قبلی
      await _loadSavedSession();

      // ✅ اگر session token داریم اما session ID نداریم یا معتبر نیست، پیدا کن
      if (_sessionToken != null && 
          (_currentSessionId == null || 
           !await _verifySessionIdExists(_currentSessionId!))) {
        logInfo('🔄 Session ID missing or invalid, trying to find from token...');
        final foundSessionId = await findCurrentSessionId();
        if (foundSessionId != null) {
          _currentSessionId = foundSessionId;
          await _saveSession();
          logInfo('✅ Found and restored session ID: $foundSessionId');
        }
      }

      // بررسی اعتبار نشست موجود
      if (_currentSessionId != null) {
        // بررسی اولیه: اگر Supabase session معتبر است، local session را هم معتبر در نظر بگیر
        final supabaseSession = _supabase.auth.currentSession;
        if (supabaseSession != null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final expiresAt = supabaseSession.expiresAt ?? 0;
          // اگر Supabase session معتبر است (حداقل 5 دقیقه باقی مانده)، local session را هم معتبر در نظر بگیر
          if (expiresAt - now > 300) {
            logInfo('✅ Supabase session is valid, assuming local session is valid: $_currentSessionId');
            // شروع ردیابی فعالیت
            _startActivityTracking();
            _setupRealtimeListener();
            _startSessionMonitoring();
          } else {
            // اگر Supabase session منقضی شده، verify کن
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
        } else {
          // اگر Supabase session وجود ندارد، verify کن
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
      // بررسی اولیه: اگر Supabase session معتبر است، local session را هم معتبر در نظر بگیر
      final supabaseSession = _supabase.auth.currentSession;
      if (supabaseSession != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiresAt = supabaseSession.expiresAt ?? 0;
        // اگر Supabase session معتبر است (حداقل 5 دقیقه باقی مانده)، local session را هم معتبر در نظر بگیر
        if (expiresAt - now > 300) {
          logInfo('✅ Supabase session is valid, assuming local session is valid');
          return true;
        }
      }

      // استفاده از RPC function برای بررسی امنیتی با timeout بیشتر
      final response = await _supabase.rpc('verify_active_session', params: {
        'session_id': _currentSessionId,
      }).timeout(
        const Duration(seconds: 5), // افزایش timeout برای شبکه‌های کند
        onTimeout: () {
          logInfo('⚠️ Session verification timeout, assuming valid (network may be slow)');
          return true; // در صورت timeout، session را معتبر در نظر بگیر
        },
      );

      return response == true;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      final isNetworkError = errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('connection') ||
          errorString.contains('socket') ||
          errorString.contains('failed host lookup');
      
      if (isNetworkError) {
        logInfo('⚠️ Network error during session verification, assuming valid: $e');
        // با قطع اینترنت، session را معتبر در نظر بگیر
        return true;
      }
      
      logInfo('❌ خطا در بررسی نشست: $e');
      // در صورت خطای دیگر، session را معتبر در نظر بگیر تا کاربر منتظر نماند
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
      // بررسی اعتبار نشست با timeout کوتاه و retry logic
      try {
        bool isValid = false;
        int retryCount = 0;
        const maxRetries = 2;
        
        // چند بار تلاش کن قبل از terminate
        while (retryCount < maxRetries && !isValid) {
          isValid = await _verifySession();
          if (!isValid && retryCount < maxRetries - 1) {
            retryCount++;
            logInfo('⚠️ Session verification failed, retrying... ($retryCount/$maxRetries)');
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          } else {
            break;
          }
        }
        
        if (!isValid) {
          // فقط اگر همه تلاش‌ها ناموفق بود، بررسی کن که آیا Supabase session هنوز معتبر است
          final supabaseSession = _supabase.auth.currentSession;
          if (supabaseSession == null) {
            // بررسی دقیق‌تر: اگر session واقعاً منقضی شده (نه فقط network error)
            logInfo('⚠️ Both local and Supabase sessions appear invalid');
            // فقط اگر واقعاً منقضی شده باشد terminate کن
            // اما با قطع اینترنت، session را حفظ می‌کنیم
            return false;
          }
          
          // اگر Supabase session هنوز معتبر است، فقط لاگ کن و ادامه بده
          // این یعنی مشکل network است نه session
          logInfo('⚠️ Local session verification failed but Supabase session is valid, continuing...');
          // حتی اگر local verify نشد، با Supabase session معتبر، ادامه می‌دهیم
        }
        
        // آپدیت موقعیت و IP در پس‌زمینه (غیرمسدودکننده)
        updateLocationAndIP();
        return true;
      } catch (e) {
        // در صورت خطا، session را معتبر در نظر بگیر
        logInfo('⚠️ Error verifying session: $e, assuming valid');
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

        // آپدیت profiles (فقط IP - location در active_sessions ذخیره می‌شود)
        if (ipAddress != null) {
          final updateData = <String, dynamic>{
            'last_ip': ipAddress,
          };

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
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              logInfo('✅ Realtime listener subscribed successfully');
            } else if (status == RealtimeSubscribeStatus.timedOut) {
              logInfo('⚠️ Realtime listener timeout, reconnecting...');
              Future.delayed(const Duration(seconds: 2), () {
                if (_currentSessionId != null && !_isTerminating) {
                  _setupRealtimeListener();
                }
              });
            } else if (status == RealtimeSubscribeStatus.channelError) {
              logInfo('❌ Realtime listener channel error: $error');
              Future.delayed(const Duration(seconds: 5), () {
                if (_currentSessionId != null && !_isTerminating) {
                  _setupRealtimeListener();
                }
              });
            }
          });

      logInfo('✅ Realtime listener راه‌اندازی شد');
    } catch (e) {
      logInfo('❌ خطا در راه‌اندازی Realtime: $e');
      // ✅ Retry بعد از 5 ثانیه
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentSessionId != null && !_isTerminating) {
          _setupRealtimeListener();
        }
      });
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
          // ✅ بررسی امنیتی: بررسی اینکه نشست هنوز active است
          if (_currentSessionId != null) {
            final sessionCheck = await _checkSessionActive();
            if (!sessionCheck) {
              logInfo('🔴 Session is no longer active, terminating...');
              await _handleSessionTermination();
              return;
            }
          }

          // بررسی اولیه: اگر Supabase session معتبر است، نیازی به verify نیست
          final supabaseSession = _supabase.auth.currentSession;
          if (supabaseSession != null) {
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final expiresAt = supabaseSession.expiresAt ?? 0;
            // اگر session معتبر است (حداقل 10 دقیقه باقی مانده)، فقط continue کن
            if (expiresAt - now > 600) {
              // Session معتبر است، نیازی به verify نیست
              return;
            }
          }
          
          final stillValid = await ensureSessionRegistered();
          if (!stillValid) {
            // فقط اگر Supabase session هم منقضی شده باشد، تایمر را متوقف کن
            final finalSession = _supabase.auth.currentSession;
            if (finalSession == null) {
              _sessionMonitorTimer?.cancel();
            }
            // در غیر این صورت (مثلاً network error)، تایمر را ادامه بده
          }
        } catch (e) {
          final errorString = e.toString().toLowerCase();
          final isNetworkError = errorString.contains('network') ||
              errorString.contains('timeout') ||
              errorString.contains('connection');
          
          if (isNetworkError) {
            logInfo('⚠️ Network error during session monitoring, keeping session active: $e');
            // با قطع اینترنت، session را حفظ می‌کنیم
          } else {
            logInfo('⚠️ خطا در monitoring نشست: $e');
          }
        }
      },
    );
  }

  /// ✅ بررسی اینکه نشست هنوز active است (برای امنیت)
  Future<bool> _checkSessionActive() async {
    if (_currentSessionId == null) return false;

    try {
      final response = await _supabase
          .from('active_sessions')
          .select('is_active, user_id')
          .eq('id', _currentSessionId!)
          .maybeSingle();

      if (response == null) {
        logInfo('⚠️ Session not found in database');
        return false;
      }

      final isActive = response['is_active'] as bool? ?? false;
      if (!isActive) {
        logInfo('🔴 Session is marked as inactive in database');
        return false;
      }

      // ✅ بررسی امنیتی: مطمئن شویم نشست متعلق به کاربر فعلی است
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final sessionUserId = response['user_id'] as String?;
        if (sessionUserId != currentUser.id) {
          logInfo('🔴 Session user_id mismatch - security violation');
          return false;
        }
      }

      return true;
    } catch (e) {
      logInfo('⚠️ Error checking session active status: $e');
      // در صورت خطا، session را معتبر در نظر بگیر (برای جلوگیری از signOut ناخواسته)
      return true;
    }
  }

  /// ✅ بررسی عمومی که نشست هنوز معتبر است (برای استفاده قبل از عملیات مهم)
  Future<bool> isSessionStillValid() async {
    if (_currentSessionId == null) return false;
    
    // بررسی سریع: اگر Supabase session معتبر است، احتمالاً local session هم معتبر است
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession == null) {
      return false;
    }

    // بررسی دقیق: چک کردن در دیتابیس
    return await _checkSessionActive();
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
      // ✅ بررسی امنیتی: دریافت user_id فعلی
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        logInfo('❌ [canTerminateSession] User not authenticated');
        return false;
      }

      // ✅ بررسی امنیتی: دریافت اطلاعات نشست فعلی با user_id
      final currentResponse = await _supabase
          .from('active_sessions')
          .select('created_at, user_id')
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .maybeSingle();

      if (currentResponse == null) {
        logInfo('❌ [canTerminateSession] Current session not found');
        return false;
      }

      // ✅ بررسی امنیتی: مطمئن شویم نشست فعلی متعلق به کاربر فعلی است
      final currentUserId = currentResponse['user_id'] as String?;
      if (currentUserId != currentUser.id) {
        logInfo('❌ [canTerminateSession] Session user_id mismatch - security violation');
        return false;
      }

      final currentCreatedAt =
          DateTime.parse(currentResponse['created_at'] as String);
      final daysSinceCreation =
          DateTime.now().difference(currentCreatedAt).inDays;

      // اگر نشست فعلی 10 روز یا بیشتر قدمت دارد، می‌تواند همه را حذف کند
      if (daysSinceCreation >= 10) {
        // ✅ اما باید مطمئن شویم که نشست هدف هم متعلق به همان کاربر است
        final targetResponse = await _supabase
            .from('active_sessions')
            .select('user_id')
            .eq('id', targetSessionId)
            .eq('is_active', true)
            .maybeSingle();

        if (targetResponse == null) return false;
        
        final targetUserId = targetResponse['user_id'] as String?;
        if (targetUserId != currentUser.id) {
          logInfo('❌ [canTerminateSession] Target session belongs to different user - security violation');
          return false;
        }
        
        return true;
      }

      // ✅ بررسی امنیتی: دریافت اطلاعات نشست مورد نظر با user_id
      final targetResponse = await _supabase
          .from('active_sessions')
          .select('created_at, user_id')
          .eq('id', targetSessionId)
          .eq('is_active', true)
          .maybeSingle();

      if (targetResponse == null) return false;

      // ✅ بررسی امنیتی: مطمئن شویم نشست هدف متعلق به کاربر فعلی است
      final targetUserId = targetResponse['user_id'] as String?;
      if (targetUserId != currentUser.id) {
        logInfo('❌ [canTerminateSession] Target session belongs to different user - security violation');
        return false;
      }

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
      // ✅ بررسی امنیتی: بررسی authentication
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        logInfo('❌ [terminateSession] User not authenticated');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'کاربر احراز هویت نشده است',
        );
      }

      // ✅ بررسی امنیتی: بررسی session ID
      if (_currentSessionId == null) {
        logInfo('❌ [terminateSession] Current session ID is null');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'نشست فعلی معتبر نیست',
        );
      }

      // ✅ بررسی امنیتی: بررسی مجدد قبل از فراخوانی RPC (جلوگیری از Race Condition)
      final canTerminateThis = await canTerminateSession(sessionId);

      if (!canTerminateThis) {
        // بررسی قدمت نشست فعلی
        final response = await _supabase
            .from('active_sessions')
            .select('created_at, user_id')
            .eq('id', _currentSessionId!)
            .eq('is_active', true)
            .maybeSingle();

        if (response != null) {
          // ✅ بررسی امنیتی: مطمئن شویم نشست فعلی متعلق به کاربر فعلی است
          final sessionUserId = response['user_id'] as String?;
          if (sessionUserId != currentUser.id) {
            logInfo('❌ [terminateSession] Session user_id mismatch - security violation');
            return TerminateSessionResult(
              success: false,
              errorMessage: 'خطای امنیتی: نشست متعلق به شما نیست',
            );
          }

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

      // ✅ بررسی امنیتی نهایی: بررسی مجدد user_id قبل از فراخوانی RPC
      final finalTargetCheck = await _supabase
          .from('active_sessions')
          .select('user_id')
          .eq('id', sessionId)
          .eq('is_active', true)
          .maybeSingle();

      if (finalTargetCheck == null) {
        return TerminateSessionResult(
          success: false,
          errorMessage: 'نشست مورد نظر یافت نشد یا قبلاً حذف شده است',
        );
      }

      final targetUserId = finalTargetCheck['user_id'] as String?;
      if (targetUserId != currentUser.id) {
        logInfo('❌ [terminateSession] Target session belongs to different user - security violation');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'خطای امنیتی: شما نمی‌توانید نشست کاربران دیگر را حذف کنید',
        );
      }

      // استفاده از RPC function برای امنیت بیشتر
      // ✅ RPC function باید در دیتابیس نیز همه این بررسی‌ها را انجام دهد
      await _supabase.rpc('terminate_session', params: {
        'session_id': sessionId,
        'terminating_session_id': _currentSessionId,
      });

      logInfo('✅ نشست خاتمه یافت: $sessionId');
      return TerminateSessionResult(success: true);
    } catch (e) {
      logInfo('❌ خطا در خاتمه نشست: $e');
      String errorMessage = 'خطا در خاتمه نشست';
      
      // ✅ بررسی خطاهای امنیتی
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('user_id') || 
          errorString.contains('security') ||
          errorString.contains('permission') ||
          errorString.contains('unauthorized')) {
        errorMessage = 'خطای امنیتی: شما مجاز به حذف این نشست نیستید';
      } else if (errorString.contains('روز دیگر') ||
          errorString.contains('قدیمی‌تر')) {
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
      // ✅ بررسی امنیتی: بررسی authentication
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        logInfo('❌ [terminateOtherSessions] User not authenticated');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'کاربر احراز هویت نشده است',
        );
      }

      // ✅ بررسی امنیتی: بررسی session ID
      if (_currentSessionId == null) {
        logInfo('❌ [terminateOtherSessions] Current session ID is null');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'نشست فعلی معتبر نیست',
        );
      }

      // ✅ بررسی امنیتی: بررسی مجدد قبل از فراخوانی RPC
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

      // ✅ بررسی امنیتی نهایی: مطمئن شویم نشست فعلی متعلق به کاربر فعلی است
      final finalCheck = await _supabase
          .from('active_sessions')
          .select('user_id')
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .maybeSingle();

      if (finalCheck == null) {
        return TerminateSessionResult(
          success: false,
          errorMessage: 'نشست فعلی یافت نشد',
        );
      }

      final sessionUserId = finalCheck['user_id'] as String?;
      if (sessionUserId != currentUser.id) {
        logInfo('❌ [terminateOtherSessions] Session user_id mismatch - security violation');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'خطای امنیتی: نشست متعلق به شما نیست',
        );
      }

      // ✅ RPC function باید در دیتابیس نیز بررسی کند که فقط نشست‌های همان کاربر حذف شوند
      await _supabase.rpc('terminate_other_sessions', params: {
        'current_session_id': _currentSessionId,
      });

      logInfo('✅ سایر نشست‌ها خاتمه یافتند');
      return TerminateSessionResult(success: true);
    } catch (e) {
      logInfo('❌ خطا در خاتمه سایر نشست‌ها: $e');
      String errorMessage = 'خطا در خاتمه نشست‌ها';
      
      // ✅ بررسی خطاهای امنیتی
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('user_id') || 
          errorString.contains('security') ||
          errorString.contains('permission') ||
          errorString.contains('unauthorized')) {
        errorMessage = 'خطای امنیتی: شما مجاز به حذف این نشست‌ها نیستید';
      } else if (errorString.contains('روز دیگر')) {
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
