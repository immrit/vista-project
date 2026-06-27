import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Vista/utils/env_config.dart';
import 'current_user_service.dart';
import '../features/auth/providers/auth_controller.dart';
import '../security/logging_utility.dart';
import 'device_id_service.dart';
import 'system_status_service.dart';

class PaymentService {
  static const platform = MethodChannel('ir.coffevista.vista/bazaar_native');

  bool _isConnected = false;

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  Future<bool> init() async {
    // If Zibal, we don't need native Bazaar connection
    if (EnvConfig.paymentGateway == 'zibal') {
      return true;
    }

    print('🔄 [Flutter] Connecting to Native Poolakey (Bazaar)...');
    try {
      final bool result = await platform.invokeMethod('connect');
      _isConnected = result;
      return result;
    } catch (e) {
      print("❌ [Flutter] Connection Error: $e");
      return false;
    }
  }

  /// Fetches admin-set subscription prices from the backend so the paywall
  /// shows whatever prices/plans are configured in the management panel
  /// (never hardcoded). Returns [] on any failure; caller falls back to
  /// its local defaults.
  Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return [];

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

      final response = await dio.get('/payment/subscription-plans');
      final data = response.data;
      final plans = data is Map ? data['plans'] : null;
      if (plans is List) {
        return plans
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      return [];
    } catch (e) {
      logWarning('fetch subscription plans failed', error: e);
      return [];
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
          'message': 'اتصال به درگاه پرداخت برقرار نشد.'
        };
      }
    }

    if (EnvConfig.paymentGateway == 'zibal') {
      return _processZibalPurchase(productId);
    } else {
      return _processBazaarPurchase(productId);
    }
  }

  Future<Map<String, dynamic>> _processZibalPurchase(String productId) async {
    print("💳 [Flutter] Processing via Zibal for product: $productId");
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

      // Callback URL needs to be your vista-web payment verification page.
      final callbackUrl = 'https://cafevista.ir/payment/callback';

      final response = await dio.post(
        '/payment/zibal/request',
        data: {
          'package_id': productId,
          'callback_url': callbackUrl,
        },
      );

      final data = response.data;
      if (data['success'] == true || data['track_id'] != null) {
        final paymentUrl = data['url'] ?? 'https://gateway.zibal.ir/start/${data["track_id"]}';
        
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return {
            'success': true,
            'message': 'در حال انتقال به درگاه پرداخت زیبال...',
            'pending_web_flow': true // Indicates to UI that payment is completing via browser
          };
        } else {
          return {'success': false, 'message': 'امکان باز کردن درگاه پرداخت وجود ندارد.'};
        }
      } else {
         return {'success': false, 'message': data['message'] ?? 'خطا در ایجاد تراکنش'};
      }
    } catch (e) {
      logWarning('Zibal request failed', error: e);
      return {'success': false, 'message': 'خطا در ارتباط با سرور پرداخت زیبال.'};
    }
  }

  Future<Map<String, dynamic>> _processBazaarPurchase(String productId) async {
    try {
      final userId = await CurrentUserService.instance.resolveUserId();
      final Map<dynamic, dynamic> result = await platform.invokeMethod('subscribe', {
        'productId': productId,
        'payload': 'user_$userId',
      });

      final String purchaseToken = result['purchaseToken'];
      final String packageName = result['packageName'];

      print("💎 [Flutter] Token: $purchaseToken");
      print("📦 [Flutter] Package: $packageName");

      return await _verifyBazaarOnServer(purchaseToken, productId, packageName);
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

  Future<Map<String, dynamic>> _verifyBazaarOnServer(
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
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'اشتراک ویژه فعال شد! 🎉',
          'expires_at': data['expires_at'],
          'days_added': data['days_added'],
          'plan': data['plan'],
        };
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
