import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager_service_v2.dart';
import 'package:http/http.dart' as http;
import '../model/publicPostModel.dart';
import '../security/logging_utility.dart';

/// سرویس ارتباط با سرور Node.js برای عملیات چت
///
/// این سرویس مسئول ارسال درخواست‌های حذف پیام به سرور است.
/// سرور تمام منطق حذف (DB + S3) را انجام می‌دهد.
class VistaNodeService {
  static Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final sessionManager = SessionManagerServiceV2.instance;
    final sessionId = sessionManager.currentSessionId;
    final sessionToken = sessionManager.currentSessionToken;
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['x-session-id'] = sessionId;
    }
    if (sessionToken != null && sessionToken.isNotEmpty) {
      headers['x-session-token'] = sessionToken;
    }

    return headers;
  }

  static const String _baseUrl = 'https://function-vista.chbk.dev/api';
  static const Duration _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // Personalized Feed (Node.js)
  // ---------------------------------------------------------------------------

  /// Fetch "For You" personalized feed from Node.js.
  ///
  /// Expected response shape:
  /// {
  ///   "items": [ { ...postMap } ],
  ///   "hasMore": true
  /// }
  static Future<Map<String, dynamic>> fetchForYouFeed({
    int limit = 15,
    String? before,
    bool? debug,
  }) async {
    final url = Uri.parse('$_baseUrl/feed/for-you');
    final effectiveDebug = debug == true;

    try {
      final response = await http
          .post(
            url,
            headers: await _buildAuthHeaders(),
            body: json.encode({
              'limit': limit,
              if (before != null && before.isNotEmpty) 'before': before,
              if (effectiveDebug) 'debug': true,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Feed error ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<PublicPostModel>> fetchForYouFeedPosts({
    int limit = 15,
    String? before,
    bool? debug,
  }) async {
    final data = await fetchForYouFeed(limit: limit, before: before, debug: debug);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items.map((m) => PublicPostModel.fromMap(m)).toList();
  }

  /// Track a feed event (like/open/share/hide/etc).
  ///
  /// This is best-effort. We swallow errors by default to avoid degrading UX.
  static Future<void> trackFeedEvent({
    required String postId,
    required String eventType,
    Map<String, dynamic>? meta,
  }) async {
    final url = Uri.parse('$_baseUrl/feed/event');

    try {
      await http
          .post(
            url,
            headers: await _buildAuthHeaders(),
            body: json.encode({
              'postId': postId,
              'eventType': eventType,
              if (meta != null) 'meta': meta,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // best-effort
    }
  }

  /// حذف پیام از طریق سرور Node.js
  ///
  /// سرور:
  /// 1. اطلاعات پیام را از DB می‌خواند
  /// 2. فایل S3 را (اگر وجود دارد) حذف می‌کند
  /// 3. رکورد را از DB حذف می‌کند
  static Future<void> deleteMessage(String messageId) async {
    final url = Uri.parse('$_baseUrl/chat/delete-message');

    logDebug('🚀 [VistaNodeService] Sending delete request...');
    logDebug('   - Message ID: $messageId');
    logDebug('   - URL: $url');

    try {
      final response = await http
          .post(
            url,
            headers: await _buildAuthHeaders(),
            body: json.encode({'messageId': messageId}),
          )
          .timeout(_timeout);

      logDebug('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logDebug('✅ [VistaNodeService] Success:');
        logDebug('   - S3 Deleted: ${data['s3Deleted']}');
        logDebug('   - S3 Message: ${data['s3Message']}');
        logDebug('   - DB Deleted: ${data['dbDeleted']}');
        logDebug('   - Duration: ${data['duration']}');
      } else {
        final errorBody = response.body;
        logWarning('❌ [VistaNodeService] Server Error: $errorBody');
        throw Exception('Server returned ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      logWarning('❌ [VistaNodeService] Error: $e');
      rethrow;
    }
  }

  /// حذف چند پیام به صورت batch
  static Future<void> deleteMessagesBatch(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    final url = Uri.parse('$_baseUrl/chat/delete-messages-batch');

    logDebug('🚀 [VistaNodeService] Sending batch delete request...');
    logDebug('   - Count: ${messageIds.length}');

    try {
      final response = await http
          .post(
            url,
            headers: await _buildAuthHeaders(),
            body: json.encode({'messageIds': messageIds}),
          )
          .timeout(_timeout);

      logDebug('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Batch delete failed: ${response.body}');
      }

      final data = json.decode(response.body);
      logDebug('✅ [VistaNodeService] Batch Success:');
      logDebug('   - Messages Deleted: ${messageIds.length}');
      logDebug('   - S3 Files Deleted: ${data['s3FilesDeleted']}');
    } catch (e) {
      logWarning('❌ [VistaNodeService] Batch Error: $e');
      rethrow;
    }
  }

  /// پاکسازی کامل یک مکالمه
  static Future<void> clearConversation(String conversationId) async {
    final url = Uri.parse('$_baseUrl/chat/clear-conversation');

    logDebug('🧹 [VistaNodeService] Clearing conversation: $conversationId');

    try {
      final response = await http
          .post(
            url,
            headers: await _buildAuthHeaders(),
            body: json.encode({'conversationId': conversationId}),
          )
          .timeout(_timeout);

      logDebug('📨 [VistaNodeService] Response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Clear conversation failed: ${response.body}');
      }

      final data = json.decode(response.body);
      logDebug('✅ [VistaNodeService] Conversation Cleared:');
      logDebug('   - Messages Deleted: ${data['messagesDeleted']}');
      logDebug('   - S3 Files Deleted: ${data['s3FilesDeleted']}');
    } catch (e) {
      logWarning('❌ [VistaNodeService] Clear Error: $e');
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

