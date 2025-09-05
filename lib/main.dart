import 'dart:async';
import 'package:Vista/DB/conversation_cache_service.dart';
import 'package:Vista/view/screen/Settings/vistaStore/store.dart';
import 'package:Vista/view/screen/SplashScreen.dart';
import 'package:Vista/view/util/const.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'DB/hive_initialize.dart';
import 'firebase_options.dart';
import 'provider/theme_provider.dart';

import 'services/ChatService.dart';
import 'services/auto_cleanup_service.dart';
import 'services/cache_manager.dart';
import 'services/deep_link_service.dart' as new_deep_link;
import 'services/PushNotificationService.dart';
import 'view/screen/chat/ChatScreen.dart';
import 'view/screen/Settings/Settings.dart';
import 'view/screen/homeScreen.dart';
import 'view/screen/ouathUser/loginUser.dart';
import 'view/screen/ouathUser/resetPassword.dart';
import 'view/screen/ouathUser/signupUser.dart';
import 'view/screen/ouathUser/welcome.dart';
import 'view/screen/ouathUser/editeProfile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'DB/message_cache_service.dart';
import 'services/wallpaper_cache_service.dart';
import 'view/screen/PublicPosts/publicPosts.dart';
import 'view/screen/PublicPosts/PostDetailPage.dart';
import 'view/screen/PublicPosts/profileScreen.dart';
import 'security/e2ee_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// GlobalKey برای navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Notification response handler
Future<void> notificationResponseHandler(NotificationResponse response) async {
  print('Notification response received: ${response.actionId}');
}

/// Background message handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.messageId}');
}

