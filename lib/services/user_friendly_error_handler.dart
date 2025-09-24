import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

/// سیستم مدیریت خطاهای کاربرپسند
/// این کلاس خطاهای فنی را به پیام‌های قابل فهم برای کاربر تبدیل می‌کند
class UserFriendlyErrorHandler {
  static const String _defaultErrorMessage =
      'خطایی رخ داده است. لطفاً دوباره تلاش کنید.';

  /// تبدیل خطای فنی به پیام کاربرپسند
  static String getFriendlyMessage(dynamic error, {String? context}) {
    // خطاهای شبکه
    if (error is SocketException) {
      return 'اتصال به اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.';
    }

    if (error is TimeoutException) {
      return 'زمان اتصال به سرور به پایان رسید. لطفاً دوباره تلاش کنید.';
    }

    if (error is http.ClientException) {
      return 'مشکل در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.';
    }

    // خطاهای Supabase
    if (error is AuthException) {
      return _handleAuthError(error);
    }

    if (error is PostgrestException) {
      return _handleDatabaseError(error);
    }

    if (error is RealtimeSubscribeException) {
      return 'مشکل در دریافت اطلاعات جدید. لطفاً صفحه را رفرش کنید.';
    }

    // خطاهای فایل
    if (error.toString().contains('File not found') ||
        error.toString().contains('No such file')) {
      return 'فایل مورد نظر یافت نشد.';
    }

    if (error.toString().contains('Permission denied')) {
      return 'دسترسی به فایل مورد نظر امکان‌پذیر نیست.';
    }

    if (error.toString().contains('File too large')) {
      return 'حجم فایل بیش از حد مجاز است.';
    }

    // خطاهای آپلود
    if (error.toString().contains('Upload failed') ||
        error.toString().contains('Upload error')) {
      return 'آپلود فایل ناموفق بود. لطفاً دوباره تلاش کنید.';
    }

    // خطاهای خاص بر اساس context
    if (context != null) {
      return _getContextSpecificMessage(context, error);
    }

    // خطای پیش‌فرض
    return _defaultErrorMessage;
  }

  /// مدیریت خطاهای احراز هویت
  static String _handleAuthError(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return 'اطلاعات ورودی نامعتبر است.';
      case '401':
        return 'احراز هویت ناموفق بود. لطفاً دوباره وارد شوید.';
      case '403':
        return 'دسترسی به این بخش امکان‌پذیر نیست.';
      case '422':
        return 'اطلاعات وارد شده صحیح نیست.';
      default:
        return 'مشکل در احراز هویت. لطفاً دوباره تلاش کنید.';
    }
  }

  /// مدیریت خطاهای دیتابیس
  static String _handleDatabaseError(PostgrestException error) {
    switch (error.code) {
      case '23505': // Duplicate key
        return 'این اطلاعات قبلاً ثبت شده است.';
      case '23503': // Foreign key violation
        return 'اطلاعات مرتبط یافت نشد.';
      case '42501': // Insufficient privilege
        return 'دسترسی لازم برای این عملیات را ندارید.';
      case '42P01': // Undefined table
        return 'خطا در سیستم. لطفاً با پشتیبانی تماس بگیرید.';
      case 'PGRST116': // No rows returned
        return 'اطلاعات مورد نظر یافت نشد.';
      default:
        if (error.code?.startsWith('5') == true) {
          return 'خطا در سرور. لطفاً کمی بعد دوباره تلاش کنید.';
        }
        return 'خطا در پردازش اطلاعات. لطفاً دوباره تلاش کنید.';
    }
  }

  /// پیام‌های خاص بر اساس context
  static String _getContextSpecificMessage(String context, dynamic error) {
    switch (context.toLowerCase()) {
      case 'login':
        return 'ورود ناموفق بود. نام کاربری و رمز عبور را بررسی کنید.';
      case 'register':
        return 'ثبت‌نام ناموفق بود. لطفاً اطلاعات را بررسی کنید.';
      case 'profile_update':
        return 'به‌روزرسانی پروفایل ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'post_create':
        return 'ایجاد پست ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'post_delete':
        return 'حذف پست ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'image_upload':
        return 'آپلود تصویر ناموفق بود. لطفاً تصویر دیگری انتخاب کنید.';
      case 'video_upload':
        return 'آپلود ویدیو ناموفق بود. لطفاً ویدیوی دیگری انتخاب کنید.';
      case 'audio_upload':
        return 'آپلود فایل صوتی ناموفق بود. لطفاً فایل دیگری انتخاب کنید.';
      case 'follow':
        return 'خطا در دنبال کردن کاربر. لطفاً دوباره تلاش کنید.';
      case 'unfollow':
        return 'خطا در لغو دنبال کردن کاربر. لطفاً دوباره تلاش کنید.';
      case 'like':
        return 'خطا در لایک کردن پست. لطفاً دوباره تلاش کنید.';
      case 'comment':
        return 'ارسال نظر ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'message_send':
        return 'ارسال پیام ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'story_create':
        return 'ایجاد استوری ناموفق بود. لطفاً دوباره تلاش کنید.';
      case 'search':
        return 'جستجو ناموفق بود. لطفاً دوباره تلاش کنید.';
      default:
        return _defaultErrorMessage;
    }
  }

  /// نمایش خطا به کاربر با SnackBar
  static void showError(BuildContext context, dynamic error,
      {String? errorContext}) {
    final message = getFriendlyMessage(error, context: errorContext);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'بستن',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// نمایش خطا با Dialog
  static void showErrorDialog(BuildContext context, dynamic error,
      {String? errorContext}) {
    final message = getFriendlyMessage(error, context: errorContext);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطا'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  /// بررسی اینکه آیا خطا قابل حل است یا نه
  static bool isRecoverableError(dynamic error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }

    if (error is PostgrestException) {
      return error.code?.startsWith('5') == true; // Server errors
    }

    return false;
  }

  /// دریافت پیشنهاد راه‌حل برای خطا
  static String getSolutionSuggestion(dynamic error) {
    if (error is SocketException) {
      return 'لطفاً اتصال اینترنت خود را بررسی کنید.';
    }

    if (error is TimeoutException) {
      return 'لطفاً اتصال اینترنت خود را بررسی کنید و دوباره تلاش کنید.';
    }

    if (error is PostgrestException && error.code?.startsWith('5') == true) {
      return 'لطفاً کمی صبر کنید و دوباره تلاش کنید.';
    }

    return 'لطفاً دوباره تلاش کنید.';
  }

  /// لاگ کردن خطا برای توسعه‌دهندگان (فقط در حالت debug)
  static void logError(dynamic error,
      {String? context, StackTrace? stackTrace}) {
    if (kDebugMode) {
      print('🚨 Error in $context: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }
}

/// Extension برای راحت‌تر کردن استفاده
extension ErrorHandlingExtension on BuildContext {
  /// نمایش خطا با SnackBar
  void showError(dynamic error, {String? errorContext}) {
    UserFriendlyErrorHandler.showError(this, error, errorContext: errorContext);
  }

  /// نمایش خطا با Dialog
  void showErrorDialog(dynamic error, {String? errorContext}) {
    UserFriendlyErrorHandler.showErrorDialog(this, error,
        errorContext: errorContext);
  }
}
