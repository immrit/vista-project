import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Vista/features/home/screens/homeScreen.dart';
import 'package:Vista/features/auth/screens/auth_wizard_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:Vista/middleware/session_middleware.dart';

class SessionAuthWrapper extends StatefulWidget {
  const SessionAuthWrapper({super.key});

  @override
  State<SessionAuthWrapper> createState() => _SessionAuthWrapperState();
}

class _SessionAuthWrapperState extends State<SessionAuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _setupAuthListener();
  }

  void _checkSession() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
    } else {
      // Just to be sure, waiting a bit or just assume logged out
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
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
    } else {
      return const AuthWizardScreen();
    }
  }
}
