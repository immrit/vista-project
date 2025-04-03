import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

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
    String? token = _extractToken(uri);
    print('handleEmailChange token: $token');

    if (token != null) {
      if (context == null) {
        pendingEmailChangeToken = token;
        print(
            'Context not available, saving email change token for later: $token');
        return;
      }

      try {
        // بررسی وجود ایمیل جدید ذخیره شده
        if (pendingNewEmail == null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('ایمیل جدید ثبت نشده است. لطفاً دوباره تلاش کنید.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('در حال تأیید تغییر ایمیل...'),
            duration: Duration(seconds: 2),
          ),
        );
        print(
            'Verifying email change with token: $token and email: $pendingNewEmail');
        final supabase = Supabase.instance.client;

        // فراخوانی verifyOTP همراه با ارسال ایمیل جدید
        final res = await supabase.auth.verifyOTP(
          token: token,
          type: OtpType.emailChange,
          email: pendingNewEmail,
        );
        print('Email change verification response: $res');

        final updatedUser = res.user;
        if (updatedUser != null && updatedUser.email != null) {
          try {
            await supabase.from('profiles').update({
              'email': updatedUser.email,
            }).eq('id', updatedUser.id);
            print('Profile updated with new email: ${updatedUser.email}');

            // به‌روزرسانی provider برای نمایش ایمیل جدید در اینترفیس کاربری
            if (context is ConsumerStatefulElement) {
              final ref = context as ConsumerStatefulElement;
              ref.read(userEmailProvider.notifier).state = updatedUser.email;
            }
          } catch (dbErr) {
            print('Error updating profile: $dbErr');
          }
        } else {
          print('updatedUser یا ایمیل آن null است.');
        }

        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('ایمیل شما با موفقیت تغییر کرد'),
            backgroundColor: Colors.green,
          ),
        );
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/editeProfile', (route) => false);

        // پاکسازی متغیر pendingNewEmail پس از اعمال تغییر
        pendingNewEmail = null;
      } catch (e) {
        print('Email change error: $e');
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('خطا در تغییر ایمیل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('لینک تغییر ایمیل نامعتبر است'),
          backgroundColor: Colors.red,
        ),
      );
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
            final ref = context as ConsumerStatefulElement;
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
