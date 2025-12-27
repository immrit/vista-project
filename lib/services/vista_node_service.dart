import 'dart:convert';
import 'package:http/http.dart' as http;

class VistaNodeService {
  static const String _baseUrl = 'https://function-vista.chbk.dev/api';

  /// حذف امن پیام از طریق سرور Node.js
  /// این متد هم پیام را از دیتابیس پاک می‌کند و هم فایل ضمیمه را از S3
  static Future<void> deleteMessage(String messageId, {String? fileKey}) async {
    final url = Uri.parse('$_baseUrl/chat/delete-message');

    try {
      print(
          '🚀 [VistaNodeService] Preparing to delete: messageId=$messageId, fileKey=$fileKey');
      print('🔗 [VistaNodeService] Target URL: $url');
      print('📦 [VistaNodeService] Payload: ${json.encode({
            'messageId': messageId,
            if (fileKey != null) 'fileKey': fileKey,
          })}');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'messageId': messageId,
              if (fileKey != null) 'fileKey': fileKey,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Increased timeout to 10s

      print(
          '📨 [VistaNodeService] Server Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to delete message. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('❌ [VistaNodeService] Error: $e');
      throw Exception('NodeService Error: $e');
    }
  }

  /// دریافت IP عمومی کاربر از سرور
  static Future<String> getPublicIp() async {
    final url = Uri.parse('$_baseUrl/utils/get-ip');

    try {
      // 🔒 FIX: Added timeout to prevent hanging
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('IP Request Timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['ip'] as String;
      } else {
        throw Exception('Failed to get IP: ${response.statusCode}');
      }
    } catch (e) {
      // در صورت خطا، یک مقدار پیش‌فرض برمی‌گردانیم تا برنامه کرش نکند
      return 'unavailable';
    }
  }
}
