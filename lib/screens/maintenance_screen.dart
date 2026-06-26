import 'dart:async';
import 'package:flutter/material.dart';
import 'package:Vista/services/system_status_service.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final status = await SystemStatusService.instance.fetchStatus(force: true);
      if (status != null && !status.maintenance) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ما در حال ارتقا و بهبود سیستم هستیم تا تجربه بهتری را برای شما رقم بزنیم. لطفاً کمی بعد مجدداً تلاش کنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              const SizedBox(height: 48),
              CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
