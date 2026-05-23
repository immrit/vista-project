import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:Vista/app/app_initialization.dart';
import 'package:Vista/app/app_runner.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    // لود باینری‌های حیاتی قبل از شروع اپلیکیشن
    WidgetsFlutterBinding.ensureInitialized();

    // هندلینگ خطاهایی که در محیط فلاتر (ویجت‌ها و غیره) اتفاق می‌افتند
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('RealtimeSubscribeException')) {
        return;
      }
      FlutterError.presentError(details);
      debugPrint('⚠️ Flutter Global Error: ${details.exception}');
      // TODO: FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    await AppInitialization.initCore();
    AppRunner.run();
  }, (error, stack) {
    if (error.toString().contains('RealtimeSubscribeException')) return;

    // هندلینگ خطاهای خارج از اکوسیستم دارت (مثلا متدهای نیتیو)
    debugPrint('⚠️ Zoned Global Error: $error');
    debugPrint('Stack trace: $stack');
    // TODO: FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
