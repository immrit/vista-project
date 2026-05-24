import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_outlined,
                  size: 100, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'در حال بروزرسانی',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Vazir',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ما در حال ارتقا و بهبود سیستم هستیم تا تجربه بهتری را برای شما رقم بزنیم. لطفاً کمی بعد مجدداً تلاش کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: 'Vazir',
                ),
              ),
              const SizedBox(height: 48),
              CircularProgressIndicator(color: Colors.white.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
