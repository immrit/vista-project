import 'package:logger/logger.dart';

// Global logger instance
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

/// Log informational messages
void logInfo(String message, {dynamic error, StackTrace? stackTrace}) {
  logger.i(message, error: error, stackTrace: stackTrace);
}

/// Log debug messages
void logDebug(String message, {dynamic error, StackTrace? stackTrace}) {
  logger.d(message, error: error, stackTrace: stackTrace);
}

/// Log warning messages
void logWarning(String message, {dynamic error, StackTrace? stackTrace}) {
  logger.w(message, error: error, stackTrace: stackTrace);
}

/// Log error messages
void logError(String message, {dynamic error, StackTrace? stackTrace}) {
  logger.e(message, error: error, stackTrace: stackTrace);
}
