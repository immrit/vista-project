// lib/services/auth_api_service.dart
import 'package:dio/dio.dart';

class AuthApiService {
  // آدرس سرور نود جی‌اس شما
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
      // لاگ کردن خطا برای دیباگ
      print('Send OTP Error: $e');
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
}
