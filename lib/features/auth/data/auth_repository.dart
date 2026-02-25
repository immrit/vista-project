import 'package:dio/dio.dart';
import '../../../security/logging_utility.dart';

class RecoveryOption {
  final String id;
  final String method; // 'email' | 'sms'
  final String masked;

  const RecoveryOption({
    required this.id,
    required this.method,
    required this.masked,
  });

  factory RecoveryOption.fromJson(Map<String, dynamic> json) {
    return RecoveryOption(
      id: (json['id'] as String?) ?? '',
      method: (json['method'] as String?)?.toLowerCase() ?? '',
      masked: (json['masked'] as String?) ?? '',
    );
  }
}

class AuthRepository {
  // آدرس سرور نود جی‌اس
  static const String _baseUrl = 'https://function-vista.chbk.dev/api/auth';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  // ارسال کد تایید
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _dio.post('/send-otp', data: {
        'phone_number': phoneNumber,
      });
      return response.data['success'] == true;
    } catch (e) {
      logError('Send OTP Error', error: e);
      throw 'خطا در ارسال پیامک. لطفا اتصال اینترنت خود را بررسی کنید.';
    }
  }

  // بررسی کد تایید
  Future<dynamic> verifyOtp(String phoneNumber, String code,
      {bool isUpdateMode = false}) async {
    try {
      final response = await _dio.post('/verify-otp', data: {
        'phone_number': phoneNumber,
        'code': code,
        'is_update_mode': isUpdateMode,
      });

      if (response.data['success'] == true) {
        return response.data['user'];
      } else {
        throw response.data['message'] ?? 'کد وارد شده صحیح نیست';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data['message'] ?? 'خطای سمت سرور';
      }
      throw 'خطا در برقراری ارتباط با سرور';
    }
  }

  Future<void> resetPasswordSms({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post('/reset-password-sms', data: {
        'phone_number': phoneNumber,
        'code': code,
        'new_password': newPassword,
      });

      final ok = response.data is Map && response.data['success'] == true;
      if (ok) return;

      throw response.data is Map
          ? (response.data['message'] as String? ?? 'خطای نامشخص')
          : 'خطای نامشخص';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw 'کد نامعتبر است';
      }
      if (status == 429) {
        throw 'تلاش‌های زیادی انجام شده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید';
      }
      logError('Reset Password SMS Error', error: e);
      throw 'خطا در بازنشانی رمز عبور. لطفاً دوباره تلاش کنید';
    } catch (e) {
      logError('Reset Password SMS Error', error: e);
      rethrow;
    }
  }

  Future<List<RecoveryOption>> getRecoveryOptions(String identifier) async {
    try {
      final response = await _dio.post('/recovery-options', data: {
        'identifier': identifier,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در سرویس بازیابی';
      }

      final options = data is Map ? data['options'] : null;
      if (options is List) {
        return options
            .whereType<Map>()
            .map((e) => RecoveryOption.fromJson(e.cast<String, dynamic>()))
            .where((o) => o.id.isNotEmpty && o.method.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 503) {
        throw 'سرویس بازیابی موقتاً در دسترس نیست. لطفاً کمی بعد دوباره تلاش کنید';
      }
      if (status == 429) {
        throw 'تلاش‌های زیادی انجام شده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید';
      }
      logError('Get Recovery Options Error', error: e);
      throw 'خطا در دریافت گزینه‌های بازیابی';
    } catch (e) {
      logError('Get Recovery Options Error', error: e);
      rethrow;
    }
  }

  Future<void> sendRecoveryCode(String optionId) async {
    try {
      final response = await _dio.post('/recovery-send', data: {
        'option_id': optionId,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در ارسال کد';
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        throw 'لطفاً کمی بعد دوباره تلاش کنید';
      }
      if (status == 503) {
        throw 'سرویس بازیابی موقتاً در دسترس نیست. لطفاً کمی بعد دوباره تلاش کنید';
      }
      logError('Send Recovery Code Error', error: e);
      throw 'خطا در ارسال کد';
    } catch (e) {
      logError('Send Recovery Code Error', error: e);
      rethrow;
    }
  }

  Future<void> completeRecovery({
    required String optionId,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post('/recovery-complete', data: {
        'option_id': optionId,
        'code': code,
        'new_password': newPassword,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در تغییر رمز عبور';
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (status == 400 && data is Map && data['message'] == 'WEAK_PASSWORD') {
        throw 'رمز عبور ضعیف است';
      }
      if (status == 401) {
        throw 'کد نامعتبر است';
      }
      if (status == 429) {
        throw 'تلاش‌های زیادی انجام شده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید';
      }
      if (status == 503) {
        throw 'سرویس بازیابی موقتاً در دسترس نیست. لطفاً کمی بعد دوباره تلاش کنید';
      }
      logError('Complete Recovery Error', error: e);
      throw 'خطا در تغییر رمز عبور';
    } catch (e) {
      logError('Complete Recovery Error', error: e);
      rethrow;
    }
  }
}
