import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// انواع خطاهای سیستم
enum ErrorType {
  network,
  authentication,
  permission,
  rateLimit,
  serverError,
  clientError,
  unknown,
}

/// کلاس بهبود یافته برای مدیریت خطاها در سیستم پیام‌رسانی
class ImprovedErrorHandler {
  static const int maxRetryAttempts = 5;
  static const Duration baseRetryDelay = Duration(seconds: 3);

  /// تشخیص نوع خطا
  static ErrorType _classifyError(dynamic error) {
    // خطاهای شبکه
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return ErrorType.network;
    }

    final text = error.toString().toLowerCase();
    if (text.contains('401') || text.contains('unauthorized')) {
      return ErrorType.authentication;
    }
    if (text.contains('403') || text.contains('forbidden')) {
      return ErrorType.permission;
    }
    if (text.contains('429') || text.contains('rate limit')) {
      return ErrorType.rateLimit;
    }
    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('internal server')) {
      return ErrorType.serverError;
    }
    if (text.contains('400') ||
        text.contains('404') ||
        text.contains('409') ||
        text.contains('invalid')) {
      return ErrorType.clientError;
    }
    if (error.toString().contains('rate limit')) {
      return ErrorType.rateLimit;
    }

    if (error
        .toString()
        .contains('Connection closed before full header was received')) {
      return ErrorType.network;
    }

    return ErrorType.unknown;
  }

  /// محاسبه تاخیر retry با exponential backoff
  static Duration _calculateRetryDelay(int attempt) {
    return Duration(
      milliseconds: (baseRetryDelay.inMilliseconds * (1 << attempt)).clamp(
        baseRetryDelay.inMilliseconds,
        30000, // حداکثر 30 ثانیه
      ),
    );
  }

  /// اجرای عملیات با retry logic بهبود یافته
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = maxRetryAttempts,
    bool Function(dynamic error)? shouldRetry,
    void Function(dynamic error, int attempt)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;

    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;

        if (attempt == maxRetries) {
          throw _enhanceError(error, attempt);
        }

        final errorType = _classifyError(error);

        // بررسی اینکه آیا باید retry کرد یا خیر
        if (shouldRetry != null && !shouldRetry(error)) {
          throw _enhanceError(error, attempt);
        }

        if (!_shouldRetryForErrorType(errorType)) {
          throw _enhanceError(error, attempt);
        }

        attempt++;
        final delay = _calculateRetryDelay(attempt);

        if (onRetry != null) {
          onRetry(error, attempt);
        }

        if (kDebugMode) {
          print(
              'Retry attempt $attempt after ${delay.inMilliseconds}ms for error: ${error.toString()}');
        }

        await Future.delayed(delay);
      }
    }

    throw _enhanceError(lastError, attempt);
  }

  /// تعیین اینکه آیا برای نوع خطای خاص باید retry کرد
  static bool _shouldRetryForErrorType(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.network:
      case ErrorType.serverError:
      case ErrorType.rateLimit:
        return true;
      case ErrorType.authentication:
      case ErrorType.permission:
      case ErrorType.clientError:
        return false;
      case ErrorType.unknown:
        return true; // ممکن است قابل حل باشد
    }
  }

  /// بهبود پیام خطا با اطلاعات بیشتر
  static Exception _enhanceError(dynamic originalError, int attempts) {
    final errorType = _classifyError(originalError);
    final message = _getErrorMessage(errorType, originalError);

    return MessagingException(
      message: message,
      originalError: originalError,
      errorType: errorType,
      attempts: attempts,
    );
  }

  /// دریافت پیام خطای مناسب برای کاربر
  static String _getErrorMessage(ErrorType errorType, dynamic error) {
    switch (errorType) {
      case ErrorType.network:
        return 'مشکل در اتصال به اینترنت. لطفاً اتصال خود را بررسی کنید.';
      case ErrorType.authentication:
        return 'خطا در احراز هویت. لطفاً دوباره وارد شوید.';
      case ErrorType.permission:
        return 'شما دسترسی لازم برای این عملیات را ندارید.';
      case ErrorType.rateLimit:
        return 'تعداد درخواست‌های شما بیش از حد مجاز است. لطفاً کمی صبر کنید.';
      case ErrorType.serverError:
        return 'خطا در سرور. لطفاً دوباره تلاش کنید.';
      case ErrorType.clientError:
        return 'درخواست نامعتبر. لطفاً اطلاعات ورودی را بررسی کنید.';
      case ErrorType.unknown:
        return 'خطای غیرمنتظره. لطفاً دوباره تلاش کنید.';
    }
  }

  /// مدیریت خطاهای مربوط به ارسال پیام
  static Future<T> handleMessageOperation<T>(
    Future<T> Function() operation, {
    void Function(String error)? onError,
  }) async {
    return executeWithRetry(
      operation,
      shouldRetry: (error) {
        final errorType = _classifyError(error);
        return errorType == ErrorType.network ||
            errorType == ErrorType.serverError ||
            errorType == ErrorType.rateLimit;
      },
      onRetry: (error, attempt) {
        if (onError != null) {
          onError('تلاش $attempt برای ارسال پیام...');
        }
      },
    );
  }

  /// مدیریت خطاهای مربوط به دریافت پیام‌ها
  static Future<T> handleMessageRetrieval<T>(
    Future<T> Function() operation, {
    T? fallbackValue,
  }) async {
    try {
      return await executeWithRetry(operation);
    } catch (error) {
      if (fallbackValue != null) {
        if (kDebugMode) {
          logInfo('Using fallback value due to error: $error');
        }
        return fallbackValue;
      }
      rethrow;
    }
  }

  /// مدیریت خطاهای real-time stream
  static Stream<T> handleStreamErrors<T>(
    Stream<T> stream, {
    T? fallbackValue,
    void Function(dynamic error)? onError,
  }) {
    return stream.handleError((error) {
      if (onError != null) {
        onError(error);
      }

      if (kDebugMode) {
        logInfo('Stream error: $error');
      }

      // برای خطاهای authentication، stream را terminate کن
      if (_classifyError(error) == ErrorType.authentication) {
        throw error;
      }
    });
  }

  /// بررسی وضعیت اتصال
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// مدیریت offline state
  static Future<T> handleOfflineOperation<T>(
    Future<T> Function() onlineOperation,
    T Function() offlineOperation,
  ) async {
    final isOnline = await checkConnectivity();

    if (isOnline) {
      try {
        return await onlineOperation();
      } catch (error) {
        if (_classifyError(error) == ErrorType.network) {
          return offlineOperation();
        }
        rethrow;
      }
    } else {
      return offlineOperation();
    }
  }
}

/// کلاس خطای سفارشی برای سیستم پیام‌رسانی
class MessagingException implements Exception {
  final String message;
  final dynamic originalError;
  final ErrorType errorType;
  final int attempts;

  const MessagingException({
    required this.message,
    required this.originalError,
    required this.errorType,
    required this.attempts,
  });

  @override
  String toString() {
    return 'MessagingException: $message (Type: $errorType, Attempts: $attempts)';
  }

  /// آیا این خطا قابل حل است؟
  bool get isRecoverable {
    switch (errorType) {
      case ErrorType.network:
      case ErrorType.serverError:
      case ErrorType.rateLimit:
        return true;
      default:
        return false;
    }
  }

  /// آیا کاربر باید دوباره تلاش کند؟
  bool get shouldRetryManually {
    return isRecoverable && attempts >= ImprovedErrorHandler.maxRetryAttempts;
  }
}
