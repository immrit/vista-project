import 'package:flutter/material.dart';
import '/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:developer' as developer;

import 'homeScreen.dart';
import 'ouathUser/welcome.dart';
import 'ouathUser/TwoFactorVerificationScreen.dart';
import '../../security/simple_2fa_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // یک تأخیر کوتاه برای نمایش انیمیشن اسپلش
    // دریافت داده به صفحه مربوطه منتقل شده تا رابط کاربری مسدود نشود
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final session = supabase.auth.currentSession;
    if (session == null) {
      // کاربر لاگین نیست - انتقال به صفحه خوش‌آمدگویی
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    } else {
      // کاربر لاگین است - بررسی نیاز به 2FA
      try {
        developer.log(
            'Checking 2FA status in SplashScreen for user: ${session.user.id}');

        // تست عملکرد storage
        final storageWorking = await Simple2FAService.testStorage();
        developer.log('Storage working: $storageWorking');

        // تست عملکرد SharedPreferences
        final sharedPrefsWorking =
            await Simple2FAService.testSharedPreferences();
        developer.log('SharedPreferences working: $sharedPrefsWorking');

        // لیست تمام کلیدهای SharedPreferences
        final allKeys = await Simple2FAService.listAllSharedPreferencesKeys();
        developer.log('All SharedPreferences keys: $allKeys');

        // استفاده از بررسی جدید نشست-محور
        developer.log('🔍 About to call requires2FAVerification...',
            name: 'SplashScreen');
        final requires2FAVerification =
            await Simple2FAService.requires2FAVerification(session.user.id);
        developer.log(
            '🔍 requires2FAVerification returned: $requires2FAVerification',
            name: 'SplashScreen');
        developer.log('2FA verification required: $requires2FAVerification');

        // اضافه کردن debug برای بررسی وضعیت نشست
        final debugInfo =
            await Simple2FAService.debugSessionStatus(session.user.id);
        developer.log('Debug Session Info: $debugInfo');

        if (requires2FAVerification) {
          developer
              .log('🔴 2FA verification required - redirecting to 2FA screen');
          // تمدید خودکار نشست 2FA اگر وجود داشته باشد
          await Simple2FAService.autoExtend2FASession(session.user.id);
          Navigator.pushReplacementNamed(context, '/2fa-verification',
              arguments: {
                'userId': session.user.id,
                'onSuccess': () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
              });
        } else {
          developer
              .log('🟢 2FA verification NOT required - redirecting to home');
          // تمدید خودکار نشست 2FA
          await Simple2FAService.autoExtend2FASession(session.user.id);
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        developer.log('Error checking 2FA status: $e');
        // در صورت خطا، به صفحه اصلی منتقل کن
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 1500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Image.asset(
                  'lib/view/util/images/vistalogo.png',
                  height: 200,
                ),
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
}
