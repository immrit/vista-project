import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../features/auth/providers/auth_controller.dart';
import '../features/chat/services/sse_manager.dart';
import '../security/logging_utility.dart';
import 'http_client_factory.dart';

class TypingService {
  static final TypingService _instance = TypingService._internal();
  factory TypingService() => _instance;
  TypingService._internal();

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  static const Duration _typingTimeout = Duration(seconds: 8);
  static const Duration _typingSyncThrottle = Duration(seconds: 1);

  // P3: shared pinned client (cert pinning + god-mode interceptors).
  late final Dio _dio = createApiV1Dio(baseUrl: _backendUrl);

  final Map<String, Timer> _typingTimers = {};
  final Map<String, Set<String>> _typingUsers = {};
  final Map<String, DateTime> _lastTypingSyncAt = {};
  final Map<String, StreamController<Set<String>>> _typingStreams = {};
  final Map<String, int> _streamListenersCount = {};

  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  bool _isDisposed = false;

  Future<void> startTyping(String conversationId, String userId) async {
    try {
      _typingUsers[conversationId] ??= {};
      _typingUsers[conversationId]!.add(userId);
      _notifyTypingUpdate(conversationId);

      final now = DateTime.now();
      final lastSync = _lastTypingSyncAt[conversationId];
      if (lastSync == null || now.difference(lastSync) >= _typingSyncThrottle) {
        await _sendTyping(conversationId);
        _lastTypingSyncAt[conversationId] = now;
      }

      _typingTimers[conversationId]?.cancel();
      _typingTimers[conversationId] = Timer(_typingTimeout, () {
        unawaited(stopTyping(conversationId, userId));
      });
    } catch (e) {
      logInfo('Error starting typing indicator: $e');
    }
  }

  Future<void> stopTyping(String conversationId, String userId) async {
    _typingTimers.remove(conversationId)?.cancel();
    final users = _typingUsers[conversationId];
    if (users == null) return;

    users.remove(userId);
    if (users.isEmpty) {
      _typingUsers.remove(conversationId);
      _lastTypingSyncAt.remove(conversationId);
    }
    _notifyTypingUpdate(conversationId);
  }

  Set<String> getTypingUsers(String conversationId) {
    return _typingUsers[conversationId] ?? const <String>{};
  }

  Stream<Set<String>> getTypingStream(String conversationId) {
    _ensureSseSubscription();

    if (!_typingStreams.containsKey(conversationId)) {
      late final StreamController<Set<String>> controller;
      controller = StreamController<Set<String>>.broadcast(
        onListen: () {
          _streamListenersCount[conversationId] =
              (_streamListenersCount[conversationId] ?? 0) + 1;
          _notifyTypingUpdate(conversationId);
        },
        onCancel: () {
          final remaining = (_streamListenersCount[conversationId] ?? 1) - 1;
          if (remaining <= 0) {
            _streamListenersCount.remove(conversationId);
          } else {
            _streamListenersCount[conversationId] = remaining;
          }
        },
      );
      _typingStreams[conversationId] = controller;
    }
    return _typingStreams[conversationId]!.stream;
  }

  Future<void> _sendTyping(String conversationId) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;
    await _dio.post(
      '/chat/conversations/$conversationId/typing',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  void _ensureSseSubscription() {
    if (_sseSubscription != null || _isDisposed) return;
    SseManager.instance.start();
    _sseSubscription = SseManager.instance.events.listen(
      (event) {
        if (event['type'] != 'typing') return;
        final data = event['data'];
        if (data is! Map) return;

        final conversationId = data['conversation_id']?.toString() ?? '';
        final userId = data['user_id']?.toString() ?? '';
        if (conversationId.isEmpty || userId.isEmpty) return;

        _typingUsers[conversationId] ??= {};
        _typingUsers[conversationId]!.add(userId);
        _notifyTypingUpdate(conversationId);

        final key = '$conversationId:$userId';
        _typingTimers[key]?.cancel();
        _typingTimers[key] = Timer(_typingTimeout, () {
          _typingUsers[conversationId]?.remove(userId);
          if (_typingUsers[conversationId]?.isEmpty ?? false) {
            _typingUsers.remove(conversationId);
          }
          _notifyTypingUpdate(conversationId);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        logInfo('TypingService SSE error: $error');
      },
    );
  }

  void _notifyTypingUpdate(String conversationId) {
    final controller = _typingStreams[conversationId];
    if (controller == null || controller.isClosed) return;
    controller.add(Set<String>.from(_typingUsers[conversationId] ?? const {}));
  }

  void dispose() {
    _isDisposed = true;
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingUsers.clear();
    _lastTypingSyncAt.clear();
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;
    for (final controller in _typingStreams.values) {
      controller.close();
    }
    _typingStreams.clear();
    _streamListenersCount.clear();
  }
}

class TypingIndicator {
  final String userId;
  final String userName;
  final String userAvatar;
  final DateTime startedAt;

  TypingIndicator({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.startedAt,
  });

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      userId: json['user_id'],
      userName: json['user_name'] ?? 'کاربر ناشناس',
      userAvatar: json['user_avatar'] ?? '',
      startedAt: DateTime.parse(json['started_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'started_at': startedAt.toIso8601String(),
    };
  }
}
