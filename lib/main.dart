import 'dart:async';
import 'dart:io' show Platform; // اضافه کن
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
import 'model/Hive Model/RecentSearch.dart';
import 'provider/profile_completion_provider.dart';
import 'provider/provider.dart';
import 'provider/theme_provider.dart';
import 'security/security.dart';
import 'services/ChatService.dart';
import 'services/deepLink.dart';
import 'services/deep_link_service.dart' as new_deep_link;
import 'services/PushNotificationService.dart';
import 'view/screen/chat/ChatScreen.dart';
import 'view/util/themes.dart';
import 'view/screen/Settings/Settings.dart';
import 'view/screen/homeScreen.dart';
import 'view/screen/ouathUser/loginUser.dart';
import 'view/screen/ouathUser/resetPassword.dart';
import 'view/screen/ouathUser/signupUser.dart';
import 'view/screen/ouathUser/welcome.dart';
import 'view/screen/ouathUser/editeProfile.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // اضافه کن
import 'package:intl/intl.dart';
import 'DB/message_cache_service.dart';
import 'services/wallpaper_cache_service.dart';
import 'view/screen/PublicPosts/publicPosts.dart';
import 'view/screen/PublicPosts/PostDetailPage.dart';
import 'view/screen/PublicPosts/profileScreen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// GlobalKey برای navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Notification response handler - now handled by PushNotificationService
/// This is kept for compatibility but the actual handling is done in PushNotificationService
Future<void> notificationResponseHandler(NotificationResponse response) async {
  // This handler is now managed by PushNotificationService
  // The actual navigation logic is in PushNotificationService.handleNotificationNavigation
  print('Notification response received: ${response.actionId}');
}

/// Background message handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // این هندلر فقط برای پیام‌های پس‌زمینه استفاده می‌شود
  // پیام‌های پیش‌زمینه توسط PushNotificationService مدیریت می‌شوند
  print('Background message received: ${message.messageId}');
}

void main() async {
  await HiveInitialize.initialize();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for all locales
  await initializeDateFormatting('fa', null); // اضافه کنید

  // فقط برای غیر وب مسیر را ست کن
  if (!kIsWeb) {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  } else {
    await Hive.initFlutter();
  }

  // debugPrint و احراز وضعیت آنلاین/آفلاین پروفایل
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.contains('MESA') == false) {
      print(message);
    }

    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        // کاربر آنلاین
        await supabase.from('profiles').update({
          'is_online': true,
          'last_online': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', data.session!.user.id);
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (data.session?.user.id != null) {
          await supabase.from('profiles').update({
            'is_online': false,
            'last_online': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', data.session!.user.id);
        }
      }
    });
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // راه اندازی Hive
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(SearchTypeAdapter()); // typeId: 2
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecentSearchAdapter()); // typeId: 1
  }
  await Hive.openBox('settings');

  // راه‌اندازی Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // هندلر پس‌زمینه FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await initializeSupabaseWithFailover();

    // راه‌اندازی Supabase
    // await Supabase.initialize(
    //     url: 'https://api.coffevista.ir:8443',
    //     anonKey:
    //         'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
    //     debug: true);

    final response =
        await Supabase.instance.client.from('profiles').select().single();

    print('Profile data: $response');
  } catch (e) {
    print('Supabase initialization error: $e');
  }

  // بروزرسانی IP فقط روی غیر وب
  if (!kIsWeb) {
    await updateIpAddress();
  }

  // تنظیم تم
  var box = Hive.box('settings');
  String savedTheme = box.get('selectedTheme', defaultValue: 'light');
  ThemeData initialTheme = _getInitialTheme(savedTheme);

  // راه اندازی flutter_local_notifications و ساخت کانال‌ها:
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: notificationResponseHandler,
  );

  // راه‌اندازی Deep Link Service
  final deepLinkService = new_deep_link.DeepLinkService();
  await deepLinkService.initDeepLinks(navigatorKey);

  // چت کانال
  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages',
    'پیام‌های چت',
    description: 'اعلان پیام‌های جدید چت',
    importance: Importance.high,
    showBadge: true,
  );
  // سوشیال کانال
  const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
    'social_notify',
    'اعلان اجتماعی',
    description: 'اعلان‌های اجتماعی (لایک، کامنت و ...)',
    importance: Importance.high,
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

  // FCM foreground messages are now handled by PushNotificationService
  // This listener is set up in PushNotificationService.init() after user login

  // پیش‌بارگذاری والپیپرهای چت در background
  unawaited(WallpaperCacheService.preloadWallpapers());

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

