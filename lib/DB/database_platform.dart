import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform-specific database configuration
class DatabasePlatform {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Returns true if SQLite/Drift should be used
  static bool get shouldUseDrift => !isWeb;

  /// Returns true if Hive should be used
  static bool get shouldUseHive => isWeb;
}
