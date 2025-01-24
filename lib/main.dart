import 'dart:async';
import 'package:Vista/view/screen/SplashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'model/Hive Model/RecentSearch.dart';
import 'provider/provider.dart';
import 'security/security.dart';
import 'util/themes.dart';
import 'view/screen/Settings.dart';
import 'view/screen/homeScreen.dart';
import 'view/screen/ouathUser/loginUser.dart';
import 'view/screen/ouathUser/resetPassword.dart';
import 'view/screen/ouathUser/signupUser.dart';
import 'view/screen/ouathUser/welcome.dart';
import 'view/screen/ouathUser/editeProfile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تنظیم debug print
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.contains('MESA') == false) {
      print(message);
    }
  };

  // تنظیم orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // راه‌اندازی Hive
  await Hive.initFlutter();

  // // پاک کردن باکس‌های قبلی برای اطمینان
  // await Hive.deleteFromDisk();

  // ثبت adapter ها با typeId های جدید
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(SearchTypeAdapter()); // typeId: 2
  }

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RecentSearchAdapter()); // typeId: 1
  }

  // باز کردن باکس‌ها
  await Hive.openBox('settings');
  await Hive.openBox<RecentSearch>('recent_searches');

  // راه‌اندازی Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    // راه‌اندازی Supabase
    await Supabase.initialize(
        url: 'http://mydash.coffevista.ir:8000',
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.initialTheme});

  // تغییر به ConsumerStatefulWidget
  final ThemeData initialTheme;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _handleIncomingLinks();

    supabase.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        await FirebaseMessaging.instance.requestPermission();
        await FirebaseMessaging.instance.getAPNSToken();
        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null) {
          await _setFcmToken(fcmToken);
          print("FcmToken: $fcmToken");
        }
      }
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      await _setFcmToken(fcmToken);
    });
  }

  Future<void> _setFcmToken(String fcmToken) async {
    final user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final username = user?.userMetadata?['username'] ??
          user?.email?.split('@')[0] ??
          'user_$userId';

      final fullName = user?.userMetadata?['full_name'] ??
          username; // Fallback to username if no full_name

      await supabase.from('profiles').upsert({
        'id': userId,
        'fcm_token': fcmToken,
        'username': username,
        'full_name': fullName, // Add required full_name field
      });
    }
  }

  // مدیریت دیپ لینک‌ها
  void _handleIncomingLinks() {
    try {
      _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          if (uri.scheme == 'vista' && uri.host == 'auth') {
            switch (uri.path) {
              case '/reset-password':
                _handleResetPassword(uri);
                break;
              case '/invite':
                // _handleInvite(uri);
                break;
              case '/confirm':
                // _handleConfirm(uri);
                break;
              case '/email-change':
                // _handleEmailChange(uri);
                break;
            }
          }
        }
      }, onError: (err) {
        print('Deep link error: $err');
      });
    } catch (e) {
      print('Incoming links handler error: $e');
    }
  }

  void _handleResetPassword(Uri uri) {
    String? token = uri.queryParameters['token'];
    if (token != null && mounted) {
      Navigator.pushNamed(context, '/reset-password', arguments: token);
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
            final theme =
                ref.watch(themeProvider); // دریافت تم جاری از طریق Riverpod
            return Portal(
              child: MaterialApp(
                title: 'Vista',
                debugShowCheckedModeBanner: false,
                theme: theme, // استفاده از تم جاری
                home: SplashScreen(),
                initialRoute: '/',
                routes: {
                  '/signup': (context) => const SignUpScreen(),
                  '/home': (context) => const HomeScreen(),
                  '/login': (context) => const Loginuser(),
                  '/editeProfile': (context) => const EditProfile(),
                  // '/profile': (context) => const Profile(),
                  '/welcome': (context) => const WelcomePage(),
                  '/settings': (context) => const Settings(),
                  '/reset-password': (context) => ResetPasswordPage(
                        token: ModalRoute.of(context)?.settings.arguments
                            as String,
                      ),
                },
              ),
            );
          },
        );
      },
    );
  }
}
