import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:Vista/app/app_initialization.dart';
import 'package:Vista/app/app_runner.dart';
import 'package:Vista/services/crash_reporting_service.dart';

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
      unawaited(
        CrashReportingService.instance.recordError(
          details.exception,
          details.stack ?? StackTrace.current,
          fatal: true,
          source: 'flutter_error',
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (error.toString().contains('RealtimeSubscribeException')) return true;
      unawaited(
        CrashReportingService.instance.recordError(
          error,
          stack,
          fatal: true,
          source: 'platform_dispatcher',
        ),
      );
      return true;
    };

    await AppInitialization.initCore();
    AppRunner.run();
  }, (error, stack) {
    if (error.toString().contains('RealtimeSubscribeException')) return;

    unawaited(
      CrashReportingService.instance.recordError(
        error,
        stack,
        fatal: true,
        source: 'zone_guarded',
      ),
    );
  });
}
