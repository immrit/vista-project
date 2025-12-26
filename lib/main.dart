import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform; // ✅ برای تشخیص پلتفرم
import 'package:Vista/DB/unified_conversation_cache_service.dart';
import 'package:Vista/view/screen/Settings/vistaStore/store.dart';
import 'package:Vista/view/screen/SplashScreen.dart';
import 'package:Vista/view/util/const.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'DB/profile_cache_service.dart';
import 'DB/settings_cache_service.dart';
import 'DB/advanced_settings_service.dart';
import 'DB/isar_database_manager.dart'; // Added Isar
import 'DB/high_performance_cache_system.dart';
import 'services/voice_cache_service.dart';
import 'services/network_status_service.dart';
import 'services/network_state_service.dart';
import 'services/retry_queue_service.dart';
import 'services/session_manager_service_v2.dart';
import 'middleware/session_middleware.dart';
import 'firebase_options.dart';
import 'provider/theme_provider.dart';
import 'services/memory_leak_detector.dart';
import 'services/cache_manager.dart';

import 'services/ChatService_LEGACY.dart';
import 'services/deep_link_service.dart' as new_deep_link;
import 'services/PushNotificationService.dart';
import 'services/notification_navigation_service.dart';
// ✅ استفاده از صفحه چت جدید (ChatScreen قدیمی دیگه استفاده نمیشه)
import 'features/chat/screens/modern_chat_screen.dart';
import 'view/screen/Settings/Settings.dart';
import 'view/screen/homeScreen.dart';
import 'view/screen/ouathUser/editeProfile.dart';
import 'view/screen/auth/auth_screen.dart';
import 'view/screen/auth/biometric_login_screen.dart';
import 'view/screen/auth/reset_password_screen.dart';
import 'view/screen/auth/password_reset_code_screen.dart';
import 'view/screen/onboarding/Onboarding.dart';
import 'services/advanced_security_service.dart';
import 'services/wallpaper_cache_service.dart';
import 'services/profile_service.dart';
import 'services/user_presence_service.dart';
import 'services/optimized_message_deletion_service.dart';
import 'view/screen/PublicPosts/publicPosts.dart';
import 'view/screen/PublicPosts/PostDetailPage.dart';
import 'view/screen/PublicPosts/profileScreen.dart';
import 'utils/performance_monitor.dart';
import 'services/animation_controller_service.dart';
import 'services/advanced_haptic_feedback_service.dart';
import 'services/auto_lock_service.dart';
import 'provider/settings_providers.dart';
import 'view/util/themes.dart';
import 'package:package_info_plus/package_info_plus.dart'; // ✅ برای گرفتن نسخه اپ
import 'package:device_info_plus/device_info_plus.dart'; // ✅ برای گرفتن مدل دستگاه
import 'package:loading_animation_widget/loading_animation_widget.dart';
// Clipboard از طریق flutter/services.dart که قبلاً import شده در دسترس است

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// GlobalKey برای navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔥 Background Message Handler - باید Top-Level باشه (خارج از کلاس‌ها)
/// این تابع وقتی اپ کاملا بسته است و پیام میاد اجرا میشه
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // چون در پس‌زمینه هستیم باید Firebase رو دستی اینیشیالایز کنیم
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("📬 Handling a background message: ${message.messageId}");
  print("   Type: ${message.data['type']}");
  print("   Data: ${message.data}");

  // اگر پیام نوعش chat_message بود، باید نوتیفیکیشن رو دستی نشون بدیم
  if (message.data['type'] == 'chat_message') {
    // اینجا یه نمونه موقت از سرویس میسازیم فقط برای نمایش اعلان
    // نکته: چون دسترسی به ProviderScope نداریم، مستقیم کلاس رو صدا میزنیم
    final notificationService = PushNotificationService(null);
    await notificationService.showBackgroundNotification(message);
  }
}

