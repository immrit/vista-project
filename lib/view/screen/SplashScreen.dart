import 'dart:async';
import 'package:flutter/material.dart';
import '/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../services/advanced_security_service.dart';
import '../../services/onboarding_service.dart';

import 'auth/auth_screen.dart';
import 'auth/biometric_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'در حال بارگذاری...';
  int _loadingTime = 0;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _startLoadingTimer();
    _redirect();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _startLoadingTimer() {
    _loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _loadingTime++;
        });

        // اگر بیش از 10 ثانیه طول کشید، پیام timeout نمایش بده
        if (_loadingTime >= 10) {
          setState(() {
            _statusMessage = 'اتصال کند است - لطفاً صبر کنید...';
          });
        }
      }
    });
  }

  Future<void> _redirect() async {
    // یک تأخیر کوتاه برای نمایش انیمیشن اسپلش
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      setState(() {
        _statusMessage = 'بررسی وضعیت اتصال...';
      });

      final session = supabase.auth.currentSession;
      if (session == null) {
        // کاربر لاگین نیست - بررسی امنیت و انتقال به صفحه مناسب
        await _handleUnauthenticatedUser();
      } else {
        // کاربر لاگین است - بررسی امنیت و انتقال به صفحه مناسب
        await _handleAuthenticatedUser();
      }
    } catch (e) {
      print('خطا در splash screen: $e');
      // در صورت خطا، به صفحه ورود منتقل شود
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
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

      // بررسی وضعیت onboarding
      final isOnboardingCompleted =
          await OnboardingService.isOnboardingCompleted();

      if (!isOnboardingCompleted) {
        // نمایش onboarding برای کاربران جدید
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        // انتقال به صفحه احراز هویت مدرن
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    } catch (e) {
      // در صورت خطا، به صفحه ورود جدید منتقل شود
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
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
                Navigator.pushReplacementNamed(context, '/auth');
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
        child: Stack(
          children: [
            // لوگو و انیمیشن لودینگ در وسط صفحه
            Center(
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
            // متن وضعیت و دکمه در پایین صفحه
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // نمایش پیام وضعیت در پایین صفحه
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusMessage,
                      key: ValueKey(_statusMessage),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // نمایش دکمه retry اگر بیش از 15 ثانیه طول کشید
                  if (_loadingTime >= 15) ...[
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadingTime = 0;
                          _statusMessage = 'تلاش مجدد...';
                        });
                        _redirect();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        minimumSize: const Size(120, 36),
                      ),
                      child: const Text(
                        'تلاش مجدد',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
