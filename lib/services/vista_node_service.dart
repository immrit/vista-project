import 'dart:convert';
import 'package:http/http.dart' as http;

/// سرویس ارتباط با سرور Node.js برای عملیات چت
///
/// این سرویس مسئول ارسال درخواست‌های حذف پیام به سرور است.
/// سرور تمام منطق حذف (DB + S3) را انجام می‌دهد.
class VistaNodeService {
  static const String _baseUrl = 'https://function-vista.chbk.dev/api';
  static const Duration _timeout = Duration(seconds: 15);

  /// حذف پیام از طریق سرور Node.js
  ///
  /// سرور:
  /// 1. اطلاعات پیام را از DB می‌خواند
  /// 2. فایل S3 را (اگر وجود دارد) حذف می‌کند
  /// 3. رکورد را از DB حذف می‌کند
  static Future<void> deleteMessage(String messageId) async {
    final url = Uri.parse('$_baseUrl/chat/delete-message');

    print('🚀 [VistaNodeService] Sending delete request...');
    print('   - Message ID: $messageId');
    print('   - URL: $url');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messageId': messageId}),
          )
          .timeout(_timeout);

      print('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [VistaNodeService] Success:');
        print('   - S3 Deleted: ${data['s3Deleted']}');
        print('   - S3 Message: ${data['s3Message']}');
        print('   - DB Deleted: ${data['dbDeleted']}');
        print('   - Duration: ${data['duration']}');
      } else {
        final errorBody = response.body;
        print('❌ [VistaNodeService] Server Error: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      print('❌ [VistaNodeService] Error: $e');
      rethrow;
    }
  }

  /// حذف چند پیام به صورت batch
  static Future<void> deleteMessagesBatch(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    final url = Uri.parse('$_baseUrl/chat/delete-messages-batch');

    print('🚀 [VistaNodeService] Sending batch delete request...');
    print('   - Count: ${messageIds.length}');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'messageIds': messageIds}),
          )
          .timeout(_timeout);

      print('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Batch delete failed: ${response.body}');
      }

      final data = json.decode(response.body);
      print('✅ [VistaNodeService] Batch Success:');
      print('   - Messages Deleted: ${messageIds.length}');
      print('   - S3 Files Deleted: ${data['s3FilesDeleted']}');
    } catch (e) {
      print('❌ [VistaNodeService] Batch Error: $e');
      rethrow;
    }
  }

  /// پاکسازی کامل یک مکالمه
  static Future<void> clearConversation(String conversationId) async {
    final url = Uri.parse('$_baseUrl/chat/clear-conversation');

    print('🧹 [VistaNodeService] Clearing conversation: $conversationId');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'conversationId': conversationId}),
          )
          .timeout(_timeout);

      print('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Clear conversation failed: ${response.body}');
      }

      final data = json.decode(response.body);
      print('✅ [VistaNodeService] Conversation Cleared:');
      print('   - Messages Deleted: ${data['messagesDeleted']}');
      print('   - S3 Files Deleted: ${data['s3FilesDeleted']}');
    } catch (e) {
      print('❌ [VistaNodeService] Clear Error: $e');
      rethrow;
    }
  }

  /// دریافت IP عمومی کاربر از سرور
  static Future<String> getPublicIp() async {
    final url = Uri.parse('$_baseUrl/utils/get-ip');

    try {
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
