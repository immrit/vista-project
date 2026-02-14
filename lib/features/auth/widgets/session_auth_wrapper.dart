import 'dart:async';

import 'package:Vista/features/auth/screens/auth_wizard_screen.dart';
import 'package:Vista/features/home/screens/homeScreen.dart';
import 'package:Vista/middleware/session_middleware.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionAuthWrapper extends StatefulWidget {
  const SessionAuthWrapper({super.key});

  @override
  State<SessionAuthWrapper> createState() => _SessionAuthWrapperState();
}

class _SessionAuthWrapperState extends State<SessionAuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _resolveAuthState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveAuthState() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
      return;
    }

    final manager = SessionManagerServiceV2.instance;
    await manager.initialize();
    await manager.ensureSessionRegistered();
    final state = await manager.verifyCurrentSession(forceServer: false);

    if (!mounted) return;
    setState(() {
      _isAuthenticated = state != SessionVerificationState.invalid;
      _isLoading = false;
    });
  }

  void _setupAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        await _resolveAuthState();
        return;
      }

      if (event == AuthChangeEvent.signedOut) {
        if (!mounted) return;
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'lib/utils/images/vistalogo.png',
                height: 200,
              ),
              const SizedBox(height: 30),
              LoadingAnimationWidget.progressiveDots(
                color: Colors.white,
                size: 50,
              ),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      return const SessionMiddleware(child: HomeScreen());
    }

    return const AuthWizardScreen();
  }
}