/// 🔥 Handler برای پاسخ سریع در بک‌گراند (Top-Level Function)
/// این تابع وقتی اپ کاملاً بسته است و کاربر روی دکمه "پاسخ" می‌زند اجرا می‌شود
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('🌙 notificationTapBackground called');
  print('   Action ID: ${notificationResponse.actionId}');
  print('   Input: ${notificationResponse.input}');

  // هندل کردن پاسخ سریع (Reply) در بک‌گراند
  if (notificationResponse.input?.isNotEmpty ?? false) {
    print('📝 دریافت پاسخ در بک‌گراند: ${notificationResponse.input}');
    // اینجا باید سرویس ارسال پیام را صدا بزنید
    // برای پیاده‌سازی کامل، باید یک نمونه جدید از Supabase Client اینجا بسازید
    // فعلاً فقط لاگ می‌کنیم تا کرش نکنیم
    try {
      // TODO: در نسخه‌های بعدی می‌توانیم Supabase را اینجا initialize کنیم و پیام را ارسال کنیم
      // final supabase = Supabase.instance.client;
      // await supabase.rpc('send_reply_message', params: {...});
    } catch (e) {
      print('❌ Error in background reply handler: $e');
    }
  }
}

/// Notification response handler (برای فورگراند)
Future<void> notificationResponseHandler(NotificationResponse response) async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔔 کلیک روی Local Notification');
  print('   Action ID: ${response.actionId}');
  print('   Input: ${response.input}');
  print('   Notification ID: ${response.id}');
  print('   Raw Payload: ${response.payload}');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (response.payload != null && response.payload!.isNotEmpty) {
    try {
      // تست parse کردن
      final decoded = jsonDecode(response.payload!);
      print('✅ Payload decoded successfully:');
      print('   Type: ${decoded['type']}');
      print('   PostID: ${decoded['post_id']}');
      print('   CommentID: ${decoded['comment_id']}');
      print('   ConversationID: ${decoded['conversation_id']}');
      print('   SenderID: ${decoded['sender_id']}');
    } catch (e) {
      print('❌ خطا در parse کردن payload: $e');
    }

    // منتظر می‌مونیم تا context آماده بشه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      print('📍 Context available: ${context != null}');

      if (context != null) {
        print('🚀 شروع navigation...');
        NotificationNavigationService.handleLocalNotificationPayload(
          context: context,
          payload: response.payload!,
        );
      } else {
        print('⚠️ Cannot navigate: context is null');
      }
    });
  } else {
    print('⚠️ Payload is null or empty');
  }
}

/// Firebase initialization with duplicate check
Future<void> _initializeFirebase() async {
  try {
    // بررسی اینکه آیا Firebase قبلاً initialize شده یا نه
    final apps = Firebase.apps;
    if (apps.isNotEmpty) {
      print(
        '⚠️ Firebase already initialized with ${apps.length} app(s), skipping...',
      );
      return;
    }

    // اگر هیچ app ای وجود ندارد، Firebase را initialize کن
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    if (e.toString().contains('already exists') ||
        e.toString().contains('DEFAULT already exists')) {
      print(
        '⚠️ Firebase already initialized (caught exception), continuing...',
      );
      // Firebase already initialized, continue normally
    } else {
      print('❌ Firebase initialization failed: $e');
      rethrow; // اگر خطای دیگری بود، دوباره پرتاب کن
    }
  }
}

void _setupPerformanceOptimizations() {
  debugPrintRebuildDirtyWidgets = false;
  debugProfileBuildsEnabled = false;

  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 200;
  imageCache.maximumSizeBytes = 80 * 1024 * 1024;

  SchedulerBinding.instance.scheduleWarmUpFrame();
  print('⚙️ Performance optimizations applied');
}

void main() {
  // ✅ تمام کارهای سنگین را از اینجا حذف کردیم و به RootApp بردیم
  // فقط کارهای ضروری سیستمی اینجا می‌مانند

  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // 🔥 Background Message Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ تنظیمات UI سیستم
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 🚀 اجرای فوری برنامه با ویجت RootApp
    // این ویجت وظیفه نشان دادن اسپلش و لود کردن سرویس‌ها را دارد
    runApp(ProviderScope(child: const RootApp()));
  }, (error, stack) {
    // باز کردن صفحه خطا یا لاگ
    if (error.toString().contains('RealtimeSubscribeException')) {
      return;
    }
    print('⚠️ Global error: $error');
  });
}

