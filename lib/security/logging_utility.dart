import 'package:logger/logger.dart';
import 'dart:isolate'; // Added for isolate identification
import 'package:flutter/foundation.dart'; // For kReleaseMode

// Global logger instance
final logger = Logger(
  // In release mode, use nothing. In debug, use pretty printer but with fewer lines
  filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
  printer: PrettyPrinter(
    methodCount: 0, // Reduced from 2 to 0 to save console space/time
    errorMethodCount: 5,
    lineLength: 80, // Reduced width
    colors: true,
    printEmojis: true,
    printTime: false, // Removing time to save string processing
  ),
  // If you want to completely disable in release (even errors), use this:
  // level: kReleaseMode ? Level.off : Level.all,
);

/// Log informational messages
void logInfo(String message, {dynamic error, StackTrace? stackTrace}) {
  if (kReleaseMode) return;
  final isolateName = Isolate.current.debugName;
  final prefix =
      (isolateName == 'main' || isolateName == null) ? '' : '[$isolateName] ';
  logger.i('$prefix$message', error: error, stackTrace: stackTrace);
}

/// Log debug messages
void logDebug(String message, {dynamic error, StackTrace? stackTrace}) {
  if (kReleaseMode) return;
  logger.d(message, error: error, stackTrace: stackTrace);
}

/// Log warning messages
void logWarning(String message, {dynamic error, StackTrace? stackTrace}) {
  if (kReleaseMode) return;
  logger.w(message, error: error, stackTrace: stackTrace);
}

/// Log error messages
void logError(String message, {dynamic error, StackTrace? stackTrace}) {
  // Errors might be useful in release (e.g. sent to Crashlytics),
  // but for console performance we silence them here if they are just local.
  // If you integrate Sentry/Crashlytics, do it here.
  if (kReleaseMode) return;
  logger.e(message, error: error, stackTrace: stackTrace);
}
