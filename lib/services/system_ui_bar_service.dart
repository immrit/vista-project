import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUiBarService {
  static const MethodChannel _channel =
      MethodChannel('ir.coffevista.vista/system_ui');

  static String? _lastSignature;

  static void sync(SystemUiOverlayStyle style) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final statusBarColor = style.statusBarColor;
    final navigationBarColor = style.systemNavigationBarColor;
    if (statusBarColor == null && navigationBarColor == null) return;

    final statusColor = statusBarColor ?? Colors.transparent;
    final navColor = navigationBarColor ?? Colors.transparent;
    final lightStatusBarIcons =
        style.statusBarIconBrightness == Brightness.dark;
    final lightNavigationBarIcons =
        style.systemNavigationBarIconBrightness == Brightness.dark;

    final signature = Object.hash(
      statusColor.toARGB32(),
      navColor.toARGB32(),
      lightStatusBarIcons,
      lightNavigationBarIcons,
    ).toString();
    if (_lastSignature == signature) return;
    _lastSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _channel.invokeMethod<void>('setSystemBars', <String, Object>{
          'statusBarColor': statusColor.toARGB32(),
          'navigationBarColor': navColor.toARGB32(),
          'lightStatusBarIcons': lightStatusBarIcons,
          'lightNavigationBarIcons': lightNavigationBarIcons,
        });
      } on MissingPluginException {
        // Non-Android and test environments do not expose this native hook.
      } catch (_) {
        // SystemChrome still applies the same style; this hook is a native backup.
      }
    });
  }
}
