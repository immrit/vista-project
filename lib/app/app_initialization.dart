import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:Vista/firebase_options.dart';
import 'package:Vista/services/PushNotificationService.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/DB/isar_database_manager.dart';
import 'package:Vista/DB/settings_cache_service.dart';
import 'package:Vista/DB/advanced_settings_service.dart';
import 'package:Vista/DB/high_performance_cache_system.dart';
import 'package:Vista/services/memory_leak_detector.dart';
import 'package:Vista/utils/performance_monitor.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📬 Handling a background message: ${message.messageId}");
  if (message.data['type'] == 'chat_message') {
    final notificationService = PushNotificationService(null);
    await notificationService.showBackgroundNotification(message);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('🌙 notificationTapBackground called');
  // Logic to handle background reply can be added here
}

class AppInitialization {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> loadDeferredServices() async {
    // Placeholder for deferred services initialization
  }

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Core services
    await initializeDateFormatting('fa', null);
    _setupPerformanceOptimizations();
    PerformanceMonitor().startMonitoring();
    await _initializeFirebase();
    await initializeSupabaseWithFailover().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Supabase init timeout'),
    );
    await SessionManagerServiceV2().initialize();
    await IsarDatabaseManager().instance;
    await SettingsCacheService().initialize();
    await AdvancedSettingsService().initialize();
    await HighPerformanceCacheSystem().initialize();
    MemoryLeakDetector().startMonitoring();
  }

  static Future<void> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('⚠️ Firebase init warning: $e');
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
