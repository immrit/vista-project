import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../main.dart';

// کلاس مدیریت دیپ لینک
class DeepLinkService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // متغیرهای استاتیک برای نگهداری توکن‌ها و ایمیل جدید در انتظار پردازش
  static String? pendingEmailChangeToken;
  static String? pendingConfirmToken;
  static String? pendingResetPasswordToken;
  static String? pendingNewEmail;

  // Provider برای مدیریت ایمیل کاربر
  static final userEmailProvider = StateProvider<String?>((ref) => null);

  // استخراج توکن از URI (از query parameters یا fragment)
  static String? _extractToken(Uri uri) {
    // بررسی توکن در query parameters
    if (uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token'];
    }

    // بررسی توکن در fragment
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(fragment);
      if (fragmentParams.containsKey('token')) {
        return fragmentParams['token'];
      }
      // در برخی موارد، کل fragment ممکن است توکن باشد
      if (fragment.length > 20) {
        return fragment;
      }
    }
    return null;
  }

  // پردازش لینک بازیابی رمز عبور
  static void handleResetPassword(Uri uri, BuildContext? context) {
    String? token = _extractToken(uri);
    print('handleResetPassword token: $token');

    if (token != null) {
      if (context == null) {
        // ذخیره توکن برای پردازش بعدی
        pendingResetPasswordToken = token;
        print(
            'Context not available, saving reset password token for later: $token');
        return;
      }
      // هدایت مستقیم به صفحه بازیابی رمز عبور
      navigatorKey.currentState?.pushNamed('/reset-password', arguments: token);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('لینک بازیابی رمز عبور نامعتبر است')),
      );
    }
  }

  // پردازش لینک تغییر ایمیل
  static Future<void> handleEmailChange(Uri uri, BuildContext? context) async {
    print('handleEmailChange called');
    final token = _extractToken(uri);

    if (token == null) {
      print('Error: No token found in email change link');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا: لینک تغییر ایمیل نامعتبر است')),
        );
      } else {
        pendingEmailChangeToken = null;
      }
      return;
    }

    print('Email change token: $token');

    try {
      // تلاش مستقیم برای تایید با OtpType.emailChange
      final response = await supabase.auth.verifyOTP(
        token: token,
        type: OtpType.emailChange,
      );

      if (response.session != null || response.user != null) {
        print('Email change verified successfully');

        // نمایش پیام موفقیت‌آمیز
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ایمیل شما با موفقیت تغییر یافت'),
              duration: Duration(seconds: 5),
            ),
          );

          // بروزرسانی اطلاعات کاربری
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/home', (route) => false);
        } else {
          pendingEmailChangeToken = token;
        }
      } else {
        print('Error: Email change verification failed');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در تغییر ایمیل: توکن نامعتبر است'),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          pendingEmailChangeToken = token;
        }
      }
    } catch (e) {
      print('Error verifying email change: $e');

      // ذخیره توکن برای پردازش بعدی
      if (context == null) {
        pendingEmailChangeToken = token;
      } else {
        // نمایش خطا به کاربر
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تغییر ایمیل: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

// اصلاح متد پردازش deep link
  void handleDeepLink(Uri uri) {
    print('Processing deep link: $uri');
    print('Path: ${uri.path}');
    print('Parameters: ${uri.queryParameters}');
    print('Fragment: ${uri.fragment}');

    if (uri.path.contains('/email-change')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        print('handleEmailChange token: $token');
        handleEmailChange(uri, navigatorKey.currentContext);
      } else {
        print('Error: No token found in email change link');
      }
    }
  }

  // پردازش لینک تایید حساب
  static Future<void> handleConfirm(Uri uri, BuildContext? context) async {
    String? token = _extractToken(uri);
    print('handleConfirm token: $token');

    if (token != null) {
      if (context == null) {
        pendingConfirmToken = token;
        print('Context not available, saving confirm token for later: $token');
        return;
      }
      await confirmAccount(token, context);
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(content: Text('لینک تایید حساب نامعتبر است')),
      );
    }
  }

  // پردازش توکن‌های در انتظار (زمانی که context هنوز در دسترس نیست)
  static void processPendingTokens(BuildContext context) {
    print('Processing pending tokens...');

    if (pendingResetPasswordToken != null) {
      print(
          'Processing pending reset password token: $pendingResetPasswordToken');
      navigatorKey.currentState
          ?.pushNamed('/reset-password', arguments: pendingResetPasswordToken);
      pendingResetPasswordToken = null;
    }

    if (pendingEmailChangeToken != null) {
      print('Processing pending email change token: $pendingEmailChangeToken');
      confirmEmailChange(pendingEmailChangeToken!, context);
      pendingEmailChangeToken = null;
    }

    if (pendingConfirmToken != null) {
      print('Processing pending confirm token: $pendingConfirmToken');
      confirmAccount(pendingConfirmToken!, context);
      pendingConfirmToken = null;
    }
  }

  // تایید تغییر ایمیل
  static Future<void> confirmEmailChange(
      String token, BuildContext context) async {
    final supabase = Supabase.instance.client;

    try {
      print('تلاش برای تأیید تغییر ایمیل با توکن: $token');

      if (pendingNewEmail == null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('ایمیل جدید ثبت نشده است. لطفاً دوباره تلاش کنید.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await supabase.auth.verifyOTP(
        token: token,
        type: OtpType.emailChange,
        email: pendingNewEmail,
      );
      print('پاسخ تأیید: ${result.user?.email}');

      final updatedUser = result.user;
      if (updatedUser != null && updatedUser.email != null) {
        print('ایمیل جدید: ${updatedUser.email}');
        try {
          await supabase.from('profiles').update({
            'email': updatedUser.email,
          }).eq('id', updatedUser.id);
          print('پروفایل به‌روزرسانی شد');

          // به‌روزرسانی provider برای نمایش ایمیل جدید در اینترفیس کاربری
          if (context is ConsumerStatefulElement) {
            final ref = context;
            ref.read(userEmailProvider.notifier).state = updatedUser.email;
          }
        } catch (dbErr) {
          print('خطا در به‌روزرسانی جدول پروفایل: $dbErr');
        }
      }

      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('ایمیل شما با موفقیت تغییر کرد'),
          backgroundColor: Colors.green,
        ),
      );
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/editeProfile', (route) => false);

      pendingNewEmail = null;
    } catch (e) {
      print('خطا در تأیید تغییر ایمیل: $e');
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('خطا در تغییر ایمیل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // تایید حساب کاربری
  static Future<void> confirmAccount(String token, BuildContext context) async {
    final supabase = Supabase.instance.client;

    try {
      print('تلاش برای تأیید حساب کاربری با توکن: $token');
      await supabase.auth.verifyOTP(
        token: token,
        type: OtpType.signup,
      );
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('حساب کاربری شما با موفقیت تأیید شد'),
          backgroundColor: Colors.green,
        ),
      );
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      print('خطا در تایید حساب کاربری: $e');
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('خطا در تایید حساب کاربری: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
