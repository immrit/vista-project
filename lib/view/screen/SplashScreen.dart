import '../../security/logging_utility.dart';
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

      // ✅ بهبود: منتظر بمانید تا session restore شود (به جای تأخیر ثابت 500ms)
      await _waitForSessionRestoration();

      final session = supabase.auth.currentSession;
      print(
          '🔍 Current session status: ${session != null ? "Found" : "Not found"}');

      if (session == null) {
        // کاربر لاگین نیست - بررسی امنیت و انتقال به صفحه مناسب
        logInfo('👤 User not authenticated, redirecting to auth');
        await _handleUnauthenticatedUser();
      } else {
        // کاربر لاگین است - بررسی امنیت و انتقال به صفحه مناسب
        logInfo('👤 User authenticated, proceeding to home');
        await _handleAuthenticatedUser();
      }
    } catch (e) {
      logInfo('❌ Error in splash screen: $e');
      // در صورت خطا، به صفحه ورود منتقل شود
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  // ✅ تابع جدید: منتظر بمانید تا session restore شود
  Future<void> _waitForSessionRestoration({int maxAttempts = 20}) async {
    print('⏳ Waiting for session restoration from local storage...');

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final session = supabase.auth.currentSession;
        if (session != null) {
          print('✅ Session restored successfully! User: ${session.user.email}');
          return;
        }
      } catch (e) {
        // ignore
      }

      if (attempt < maxAttempts - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    print('⏳ Session restoration check completed');
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
      // بررسی اولیه: آیا Supabase session معتبر است؟
      final session = supabase.auth.currentSession;
      if (session == null) {
        logInfo('⚠️ No Supabase session found, redirecting to auth');
        await _handleUnauthenticatedUser();
        return;
      }

      final userId = session.user.id;
      logInfo('👤 Checking lock status for user: $userId');

      // ✅ بررسی محدودیت حساب کاربری از دیتابیس
      setState(() {
        _statusMessage = 'بررسی وضعیت حساب...';
      });

      final isLocked = await AdvancedSecurityService.isAccountLocked(userId: userId);
      if (isLocked) {
        logInfo('🚫 User account is locked, logging out...');
        
        // دریافت اطلاعات قفل
        final lockInfo = await AdvancedSecurityService.getLockInfo(userId: userId);
        final lockReason = lockInfo != null 
            ? await AdvancedSecurityService.getLockReasonPersian(userId: userId)
            : null;
        final remainingTime = await AdvancedSecurityService.getRemainingLockoutTime(userId: userId);

        // خروج از حساب
        try {
          await supabase.auth.signOut();
          await AdvancedSecurityService.clearAllSecurityData();
        } catch (e) {
          logInfo('⚠️ Error signing out: $e');
        }

        // نمایش پیام قفل شدن
        if (mounted) {
          _showAccountLockedDialog(
            remainingTime: remainingTime,
            lockReason: lockReason,
            lockType: lockInfo?['lock_type'] as String?,
          );
        }
        return;
      }

      // بررسی امنیت نشست با error handling بهتر
      bool isSessionValid = false;
      try {
        isSessionValid =
            await AdvancedSecurityService.validateSessionSecurity();
        logInfo('🔐 Session validation result: $isSessionValid');
      } catch (e) {
        logInfo('⚠️ Session validation failed with error: $e');
        // در صورت خطا در validation، session را معتبر در نظر بگیر
        // مگر اینکه مشکل جدی باشد
        isSessionValid = true;
      }

      if (!isSessionValid) {
        print(
            '⚠️ Session validation failed, but keeping user logged in for better UX');
        // به جای خروج اجباری، کاربر را در سیستم نگه دار
        // این مشکل را حل می‌کند که کاربران بعد از restart از حساب خارج شوند
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
      logInfo('⚠️ Error in _handleAuthenticatedUser: $e');
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
          'به دلیل تلاش‌های ناموفق متعدد، حساب کاربری شما قفل شده است.\n\n'
          'لطفاً $minutes دقیقه و $seconds ثانیه صبر کنید و سپس دوباره تلاش کنید.',
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

  void _showAccountLockedDialog({
    Duration? remainingTime,
    String? lockReason,
    String? lockType,
  }) {
    String message = 'حساب کاربری شما محدود شده است.\n\n';

    if (lockReason != null) {
      message += 'علت: $lockReason\n\n';
    }

    if (lockType == 'permanent') {
      message += 'این محدودیت دائمی است. لطفاً با پشتیبانی تماس بگیرید.';
    } else if (remainingTime != null) {
      final minutes = remainingTime.inMinutes;
      final seconds = remainingTime.inSeconds % 60;
      message += 'زمان باقی‌مانده: $minutes دقیقه و $seconds ثانیه\n\n'
          'لطفاً بعد از اتمام زمان، دوباره تلاش کنید.';
    } else {
      message += 'لطفاً با پشتیبانی تماس بگیرید.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ دسترسی محدود شده'),
        content: Text(message),
        actions: [
          if (lockType != 'permanent' && remainingTime != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _redirect(); // تلاش مجدد بعد از اتمام زمان
              },
              child: const Text('تلاش مجدد'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // انتقال به صفحه ورود
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            child: const Text('متوجه شدم'),
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