/// ✅ ویجت ریشه که بلافاصله نمایش داده می‌شود
/// این ویجت در حالی که اسپلش را نشان می‌دهد، سرویس‌ها را در پس‌زمینه لود می‌کند
class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAppServices();
  }

  Future<void> _initAppServices() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Initialize Date Formatting (سریع)
      await initializeDateFormatting('fa', null);

      // 2. Performance & Monitor
      _setupPerformanceOptimizations();
      PerformanceMonitor().startMonitoring();

      // 3. Firebase (معمولا سریع)
      await _initializeFirebase();

      // 4. Supabase (این تابع را در const.dart اصلاح کردیم که سریع باشد)
      await initializeSupabaseWithFailover().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Supabase init timeout'),
      );

      // 5. Session Manager (برای خواندن دیتای آفلاین ضروری است)
      await SessionManagerServiceV2().initialize();

      // 6. Database & Settings (ضروری برای تم و ...)
      // Init Isar
      await IsarDatabaseManager().instance;
      // await DatabaseManager().initializeAllDatabases(); // Removed Sembast
      await SettingsCacheService().initialize();
      await AdvancedSettingsService().initialize();
      await HighPerformanceCacheSystem().initialize(); // Added

      // 7. Memory Leak Detection
      _initializeMemoryLeakDetection();

      // 8. Initial Notification check
      _checkInitialNotification();

      // بقیه سرویس‌ها را می‌توان به صورت موازی یا با تأخیر لود کرد
      _deferOtherServices();
    } catch (e) {
      print('❌ Error during app initialization: $e');
      // حتی اگر خطا خوردیم، اجازه می‌دهیم برنامه باز شود (حالت آفلاین/فال‌بک)
    } finally {
      stopwatch.stop();
      print('🚀 App initialized in ${stopwatch.elapsedMilliseconds}ms');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  /// اجرای سرویس‌های غیرضروری در پس‌زمینه
  void _deferOtherServices() async {
    try {
      await AnimationControllerService().loadSettings();
      await AdvancedHapticFeedbackService().initialize();
      await AutoLockService().initialize();
      await NetworkStateService().initialize();
      await RetryQueueService().initialize();
      await OptimizedMessageDeletionService().initialize();

      // سرویس‌هایی که نیاز به دسترسی به کلاینت سوپابیس دارند
      await UserPresenceService().initialize();
      ProfileService().startRealtimeUpdates();

      VoiceCacheService().initialize(); // fire and forget

      // تلاش برای کش مکالمه‌ها
      UnifiedConversationCacheService().initialize().catchError((_) {});

      // ثبت سکیوریتی و کش‌های جانبی
      await AdvancedSecurityService.initialize();
      await UnifiedCacheManager().initialize();
      await ProfileCacheService().initialize();
      await NetworkStatusService().initialize();

      // بقیه سرویس‌ها...
      WallpaperCacheService.preloadWallpapers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // تا زمانی که سرویس‌های حیاتی لود نشده‌اند، اسپلش UI را نشان بده
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/view/util/images/vistalogo.png',
                  height: 200,
                ),
                const SizedBox(height: 30),
                LoadingAnimationWidget.progressiveDots(
                  color: Colors.white,
                  size: 50,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // وقتی آماده شد، برنامه اصلی را نشان بده
    return const MyApp();
  }
}

/// بررسی اعلان اولیه (وقتی app کاملاً بسته بود و از اعلان باز شد)
Future<void> _checkInitialNotification() async {
  try {
    // 1. بررسی اینکه آیا اپ با کلیک روی نوتیفیکیشن "لوکال" (چت‌های ما) باز شده؟
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails!.notificationResponse?.payload;

      if (payload != null && payload.isNotEmpty) {
        print('🚀 App opened from Local Notification (Payload found)');
        print('   Payload: $payload');

        // منتظر می‌مانیم تا صفحه ساخته شود
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            final context = navigatorKey.currentContext;
            if (context != null) {
              // هدایت دستی به صفحه مقصد
              NotificationNavigationService.handleLocalNotificationPayload(
                context: context,
                payload: payload,
              );
            }
          });
        });
        return; // اگر لوکال بود، دیگر فایربیس را چک نکن
      }
    }

    // 2. اگر لوکال نبود، فایربیس را چک کن (برای اعلان‌های سیستمی قدیمی)
    if (Firebase.apps.isNotEmpty) {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from FCM System Notification');
        print('   Data: ${initialMessage.data}');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            final context = navigatorKey.currentContext;
            if (context != null) {
              NotificationNavigationService.handleFCMPayload(
                context: context,
                data: initialMessage.data,
              );
            }
          });
        });
      }
    }
  } catch (e) {
    print('❌ خطا در بررسی initial notification: $e');
  }
}

