import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserFriendlyErrorUtils {
  /// تبدیل خطای فنی به پیام فارسی قابل فهم برای کاربر
  static String getUserFriendlyMessage(dynamic error) {
    // 1. خطاهای شبکه و اینترنت
    if (error is SocketException) {
      return 'اتصال اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.';
    }
    if (error is TimeoutException) {
      return 'پاسخ از سرور دریافت نشد. لطفاً سرعت اینترنت خود را بررسی کنید.';
    }
    if (error is HttpException) {
      return 'خطا در برقراری ارتباط با سرور.';
    }

    // 2. خطاهای مربوط به Supabase
    if (error is PostgrestException) {
      if (error.code == '23505') {
        return 'این مورد قبلاً ثبت شده است (تکراری).';
      }
      return 'خطا در ارتباط با پایگاه داده. لطفاً دوباره تلاش کنید.';
    }
    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials')) {
        return 'نام کاربری یا رمز عبور اشتباه است.';
      }
      return 'مشکلی در احراز هویت پیش آمد. لطفاً دوباره وارد شوید.';
    }

    // 3. خطاهای فرمت داده
    if (error is FormatException) {
      return 'فرمت داده دریافتی صحیح نیست.';
    }

    // 4. خطاهای رشته ای (اگر ارور خودش استرینگ باشد)
    if (error is String) {
      return error;
    }

    // 5. خطای پیش‌فرض
    return 'یک خطای غیرمنتظره رخ داد. لطفاً بعداً تلاش کنید.';
  }

  /// نمایش اسنک‌بار با استایل استاندارد برای خطاها
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);

    // اگر کانتکست وجود نداشت یا بسته شده بود کاری نکن
    if (!context.mounted) return;

    // بستن اسنک‌بارهای قبلی
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
                  fontFamily: 'Vazir', // یا فونت پیش فرض برنامه
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
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'باشه',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// نمایش اسنک‌بار موفقیت (جهت تکمیل ابزار)
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

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
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