ThemeData _getInitialTheme(String savedTheme) {
  switch (savedTheme) {
    case 'light':
      return lightTheme;
    case 'dark':
      return darkTheme;
    case 'red':
      return redWhiteTheme;
    case 'yellow':
      return yellowBlackTheme;
    case 'teal':
      return tealWhiteTheme;
    default:
      return lightTheme;
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
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        // به‌روزرسانی وضعیت آنلاین کاربر
        final chatService = ChatService();
        chatService.updateUserOnlineStatus();
      }
    });
    // _setupProfileCheck();

    // هندلر FCM در فورگراند قبلاً در main() ست شده است.
    // اینجا نیازی به onMessage.listen مجدد نیست.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // اگر اپلیکیشن برای اولین بار initialize شده است
    if (!_appInitialized && mounted) {
      _appInitialized = true;

      // پردازش توکن‌های در انتظار بعد از ایجاد context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Deep link processing handled by new service
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      final box = await Hive.openBox('settings');
      bool clearDriftCacheOnExit =
          box.get('clearDriftCacheOnExit', defaultValue: true);
      if (clearDriftCacheOnExit) {
        await deleteMessageCacheDbFile();
        await deleteConversationCacheDbFile();
      }
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
          print("FCM Token: $fcmToken");

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

  /// راه‌اندازی مدیریت دیپ لینک
  void _setupDeepLinkHandling() {
    // پردازش لینک اولیه
    _processInitialLink();

    // گوش دادن به دیپ لینک‌های ورودی
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print('Received deep link: $uri');
        _processDeepLink(uri);
      }
    }, onError: (error) {
      print('Deep link error: $error');
    });
  }

  /// پردازش لینک اولیه
  Future<void> _processInitialLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('Processing initial link: $initialLink');
        _processDeepLink(initialLink);
      }
    } catch (e) {
      print('Error processing initial link: $e');
    }
  }

  /// پردازش دیپ لینک برای انواع مختلف
  void _processDeepLink(Uri uri) {
    print('Processing deep link: $uri');
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

  // void _setupProfileCheck() {
  //   // بررسی اولیه
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     ref.read(profileCompletionProvider.notifier).checkProfileCompletion();
  //   });

  //   // تنظیم تایمر برای بررسی هر دقیقه
  //   _profileCheckTimer = Timer.periodic(const Duration(minutes: 7), (_) {
  //     if (mounted) {
  //       _showProfileCompletionDialog();
  //     }
  //   });
  // }

  // void _showProfileCompletionDialog() async {
  //   // برای اطمینان از وجود context صحیح
  //   final context = navigatorKey.currentContext;
  //   if (context == null) return;

  //   final isComplete = await ref
  //       .read(profileCompletionProvider.notifier)
  //       .checkProfileCompletion();
  //   if (!isComplete && mounted) {
  //     // استفاده از GlobalKey برای دسترسی به context صحیح
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext dialogContext) => AlertDialog(
  //         shape:
  //             RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  //         title: const Text(
  //           'تکمیل اطلاعات پروفایل',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //         ),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Icon(Icons.person_outline, size: 48, color: Colors.blue),
  //             const SizedBox(height: 16),
  //             const Text(
  //               'لطفاً برای دسترسی به تمام امکانات برنامه، اطلاعات پروفایل خود را تکمیل کنید.',
  //               textAlign: TextAlign.center,
  //               style: TextStyle(fontSize: 14),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('بعداً'),
  //           ),
  //           FilledButton(
  //             onPressed: () {
  //               Navigator.pop(context);
  //               Navigator.pushNamed(context, '/editeProfile');
  //             },
  //             style: FilledButton.styleFrom(
  //               backgroundColor: Colors.blue,
  //             ),
  //             child: const Text(
  //               'تکمیل پروفایل',
  //               style: TextStyle(color: Colors.white),
  //             ),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  // }

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
              navigatorKey: navigatorKey, // استفاده از navigator key
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
                '/reset-password': (context) => ResetPasswordPage(
                      token: ModalRoute.of(context)?.settings.arguments
                              as String? ??
                          '',
                    ),
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
                  // اگر conversationId وجود داشت، صفحه چت را باز کن
                  if (conversationId != null) {
                    // مقداردهی اطلاعات کاربر مقابل از کش مکالمات
                    // فرض: ConversationCacheService و ConversationModel را ایمپورت کرده‌ای
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
                  // اگر conversationId نبود، یک صفحه خالی یا ارور نمایش بده
                  return Scaffold(body: Center(child: Text('مکالمه یافت نشد')));
                },
                '/verification-store': (context) {
                  return VerificationBadgeStore();
                },
              },
              // builder: (context, child) {
              //   return Directionality(
              //     textDirection: TextDirection.rtl,
              //     child: Stack(
              //       children: [
              //         child!,
              //         if (_isLoading)
              //           const Positioned.fill(
              //             child: Center(
              //               child: CircularProgressIndicator(),
              //             ),
              //           ),
              //       ],
              //     ),
              //   );
              // },
            );
          },
        );
      },
    );
  }
}
