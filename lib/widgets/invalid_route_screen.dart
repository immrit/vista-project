import 'package:flutter/material.dart';

/// Shown when a named route is opened with missing/invalid arguments, instead
/// of a blank `Scaffold()` dead-end (no message, no way back).
class InvalidRouteScreen extends StatelessWidget {
  final String message;
  const InvalidRouteScreen({super.key, this.message = 'محتوا در دسترس نیست'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 56, color: isDark ? Colors.grey[500] : Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('بازگشت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
