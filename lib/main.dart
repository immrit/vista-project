import 'dart:async';
import 'package:Vista/app/app_initialization.dart';
import 'package:Vista/app/app_runner.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    await AppInitialization.init();
    AppRunner.run();
  }, (error, stack) {
    if (error.toString().contains('RealtimeSubscribeException')) return;
    print('⚠️ Global error: $error');
  });
}
