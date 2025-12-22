import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class BazaarPaymentService {
  static const platform = MethodChannel('ir.coffevista.vista/bazaar_native');

  static const String _verifyApiUrl =
      'https://function-vista.chbk.dev/api/payment/bazaar-verify';

  bool _isConnected = false;

  Future<bool> init() async {
    print('🔄 [Flutter] Connecting to Native Poolakey...');
    try {
      final bool result = await platform.invokeMethod('connect');
      _isConnected = result;
      return result;
    } catch (e) {
      print("❌ [Flutter] Connection Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> purchaseSubscription(String productId) async {
    print("🛒 [Flutter] Requesting purchase: $productId");

    if (!_isConnected) {
      final connected = await init();
      if (!connected) {
        return {
          'success': false,
          'message':
              'اتصال به بازار برقرار نشد. لطفاً از نصب بودن بازار اطمینان حاصل کنید.'
        };
      }
    }

    try {
      // 1. انجام خرید و دریافت نتیجه کامل از کاتلین
      final Map<dynamic, dynamic> result =
          await platform.invokeMethod('purchase', {
        'productId': productId,
        'payload': 'user_${Supabase.instance.client.auth.currentUser?.id}',
      });

      // 2. استخراج اطلاعات دقیق (شامل پکیج نیمی که واقعا خرید کرده)
      final String purchaseToken = result['purchaseToken'];
      final String packageName = result['packageName']; // <--- این خیلی مهم است

      print("💎 [Flutter] Token: $purchaseToken");
      print("📦 [Flutter] Package: $packageName");

      // 3. ارسال به سرور (پکیج نیم را هم می‌فرستیم)
      return await _verifyOnServer(purchaseToken, productId, packageName);
    } catch (e) {
      if (e is PlatformException) {
        if (e.code == 'CANCELED') {
          return {'success': false, 'message': 'پرداخت توسط کاربر لغو شد.'};
        }
        if (e.code == 'FAILED') {
          return {'success': false, 'message': 'خطا در پرداخت: ${e.message}'};
        }
      }
      print("❌ [Flutter] Exception: $e");
      return {'success': false, 'message': 'خطای نامشخص در پرداخت.'};
    }
  }

  // اضافه شدن پارامتر packageName به متد
  Future<Map<String, dynamic>> _verifyOnServer(
      String token, String productId, String packageName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'کاربر لاگین نیست.'};

    try {
      print("🚀 [Server] Verifying for $packageName...");

      final response = await http
          .post(
            Uri.parse(_verifyApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}',
            },
            body: jsonEncode({
              'purchase_token': token,
              'product_id': productId,
              'package_name': packageName, // <--- ارسال پکیج نیم داینامیک
              'user_id': user.id,
            }),
          )
          .timeout(const Duration(seconds: 25));

      print("📥 [Server Response] Code: ${response.statusCode}");
      print("📥 [Server Response] Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': 'اشتراک ویژه فعال شد! 🎉'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'تایید خرید ناموفق بود.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطا در ارتباط با سرور.'};
    }
  }
}
