import 'package:flutter/material.dart';
import '/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../services/advanced_security_service.dart';

import 'ouathUser/welcome.dart';
import 'auth/modern_auth_screen.dart';
import 'auth/biometric_login_screen.dart';

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
      // کاربر لاگین نیست - بررسی امنیت و انتقال به صفحه مناسب
      await _handleUnauthenticatedUser();
    } else {
      // کاربر لاگین است - بررسی امنیت و انتقال به صفحه مناسب
      await _handleAuthenticatedUser();
    }
  }

  Future<void> _handleUnauthenticatedUser() async {
    try {
      // بررسی امنیت حساب کاربری
      final isLocked = await AdvancedSecurityService.isAccountLocked();
      if (isLocked) {
        final remainingTime =
            await AdvancedSecurityService.getRemainingLockoutTime();
        if (remainingTime != null) {
          _showLockoutMessage(remainingTime);
          return;
        }
      }

      // انتقال به صفحه احراز هویت مدرن
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ModernAuthScreen()),
      );
    } catch (e) {
      // در صورت خطا، به صفحه قدیمی منتقل شود
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    }
  }

  Future<void> _handleAuthenticatedUser() async {
    try {
      // بررسی امنیت نشست
      final isSessionValid =
          await AdvancedSecurityService.validateSessionSecurity();
      if (!isSessionValid) {
        // نشست نامعتبر - خروج و انتقال به احراز هویت
        await supabase.auth.signOut();
        await AdvancedSecurityService.clearSecureSession();
        await _handleUnauthenticatedUser();
        return;
      }

      // بررسی احراز هویت بیومتریک
      final isBiometricEnabled =
          await AdvancedSecurityService.isBiometricEnabled();
      if (isBiometricEnabled) {
        // انتقال به صفحه احراز هویت بیومتریک
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BiometricLoginScreen(
              onSuccess: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              onFallback: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),
        );
      } else {
        // انتقال مستقیم به صفحه اصلی
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // در صورت خطا، انتقال مستقیم به صفحه اصلی
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showLockoutMessage(Duration remainingTime) {
    final minutes = remainingTime.inMinutes;
    final seconds = remainingTime.inSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('حساب کاربری قفل شده'),
        content: Text(
          'به دلیل تلاش‌های ناموفق متعدد، حساب کاربری شما قفل شده است.\n'
          'لطفاً $minutes دقیقه و $seconds ثانیه صبر کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _redirect(); // تلاش مجدد
            },
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
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
