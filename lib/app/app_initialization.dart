import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:Vista/firebase_options.dart';
import 'package:Vista/services/PushNotificationService.dart';
import 'package:Vista/services/local_notification_center.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/DB/isar_database_manager.dart';
import 'package:Vista/DB/settings_cache_service.dart';
import 'package:Vista/DB/advanced_settings_service.dart';
import 'package:Vista/DB/high_performance_cache_system.dart';
import 'package:Vista/services/memory_leak_detector.dart';
import 'package:Vista/utils/performance_monitor.dart';
import 'package:Vista/security/logging_utility.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FIX: Prevent duplicate initialization in background isolate.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint("Handling a background message: ${message.messageId}");
  if (message.data['type'] == 'chat_message') {
    final notificationService = PushNotificationService(null);
    await notificationService.showBackgroundNotification(message);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground called');
  // Logic to handle background reply can be added here
}

class AppInitialization {
  static FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
      LocalNotificationCenter.plugin;
  static bool _audioBackgroundInitialized = false;
  static Completer<bool>? _audioBackgroundInitCompleter;
  static JustAudioPlatform? _plainAudioPlatform;
  static bool _audioBackgroundDisabledForSession = false;
  static bool get isAudioBackgroundReady => _audioBackgroundInitialized;

  static Future<void> loadDeferredServices() async {
    // Placeholder for deferred services initialization
  }

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ensureAudioBackgroundReady();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Initial Setup
    await initializeDateFormatting('fa', null);
    _setupPerformanceOptimizations();
    PerformanceMonitor().startMonitoring();

    // PHASE 1: Core Platform Services (Parallel)
    // These are independent and can run together.
    await Future.wait([
      _initializeFirebase(),
      initializeSupabaseWithFailover().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Supabase init timeout'),
      ),
    ]);

    await PushNotificationService(null).ensureLocalNotificationsInitialized();

    // PHASE 2: Data layer (Parallel)
    // Supabase is ready now. SessionManager needs Supabase.
    await Future.wait([
      SessionManagerServiceV2().initialize(),
      IsarDatabaseManager().instance,
    ]);

    // PHASE 3: Feature Services & Cache (Parallel)
    // These might depend on Isar/Supabase
    await Future.wait([
      SettingsCacheService().initialize(),
      AdvancedSettingsService().initialize(),
      HighPerformanceCacheSystem().initialize(),
    ]);

    // Monitoring (Fire & Forget)
    MemoryLeakDetector().startMonitoring();
  }

  static Future<bool> ensureAudioBackgroundReady(
      {bool forceRetry = false}) async {
    if (kIsWeb) return false;

    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return false;
    }

    _plainAudioPlatform ??= JustAudioPlatform.instance;

    if (_audioBackgroundDisabledForSession && !forceRetry) {
      return false;
    }

    if (_audioBackgroundInitialized && !forceRetry) {
      return true;
    }

    final runningInit = _audioBackgroundInitCompleter;
    if (runningInit != null) {
      return runningInit.future;
    }

    final completer = Completer<bool>();
    _audioBackgroundInitCompleter = completer;
    _audioBackgroundInitialized = false;
    if (forceRetry) {
      _audioBackgroundDisabledForSession = false;
    }

    final previousPlatform = JustAudioPlatform.instance;
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'vista_music_playback',
        androidNotificationChannelName: 'Vista Music Playback',
        androidNotificationChannelDescription:
            'Playback controls for post music',
        androidNotificationOngoing: true,
      );
      _audioBackgroundInitialized = true;
      _audioBackgroundDisabledForSession = false;
      logInfo('Audio background initialized successfully');
      completer.complete(true);
    } catch (e, stackTrace) {
      _audioBackgroundInitialized = false;
      // just_audio_background sets JustAudioPlatform.instance before finishing init.
      // If init fails, restore previous platform so plain just_audio still works.
      JustAudioPlatform.instance = _plainAudioPlatform ?? previousPlatform;
      logError(
        'Audio background init failed',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Audio background init failed: $e');
      debugPrint('$stackTrace');
      completer.complete(false);
    } finally {
      _audioBackgroundInitCompleter = null;
    }

    return completer.future;
  }

  static void disableAudioBackgroundForSession({
    Object? reason,
    StackTrace? stackTrace,
  }) {
    _audioBackgroundDisabledForSession = true;
    _audioBackgroundInitialized = false;
    _audioBackgroundInitCompleter = null;
    final fallbackPlatform = _plainAudioPlatform;
    if (fallbackPlatform != null) {
      JustAudioPlatform.instance = fallbackPlatform;
    }
    logWarning(
      'Audio background disabled for current session',
      error: reason,
      stackTrace: stackTrace,
    );
  }

  static Future<void> _initializeFirebase() async {
    // FIX: Prevent race condition if Firebase is already initialized.
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('Firebase init warning: $e');
    }
  }

  static void _setupPerformanceOptimizations() {
    debugPrintRebuildDirtyWidgets = false;
    debugProfileBuildsEnabled = false;
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 200;
    imageCache.maximumSizeBytes = 80 * 1024 * 1024;
    SchedulerBinding.instance.scheduleWarmUpFrame();
  }
}