void main() async {
  await HiveInitialize.initialize();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for all locales
  await initializeDateFormatting('fa', null);

  // فقط برای غیر وب مسیر را ست کن
  if (!kIsWeb) {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  } else {
    await Hive.initFlutter();
  }

  // راه‌اندازی Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // راه‌اندازی Supabase
  await initializeSupabaseWithFailover();

  // راه‌اندازی سیستم مدیریت کش مرکزی
  final cacheManager = UnifiedCacheManager();
  await cacheManager.initialize();

  // راه‌اندازی سرویس پاکسازی خودکار
  final autoCleanupService = AutoCleanupService();
  await autoCleanupService.initialize();

  // شروع نظارت بر حافظه
  cacheManager.startMemoryMonitoring();

  // راه‌اندازی اعلان‌های محلی
  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: notificationResponseHandler,
  );

  // ایجاد کانال‌های اعلان
  const chatChannel = AndroidNotificationChannel(
    'chat_notifications',
    'Chat Notifications',
    description: 'Notifications for chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  const socialChannel = AndroidNotificationChannel(
    'social_notifications',
    'Social Notifications',
    description: 'Notifications for social activities',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(chatChannel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(socialChannel);

  // پیش‌بارگذاری والپیپرهای چت در background با تأخیر
  Future.delayed(const Duration(seconds: 3), () {
    unawaited(WallpaperCacheService.preloadWallpapers());
  });

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
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
  bool _isLoading = false;
  bool _appInitialized = false;
  Timer? _profileCheckTimer;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _profileCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLinks = AppLinks();

    // مدیریت دیپ لینک‌های ورودی
    _setupDeepLinkHandling();

    // مدیریت FCM توکن
    _setupFCMToken();

    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint('کاربر وارد شد - بررسی تایید دو مرحله‌ای');

        // به‌روزرسانی وضعیت آنلاین کاربر
        final chatService = ChatService();
        chatService.updateUserOnlineStatus();
      } else if (data.event == AuthChangeEvent.signedOut) {
        debugPrint('کاربر خارج شد - پاک کردن نشست‌ها');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // اگر اپلیکیشن برای اولین بار initialize شده است
    if (!_appInitialized && mounted) {
      _appInitialized = true;

      // پردازش توکن‌های در انتظار بعد از ایجاد context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // فقط در اولین اجرا، وضعیت قفل را مقداردهی اولیه می‌کنیم
        if (mounted) {
          // final appLockManager = ref.read(appLockManagerProvider); // Removed app lock manager
          // debugPrint('شروع مقداردهی اولیه وضعیت قفل');
          // appLockManager.initialize().then((_) { // Removed app lock initialization
          //   debugPrint('وضعیت قفل مقداردهی اولیه شد');
          //   // بررسی قفل برنامه در شروع (مثل تلگرام)
          //   _checkAppLockStatus();
          // });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // AppLockLogger.lifecycle('تغییر وضعیت lifecycle: $state'); // Removed app lock logger

    if (state == AppLifecycleState.detached) {
      // AppLockLogger.lifecycle('برنامه detached شد');
      final box = await Hive.openBox('settings');
      bool clearDriftCacheOnExit =
          box.get('clearDriftCacheOnExit', defaultValue: true);
      if (clearDriftCacheOnExit) {
        await deleteMessageCacheDbFile();
        await deleteConversationCacheDbFile();
      }
    } else if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // _checkAppLockStatus(); // Removed app lock check
        }
      });
    } else if (state == AppLifecycleState.paused) {
      // علامت‌گذاری برنامه به عنوان قفل شده وقتی به پس‌زمینه می‌رود (مثل تلگرام)
      // AppLockLogger.lifecycle('برنامه paused شد - قفل کردن برنامه');
      // final appLockService = ref.read(appLockServiceProvider); // Removed app lock service
      // if (await appLockService.isAppLockEnabled()) { // Removed app lock check
      //   AppLockLogger.lifecycle('قفل کردن برنامه هنگام رفتن به پس‌زمینه');
      //   debugPrint('قفل کردن برنامه هنگام رفتن به پس‌زمینه');
      //   await appLockService.markAsLocked();
      //   ref.read(appLockStateProvider.notifier).markAppAsLocked();
      // }
    } else if (state == AppLifecycleState.inactive) {
      // وقتی اپ غیرفعال می‌شود (مثل تغییر اپ یا رفتن به تنظیمات) - قفل کن (مثل تلگرام)
      // AppLockLogger.lifecycle('برنامه inactive شد - قفل کردن برنامه');
      // final appLockService = ref.read(appLockServiceProvider); // Removed app lock service
      // if (await appLockService.isAppLockEnabled()) { // Removed app lock check
      //   AppLockLogger.lifecycle('قفل کردن برنامه هنگام غیرفعال شدن');
      //   debugPrint('قفل کردن برنامه هنگام غیرفعال شدن');
      //   await appLockService.markAsLocked();
      //   ref.read(appLockStateProvider.notifier).markAppAsLocked();
      // }
    }
  }

  /// بررسی وضعیت قفل برنامه
  // Future<void> _checkAppLockStatus() async { // Removed app lock status check
  //   try {
  //     AppLockLogger.main('شروع بررسی وضعیت قفل برنامه');
  //     final appLockManager = ref.read(appLockManagerProvider); // Removed app lock manager
  //     final appLockState = ref.read(appLockStateProvider); // Removed app lock state

  //     // جلوگیری از بررسی همزمان
  //     if (appLockState.isShowingLock || AppLockOverlay.isShowing) { // Removed app lock check
  //       AppLockLogger.main('قفل قبلاً نمایش داده شده - جلوگیری از بررسی مجدد');
  //       debugPrint('قفل قبلاً نمایش داده شده - جلوگیری از بررسی مجدد');
  //       return;
  //     }

  //     // بررسی نیاز به قفل در شروع برنامه (مثل تلگرام)
  //     final shouldShowLock = await appLockManager.shouldShowLock(); // Removed app lock check

  //     AppLockLogger.main(
  //         'بررسی وضعیت قفل برنامه: shouldShowLock=$shouldShowLock');
  //     debugPrint('بررسی وضعیت قفل برنامه: shouldShowLock=$shouldShowLock');

  //     if (shouldShowLock && mounted) {
  //       AppLockLogger.main('نمایش صفحه قفل برنامه');
  //       debugPrint('نمایش صفحه قفل برنامه');

  //       // نمایش صفحه قفل به عنوان overlay
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         if (mounted) {
  //           AppLockLogger.main(
  //               'PostFrameCallback اجرا شد - تلاش برای نمایش overlay');
  //           debugPrint('PostFrameCallback اجرا شد - تلاش برای نمایش overlay');
  //           // اضافه کردن تاخیر برای اطمینان از آماده بودن context
  //           Future.delayed(const Duration(milliseconds: 500), () {
  //             if (mounted) {
  //               AppLockLogger.main(
  //                   'تاخیر 500ms تمام شد - فراخوانی _showLockOverlay');
  //               debugPrint('تاخیر 500ms تمام شد - فراخوانی _showLockOverlay');
  //               _showLockOverlay();
  //             } else {
  //               AppLockLogger.main(
  //                   'PostFrameCallback بعد از تاخیر: mounted = false');
  //               debugPrint('PostFrameCallback بعد از تاخیر: mounted = false');
  //             }
  //           });
  //         } else {
  //           AppLockLogger.main('PostFrameCallback: mounted = false');
  //           debugPrint('PostFrameCallback: mounted = false');
  //         }
  //       });
  //     } else {
  //       AppLockLogger.main('نیازی به نمایش قفل برنامه نیست');
  //       debugPrint('نیازی به نمایش قفل برنامه نیست');
  //     }
  //   } catch (e) {
  //     AppLockLogger.error('خطا در بررسی وضعیت قفل برنامه', e);
  //     debugPrint('خطا در بررسی وضعیت قفل برنامه: $e');
  //   }
  // }

  /// راه‌اندازی مدیریت دیپ لینک
  void _setupDeepLinkHandling() {
    // پردازش لینک اولیه
    _processInitialLink();

    // گوش دادن به دیپ لینک‌های ورودی
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        final safe = 'scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}';
        print('Received deep link: $safe');
        _processDeepLink(uri);
      }
    }, onError: (error) {
      print('Deep link error');
    });
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
  void _setupFCMToken() {
    supabase.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
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
              final pushNotificationService =
                  ref.read(pushNotificationServiceProvider);
              pushNotificationService.init(context);
            }
          });
        }
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      await _setFcmToken(fcmToken);
    });
  }

  /// ذخیره توکن FCM در پروفایل کاربر
  Future<void> _setFcmToken(String fcmToken) async {
    final user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final username = user?.userMetadata?['username'] ??
          user?.email?.split('@')[0] ??
          'user_$userId';

      final fullName = user?.userMetadata?['full_name'] ?? username;

      await supabase.from('profiles').upsert({
        'id': userId,
        'fcm_token': fcmToken,
        'username': username,
        'full_name': fullName,
      });
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
            return MaterialApp(
              title: 'Vista',
              debugShowCheckedModeBanner: false,
              theme: theme,
              navigatorKey: navigatorKey,
              home: SplashScreen(),
              initialRoute: '/',
              scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              routes: {
                '/signup': (context) => const SignUpScreen(),
                '/home': (context) => const HomeScreen(),
                '/login': (context) => const Loginuser(),
                '/editeProfile': (context) => const EditProfile(),
                '/welcome': (context) => const WelcomePage(),
                '/settings': (context) => const Settings(),
                '/reset-password': (context) {
                  final args =
                      ModalRoute.of(context)?.settings.arguments as String? ??
                          '';
                  return ResetPasswordPage(token: args);
                },
                '/post-detail': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final postId = args?['postId'] as String?;
                  if (postId != null) {
                    return PostDetailsPage(postId: postId);
                  }
                  return const Scaffold(
                      body: Center(child: Text('پست یافت نشد')));
                },
                '/profile': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
                  final username = args?['username'] as String?;
                  if (username != null) {
                    return ProfileScreen(username: username, userId: '');
                  }
                  return const Scaffold(
                      body: Center(child: Text('پروفایل یافت نشد')));
                },
                '/feed': (context) => const PublicPostsScreen(),
                '/chat': (context) {
                  final conversationId =
                      ModalRoute.of(context)?.settings.arguments as String?;
                  if (conversationId != null) {
                    final conversation = ConversationCacheService()
                        .getConversationSync(conversationId);
                    final otherUserName =
                        conversation?.otherUserName ?? 'کاربر';
                    final otherUserId = conversation?.otherUserId ?? '';
                    final otherUserAvatar = conversation?.otherUserAvatar;
                    return ChatScreen(
                      conversationId: conversationId,
                      otherUserName: otherUserName,
                      otherUserId: otherUserId,
                      otherUserAvatar: otherUserAvatar,
                    );
                  }
                  return Scaffold(body: Center(child: Text('مکالمه یافت نشد')));
                },
                '/verification-store': (context) {
                  return VerificationBadgeStore();
                },

                // '/app-lock': (context) => const AppLockScreen(), // Removed app lock screen
                // '/app-lock-test-simple': (context) => const AppLockTestSimple(), // Removed app lock test simple
              },
            );
          },
        );
      },
    );
  }
}
