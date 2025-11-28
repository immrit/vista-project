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

/// 🚀 Session Manager V2 - Professional Grade
/// 
/// Key Features:
/// - Trust Supabase session as source of truth
/// - Graceful degradation with network errors
/// - Smart retry logic (3x before giving up)
/// - No aggressive checks in background
/// - Only user-initiated session termination
/// 
/// Based on best practices from:
/// - Telegram (persistent sessions)
/// - WhatsApp (offline-first)
/// - Instagram (background resilience)
class SessionManagerServiceV2 {
  static final SessionManagerServiceV2 _instance = SessionManagerServiceV2._internal();
  factory SessionManagerServiceV2() => _instance;
  static SessionManagerServiceV2 get instance => _instance;
  SessionManagerServiceV2._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? _currentSessionId;
  String? _sessionToken;
  Timer? _activityTimer;
  Timer? _healthCheckTimer;
  RealtimeChannel? _sessionChannel;

  bool _isInitialized = false;
  bool _isRegistering = false;
  bool _isInBackground = false;
  DateTime? _lastActivityUpdate;
  int _healthCheckFailures = 0;
  
  // ✅ Configuration
  static const int _maxHealthCheckFailures = 15; // 15 بار خطا = 15 دقیقه
  static const Duration _activityUpdateInterval = Duration(minutes: 3); // هر 3 دقیقه
  static const Duration _healthCheckInterval = Duration(minutes: 1); // هر 1 دقیقه
  static const Duration _sessionExpiry = Duration(days: 90); // 90 روز

  Function()? onSessionTerminated;

  String? get currentSessionId => _currentSessionId;
  bool get isSessionActive => _currentSessionId != null;
  String? get currentSessionToken => _sessionToken;
  bool get isInBackground => _isInBackground;

  /// ═══════════════════════════════════════════════════════════
  /// APP LIFECYCLE HANDLERS
  /// ═══════════════════════════════════════════════════════════

  /// وقتی برنامه به پس‌زمینه می‌رود
  Future<void> onAppPaused() async {
    _isInBackground = true;
    logInfo('⏸️ App paused - entering background mode');
    
    // متوقف کردن تمام checks تهاجمی
    _stopHealthCheck();
    
    // ذخیره سریع session
    await _saveSession();
    
    // آپدیت last_activity در background (fire and forget)
    _updateActivityInBackground();
  }

  /// وقتی برنامه از پس‌زمینه برمی‌گردد
  Future<void> onAppResumed() async {
    final wasPaused = _isInBackground;
    _isInBackground = false;
    
    if (!wasPaused) return;
    
    logInfo('▶️ App resumed - exiting background mode');
    
    // ✅ اولویت اول: بررسی Supabase session
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession == null) {
      logInfo('⚠️ No Supabase session on resume');
      await _handleSessionTermination();
      return;
    }
    
    // ✅ بررسی expire شدن
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = supabaseSession.expiresAt ?? 0;
    
    if (expiresAt - now < 300) {
      // کمتر از 5 دقیقه باقی مانده - refresh کن
      logInfo('🔄 Session expiring soon, refreshing...');
      await _refreshSessionWithRetry();
    }
    
    // Reset failures و restart timers
    _healthCheckFailures = 0;
    _startActivityTracking();
    _startHealthCheck();
    _setupRealtimeListener();
    
