import 'dart:async';
import 'package:Vista/view/screen/SplashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'DB/hive_initialize.dart';
import 'firebase_options.dart';
import 'model/Hive Model/RecentSearch.dart';
import 'provider/profile_completion_provider.dart';
import 'provider/provider.dart';
import 'security/security.dart';
import 'services/ChatService.dart';
import 'services/deepLink.dart';
import 'view/util/themes.dart';
import 'view/screen/Settings/Settings.dart';
import 'view/screen/homeScreen.dart';
import 'view/screen/ouathUser/loginUser.dart';
import 'view/screen/ouathUser/resetPassword.dart';
import 'view/screen/ouathUser/signupUser.dart';
import 'view/screen/ouathUser/welcome.dart';
import 'view/screen/ouathUser/editeProfile.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // نمایش نوتیفیکیشن پیام جدید در پس‌زمینه/ترمینیت
  if (message.data['type'] == 'chat_message') {
    final senderName = message.data['sender_name'] ?? 'کاربر';
    final content = message.data['content'] ?? 'پیام جدید';
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '$senderName پیام جدید داد',
      content.length > 60 ? '${content.substring(0, 57)}...' : content,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'پیام‌های چت',
          channelDescription: 'اعلان پیام‌های جدید چت',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_launcher',
        ),
      ),
    );
  }
}

void main() async {
  await HiveInitialize.initialize();

  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  // تنظیم debug print
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.contains('MESA') == false) {
      print(message);
    }

    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        // به‌روزرسانی وضعیت آنلاین کاربر هنگام ورود
        await supabase.from('profiles').update({
          'is_online': true,
          'last_online': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', data.session!.user.id);
      } else if (data.event == AuthChangeEvent.signedOut) {
        // به‌روزرسانی وضعیت آفلاین کاربر هنگام خروج
        if (data.session?.user.id != null) {
          await supabase.from('profiles').update({
            'is_online': false,
            'last_online': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', data.session!.user.id);
        }
      }
    });
  };

  // تنظیم orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // راه‌اندازی Hive
  await Hive.initFlutter();

  // ثبت adapter ها
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(SearchTypeAdapter()); // typeId: 2
  }

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecentSearchAdapter()); // typeId: 1
  }

  // باز کردن باکس‌ها
  await Hive.openBox('settings');
  // await Hive.openBox<RecentSearch>('recent_searches');

  // راه‌اندازی Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // هندلر پس‌زمینه FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    // راه‌اندازی Supabase
    await Supabase.initialize(
        url: 'https://api.coffevista.ir:8443',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
        debug: true);

    final response =
        await Supabase.instance.client.from('profiles').select().single();

    print('Profile data: $response');
  } catch (e) {
    print('Supabase initialization error: $e');
  }

  // بروزرسانی IP
  await updateIpAddress();

  // تنظیم تم
  var box = Hive.box('settings');
  String savedTheme = box.get('selectedTheme', defaultValue: 'light');
  ThemeData initialTheme = _getInitialTheme(savedTheme);

  // مقداردهی اولیه flutter_local_notifications و ساخت کانال
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // اگر iOS نیاز دارید، اضافه کنید
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages', // id
    'پیام‌های چت', // name
    description: 'اعلان پیام‌های جدید چت',
    importance: Importance.high,
    showBadge: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(chatChannel);

  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith((ref) => initialTheme),
      ],
      child: MyApp(initialTheme: initialTheme),
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
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.initialTheme});

  final ThemeData initialTheme;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;
  bool _isLoading = false;
  bool _appInitialized = false;
  Timer? _profileCheckTimer;

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _profileCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    _setupProfileCheck();

    // هندلر FCM در فورگراند و بکگراند
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'chat_message') {
        final senderName = message.data['sender_name'] ?? 'کاربر';
        final content = message.data['content'] ?? 'پیام جدید';
        flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch % 100000,
          '$senderName پیام جدید داد',
          content.length > 60 ? '${content.substring(0, 57)}...' : content,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_messages',
              'پیام‌های چت',
              color: Color(
                  0xff3a0088), // this is background color for transparent App Icon
              channelDescription: 'اعلان پیام‌های جدید چت',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
              icon: '@drawable/ic_notification',
            ),
          ),
        );
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
        DeepLinkService.processPendingTokens(context);
      });
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
    print('Query parameters: ${uri.queryParameters}');
    print('Query: ${uri.query}');
    print('Fragment: ${uri.fragment}');
    print('Raw data: ${uri.toString()}');

    // جلوگیری از پردازش همزمان چندین درخواست
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // اینجا ما context را فقط در صورتی که برنامه کاملاً بارگذاری شده باشد ارسال می‌کنیم
      BuildContext? safeContext = _appInitialized ? context : null;

      // اول بر اساس string کامل بررسی می‌کنیم
      if (uri.toString().contains('reset-password')) {
        print('Handling reset password');
        DeepLinkService.handleResetPassword(uri, safeContext);
      } else if (uri.toString().contains('email-change') ||
          (uri.path.contains('email-change'))) {
        print('Handling email change');
        DeepLinkService.handleEmailChange(uri, safeContext);
      } else if (uri.toString().contains('confirm')) {
        print('Handling confirmation');
        DeepLinkService.handleConfirm(uri, safeContext);
      }
      // سپس بر اساس الگوی uri.scheme و uri.host
      else if (uri.scheme == 'vista' && uri.host == 'auth') {
        // روش قدیمی
        switch (uri.path) {
          case '/reset-password':
            DeepLinkService.handleResetPassword(uri, safeContext);
            break;
          case '/email-change':
            DeepLinkService.handleEmailChange(uri, safeContext);
            break;
          case '/confirm':
            DeepLinkService.handleConfirm(uri, safeContext);
            break;
          default:
            print('Unknown path: ${uri.path}');
        }
      } else {
        print('Unrecognized deep link format: $uri');
      }
    } catch (e) {
      print('Error processing deep link: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupProfileCheck() {
    // بررسی اولیه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileCompletionProvider.notifier).checkProfileCompletion();
    });

    // تنظیم تایمر برای بررسی هر دقیقه
    _profileCheckTimer = Timer.periodic(const Duration(minutes: 7), (_) {
      if (mounted) {
        _showProfileCompletionDialog();
      }
    });
  }

  void _showProfileCompletionDialog() async {
    // برای اطمینان از وجود context صحیح
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isComplete = await ref
        .read(profileCompletionProvider.notifier)
        .checkProfileCompletion();
    if (!isComplete && mounted) {
      // استفاده از GlobalKey برای دسترسی به context صحیح
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'تکمیل اطلاعات پروفایل',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'لطفاً برای دسترسی به تمام امکانات برنامه، اطلاعات پروفایل خود را تکمیل کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بعداً'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/editeProfile');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'تکمیل پروفایل',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
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
            final theme = ref.watch(themeProvider);
            return MaterialApp(
              title: 'Vista',
              debugShowCheckedModeBanner: false,
              theme: theme,
              navigatorKey: navigatorKey, // اضافه کردن navigatorKey
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
