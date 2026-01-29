import 'package:Vista/security/logging_utility.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:Vista/services/advanced_security_service.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/features/auth/screens/biometric_login_screen.dart';

/// SplashScreen - Premium First Impression
/// طراحی ساده و مینیمال با انیمیشن زیبا
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showLogo = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  /// شروع توالی اسپلش: 2 ثانیه نمایش لوگو + چک auth + ترانزیشن
  Future<void> _startSplashSequence() async {
    // حداقل 2 ثانیه نمایش لوگو
    final minimumDelay = Future.delayed(const Duration(milliseconds: 2000));

    // همزمان چک auth
    final authStatus = _checkAuthStatus();

    // صبر برای هر دو
    await minimumDelay;
    final isLoggedIn = await authStatus;

    if (!mounted) return;

    // شروع انیمیشن fade out
    setState(() => _showLogo = false);

    // صبر برای انیمیشن خروج
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    // ناوبری با fade transition
    if (isLoggedIn) {
      await _navigateToHome();
    } else {
      _navigateToAuth();
    }
  }

  /// بررسی وضعیت احراز هویت
  Future<bool> _checkAuthStatus() async {
    try {
      // ابتدا چک SessionManager محلی (سریع‌تر)
      final sessionManager = SessionManagerServiceV2.instance;
      if (sessionManager.currentSessionId != null) {
        logInfo('🚀 Local session found');
        return true;
      }

      // سپس چک Supabase
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        logInfo('✅ Supabase session found');
        return true;
      }

      // تلاش کوتاه برای restore
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (Supabase.instance.client.auth.currentSession != null) {
          return true;
        }
      }

      logInfo('ℹ️ No session found');
      return false;
    } catch (e) {
      logInfo('❌ Auth check error: $e');
      return false;
    }
  }

  /// ناوبری به صفحه اصلی (با چک بیومتریک)
  Future<void> _navigateToHome() async {
    try {
      final isBiometricEnabled =
          await AdvancedSecurityService.isBiometricEnabled().timeout(
              const Duration(milliseconds: 300),
              onTimeout: () => false);

      if (!mounted) return;

      if (isBiometricEnabled) {
        Navigator.of(context).pushReplacement(
          _createFadeRoute(
            BiometricLoginScreen(
              onSuccess: () => Navigator.pushReplacementNamed(context, '/home'),
              onFallback: () =>
                  Navigator.pushReplacementNamed(context, '/auth'),
            ),
          ),
        );
      } else {
        Navigator.of(context)
            .pushReplacement(_createFadeRoute(null, routeName: '/home'));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  /// ناوبری به صفحه لاگین
  void _navigateToAuth() {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(_createFadeRoute(null, routeName: '/auth'));
  }

  /// ایجاد ترانزیشن fade
  Route _createFadeRoute(Widget? page, {String? routeName}) {
    return PageRouteBuilder(
      settings: routeName != null ? RouteSettings(name: routeName) : null,
      pageBuilder: (context, animation, secondaryAnimation) {
        if (page != null) return page;
        // اگر page نداریم، به route برو
        return const SizedBox.shrink();
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: AnimatedOpacity(
          opacity: _showLogo ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: _buildLogo(isDark),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    final logoPath = isDark
        ? 'lib/utils/images/vistalogo-new.png'
        : 'lib/utils/images/black-logo.png';

    return Image.asset(
      logoPath,
      height: 120,
      errorBuilder: (context, error, stackTrace) {
        // Fallback به لوگوی اصلی
        return Image.asset(
          'lib/utils/images/vistalogo.png',
          height: 120,
        );
      },
    )
        .animate(
          onPlay: (controller) => controller.forward(),
        )
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.easeOutBack,
        );
  }
}
