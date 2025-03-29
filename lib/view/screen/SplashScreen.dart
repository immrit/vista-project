import 'package:flutter/material.dart';
import '/main.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'homeScreen.dart';
import 'ouathUser/welcome.dart'; // Assuming your main file is named 'main.dart'

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  bool _hasError = false; // متغیر جدید برای نمایش وضعیت خطا

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      final response = await supabase.from('posts').select();

      if (!mounted) return;

      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => supabase.auth.currentSession == null
              ? const WelcomePage()
              : const HomeScreen(),
        ),
      );
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
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
              if (_isLoading)
                LoadingAnimationWidget.progressiveDots(
                  color: Colors.white,
                  size: 50,
                ),
              if (_hasError) ...[
                const Text(
                  'خطا در برقراری ارتباط',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkAuthAndNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'تلاش مجدد',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
