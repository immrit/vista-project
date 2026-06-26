import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../security/logging_utility.dart';

class UserFriendlyErrorUtils {
  static const String _defaultMessage = 'مشکلی رخ داد. لطفاً دوباره تلاش کنید.';

  static String getUserFriendlyMessage(dynamic error) {
    try {
      if (error is SocketException) {
        return 'اتصال اینترنت برقرار نیست. اتصال خود را بررسی کنید.';
      }
      if (error is TimeoutException) {
        return 'پاسخ از سرور دیر رسید. لطفاً دوباره تلاش کنید.';
      }
      if (error is HttpException) {
        return 'ارتباط با سرور برقرار نشد.';
      }

      if (error is FormatException) {
        return 'داده دریافتی معتبر نیست.';
      }

      final raw = _extractRawError(error);
      final sanitized = _sanitizeRawMessage(raw);
      final mapped = _mapByKeywords(sanitized);
      if (mapped != null) {
        return mapped;
      }

      if (sanitized.isEmpty || _looksTechnicalMessage(sanitized)) {
        return _defaultMessage;
      }

      return sanitized;
    } catch (_) {
      return _defaultMessage;
    }
  }

  static String _extractRawError(dynamic error) {
    if (error == null) return '';
    if (error is String) return error;
    if (error is Exception || error is Error) {
      return error.toString();
    }
    return '$error';
  }

  static String _sanitizeRawMessage(String raw) {
    var message = raw.trim();
    if (message.isEmpty) return '';

    message = message
        .replaceAll(RegExp(r'^(Exception|MessagingException):\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final technicalMarkers = [
      'stack trace',
      'stacktrace',
      '#0',
      ' at ',
      'hint:',
      'details:',
      'where:',
      'context:',
      'schema',
      'table',
      'column',
      'sql',
      'select ',
      'insert ',
      'update ',
      'delete ',
      'from ',
    ];

    final lower = message.toLowerCase();
    for (final marker in technicalMarkers) {
      final idx = lower.indexOf(marker);
      if (idx > 0) {
        message = message.substring(0, idx).trim();
        break;
      }
    }

    // Remove quoted internal identifiers or SQL fragments.
    message = message
        .replaceAll(RegExp(r'"[A-Za-z0-9_\.]+"'), '')
        .replaceAll(RegExp(r'\b(SQLSTATE)\w*\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return message;
  }

  static bool _looksTechnicalMessage(String message) {
    final lower = message.toLowerCase();
    const markers = <String>[
      'exception',
      'error code',
      'status code',
      'pgrst',
      'sqlstate',
      'constraint',
      'relation',
      'column',
      'table',
      'backend',
      'jwt',
      'trace',
      'stack',
      'invalid input syntax',
      'null value',
      'violates',
      'failed to',
      'timeout',
      'socket',
      'http',
    ];

    if (markers.any(lower.contains)) return true;

    if (RegExp(r'https?://', caseSensitive: false).hasMatch(message)) {
      return true;
    }

    if (RegExp(r'\b(select|insert|update|delete|from|where|join)\b',
            caseSensitive: false)
        .hasMatch(message)) {
      return true;
    }

    if (RegExp(r'[{}\[\]<>]').hasMatch(message)) return true;

    return false;
  }

  // ignore: unused_element
  static String _mapAuthMessage(String raw) {
    final message = raw.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'نام کاربری یا رمز عبور اشتباه است.';
    }
    if (message.contains('email not confirmed')) {
      return 'ایمیل شما هنوز تایید نشده است.';
    }
    if (message.contains('token has expired') ||
        message.contains('jwt expired')) {
      return 'جلسه شما منقضی شده است. لطفاً دوباره وارد شوید.';
    }
    if (message.contains('user already registered')) {
      return 'این حساب قبلاً ثبت شده است.';
    }
    return 'مشکلی در احراز هویت رخ داد. لطفاً دوباره وارد شوید.';
  }

  static String? _mapByKeywords(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('socket')) {
      return 'مشکل ارتباط اینترنتی وجود دارد.';
    }
    if (lower.contains('timeout')) {
      return 'زمان پاسخ‌دهی سرور به پایان رسید. دوباره تلاش کنید.';
    }
    if (lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('forbidden')) {
      return 'شما اجازه انجام این عملیات را ندارید.';
    }
    if (lower.contains('not found') || lower.contains('does not exist')) {
      return 'مورد موردنظر پیدا نشد.';
    }
    if (lower.contains('duplicate') || lower.contains('already exists')) {
      return 'این مورد قبلاً ثبت شده است.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'درخواست‌های شما بیش از حد مجاز است. کمی بعد تلاش کنید.';
    }
    if (lower.contains('story_reply_not_allowed')) {
      return 'ارسال پاسخ به این استوری مجاز نیست.';
    }
    if (lower.contains('authentication_required') ||
        lower.contains('user not logged in') ||
        lower.contains('not authenticated') ||
        lower.contains('کاربر وارد نشده')) {
      return 'برای انجام این عملیات باید وارد حساب کاربری شوید.';
    }
    if (lower.contains('invalid_reply_permission')) {
      return 'تنظیم انتخاب‌شده برای پاسخ به استوری معتبر نیست.';
    }
    if (lower.contains('empty_story_reply_message')) {
      return 'متن پاسخ به استوری نمی‌تواند خالی باشد.';
    }
    if (lower.contains('story_not_found')) {
      return 'این استوری پیدا نشد یا در دسترس نیست.';
    }

    return null;
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    logError('UI error surfaced', error: error);
    if (!context.mounted) return;

    final message = getUserFriendlyMessage(error);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomMargin = 80.0 + bottomInset;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16, right: 16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'باشه',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomMargin = 80.0 + bottomInset;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(bottom: bottomMargin, left: 16, right: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
