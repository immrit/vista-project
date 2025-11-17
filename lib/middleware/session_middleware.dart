import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_manager_service.dart';
import '../view/screen/auth/auth_screen.dart';
import '../security/logging_utility.dart';

/// Middleware برای بررسی نشست قبل از دسترسی به صفحات
class SessionMiddleware extends ConsumerStatefulWidget {
  final Widget child;

  const SessionMiddleware({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SessionMiddleware> createState() => _SessionMiddlewareState();
}

class _SessionMiddlewareState extends ConsumerState<SessionMiddleware>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // بررسی نشست هنگام بازگشت به اپلیکیشن
      _checkSession();
    }
  }

  Future<void> _checkSession() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final sessionManager = SessionManagerService();
      final isValid = await sessionManager.ensureSessionRegistered();

      if (mounted) {
        setState(() {
          _isValid = isValid;
          _isChecking = false;
        });

        if (!isValid) {
          logInfo('🚫 Session validation failed - redirecting to login');
        }
      }
    } catch (e) {
      logInfo('❌ Error checking session: $e');
      if (mounted) {
        setState(() {
          _isValid = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isValid) {
      // هدایت به صفحه لاگین
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}

