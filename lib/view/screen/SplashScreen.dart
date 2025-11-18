import '../../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../services/advanced_security_service.dart';
import '../../services/session_manager_service.dart';
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
    // یک تأخیر کوتاه برای نمایش انیمیشن اسپلش (کاهش یافته)
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    try {
      // بررسی session به صورت موازی با سایر عملیات
      final session = supabase.auth.currentSession;

      if (session == null) {
        // کاربر لاگین نیست - انتقال سریع به auth
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
        return;
      }

      // کاربر لاگین است - بررسی و ثبت session به صورت سریع
      setState(() {
        _statusMessage = 'در حال آماده‌سازی...';
      });

      // بررسی و ثبت session به صورت سریع و موازی
      final sessionManager = SessionManagerService();

      // اجرای موازی: بررسی session و سایر عملیات
      await Future.wait([
        // بررسی و ثبت session با timeout کوتاه
        sessionManager.ensureSessionRegistered().timeout(
              const Duration(seconds: 2),
              onTimeout: () => true, // در صورت timeout، ادامه بده
            ),
        // بررسی محدودیت حساب (موازی)
        _checkAccountLockStatus(session.user.id),
      ], eagerError: false);

      // انتقال به صفحه اصلی
      if (mounted) {
        final isBiometricEnabled =
            await AdvancedSecurityService.isBiometricEnabled().timeout(
                const Duration(milliseconds: 500),
                onTimeout: () => false);

        if (isBiometricEnabled) {
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
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      logInfo('❌ Error in splash screen: $e');
      // در صورت خطا، به صفحه ورود منتقل شود
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  // بررسی محدودیت حساب به صورت سریع
  Future<void> _checkAccountLockStatus(String userId) async {
    try {
      final isLocked =
          await AdvancedSecurityService.isAccountLocked(userId: userId)
              .timeout(const Duration(seconds: 1), onTimeout: () => false);

      if (isLocked && mounted) {
        final lockInfo = await AdvancedSecurityService.getLockInfo(
                userId: userId)
            .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
        final lockReason = lockInfo != null
            ? await AdvancedSecurityService.getLockReasonPersian(userId: userId)
                .timeout(const Duration(milliseconds: 500),
                    onTimeout: () => null)
            : null;
        final remainingTime = await AdvancedSecurityService
                .getRemainingLockoutTime(userId: userId)
            .timeout(const Duration(milliseconds: 500), onTimeout: () => null);

        // خروج از حساب
        try {
          await supabase.auth.signOut();
          await AdvancedSecurityService.clearAllSecurityData();
        } catch (e) {
          // ignore
        }

        // نمایش پیام قفل شدن
        if (mounted) {
          _showAccountLockedDialog(
            remainingTime: remainingTime,
            lockReason: lockReason,
            lockType: lockInfo?['lock_type'] as String?,
          );
        }
      }
    } catch (e) {
      // ignore - خطا را نادیده بگیر
    }
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
