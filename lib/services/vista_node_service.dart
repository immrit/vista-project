import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/publicPostModel.dart';
import '../security/logging_utility.dart';
import 'session_manager_service_v2.dart';

enum NodeErrorKind {
  auth,
  network,
  timeout,
  server,
  unknown,
}

class NodeApiException implements Exception {
  final NodeErrorKind kind;
  final int? statusCode;
  final String message;
  final String? errorCode;
  final bool retriable;

  const NodeApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.errorCode,
    this.retriable = false,
  });

  bool get isAuthFailure => kind == NodeErrorKind.auth;

  @override
  String toString() => message;
}

class VistaNodeService {
  static const String _baseUrl = 'https://function-vista.chbk.dev/api';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
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

  static dynamic _safeDecodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  static NodeApiException _mapHttpError(http.Response response) {
    final payload = _safeDecodeBody(response.body);
    String message = 'خطا در ارتباط با سرور.';
    String? errorCode;
    bool retriable = false;

    if (payload is Map<String, dynamic>) {
      final payloadMessage = payload['message']?.toString();
      if (payloadMessage != null && payloadMessage.isNotEmpty) {
        message = payloadMessage;
      }
      errorCode =
          payload['error_code']?.toString() ?? payload['error']?.toString();
      retriable = payload['retriable'] == true;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      return NodeApiException(
        kind: NodeErrorKind.auth,
        statusCode: response.statusCode,
        errorCode: errorCode,
        retriable: false,
        message: 'برای ادامه، دوباره وارد حساب شوید.',
      );
    }

    if (response.statusCode >= 500) {
      return NodeApiException(
        kind: NodeErrorKind.server,
        statusCode: response.statusCode,
        errorCode: errorCode,
        retriable: true,
        message: message,
      );
    }

    return NodeApiException(
      kind: NodeErrorKind.unknown,
      statusCode: response.statusCode,
      errorCode: errorCode,
      retriable: retriable,
      message: message,
    );
  }

  static Future<bool> _tryRefreshSession() async {
    try {
      final refreshed = await Supabase.instance.client.auth.refreshSession();
      return refreshed.session != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _handleFinalAuthFailure() async {
    try {
      await SessionManagerServiceV2.instance.userLogout();
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
  }

  static Future<http.Response> _sendOnce({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    String? body,
  }) async {
    switch (method) {
      case 'GET':
        return http.get(url, headers: headers).timeout(_timeout);
      case 'POST':
        return http.post(url, headers: headers, body: body).timeout(_timeout);
      default:
        throw const NodeApiException(
          kind: NodeErrorKind.unknown,
          message: 'Unsupported request method.',
        );
    }
  }

  static Future<Map<String, dynamic>> _sendWithAuthRetry({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool allowAuthRetry = true,
  }) async {
    final url = Uri.parse('$_baseUrl$path');

    Future<http.Response> doCall() async {
      final headers = await _buildAuthHeaders();
      return _sendOnce(
        method: method,
        url: url,
        headers: headers,
        body: body == null ? null : json.encode(body),
      );
    }

    try {
      var response = await doCall();

      if (response.statusCode == 401 && allowAuthRetry) {
        final refreshed = await _tryRefreshSession();
        if (refreshed) {
          response = await doCall();
        }
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _handleFinalAuthFailure();
        throw _mapHttpError(response);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _mapHttpError(response);
      }

      final decoded = _safeDecodeBody(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } on TimeoutException {
      throw const NodeApiException(
        kind: NodeErrorKind.timeout,
        message: 'درخواست زمان‌بر شد. لطفا دوباره تلاش کنید.',
        retriable: true,
      );
    } on SocketException {
      throw const NodeApiException(
        kind: NodeErrorKind.network,
        message: 'اتصال اینترنت برقرار نیست.',
        retriable: true,
      );
    } on NodeApiException {
      rethrow;
    } catch (e) {
      logWarning('Node request failed', error: e);
      throw const NodeApiException(
        kind: NodeErrorKind.unknown,
        message: 'خطا در ارتباط با سرور.',
        retriable: true,
      );
    }
  }

  static Future<Map<String, dynamic>> fetchForYouFeed({
    int limit = 15,
    String? before,
    bool? debug,
  }) {
    return _sendWithAuthRetry(
      method: 'POST',
      path: '/feed/for-you',
      body: {
        'limit': limit,
        if (before != null && before.isNotEmpty) 'before': before,
        if (debug == true) 'debug': true,
      },
    );
  }

  static Future<List<PublicPostModel>> fetchForYouFeedPosts({
    int limit = 15,
    String? before,
    bool? debug,
  }) async {
    final data =
        await fetchForYouFeed(limit: limit, before: before, debug: debug);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items.map((m) => PublicPostModel.fromMap(m)).toList();
  }

  static Future<void> trackFeedEvent({
    required String postId,
    required String eventType,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await _sendWithAuthRetry(
        method: 'POST',
        path: '/feed/event',
        body: {
          'postId': postId,
          'eventType': eventType,
          if (meta != null) 'meta': meta,
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> deleteMessage(String messageId) async {
    await _sendWithAuthRetry(
      method: 'POST',
      path: '/chat/delete-message',
      body: {'messageId': messageId},
    );
  }

  static Future<void> deleteMessagesBatch(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await _sendWithAuthRetry(
      method: 'POST',
      path: '/chat/delete-messages-batch',
      body: {'messageIds': messageIds},
    );
  }

  static Future<void> clearConversation(String conversationId) async {
    await _sendWithAuthRetry(
      method: 'POST',
      path: '/chat/clear-conversation',
      body: {'conversationId': conversationId},
    );
  }

  static Future<Map<String, dynamic>> verifyBazaarPurchase({
    required String purchaseToken,
    required String productId,
    required String packageName,
  }) {
    return _sendWithAuthRetry(
      method: 'POST',
      path: '/payment/bazaar-verify',
      body: {
        'purchase_token': purchaseToken,
        'product_id': productId,
        'package_name': packageName,
      },
    );
  }

  static Future<String> getPublicIp() async {
    final url = Uri.parse('$_baseUrl/utils/get-ip');
    try {
      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode == 200) {
        final data = _safeDecodeBody(response.body);
        if (data is Map<String, dynamic>) {
          final ip = data['ip']?.toString();
          if (ip != null && ip.isNotEmpty) return ip;
        }
      }
    } catch (_) {}
    return 'unavailable';
  }
}
