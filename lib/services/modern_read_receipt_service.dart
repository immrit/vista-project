import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:Vista/utils/env_config.dart';

import '../features/auth/providers/auth_controller.dart';
import '../features/chat/services/sse_manager.dart';

enum MessageDeliveryStatus { pending, sent, delivered, read, failed }

class MessageStatusInfo {
  final String messageId;
  final MessageDeliveryStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  const MessageStatusInfo({
    required this.messageId,
    required this.status,
    this.sentAt,
    this.deliveredAt,
    this.seenAt,
  });

  MessageStatusInfo copyWith({
    MessageDeliveryStatus? status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? seenAt,
  }) {
    return MessageStatusInfo(
      messageId: messageId,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      seenAt: seenAt ?? this.seenAt,
    );
  }
}

typedef LastMessageStatusCallback = void Function(
    String conversationId, MessageDeliveryStatus status);

class ModernReadReceiptService {
  static final ModernReadReceiptService _instance =
      ModernReadReceiptService._internal();
  factory ModernReadReceiptService() => _instance;
  ModernReadReceiptService._internal();

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final _statusUpdatesController =
      StreamController<Map<String, MessageStatusInfo>>.broadcast();
  final Map<String, MessageStatusInfo> _statusCache = {};
  final Map<String, String> _lastMessageIds = {};
  final Set<String> _listenedConversationIds = {};

  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  bool? _sendReadReceiptsEnabled;
  DateTime? _settingsLastCheckedAt;
  LastMessageStatusCallback? onLastMessageStatusChanged;

  Stream<Map<String, MessageStatusInfo>> get statusUpdates =>
      _statusUpdatesController.stream;

  void startListening(String conversationId) {
    if (conversationId.isEmpty) return;
    _listenedConversationIds.add(conversationId);
    _ensureSseSubscription();
  }

  void stopListening(String conversationId) {
    _listenedConversationIds.remove(conversationId);
  }

  void setLastMessageId(String conversationId, String messageId) {
    if (conversationId.isEmpty || messageId.isEmpty) return;
    _lastMessageIds[conversationId] = messageId;
  }

  String? getLastMessageId(String conversationId) =>
      _lastMessageIds[conversationId];

  Future<void> markAsDelivered(String messageId) async {
    if (messageId.isEmpty) return;
    _statusCache[messageId] = MessageStatusInfo(
      messageId: messageId,
      status: MessageDeliveryStatus.delivered,
      deliveredAt: DateTime.now(),
    );
  }

  void markAsRead(String messageId) {
    if (messageId.isEmpty) return;
    final now = DateTime.now();
    final info = MessageStatusInfo(
      messageId: messageId,
      status: MessageDeliveryStatus.read,
      deliveredAt: now,
      seenAt: now,
    );
    _statusCache[messageId] = info;
    _statusUpdatesController.add({messageId: info});
  }

  Future<void> markAllAsRead(String conversationId) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty || conversationId.isEmpty) return;
    if (!await _canSendReadReceipts(token)) return;
    await _dio.post(
      '/chat/conversations/$conversationId/read',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  void markVisibleMessagesAsRead(List<String> messageIds) {
    for (final id in messageIds) {
      markAsRead(id);
    }
  }

  MessageStatusInfo? getCachedStatus(String messageId) =>
      _statusCache[messageId];

  Future<MessageStatusInfo?> getMessageStatus(String messageId) async =>
      _statusCache[messageId];

  Future<Map<String, MessageStatusInfo>> getMessagesStatus(
    List<String> messageIds,
  ) async {
    return {
      for (final id in messageIds)
        if (_statusCache[id] != null) id: _statusCache[id]!,
    };
  }

  Future<int> getUnreadCount(String conversationId) async => 0;

  Stream<int> watchUnreadCount(String conversationId) => Stream.value(0);

  void clearCache() {
    _statusCache.clear();
  }

  void invalidateSettingsCache() {
    _sendReadReceiptsEnabled = null;
    _settingsLastCheckedAt = null;
  }

  void dispose() {
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;
    _listenedConversationIds.clear();
    _statusCache.clear();
  }

  void _ensureSseSubscription() {
    if (_sseSubscription != null) return;
    SseManager.instance.start();
    _sseSubscription = SseManager.instance.events.listen(
      (event) async {
        if (event['type'] != 'read_receipt') return;
        final data = event['data'];
        if (data is! Map) return;

        final conversationId = data['conversation_id']?.toString() ?? '';
        if (conversationId.isEmpty ||
            !_listenedConversationIds.contains(conversationId)) {
          return;
        }

        final readerId = data['user_id']?.toString() ?? '';
        final currentUserId = await TokenStorage.getUserId();
        if (readerId.isNotEmpty &&
            currentUserId != null &&
            readerId == currentUserId) {
          // Ignore our own read cursor; it must not mark outgoing ticks as read.
          return;
        }

        final lastMessageId = _lastMessageIds[conversationId];
        if (lastMessageId == null || lastMessageId.isEmpty) return;

        final readAt = DateTime.tryParse(data['read_at']?.toString() ?? '') ??
            DateTime.now();
        final info = MessageStatusInfo(
          messageId: lastMessageId,
          status: MessageDeliveryStatus.read,
          deliveredAt: readAt,
          seenAt: readAt,
        );
        _statusCache[lastMessageId] = info;
        _statusUpdatesController.add({lastMessageId: info});
        onLastMessageStatusChanged?.call(
          conversationId,
          MessageDeliveryStatus.read,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('ModernReadReceiptService SSE error: $error');
      },
    );
  }

  Future<bool> _canSendReadReceipts(String token) async {
    final now = DateTime.now();
    final cachedAt = _settingsLastCheckedAt;
    if (_sendReadReceiptsEnabled != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(minutes: 5)) {
      return _sendReadReceiptsEnabled!;
    }

    try {
      final response = await _dio.get(
        '/me/privacy',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      final enabled =
          data is Map ? (data['send_read_receipts'] as bool? ?? true) : true;
      _sendReadReceiptsEnabled = enabled;
      _settingsLastCheckedAt = now;
      return enabled;
    } catch (e) {
      debugPrint('ModernReadReceiptService settings error: $e');
      return _sendReadReceiptsEnabled ?? true;
    }
  }
}
