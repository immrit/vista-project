// lib/features/chat/services/message_actions_service.dart
//
// سرویس اقدامات روی پیام‌ها (ویرایش، حذف، فوروارد)
// Go backend message actions
//

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_controller.dart';
import '../../../security/logging_utility.dart';
import '../../../services/http_client_factory.dart';

/// نتیجه عملیات
class ActionResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const ActionResult.success([this.data])
      : isSuccess = true,
        error = null;

  const ActionResult.failure(this.error)
      : isSuccess = false,
        data = null;
}

/// سرویس اقدامات پیام — Go backend edition
class MessageActionsService {
  // محدودیت زمانی ویرایش (48 ساعت)
  static const editTimeLimit = Duration(hours: 48);

  final Dio _dio = createApiV1Dio(baseUrl: EnvConfig.apiBaseUrl);

  Future<Options?> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<String?> _currentUserId() async {
    return TokenStorage.getUserId();
  }

  // ─── بررسی امکان ویرایش ─────────────────────────────────────────
  bool canEditMessage(String senderId, DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    return age <= editTimeLimit;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✏️ EDIT MESSAGE → PUT /v1/chat/messages/{id}
  // ═══════════════════════════════════════════════════════════════════

  Future<ActionResult<void>> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      final options = await _authOptions();
      if (options == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }

      final dio = _dio;
      await dio.put(
        '/chat/messages/$messageId',
        data: {'content': newContent.trim()},
        options: options,
      );

      logInfo('✅ Message edited: $messageId');
      return const ActionResult.success();
    } on DioException catch (e) {
      final msg = _extractError(e);
      logWarning('❌ Error editing message: $msg');
      return ActionResult.failure(msg);
    } catch (e) {
      return const ActionResult.failure('خطا در ویرایش پیام');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ↗️ FORWARD MESSAGE → POST /v1/chat/messages/{id}/forward
  // ═══════════════════════════════════════════════════════════════════

  Future<ActionResult<int>> forwardMessage({
    required String messageId,
    required List<String> targetConversationIds,
  }) async {
    try {
      final options = await _authOptions();
      if (options == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }
      if (targetConversationIds.isEmpty) {
        return const ActionResult.failure('هیچ مکالمه‌ای انتخاب نشده');
      }

      final dio = _dio;
      int successCount = 0;

      for (final conversationId in targetConversationIds) {
        try {
          await dio.post(
            '/chat/messages/$messageId/forward',
            data: {'target_conversation_id': conversationId},
            options: options,
          );
          successCount++;
        } catch (e) {
          logWarning('❌ Error forwarding to $conversationId: $e');
        }
      }

      if (successCount == 0) {
        return const ActionResult.failure('خطا در فوروارد پیام');
      }
      return ActionResult.success(successCount);
    } on DioException catch (e) {
      return ActionResult.failure(_extractError(e));
    } catch (e) {
      return const ActionResult.failure('خطا در فوروارد پیام');
    }
  }

  Future<ActionResult<int>> forwardMultipleMessages({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) async {
    int totalSuccess = 0;
    for (final messageId in messageIds) {
      final result = await forwardMessage(
        messageId: messageId,
        targetConversationIds: targetConversationIds,
      );
      if (result.isSuccess) totalSuccess += result.data ?? 0;
    }
    if (totalSuccess == 0) {
      return const ActionResult.failure('خطا در فوروارد پیام‌ها');
    }
    return ActionResult.success(totalSuccess);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🗑️ DELETE MESSAGE → DELETE /v1/chat/messages/{id}
  // ═══════════════════════════════════════════════════════════════════

  Future<ActionResult<void>> deleteMessage({
    required String messageId,
    required String conversationId,
    bool forEveryone = false,
  }) async {
    try {
      final userId = await _currentUserId();
      if (userId == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }
      final options = await _authOptions();
      if (options == null) {
        return const ActionResult.failure('توکن نامعتبر است');
      }

      final dio = _dio;
      await dio.delete(
        '/chat/messages/$messageId',
        queryParameters: {'for_everyone': forEveryone},
        options: options,
      );

      logInfo('✅ Message deleted: $messageId (forEveryone=$forEveryone)');
      return const ActionResult.success();
    } on DioException catch (e) {
      return ActionResult.failure(_extractError(e));
    } catch (e) {
      return const ActionResult.failure('خطا در حذف پیام');
    }
  }

  Future<ActionResult<int>> deleteMultipleMessages({
    required List<String> messageIds,
    required String conversationId,
    bool forEveryone = false,
  }) async {
    int successCount = 0;
    for (final messageId in messageIds) {
      final result = await deleteMessage(
        messageId: messageId,
        conversationId: conversationId,
        forEveryone: forEveryone,
      );
      if (result.isSuccess) successCount++;
    }
    if (successCount == 0) {
      return const ActionResult.failure('هیچ پیامی حذف نشد');
    }
    return ActionResult.success(successCount);
  }

  Future<Set<String>> getHiddenMessageIds(String conversationId) async {
    return const <String>{};
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📌 PIN MESSAGE → POST /v1/chat/messages/{id}/pin
  // ═══════════════════════════════════════════════════════════════════

  Future<ActionResult<void>> pinMessage({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      final options = await _authOptions();
      if (options == null) return const ActionResult.failure('توکن نامعتبر');

      final dio = _dio;
      await dio.post(
        '/chat/messages/$messageId/pin',
        options: options,
      );
      return const ActionResult.success();
    } on DioException catch (e) {
      return ActionResult.failure(_extractError(e));
    } catch (_) {
      return const ActionResult.failure('خطا در پین کردن پیام');
    }
  }

  Future<ActionResult<void>> unpinMessage(String messageId) async {
    try {
      final options = await _authOptions();
      if (options == null) return const ActionResult.failure('توکن نامعتبر');

      final dio = _dio;
      await dio.delete(
        '/chat/messages/$messageId/pin',
        options: options,
      );
      return const ActionResult.success();
    } on DioException catch (e) {
      return ActionResult.failure(_extractError(e));
    } catch (_) {
      return const ActionResult.failure('خطا در آنپین کردن پیام');
    }
  }

  Future<List<Map<String, dynamic>>> getPinnedMessages(
      String conversationId) async {
    try {
      final options = await _authOptions();
      if (options == null) return [];
      final dio = _dio;
      final response = await dio.get(
        '/chat/conversations/$conversationId/pinned',
        options: options,
      );
      final data = response.data;
      if (data is Map && data['messages'] is List) {
        return List<Map<String, dynamic>>.from(
            data['messages'].whereType<Map>());
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── خطاگیری ────────────────────────────────────────────────────
  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          'خطای سرور (${e.response?.statusCode})';
    }
    return 'خطای شبکه: ${e.message}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🎯 PROVIDERS
// ═══════════════════════════════════════════════════════════════════

final messageActionsServiceProvider = Provider<MessageActionsService>((ref) {
  return MessageActionsService();
});

/// Actions handler provider
final messageActionsProvider = Provider<MessageActionsHandler>((ref) {
  final service = ref.watch(messageActionsServiceProvider);
  return MessageActionsHandler(service);
});

class MessageActionsHandler {
  final MessageActionsService _service;

  MessageActionsHandler(this._service);

  bool canEdit(String senderId, DateTime createdAt) =>
      _service.canEditMessage(senderId, createdAt);

  Future<ActionResult<void>> edit({
    required String messageId,
    required String newContent,
  }) =>
      _service.editMessage(messageId: messageId, newContent: newContent);

  Future<ActionResult<int>> forward({
    required String messageId,
    required List<String> targetConversationIds,
  }) =>
      _service.forwardMessage(
        messageId: messageId,
        targetConversationIds: targetConversationIds,
      );

  Future<ActionResult<int>> forwardMultiple({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) =>
      _service.forwardMultipleMessages(
        messageIds: messageIds,
        targetConversationIds: targetConversationIds,
      );

  Future<ActionResult<void>> pin({
    required String messageId,
    required String conversationId,
  }) =>
      _service.pinMessage(messageId: messageId, conversationId: conversationId);

  Future<ActionResult<void>> unpin(String messageId) =>
      _service.unpinMessage(messageId);
}
