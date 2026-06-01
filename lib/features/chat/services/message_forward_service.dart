import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../auth/providers/auth_controller.dart';

class MessageForwardResult {
  final bool isSuccess;
  final String? error;
  final Map<String, String>? forwardedMessageIds;

  const MessageForwardResult({
    required this.isSuccess,
    this.error,
    this.forwardedMessageIds,
  });

  factory MessageForwardResult.success(Map<String, String> messageIds) {
    return MessageForwardResult(
      isSuccess: true,
      forwardedMessageIds: messageIds,
    );
  }

  factory MessageForwardResult.failure(String error) {
    return MessageForwardResult(isSuccess: false, error: error);
  }
}

class MessageForwardService {
  late final Dio _dio;

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  MessageForwardService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '$_backendUrl/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<MessageForwardResult> forwardSingle({
    required String messageId,
    required List<String> targetConversationIds,
  }) {
    return forwardMultiple(
      messageIds: [messageId],
      targetConversationIds: targetConversationIds,
    );
  }

  Future<MessageForwardResult> forwardMultiple({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) async {
    if (messageIds.isEmpty || targetConversationIds.isEmpty) {
      return MessageForwardResult.failure('پیام یا مکالمه انتخاب نشده');
    }
    try {
      final forwarded = <String, String>{};
      final options = await _authOptions();
      for (final conversationId in targetConversationIds) {
        for (final messageId in messageIds) {
          final response = await _dio.post(
            '/chat/messages/$messageId/forward',
            data: {'target_conversation_id': conversationId},
            options: options,
          );
          final id = _asMap(response.data)['id']?.toString();
          if (id != null && id.isNotEmpty) {
            forwarded[conversationId] = id;
          }
        }
      }
      return MessageForwardResult.success(forwarded);
    } catch (e) {
      return MessageForwardResult.failure(e.toString());
    }
  }

  Future<MessageForwardResult> forwardWithCaption({
    required List<String> messageIds,
    required String targetConversationId,
    required String caption,
  }) async {
    final result = await forwardMultiple(
      messageIds: messageIds,
      targetConversationIds: [targetConversationId],
    );
    if (!result.isSuccess || caption.trim().isEmpty) {
      return result;
    }
    try {
      await _dio.post(
        '/chat/conversations/$targetConversationId/messages',
        data: {'content': caption.trim(), 'message_type': 'text'},
        options: await _authOptions(),
      );
      return result;
    } catch (e) {
      return MessageForwardResult.failure(e.toString());
    }
  }

  Future<int> getForwardCount(String originalMessageId) async {
    return 0;
  }

  Future<Map<String, dynamic>?> getOriginalSenderInfo(String messageId) async {
    return null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
