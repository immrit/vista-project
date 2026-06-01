import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:Vista/utils/env_config.dart';
import 'current_user_service.dart';
import '../features/auth/providers/auth_controller.dart';
import '../security/logging_utility.dart';
import 'device_id_service.dart';
import 'system_status_service.dart';

class BazaarPaymentService {
  static const platform = MethodChannel('ir.coffevista.vista/bazaar_native');

  bool _isConnected = false;

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

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

    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.payments,
        forceRefresh: true,
      );
    } on FeatureDisabledException {
      return {
        'success': false,
        'message': 'پرداخت‌ها موقتاً توسط مدیریت غیرفعال شده‌اند.'
      };
    } on MaintenanceModeException {
      return {'success': false, 'message': 'سیستم در حالت تعمیرات است.'};
    }

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
      final userId = await CurrentUserService.instance.resolveUserId();
      final Map<dynamic, dynamic> result =
          await platform.invokeMethod('subscribe', {
        'productId': productId,
        'payload': 'user_$userId',
      });

      // 2. استخراج اطلاعات دقیق (شامل پکیج نیمی که واقعا خرید کرده)
      final String purchaseToken = result['purchaseToken'];
      final String packageName = result['packageName'];

      print("💎 [Flutter] Token: $purchaseToken");
      print("📦 [Flutter] Package: $packageName");

      // 3. ارسال به سرور Go
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

  /// ارسال درخواست تأیید به سرور Go
  Future<Map<String, dynamic>> _verifyOnServer(
      String token, String productId, String packageName) async {
    final userId = await CurrentUserService.instance.resolveUserId();
    if (userId == null) {
      return {'success': false, 'message': 'کاربر لاگین نیست.'};
    }

    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {'success': false, 'message': 'توکن احراز هویت یافت نشد.'};
      }

      final dio = Dio(BaseOptions(
        baseUrl: '$_backendUrl/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-Device-ID': DeviceIdService.id,
        },
      ));

      final response = await dio.post(
        '/payment/bazaar-verify',
        data: {
          'purchase_token': token,
          'product_id': productId,
          'package_name': packageName,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return {'success': true, 'message': 'اشتراک ویژه فعال شد! 🎉'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'تایید خرید ناموفق بود.'
        };
      }
    } on DioException catch (e) {
      logWarning('Bazaar verify request failed', error: e);
      final msg = (e.response?.data is Map)
          ? (e.response!.data['message'] ?? 'در تایید خرید خطا رخ داد.')
          : 'در تایید خرید خطا رخ داد. لطفا دوباره تلاش کنید.';
      return {'success': false, 'message': msg};
    } catch (e) {
      logWarning('Bazaar verify unexpected error', error: e);
      return {
        'success': false,
        'message': 'در تایید خرید خطا رخ داد. لطفا دوباره تلاش کنید.'
      };
    }
  }
}
