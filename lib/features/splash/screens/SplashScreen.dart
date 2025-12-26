import 'package:Vista/security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:Vista/services/advanced_security_service.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/features/auth/screens/biometric_login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    try {
      // ✅ Offline-First: Check SessionManagerV2 directly
      // Since it's initialized in main.dart, it already has the local session loaded.
      final sessionManager = SessionManagerServiceV2.instance;

      // اگر session معتبر داریم (محلی یا ریموت)، مستقیم برو داخل
      if (sessionManager.currentSessionId != null) {
        logInfo('🚀 Offline-First: Local session found, skipping wait.');
        // سریع برو به صفحه اصلی
        if (mounted) {
          _navigateToHome();
        }
        return;
      }

      // اگر session نداریم، شاید Supabase در حال restore باشد (برای اولین نصب یا clear data)
      // یک صبر کوتاه (غیرمسدودکننده برای حس بهتر)
      logInfo('⏳ No local session, waiting briefly for Supabase restore...');

      // تلاش کوتاه برای دیدن اینکه آیا Supabase خودش چیزی پیدا می‌کند
      // مثلاً اگر deep link باشد یا ...
      int attempts = 0;
      while (attempts < 5) {
        // حدود 1 ثانیه
        if (Supabase.instance.client.auth.currentSession != null) {
          logInfo('✅ Supabase session restored during splash wait');
          if (mounted) _navigateToHome();
          return;
        }
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      // اگر هنوز هیچ خبری نیست، برو لاگین
      logInfo('ℹ️ No session found, redirecting to auth');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      logInfo('❌ Error in splash screen: $e');
      // در بدترین حالت، برو لاگین
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  Future<void> _navigateToHome() async {
    // بررسی سریع بیومتریک (اگر فعال باشد)
    final isBiometricEnabled =
        await AdvancedSecurityService.isBiometricEnabled()
            .timeout(const Duration(milliseconds: 300), // timeout خیلی کوتاه
                onTimeout: () => false);

    if (!mounted) return;

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

  // بررسی محدودیت حساب به صورت سریع

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
      ),
    );
  }
}