    // آپدیت activity
    await _updateActivity();
  }

  /// ═══════════════════════════════════════════════════════════
  /// INITIALIZATION
  /// ═══════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logInfo('🔧 Initializing Session Manager V2...');

      // بارگذاری session محلی
      await _loadSavedSession();

      // ✅ اگر Supabase session معتبر است، local session هم معتبر است
      final supabaseSession = _supabase.auth.currentSession;
      if (supabaseSession != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiresAt = supabaseSession.expiresAt ?? 0;
        
        if (expiresAt - now > 300) {
          // Session معتبر است
          logInfo('✅ Supabase session valid - local session trusted');
          
          // اگر session ID نداریم، پیدا کن
          if (_currentSessionId == null && _sessionToken != null) {
            await _findSessionFromToken();
          }
          
          // شروع tracking
          _startActivityTracking();
          _startHealthCheck();
          _setupRealtimeListener();
          
          _isInitialized = true;
          return;
        }
      }

      // اگر session ID داریم، بررسی کن
      if (_currentSessionId != null) {
        final isValid = await _quickSessionCheck();
        if (isValid) {
          logInfo('✅ Local session verified');
          _startActivityTracking();
          _startHealthCheck();
          _setupRealtimeListener();
        } else {
          await _clearSavedSession();
        }
      }

      _isInitialized = true;
      logInfo('✅ Session Manager V2 initialized');
    } catch (e) {
      logInfo('❌ Error initializing Session Manager: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// SESSION REGISTRATION
  /// ═══════════════════════════════════════════════════════════

  Future<String?> registerSession() async {
    if (_isRegistering) {
      logInfo('⚠️ Registration already in progress');
      return _currentSessionId;
    }

    // ✅ اگر session معتبر داریم، از ثبت مجدد جلوگیری کن
    if (_currentSessionId != null) {
      final isValid = await _quickSessionCheck();
      if (isValid) {
        logInfo('✅ Valid session exists: $_currentSessionId');
        return _currentSessionId;
      }
    }

    _isRegistering = true;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logInfo('❌ User not authenticated');
        _isRegistering = false;
        return null;
      }

      // تولید session جدید
      _sessionToken = const Uuid().v4();
      final sessionId = const Uuid().v4();

      // دریافت اطلاعات
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final ipAddress = await _getIPWithTimeout();
      final locationData = await _getCurrentLocation();

      logInfo('📝 Registering new session...');

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
        'expires_at': DateTime.now().toUtc().add(_sessionExpiry).toIso8601String(),
      };

      final response = await _supabase
          .from('active_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSessionId = response['id'] as String;
      _sessionToken = response['session_token'] as String;

      await _saveSession();

      logInfo('✅ Session registered: $_currentSessionId');

      // شروع tracking
      _startActivityTracking();
      _startHealthCheck();
      _setupRealtimeListener();

      _isRegistering = false;
      return _currentSessionId;
    } catch (e) {
      logInfo('❌ Error registering session: $e');
      _currentSessionId = null;
      _sessionToken = null;
      _isRegistering = false;
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// SESSION VERIFICATION (NON-AGGRESSIVE)
  /// ═══════════════════════════════════════════════════════════

  /// بررسی سریع session (فقط اگر واقعاً لازم باشد)
  Future<bool> _quickSessionCheck() async {
    if (_currentSessionId == null) return false;

    // ✅ اولویت اول: Supabase session
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = supabaseSession.expiresAt ?? 0;
      
      if (expiresAt - now > 300) {
        _healthCheckFailures = 0;
        return true;
      }
    }

    // ✅ بررسی database با retry
    return await _checkSessionInDatabase();
  }

  /// بررسی session در database با retry logic
  Future<bool> _checkSessionInDatabase() async {
    if (_currentSessionId == null) return false;

    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final response = await _supabase
            .from('active_sessions')
            .select('is_active, expires_at')
            .eq('id', _currentSessionId!)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (response == null) {
          logInfo('⚠️ Session not found in database');
          _healthCheckFailures++;
          
          if (_healthCheckFailures >= _maxHealthCheckFailures) {
            return false;
          }
          return true; // با خطای موقت، معتبر نگه دار
        }

        _healthCheckFailures = 0;

        final isActive = response['is_active'] as bool? ?? false;
        if (!isActive) {
          logInfo('🔴 Session marked inactive');
          return false;
        }

        // بررسی expire
        final expiresAtStr = response['expires_at'] as String?;
        if (expiresAtStr != null) {
          final expiresAt = DateTime.parse(expiresAtStr);
          if (DateTime.now().toUtc().isAfter(expiresAt)) {
            logInfo('⏰ Session expired in database');
            // سعی کن تمدید کنی
            await _extendSessionExpiry();
            return true;
          }
        }

        return true;
      } catch (e) {
        retries++;
        final errorString = e.toString().toLowerCase();
        final isNetworkError = errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('connection') ||
            errorString.contains('socket');

        if (isNetworkError) {
          logInfo('⚠️ Network error during check (attempt $retries/$maxRetries)');
          
          if (retries < maxRetries) {
            await Future.delayed(Duration(seconds: retries * 2));
            continue;
          }
          
          // با network error، session را معتبر نگه دار
          return true;
        }

        logInfo('⚠️ Error checking session: $e');
        _healthCheckFailures++;
        
        if (_healthCheckFailures >= _maxHealthCheckFailures) {
          return false;
        }
        return true;
      }
    }

    return true; // در صورت fail شدن همه retries، معتبر نگه دار
  }

  /// ═══════════════════════════════════════════════════════════
  /// ACTIVITY TRACKING (OPTIMIZED)
  /// ═══════════════════════════════════════════════════════════

  void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(_activityUpdateInterval, (_) {
      if (!_isInBackground) {
        _updateActivity();
      }
    });
  }

  Future<void> _updateActivity() async {
    if (_currentSessionId == null) return;
    if (_isInBackground) return;

    // ✅ Rate limiting - فقط اگر 2 دقیقه از آخرین آپدیت گذشته باشد
    if (_lastActivityUpdate != null) {
      final diff = DateTime.now().difference(_lastActivityUpdate!);
      if (diff.inMinutes < 2) {
        return;
      }
    }

    try {
      final now = DateTime.now().toUtc();
      await _supabase
          .from('active_sessions')
          .update({
            'last_activity': now.toIso8601String(),
            'expires_at': now.add(_sessionExpiry).toIso8601String(),
          })
          .eq('id', _currentSessionId!)
          .eq('is_active', true)
          .timeout(const Duration(seconds: 5));

      _lastActivityUpdate = now;
      _healthCheckFailures = 0;
    } catch (e) {
      logInfo('⚠️ Activity update failed (non-critical): $e');
    }
  }

  void _updateActivityInBackground() {
    if (_currentSessionId == null) return;
    
    // Fire and forget
    Future.microtask(() async {
      try {
        await _supabase
            .from('active_sessions')
            .update({
              'last_activity': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', _currentSessionId!)
            .eq('is_active', true)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        // Ignore
      }
    });
  }

  /// ═══════════════════════════════════════════════════════════
  /// HEALTH CHECK (NON-AGGRESSIVE)
  /// ═══════════════════════════════════════════════════════════

  void _startHealthCheck() {
    // ✅ در debug mode، health check را غیرفعال کن
    if (kDebugMode) {
      logInfo('🔧 Debug mode: Health check disabled');
      return;
    }

    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) async {
      if (_isInBackground) return; // در background چک نکن
      
      await _performHealthCheck();
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> _performHealthCheck() async {
    // ✅ اولویت اول: Supabase session
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession == null) {
      logInfo('⚠️ No Supabase session in health check');
      _healthCheckFailures++;
      
      if (_healthCheckFailures >= _maxHealthCheckFailures) {
        logInfo('🔴 Max health check failures reached');
        await _handleSessionTermination();
      }
      return;
    }

    // بررسی expire
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = supabaseSession.expiresAt ?? 0;
    
    if (expiresAt - now < 600) {
      // کمتر از 10 دقیقه - refresh کن
      logInfo('🔄 Session expiring soon in health check');
      await _refreshSessionWithRetry();
    }

    // Reset failures
    _healthCheckFailures = 0;
  }

  /// ═══════════════════════════════════════════════════════════
  /// SESSION REFRESH WITH RETRY
  /// ═══════════════════════════════════════════════════════════

  Future<bool> _refreshSessionWithRetry() async {
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final response = await _supabase.auth.refreshSession();
        
        if (response.session != null) {
          logInfo('✅ Session refreshed successfully');
          return true;
        }
        
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(seconds: retries * 2));
        }
      } catch (e) {
        retries++;
        logInfo('⚠️ Refresh attempt $retries failed: $e');
        
        if (retries < maxRetries) {
          await Future.delayed(Duration(seconds: retries * 2));
        }
      }
    }

    logInfo('❌ All refresh attempts failed');
    return false;
  }

  /// ═══════════════════════════════════════════════════════════
  /// REALTIME LISTENER
  /// ═══════════════════════════════════════════════════════════

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
                logInfo('⚠️ Session terminated by another device (Realtime)');
                _handleSessionTermination();
              }
            },
          )
          .subscribe();

      logInfo('✅ Realtime listener setup complete');
    } catch (e) {
      logInfo('⚠️ Realtime setup failed (non-critical): $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// SESSION TERMINATION
  /// ═══════════════════════════════════════════════════════════

  Future<void> _handleSessionTermination() async {
    logInfo('🔴 Handling session termination...');

    // متوقف کردن همه چیز
    _stopHealthCheck();
    _activityTimer?.cancel();
    _activityTimer = null;
    _sessionChannel?.unsubscribe();
    _sessionChannel = null;

    // غیرفعال کردن در database
    if (_currentSessionId != null) {
      try {
        await _supabase
            .from('active_sessions')
            .update({'is_active': false})
            .eq('id', _currentSessionId!)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        logInfo('⚠️ Error deactivating session: $e');
      }
    }

    // پاک کردن local data
    await _clearSavedSession();
    _currentSessionId = null;
    _sessionToken = null;
    _healthCheckFailures = 0;

    // خروج از Supabase
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      logInfo('⚠️ Error signing out: $e');
    }

    // callback
    onSessionTerminated?.call();

    logInfo('✅ Session termination complete');
  }

  /// ═══════════════════════════════════════════════════════════
  /// UTILITY METHODS
  /// ═══════════════════════════════════════════════════════════

  Future<void> _extendSessionExpiry() async {
    if (_currentSessionId == null) return;

    try {
      await _supabase
          .from('active_sessions')
          .update({
            'expires_at': DateTime.now().toUtc().add(_sessionExpiry).toIso8601String(),
          })
          .eq('id', _currentSessionId!)
          .timeout(const Duration(seconds: 5));
      
      logInfo('✅ Session expiry extended');
    } catch (e) {
      logInfo('⚠️ Failed to extend expiry (non-critical): $e');
    }
  }

  Future<void> _findSessionFromToken() async {
    if (_sessionToken == null) return;

    try {
      final response = await _supabase
          .from('active_sessions')
          .select('id')
          .eq('session_token', _sessionToken!)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        _currentSessionId = response['id'] as String;
        await _saveSession();
        logInfo('✅ Session found from token: $_currentSessionId');
      }
    } catch (e) {
      logInfo('⚠️ Error finding session from token: $e');
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_id', _currentSessionId ?? '');
      await prefs.setString('session_token', _sessionToken ?? '');
    } catch (e) {
      logInfo('❌ Error saving session: $e');
    }
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentSessionId = prefs.getString('session_id');
      _sessionToken = prefs.getString('session_token');

      if (_currentSessionId?.isEmpty ?? true) _currentSessionId = null;
      if (_sessionToken?.isEmpty ?? true) _sessionToken = null;
    } catch (e) {
      logInfo('❌ Error loading session: $e');
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_id');
      await prefs.remove('session_token');
    } catch (e) {
      logInfo('❌ Error clearing session: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// PUBLIC API
  /// ═══════════════════════════════════════════════════════════

  Future<bool> ensureSessionRegistered() async {
    final supabaseSession = _supabase.auth.currentSession;
    if (supabaseSession == null) return false;

    if (_currentSessionId != null) {
      final isValid = await _quickSessionCheck();
      if (isValid) return true;
    }

    final sessionId = await registerSession();
    return sessionId != null;
  }

  void updateLocationAndIP() {
    // Fire and forget در background
    Future.microtask(() async {
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null || _currentSessionId == null) return;

        final ipAddress = await _getIPWithTimeout();
        final locationData = await _getCurrentLocation();

        final updateData = <String, dynamic>{
          'last_activity': DateTime.now().toUtc().toIso8601String(),
        };

        if (ipAddress != null) updateData['ip_address'] = ipAddress;
        if (locationData['location_city'] != null) {
          updateData['location_city'] = locationData['location_city'];
        }
        if (locationData['location_country'] != null) {
          updateData['location_country'] = locationData['location_country'];
        }
        if (locationData['location_region'] != null) {
          updateData['location_region'] = locationData['location_region'];
        }
        if (locationData['location'] != null) {
          updateData['location'] = locationData['location'];
        }

        await _supabase
            .from('active_sessions')
            .update(updateData)
            .eq('id', _currentSessionId!)
            .timeout(const Duration(seconds: 5));

        if (ipAddress != null) {
          await _supabase
              .from('profiles')
              .update({'last_ip': ipAddress})
              .eq('id', userId)
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        logInfo('⚠️ Location/IP update failed (non-critical): $e');
      }
    });
  }

  Future<void> userLogout() async {
    logInfo('👤 User logout...');
    await _handleSessionTermination();
  }

  /// دریافت لیست نشست‌های فعال
  Future<List<SessionModel>> getActiveSessions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        logInfo('⚠️ [getActiveSessions] User not authenticated');
        return [];
      }

      logInfo('📡 [getActiveSessions] Fetching sessions for user: $userId');

      final response = await _supabase
          .from('active_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_activity', ascending: false);

      logInfo('📥 [getActiveSessions] Received ${response.length} sessions from database');

      final sessions = <SessionModel>[];
      for (final json in response) {
        try {
          // ✅ بررسی و تبدیل device_info اگر string است
          if (json['device_info'] is String) {
            try {
              json['device_info'] = jsonDecode(json['device_info'] as String);
            } catch (e) {
              logInfo('⚠️ [getActiveSessions] Error parsing device_info as JSON: $e');
              continue; // این session را skip کن
            }
          }

          // ✅ بررسی و تبدیل location اگر string است
          if (json['location'] is String) {
            try {
              final locationStr = json['location'] as String;
              if (locationStr.isNotEmpty && locationStr.startsWith('{')) {
                json['location'] = jsonDecode(locationStr);
              }
            } catch (e) {
              logInfo('⚠️ [getActiveSessions] Error parsing location as JSON: $e');
              // location را null بگذار
              json['location'] = null;
            }
          }

          final session = SessionModel.fromJson(json);
          sessions.add(session);
        } catch (e, stackTrace) {
          logInfo('❌ [getActiveSessions] Error parsing session ${json['id']}: $e');
          logInfo('📚 [getActiveSessions] Stack: $stackTrace');
          logInfo('📋 [getActiveSessions] Session data: $json');
          // این session را skip کن اما ادامه بده
        }
      }

      logInfo('✅ [getActiveSessions] Successfully parsed ${sessions.length} sessions');
      return sessions;
    } catch (e, stackTrace) {
      logInfo('❌ [getActiveSessions] خطا در دریافت نشست‌ها: $e');
      logInfo('📚 [getActiveSessions] Stack: $stackTrace');
      return [];
    }
  }

  /// Stream نشست‌های فعال
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
          .stream(primaryKey: ['id'])
          .handleError((error, stackTrace) {
        logInfo('❌ [watchActiveSessions] Stream error: $error');
        logInfo('📚 [watchActiveSessions] Stack: $stackTrace');
      });

      await for (final data in stream) {
        try {
          logInfo('📡 [watchActiveSessions] Received ${data.length} items from stream');
          
          // فیلتر کردن داده‌ها بر اساس user_id و is_active
          final filtered = data.where((json) {
            final userId = json['user_id'] as String?;
            final isActive = json['is_active'] as bool?;
            final matches = userId == user.id && isActive == true;
            if (!matches) {
              logInfo('🔍 [watchActiveSessions] Filtered out session: userId=$userId, isActive=$isActive');
            }
            return matches;
          }).toList();
          
          logInfo('✅ [watchActiveSessions] After filtering: ${filtered.length} sessions');

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

          final sessions = <SessionModel>[];
          for (final json in filtered) {
            try {
              // ✅ بررسی و تبدیل device_info اگر string است
              if (json['device_info'] is String) {
                try {
                  json['device_info'] = jsonDecode(json['device_info'] as String);
                } catch (e) {
                  logInfo('⚠️ [watchActiveSessions] Error parsing device_info as JSON: $e');
                  continue; // این session را skip کن
                }
              }

              // ✅ بررسی و تبدیل location اگر string است
              if (json['location'] is String) {
                try {
                  final locationStr = json['location'] as String;
                  if (locationStr.isNotEmpty && locationStr.startsWith('{')) {
                    json['location'] = jsonDecode(locationStr);
                  }
                } catch (e) {
                  logInfo('⚠️ [watchActiveSessions] Error parsing location as JSON: $e');
                  // location را null بگذار
                  json['location'] = null;
                }
              }

              final session = SessionModel.fromJson(json);
              sessions.add(session);
            } catch (e, stackTrace) {
              logInfo('⚠️ [watchActiveSessions] Error parsing session ${json['id']}: $e');
              logInfo('📚 [watchActiveSessions] Stack: $stackTrace');
              logInfo('📋 [watchActiveSessions] Session data: $json');
              // این session را skip کن اما ادامه بده
            }
          }

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

      // ✅ بررسی امنیتی: بررسی مجدد قبل از فراخوانی RPC
      final canTerminateThis = await _canTerminateSession(sessionId);

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
            logInfo(
                '❌ [terminateSession] Session user_id mismatch - security violation');
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
          errorMessage: 'نشست مورد نظر یافت نشد',
        );
      }

      final targetUserId = finalTargetCheck['user_id'] as String?;
      if (targetUserId != currentUser.id) {
        logInfo(
            '❌ [terminateSession] Target session belongs to different user - security violation');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'خطای امنیتی: نشست متعلق به شما نیست',
        );
      }

      // فراخوانی RPC function برای خاتمه نشست
      try {
        final result = await _supabase.rpc('terminate_session', params: {
          'target_session_id': sessionId,
        });

        if (result == true) {
          logInfo('✅ [terminateSession] Session terminated successfully');
          return TerminateSessionResult(
            success: true,
          );
        } else {
          logInfo('⚠️ [terminateSession] RPC returned false');
          return TerminateSessionResult(
            success: false,
            errorMessage: 'عملیات خاتمه نشست ناموفق بود',
          );
        }
      } catch (e) {
        logInfo('❌ [terminateSession] RPC error: $e');
        return TerminateSessionResult(
          success: false,
          errorMessage: 'خطا در خاتمه نشست: $e',
        );
      }
    } catch (e, stackTrace) {
      logInfo('❌ [terminateSession] Error: $e');
      logInfo('📚 [terminateSession] Stack: $stackTrace');
      return TerminateSessionResult(
        success: false,
        errorMessage: 'خطای غیرمنتظره: $e',
      );
    }
  }

  /// بررسی اینکه آیا می‌تواند یک نشست خاص را حذف کند
  Future<bool> _canTerminateSession(String targetSessionId) async {
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
        logInfo(
            '❌ [canTerminateSession] Session user_id mismatch - security violation');
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
          logInfo(
              '❌ [canTerminateSession] Target session belongs to different user - security violation');
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
        logInfo(
            '❌ [canTerminateSession] Target session belongs to different user - security violation');
        return false;
      }

      final targetCreatedAt =
          DateTime.parse(targetResponse['created_at'] as String);

      // فقط می‌تواند نشست‌های جدیدتر از خودش را حذف کند
      return targetCreatedAt.isAfter(currentCreatedAt);
    } catch (e) {
      logInfo('❌ خطا در بررسی امکان حذف نشست: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════

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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          final city = data['city']?.toString();
          final country = data['country']?.toString();
          final region = data['regionName']?.toString();
          final lat = data['lat']?.toString();
          final lon = data['lon']?.toString();

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

  Map<String, dynamic> _getEmptyLocationData() {
    return {
      'location_city': null,
      'location_country': null,
      'location_region': null,
      'location': null,
    };
  }

  void dispose() {
    _stopHealthCheck();
    _activityTimer?.cancel();
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

