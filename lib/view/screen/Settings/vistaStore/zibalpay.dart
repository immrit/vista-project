import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../../main.dart';

class ZibalPaymentService {
  // API زیبال
  static const String merchantId = '655d88b4a9a498000b5fdca9'; // مرچنت کد زیبال
  static const String requestUrl = 'https://gateway.zibal.ir/v1/request';
  static const String verifyUrl = 'https://gateway.zibal.ir/v1/verify';
  static const String paymentUrl = 'https://gateway.zibal.ir/start/';
  static const String callbackURL =
      'YOUR_APP_SCHEME://payment'; // URL بازگشت از درگاه

  // قیمت‌های نشان‌های ویژه (به تومان)
  static const Map<String, int> badgePrices = {
    'gold': 199000,
    'black': 499000,
  };

  // شروع فرآیند پرداخت
  Future<Map<String, dynamic>> startPayment(
      String badgeType, BuildContext context) async {
    try {
      // بررسی اینکه کاربر وارد سیستم شده است
      final user = supabase.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'لطفاً ابتدا وارد سیستم شوید'};
      }

      // بررسی اینکه کاربر از قبل این نشان را ندارد
      final currentProfile = await supabase
          .from('profiles')
          .select('badge_type')
          .eq('id', user.id)
          .single();

      if (currentProfile['badge_type'] == badgeType) {
        return {
          'success': false,
          'message': 'شما در حال حاضر این نشان را دارید'
        };
      }

      // دریافت مبلغ بر اساس نوع نشان
      final amount = badgePrices[badgeType];
      if (amount == null) {
        return {'success': false, 'message': 'نوع نشان نامعتبر است'};
      }

      // آماده‌سازی درخواست پرداخت
      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'merchant': merchantId,
          'amount': amount,
          'callbackUrl': callbackURL,
          'description': 'خرید نشان $badgeType',
          'orderId': '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
          'mobile': '', // شماره موبایل کاربر (اختیاری)
        }),
      );

      // بررسی پاسخ درخواست
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['result'] == 100) {
        // دریافت شناسه تراکنش (trackId)
        final String trackId = responseData['trackId'].toString();

        // ذخیره اطلاعات تراکنش در سوپابیس
        await supabase.from('transactions').insert({
          'user_id': user.id,
          'amount': amount,
          'authority': trackId, // از trackId به عنوان authority استفاده می‌کنیم
          'badge_type': badgeType,
          'status': 'pending',
        });

        // باز کردن درگاه پرداخت
        final uri = Uri.parse('$paymentUrl$trackId');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return {'success': true, 'trackId': trackId};
        } else {
          // خطا در باز کردن مرورگر
          return {'success': false, 'message': 'خطا در باز کردن درگاه پرداخت'};
        }
      } else {
        // خطا در ایجاد درخواست پرداخت
        return {
          'success': false,
          'message':
              'خطا در اتصال به درگاه پرداخت: ${responseData['message'] ?? responseData['result']}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطای غیرمنتظره: $e'};
    }
  }

  // بررسی نتیجه پرداخت
  Future<Map<String, dynamic>> verifyPayment(
      String trackId, String success) async {
    try {
      // بررسی وضعیت پرداخت
      if (success != '1') {
        // پرداخت ناموفق بوده است
        await supabase.from('transactions').update({
          'status': 'failed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('authority', trackId);

        return {'success': false, 'message': 'پرداخت توسط کاربر لغو شد'};
      }

      // بررسی اینکه تراکنش در دیتابیس وجود دارد
      final transactionData = await supabase
          .from('transactions')
          .select('*')
          .eq('authority', trackId)
          .single();

      // بررسی وضعیت فعلی تراکنش
      if (transactionData['status'] == 'success') {
        return {'success': true, 'message': 'پرداخت قبلاً تأیید شده است'};
      }

      // درخواست تأیید پرداخت به زیبال
      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'merchant': merchantId,
          'trackId': trackId,
        }),
      );

      // بررسی پاسخ تأیید
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (responseData['result'] == 100) {
        // پرداخت موفق بوده است
        final refNumber = responseData['refNumber']?.toString() ?? '';

        // به‌روزرسانی وضعیت تراکنش
        await supabase.from('transactions').update({
          'status': 'success',
          'reference_id': refNumber,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('authority', trackId);

        // به‌روزرسانی پروفایل کاربر
        await supabase.from('profiles').update({
          'badge_type': transactionData['badge_type'],
          'is_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', transactionData['user_id']);

        return {
          'success': true,
          'message': 'پرداخت با موفقیت انجام شد',
          'referenceId': refNumber,
          'badgeType': transactionData['badge_type'],
        };
      } else {
        // پرداخت ناموفق بوده است
        await supabase.from('transactions').update({
          'status': 'failed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('authority', trackId);

        return {
          'success': false,
          'message':
              'تأیید پرداخت ناموفق بود. ${responseData['message'] ?? responseData['result']}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در تأیید پرداخت: $e'};
    }
  }
}
