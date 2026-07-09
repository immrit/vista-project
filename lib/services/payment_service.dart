import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Vista/utils/env_config.dart';
import 'current_user_service.dart';
import '../features/auth/providers/auth_controller.dart';
import '../security/logging_utility.dart';
import 'http_client_factory.dart';
import 'system_status_service.dart';

class PaymentService {
  static const platform = MethodChannel('ir.coffevista.vista/bazaar_native');

  bool _isConnected = false;

  /// Pinned client with the global interceptors (TLS pinning, token refresh,
  /// feature-gate/maintenance handling). Payment is the one flow that must
  /// not die on an expired access token, so never use a raw Dio here.
  final Dio _dio = createApiV1Dio();

  Future<Options?> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<bool> init() async {
    // If Zibal, we don't need native Bazaar connection
    if (EnvConfig.paymentGateway == 'zibal') {
      return true;
    }

    logInfo('Connecting to Native Poolakey (Bazaar)...');
    try {
      final bool result = await platform.invokeMethod('connect');
      _isConnected = result;
      return result;
    } catch (e) {
      logWarning('Bazaar connection error', error: e);
      return false;
    }
  }

  /// Fetches admin-set subscription prices from the backend so the paywall
  /// shows whatever prices/plans are configured in the management panel
  /// (never hardcoded). Returns [] on any failure; caller falls back to
  /// its local defaults.
  Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final options = await _authOptions();
      if (options == null) return [];

      final response =
          await _dio.get('/payment/subscription-plans', options: options);
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
    logInfo('Requesting purchase: $productId');

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
    logInfo('Processing via Zibal for product: $productId');
    try {
      final options = await _authOptions();
      if (options == null) {
        return {'success': false, 'message': 'توکن احراز هویت یافت نشد.'};
      }

      // Callback URL needs to be your vista-web payment verification page.
      final callbackUrl = 'https://cafevista.ir/payment/callback';

      final response = await _dio.post(
        '/payment/zibal/request',
        data: {
          'package_id': productId,
          'callback_url': callbackUrl,
        },
        options: options,
      );

      final data = response.data;
      if (data['success'] == true || data['track_id'] != null) {
        final paymentUrl = data['url'] ??
            'https://gateway.zibal.ir/start/${data["track_id"]}';

        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return {
            'success': true,
            'message': 'در حال انتقال به درگاه پرداخت زیبال...',
            'pending_web_flow':
                true // Indicates to UI that payment is completing via browser
          };
        } else {
          return {
            'success': false,
            'message': 'امکان باز کردن درگاه پرداخت وجود ندارد.'
          };
        }
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'خطا در ایجاد تراکنش'
        };
      }
    } catch (e) {
      logWarning('Zibal request failed', error: e);
      return {'success': false, 'message': 'خطا در ارتباط با سرور پرداخت زیبال.'};
    }
  }

  /// Confirms a Zibal payment after the user returns from the gateway.
  /// The backend re-queries Zibal with the track_id and only then grants the
  /// subscription, so a cancelled/abandoned payment never activates premium.
  Future<Map<String, dynamic>> verifyZibalPurchase(String trackId) async {
    final parsedTrackId = int.tryParse(trackId.trim());
    if (parsedTrackId == null || parsedTrackId <= 0) {
      return {'success': false, 'message': 'شناسه تراکنش نامعتبر است.'};
    }
    try {
      final options = await _authOptions();
      if (options == null) {
        return {'success': false, 'message': 'توکن احراز هویت یافت نشد.'};
      }

      final response = await _dio.post(
        '/payment/zibal/verify',
        data: {'track_id': parsedTrackId},
        options: options,
      );

      final data = (response.data as Map).cast<String, dynamic>();
      if (data['success'] == true) {
        return {
          'success': true,
          'message': data['message']?.toString() ?? 'اشتراک ویژه فعال شد! 🎉',
          'expires_at': data['expires_at'],
          'days_added': data['days_added'],
          'plan': data['plan'],
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'تایید پرداخت ناموفق بود.',
      };
    } on DioException catch (e) {
      logWarning('Zibal verify request failed', error: e);
      final msg = (e.response?.data is Map)
          ? (e.response!.data['message'] ?? 'در تایید پرداخت خطا رخ داد.')
          : 'در تایید پرداخت خطا رخ داد. لطفا دوباره تلاش کنید.';
      return {'success': false, 'message': msg};
    } catch (e) {
      logWarning('Zibal verify unexpected error', error: e);
      return {
        'success': false,
        'message': 'در تایید پرداخت خطا رخ داد. لطفا دوباره تلاش کنید.'
      };
    }
  }

  Future<Map<String, dynamic>> _processBazaarPurchase(String productId) async {
    try {
      final userId = await CurrentUserService.instance.resolveUserId();
      final Map<dynamic, dynamic> result =
          await platform.invokeMethod('subscribe', {
        'productId': productId,
        'payload': 'user_$userId',
      });

      final String purchaseToken = result['purchaseToken'];
      final String packageName = result['packageName'];

      // NEVER log purchaseToken — it is the credential the server uses to
      // verify and grant the subscription.
      logInfo('Bazaar purchase completed for package: $packageName');

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
      logWarning('Bazaar purchase exception', error: e);
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
      final options = await _authOptions();
      if (options == null) {
        return {'success': false, 'message': 'توکن احراز هویت یافت نشد.'};
      }

      final response = await _dio.post(
        '/payment/bazaar-verify',
        data: {
          'purchase_token': token,
          'product_id': productId,
          'package_name': packageName,
        },
        options: options,
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
