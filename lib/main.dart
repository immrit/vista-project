import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'Provider/appwriteProvider.dart';
import 'View/HomeScreen.dart';
import 'View/WelcomeScreen.dart';
import 'View/authentication/loginScreen.dart';
import 'View/authentication/signupScreen.dart';

void main() async {
  // await Hive.initFlutter(); // مقداردهی اولیه Hive
  // await Hive.openBox('settings'); // باز کردن جعبه تنظیمات
  // WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
  //     .then((_) async {
  //   // بازیابی تم ذخیره‌شده از Hive
  //   var box = Hive.box('settings');
  //   String savedTheme = box.get('selectedTheme', defaultValue: 'light');
  //   ThemeData initialTheme;

  //   // تنظیم تم اولیه بر اساس تم ذخیره‌شده
  //   switch (savedTheme) {
  //     case 'light':
  //       initialTheme = lightTheme;
  //       break;
  //     case 'dark':
  //       initialTheme = darkTheme;
  //       break;
  //     case 'red':
  //       initialTheme = redWhiteTheme;
  //       break;
  //     case 'yellow':
  //       initialTheme = yellowBlackTheme;
  //       break;
  //     case 'teal':
  //       initialTheme = tealWhiteTheme;
  //       break;
  //     default:
  //       initialTheme = lightTheme;
  //   }

  runApp(ProviderScope(
    //   overrides: [
    //     themeProvider.overrideWith((ref) => initialTheme),
    //   ],
    child: const MyApp(),
    // ),
  ));
}
// );
// }

class MyApp extends ConsumerStatefulWidget {
  // final ThemeData initialTheme;

  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription? _sub;
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _handleIncomingLinks();

    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final account = ref.read(accountProvider);
    try {
      final user = await account.get();
      print('User logged in: ${user.$id}');
    } catch (e) {
      print('No user logged in.');
    }
  }

  void _handleIncomingLinks() {
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null &&
          uri.scheme == 'vistaNote' &&
          uri.host == 'reset-password') {
        String? accessToken = uri.queryParameters['access_token'];
        if (accessToken != null) {
          Navigator.pushNamed(context, '/reset-password',
              arguments: accessToken);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
            // final theme = ref.watch(themeProvider);
            return MaterialApp(
              title: 'Vista',
              debugShowCheckedModeBanner: false,
              // theme: theme,
              home: FutureBuilder(
                future: ref.read(accountProvider).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasData) {
                    return const HomeScreen();
                  } else {
                    return const WelcomePage();
                  }
                },
              ),
              initialRoute: '/',
              routes: {
                '/signup': (context) => const SignUpScreen(),
                //   '/home': (context) => const HomeScreen(),
                '/login': (context) => const Loginuser(),
                //   '/editeProfile': (context) => const EditProfile(),
                //   '/welcome': (context) => const WelcomePage(),
                //   '/settings': (context) => const Settings(),
                //   '/reset-password': (context) => ResetPasswordPage(
                //         token:
                //             ModalRoute.of(context)?.settings.arguments as String,
                //       ),
              },
            );
          },
        );
      },
    );
  }
}