final supabase = Supabase.instance.client;

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  StreamSubscription<AuthState>?
      _authSubscription; // ✅ برای مدیریت subscription
  bool _isLoading = false;
  bool _appInitialized = false;
  Timer? _profileCheckTimer;
  Timer? _sessionCheckTimer; // ✅ برای session monitoring

  @override
  void dispose() {
    _authSubscription?.cancel(); // ✅ Cancel subscription
    _sessionCheckTimer?.cancel(); // ✅ Cancel timer
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _profileCheckTimer?.cancel();

    // ✅ null کردن callback session termination برای جلوگیری از خطا
    try {
      final sessionManager = SessionManagerServiceV2();
      sessionManager.onSessionTerminated = null;
    } catch (e) {
      print('⚠️ Error clearing session termination callback: $e');
    }

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();

    // مدیریت دیپ لینک‌های ورودی
    _setupDeepLinkHandling();

    // ✅ مدیریت صحیح Auth State Changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      print('🔔 Auth event: $event');

      try {
        switch (event) {
          case AuthChangeEvent.initialSession:
            // بررسی session اولیه
            if (session != null) {
              print('✅ Initial session restored: ${session.user.email}');
              await _handleUserSignIn(session);
            } else {
              print('ℹ️ No initial session - user needs to login');
            }
            break;
          case AuthChangeEvent.signedIn:
            print('✅ User signed in: ${session?.user.email}');
            await _handleUserSignIn(session);
            break;
          case AuthChangeEvent.signedOut:
            print('🚪 User signed out');
            await _handleUserSignOut();
            break;
          case AuthChangeEvent.tokenRefreshed:
            print('🔄 Token refreshed successfully');
            // Session به‌روزرسانی شد - نیازی به کار خاصی نیست
            break;
          case AuthChangeEvent.userUpdated:
            print('👤 User profile updated');
            break;
          case AuthChangeEvent.passwordRecovery:
            print('🔑 Password recovery initiated');
            break;
          default:
            print('ℹ️ Auth event: $event');
        }
      } catch (e) {
        print('❌ Error handling auth state change: $e');
        // Only sign the user out for fatal auth errors. Ignore transient
        // network/timeouts to avoid forcing logout when offline.
        final errorString = e.toString().toLowerCase();
        final isNetworkError = errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('connection') ||
            errorString.contains('socket') ||
            errorString.contains('failed host lookup') ||
            errorString.contains('retryable');

        // Only treat clearly revoked/invalid refresh token as fatal.
        final isFatalAuthError = !isNetworkError &&
            (errorString.contains('invalid refresh token') ||
                errorString.contains('token revoked'));

        if (isFatalAuthError) {
          print('🔴 Fatal Auth Error: Signing out...');

          if (mounted && navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text(
                    'جلسه کاری شما منقضی شده است. لطفاً دوباره وارد شوید.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }

          await supabase.auth.signOut();
        } else if (isNetworkError) {
          print('⚠️ Network error detected, keeping session active');
          // Keep session active when transient network errors occur
        } else {
          print('🛡️ Ignored non-fatal auth error to keep user logged in');
        }
      }
    });

    // ✅ شروع session monitoring
    _startSessionMonitoring();

    // ✅ گوش دادن به تغییرات شبکه برای آپدیت نشست
    // به محض اینکه وضعیت شبکه از "قطع" به "وصل" تغییر کرد، اطلاعات نشست را آپدیت کن
    _setupNetworkStateListener();

    // ✅ تنظیم callback برای خاتمه نشست
    _setupSessionTerminationHandler();
  }

  /// تنظیم handler برای خاتمه نشست (فقط در صورت خاتمه توسط کاربر دیگر)
  void _setupSessionTerminationHandler() {
    final sessionManager = SessionManagerServiceV2();
    sessionManager.onSessionTerminated = () {
      // استفاده از postFrameCallback برای اطمینان از اینکه در frame بعدی اجرا می‌شود
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final context = navigatorKey.currentContext;
        if (context == null || !context.mounted) return;

        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );

          // نمایش SnackBar با تأخیر کوتاه برای اطمینان از اینکه navigation کامل شده
          Future.delayed(const Duration(milliseconds: 300), () {
            final snackContext = navigatorKey.currentContext;
            if (snackContext != null && snackContext.mounted) {
              ScaffoldMessenger.of(snackContext).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('نشست شما توسط دستگاه دیگری خاتمه یافت'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange[700],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
        } catch (e) {
          print('⚠️ Error in session termination handler: $e');
        }
      });
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // اگر اپلیکیشن برای اولین بار initialize شده است
    if (!_appInitialized && mounted) {
      _appInitialized = true;

      // مدیریت FCM توکن - بعد از Firebase initialization
      // تنظیم listener برای token refresh
      _setupFCMToken();

      // پردازش توکن‌های در انتظار بعد از ایجاد context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // App initialization completed
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLockService = AutoLockService();
    final sessionManager = SessionManagerServiceV2();

    if (state == AppLifecycleState.detached) {
      // Cache cleanup is now handled by Sembast automatically
      // ✅ تلاش برای ذخیره نشست قبل از خاتمه کامل اپ
      sessionManager.onAppPaused();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App به background رفت - زمان آخرین فعالیت را ثبت کن
      autoLockService.recordUserActivity();

      // ✅ اطلاع‌رسانی به SessionManager V2 که اپ به پس‌زمینه رفت (غیرمسدودکننده)
      sessionManager.onAppPaused().catchError((e) {
        print('⚠️ Error in session pause handling: $e');
      });
    } else if (state == AppLifecycleState.resumed) {
      // App به foreground برگشت - بررسی قفل
      autoLockService.recordUserActivity();
      autoLockService.refreshSettings();

      // ✅ اطلاع‌رسانی به SessionManager V2 که اپ برگشت (غیرمسدودکننده)
      sessionManager.onAppResumed().catchError((e) {
        print('⚠️ Error in session resume handling: $e');
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // App resumed
        }
      });
    }
  }

  /// راه‌اندازی مدیریت دیپ لینک
  void _setupDeepLinkHandling() {
    // پردازش لینک اولیه
    _processInitialLink();

    // گوش دادن به دیپ لینک‌های ورودی
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          final safe =
              'scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}';
          print('Received deep link: $safe');
          _processDeepLink(uri);
        }
      },
      onError: (error) {
        print('Deep link error');
      },
    );
  }

  /// پردازش لینک اولیه
  Future<void> _processInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        final safe =
            'scheme=${initialLink.scheme}, host=${initialLink.host}, path=${initialLink.path}';
        print('Processing initial link: $safe');
        _processDeepLink(initialLink);
      }
    } catch (e) {
      print('Error processing initial link: $e');
    }
  }

  /// پردازش دیپ لینک برای انواع مختلف
  void _processDeepLink(Uri uri) {
    print('Uri scheme: ${uri.scheme}');
    print('Uri host: ${uri.host}');
    print('Uri path: ${uri.path}');

    // جلوگیری از پردازش همزمان چندین درخواست
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // استفاده از DeepLinkService جدید
      final deepLinkService = new_deep_link.DeepLinkService();
      deepLinkService.handleDeepLink(uri, navigatorKey);
    } catch (e) {
      print('Error processing deep link: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// راه‌اندازی مدیریت توکن FCM
  /// این متد فقط listener برای token refresh تنظیم می‌کنه
  /// FCM token در _handleUserSignIn -> _setupFCMTokenForUser مدیریت میشه
  void _setupFCMToken() {
    // فقط اگر Firebase initialize شده باشه
    if (Firebase.apps.isNotEmpty) {
      FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
        print('🔄 FCM Token refreshed, updating in database...');
        await _setFcmToken(fcmToken);
      });
    }
  }

  /// ✅ ذخیره توکن FCM با استفاده از RPC function جدید (با Visual Debugger)
  Future<void> _setFcmToken(String fcmToken) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('⚠️ کاربر لاگین نیست، توکن ذخیره نمی‌شود.');
        return;
      }

      // تشخیص پلتفرم و مدل دستگاه
      String deviceType = Platform.isAndroid ? 'android' : 'ios';
      String deviceModel = 'Vista App';
      String appVersion = '1.0.0';

      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = '${iosInfo.name} ${iosInfo.model}';
        }
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (_) {
        // استفاده از مقادیر پیش‌فرض در صورت خطا
      }

      print('🚀 تلاش برای ثبت توکن در دیتابیس...');

      // فراخوانی RPC
      await supabase.rpc('register_device', params: {
        'p_fcm_token': fcmToken,
        'p_device_type': deviceType,
        'p_device_model': deviceModel,
        'p_app_version': appVersion,
      });

      print('✅ توکن با موفقیت ثبت شد');
      print('   Device Type: $deviceType');
      print('   Device Model: $deviceModel');
      print('   App Version: $appVersion');
    } catch (e) {
      // خطا در کنسول لاگ می‌شود (از نمایش اسنک‌بار برای کاربر صرف‌نظر شد طبق درخواست)
    }
  }

  // ✅ توابع کمکی برای مدیریت sign in/out
  Future<void> _handleUserSignIn(Session? session) async {
    if (session == null) return;

    // آپدیت موقعیت و IP در پس‌زمینه (غیرمسدودکننده)
    final sessionManager = SessionManagerServiceV2();
    sessionManager.updateLocationAndIP();
    debugPrint('🔐 Processing user sign-in');

    // ثبت نشست در LoginScreen انجام می‌شود - اینجا ثبت نمی‌کنیم

    // به‌روزرسانی وضعیت آنلاین کاربر
    final chatService = ChatService();
    chatService.updateUserOnlineStatus();

    // کش کردن پروفایل و پست‌ها
    try {
      final uid = session.user.id;
      unawaited(ProfileCacheService().cacheProfileAndPosts(uid));
    } catch (e) {
      print('⚠️ Prefetch profile/posts on sign-in failed: $e');
    }

    // تنظیم FCM Token
    await _setupFCMTokenForUser();
  }

  Future<void> _handleUserSignOut() async {
    debugPrint('🚪 Processing user sign-out');

    // پاک کردن cache‌ها
    try {
      // ProfileCacheService به صورت خودکار cache را مدیریت می‌کند
      // در صورت نیاز می‌توانید متدهای خاصی را فراخوانی کنید
      // سایر cache‌ها...
    } catch (e) {
      print('⚠️ Error clearing caches: $e');
    }

    // هدایت به صفحه ورود
    if (mounted && navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!).pushNamedAndRemoveUntil(
        '/auth',
        (route) => false,
      );
    }
  }

  Future<void> _setupFCMTokenForUser() async {
    try {
      // بررسی اینکه Firebase initialize شده یا نه
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase not initialized, skipping FCM setup');
        return;
      }

      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.getAPNSToken();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        await _setFcmToken(fcmToken);
        // Avoid logging full FCM token
        final redacted = fcmToken.length > 8
            ? '${fcmToken.substring(0, 4)}...${fcmToken.substring(fcmToken.length - 4)}'
            : '***';
        print("FCM Token updated: $redacted");

        // راه‌اندازی PushNotificationService بعد از لاگین
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final pushNotificationService = ref.read(
              pushNotificationServiceProvider,
            );
            pushNotificationService.init(context);
          }
        });
      }
    } catch (e) {
      print('❌ خطا در راه‌اندازی FCM: $e');
    }
  }

  // ✅ Session Monitoring
  void _startSessionMonitoring() {
    _sessionCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) async {
        try {
          final session = supabase.auth.currentSession;

          if (session == null) {
            // If there's no session, do nothing. Middleware or other
            // handlers can act as needed.
            return;
          }

          // Check token expiry
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final expiresAt = session.expiresAt ?? 0;
          final timeUntilExpiry = expiresAt - now;

          // If less than 20 minutes remain, try a background refresh
          if (timeUntilExpiry < 1200) {
            print('🔄 Session refreshing in background...');
            try {
              await supabase.auth.refreshSession();
            } catch (e) {
              // If refresh fails (likely offline), do NOT sign out the user.
              print('⚠️ Refresh failed (Offline?), keeping session active: $e');
            }
          }
        } catch (e) {
          print('❌ Session check error (Ignored): $e');
        }
      },
    );
  }

  // ✅ گوش‌دادن به تغییرات وضعیت شبکه برای آپدیت نشست
  void _setupNetworkStateListener() {
    try {
      NetworkStateService().stateStream.listen((networkState) {
        if (networkState.isConnected) {
          print('✅ Network connected! Syncing session data...');

          // یک تاخیر کوتاه می‌دهیم تا اتصال پایدار شود
          Future.delayed(const Duration(seconds: 2), () {
            try {
              SessionManagerServiceV2().onNetworkRestored();
            } catch (e) {
              print('⚠️ Error calling onNetworkRestored: $e');
            }
          });
        } else {
          print('📡 Network disconnected');
        }
      });
    } catch (e) {
      print('⚠️ Error setting up network state listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, child) {
            final theme = ref.watch(dynamicThemeProvider);

            // دریافت تنظیمات انیمیشن
            final performanceAsync = ref.watch(performanceSettingsProvider);
            final animations = performanceAsync.value?['animations']
                    as Map<String, dynamic>? ??
                {};
            final animationsEnabled = animations['enabled'] as bool? ?? true;
            final reduceMotion = animations['reduce_motion'] as bool? ?? false;

            // دریافت تنظیمات دسترسی‌پذیری برای color blind mode
            final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
            final accessibility = appSettingsAsync.value?['accessibility']
                    as Map<String, dynamic>? ??
                {};
            final colorBlindMode =
                accessibility['color_blind_mode'] as String? ?? 'none';

            // اعمال color blind filter
            final colorBlindFilter = getColorBlindFilter(colorBlindMode);

            return MaterialApp(
              title: 'Vista',
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: animationsEnabled && !reduceMotion
                        ? FadeUpwardsPageTransitionsBuilder()
                        : _NoAnimationPageTransitionsBuilder(),
                    TargetPlatform.iOS: animationsEnabled && !reduceMotion
                        ? CupertinoPageTransitionsBuilder()
                        : _NoAnimationPageTransitionsBuilder(),
                  },
                ),
              ),
              builder: colorBlindFilter != null
                  ? (context, child) {
                      return ColorFiltered(
                        colorFilter: colorBlindFilter,
                        child: child!,
                      );
                    }
                  : null,
              navigatorKey: navigatorKey,
              home: SplashScreen(),
              initialRoute: '/',
              scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              routes: {
                '/home': (context) => const SessionMiddleware(
                      child: HomeScreen(),
                    ),
                '/onboarding': (context) => const Onboarding(),
                '/auth': (context) => const AuthScreen(),
                '/reset-password': (context) => const ResetPasswordScreen(),
                '/reset-password-code': (context) =>
                    const PasswordResetCodeScreen(),
                '/biometric-login': (context) => BiometricLoginScreen(
                      onSuccess: () {
                        Navigator.pushReplacementNamed(context, '/home');
                      },
                      onFallback: () {
                        Navigator.pushReplacementNamed(context, '/auth');
                      },
                    ),
                '/editeProfile': (context) => const SessionMiddleware(
                      child: EditProfile(),
                    ),
                '/settings': (context) => const SessionMiddleware(
                      child: Settings(),
                    ),
                '/post-detail': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final postId = args?['postId'] as String?;
                  if (postId != null) {
                    return SessionMiddleware(
                      child: PostDetailsPage(postId: postId),
                    );
                  }
                  return const Scaffold(
                    body: Center(child: Text('پست یافت نشد')),
                  );
                },
                '/profile': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final username = args?['username'] as String?;
                  if (username != null) {
                    return SessionMiddleware(
                      child: ProfileScreen(username: username, userId: ''),
                    );
                  }
                  return const Scaffold(
                    body: Center(child: Text('پروفایل یافت نشد')),
                  );
                },
                '/feed': (context) => const SessionMiddleware(
                      child: PublicPostsScreen(),
                    ),
                '/chat': (context) {
                  print('🔍 ChatScreen route called');
                  final args = ModalRoute.of(context)?.settings.arguments;
                  print('   Args type: ${args.runtimeType}');
                  print('   Args: $args');

                  // پشتیبانی از هر دو حالت: String مستقیم یا Map
                  String? conversationId;
                  String? otherUserId;
                  String? username;
                  String? avatarUrl;

                  if (args is String) {
                    conversationId = args;
                    print('   Using String argument: $conversationId');
                  } else if (args is Map<String, dynamic>) {
                    conversationId = args['conversationId'] as String?;
                    otherUserId = args['otherUserId'] as String?;
                    username = args['username'] as String?;
                    avatarUrl = args['avatarUrl'] as String?;
                    print(
                        '   Using Map argument: conversationId=$conversationId, otherUserId=$otherUserId');
                  }

                  if (conversationId != null && conversationId.isNotEmpty) {
                    final conversation = UnifiedConversationCacheService()
                        .getConversationSync(conversationId);
                    final otherUserName = username ??
                        conversation?.otherUserName ??
                        'در حال بارگذاری...';
                    final finalOtherUserId =
                        otherUserId ?? conversation?.otherUserId ?? '';
                    final otherUserAvatar =
                        avatarUrl ?? conversation?.otherUserAvatar;

                    print('✅ Opening ChatScreen:');
                    print('   conversationId: $conversationId');
                    print('   otherUserId: $finalOtherUserId');
                    print('   otherUserName: $otherUserName');

                    // ✅ استفاده از صفحه چت مدرن
                    return SessionMiddleware(
                      child: ModernChatScreen(
                        args: ChatScreenArgs(
                          conversationId: conversationId,
                          otherUserName: otherUserName,
                          otherUserAvatar: otherUserAvatar,
                          otherUserId: finalOtherUserId,
                        ),
                      ),
                    );
                  }

                  print('❌ ConversationId is null or empty');
                  return Scaffold(
                    body: Center(
                      child: Text('مکالمه یافت نشد'),
                    ),
                  );
                },
                '/verification-store': (context) {
                  return VerificationBadgeStore();
                },
              },
            );
          },
        );
      },
    );
  }
}

/// Page Transitions Builder بدون انیمیشن
class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Initialize memory leak detection system
void _initializeMemoryLeakDetection() {
  print('🔍 Initializing Memory Leak Detection...');

  try {
    final detector = MemoryLeakDetector();
    detector.startMonitoring();

    print('✅ Memory Leak Detection started');
    print('📊 Monitoring: Objects, Subscriptions, Timers');
  } catch (e) {
    print('⚠️ Warning: Could not start memory leak detection: $e');
  }
}
