import '../security/logging_utility.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/const.dart';

/// سرویس مدیریت نشانگر تایپ کردن مانند شبکه
class TypingService {
  static final TypingService _instance = TypingService._internal();
  factory TypingService() => _instance;
  TypingService._internal();

  static const Duration _typingTimeout = Duration(seconds: 3);
  static const Duration _typingSyncThrottle = Duration(seconds: 1);

  // تایمرها برای مدیریت typing indicators
  final Map<String, Timer> _typingTimers = {};

  // وضعیت تایپ کاربران در مکالمات مختلف
  final Map<String, Set<String>> _typingUsers = {};

  // آخرین زمان sync برای throttle کردن write های سرور
  final Map<String, DateTime> _lastTypingSyncAt = {};

  // آخرین payload ارسال شده به سرور برای dedupe
  final Map<String, String> _lastSyncedPayload = {};

  // Stream controllers برای real-time updates
  final Map<String, StreamController<Set<String>>> _typingStreams = {};
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, int> _streamListenersCount = {};

  /// شروع تایپ کردن در یک مکالمه
  Future<void> startTyping(String conversationId, String userId) async {
    try {
      _typingTimers[conversationId]?.cancel();

      _typingUsers[conversationId] ??= {};
      final users = _typingUsers[conversationId]!;
      final wasTypingBefore = users.contains(userId);
      users.add(userId);

      _notifyTypingUpdate(conversationId);

      final now = DateTime.now();
      final lastSync = _lastTypingSyncAt[conversationId];
      final shouldThrottle = wasTypingBefore &&
          lastSync != null &&
          now.difference(lastSync) < _typingSyncThrottle;

      if (!shouldThrottle) {
        await _syncTypingUsers(conversationId, users);
        _lastTypingSyncAt[conversationId] = now;
      }

      _typingTimers[conversationId] = Timer(_typingTimeout, () {
        stopTyping(conversationId, userId);
      });
    } catch (e) {
      logInfo('Error starting typing indicator: $e');
    }
  }

  /// متوقف کردن تایپ کردن در یک مکالمه
  Future<void> stopTyping(String conversationId, String userId) async {
    try {
      _typingTimers.remove(conversationId)?.cancel();

      final users = _typingUsers[conversationId];
      if (users == null) return;

      users.remove(userId);

      if (users.isNotEmpty) {
        await _syncTypingUsers(conversationId, users);
        _lastTypingSyncAt[conversationId] = DateTime.now();
      } else {
        await _syncTypingUsers(conversationId, const <String>{});
        _typingUsers.remove(conversationId);
        _lastTypingSyncAt.remove(conversationId);
        _lastSyncedPayload.remove(conversationId);
      }

      _notifyTypingUpdate(conversationId);
    } catch (e) {
      logInfo('Error stopping typing indicator: $e');
    }
  }

  Future<void> _syncTypingUsers(
    String conversationId,
    Set<String> typingUsers,
  ) async {
    final payload = typingUsers.toList()..sort();
    final payloadKey = payload.join(',');

    if (_lastSyncedPayload[conversationId] == payloadKey) {
      return;
    }

    await supabase.from('conversations').update({
      'typing_users': payload,
    }).eq('id', conversationId);

    _lastSyncedPayload[conversationId] = payloadKey;
  }

  /// دریافت کاربران در حال تایپ در یک مکالمه
  Set<String> getTypingUsers(String conversationId) {
    return _typingUsers[conversationId] ?? {};
  }

  /// دریافت stream تایپ کردن برای یک مکالمه
  Stream<Set<String>> getTypingStream(String conversationId) {
    if (!_typingStreams.containsKey(conversationId)) {
      late final StreamController<Set<String>> controller;
      controller = StreamController<Set<String>>.broadcast(
        onListen: () {
          _streamListenersCount[conversationId] =
              (_streamListenersCount[conversationId] ?? 0) + 1;
          _subscribeToConversationTyping(conversationId);
          _notifyTypingUpdate(conversationId);
          if (!_typingUsers.containsKey(conversationId)) {
            unawaited(_fetchInitialTypingUsers(conversationId));
          }
        },
        onCancel: () async {
          final listeners = (_streamListenersCount[conversationId] ?? 1) - 1;
          if (listeners <= 0) {
            _streamListenersCount.remove(conversationId);
            await _unsubscribeFromConversationTyping(conversationId);
          } else {
            _streamListenersCount[conversationId] = listeners;
          }
        },
      );
      _typingStreams[conversationId] = controller;
    }
    return _typingStreams[conversationId]!.stream;
  }

  Future<void> _fetchInitialTypingUsers(String conversationId) async {
    try {
      final response = await supabase
          .from('conversations')
          .select('typing_users')
          .eq('id', conversationId)
          .maybeSingle();
      final typingUsers = _normalizeTypingUsers(response?['typing_users']);
      if (typingUsers.isEmpty) {
        _typingUsers.remove(conversationId);
      } else {
        _typingUsers[conversationId] = typingUsers;
      }
      _notifyTypingUpdate(conversationId);
    } catch (e) {
      logInfo('Error fetching initial typing users: $e');
    }
  }

  void _subscribeToConversationTyping(String conversationId) {
    if (_typingChannels.containsKey(conversationId)) return;

    final channel = supabase
        .channel('typing_users:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: conversationId,
          ),
          callback: (payload) {
            final typingUsers =
                _normalizeTypingUsers(payload.newRecord['typing_users']);
            if (typingUsers.isEmpty) {
              _typingUsers.remove(conversationId);
            } else {
              _typingUsers[conversationId] = typingUsers;
            }
            _notifyTypingUpdate(conversationId);
          },
        )
        .subscribe();

    _typingChannels[conversationId] = channel;
  }

  Future<void> _unsubscribeFromConversationTyping(String conversationId) async {
    final channel = _typingChannels.remove(conversationId);
    if (channel == null) return;
    await supabase.removeChannel(channel);
  }

  Set<String> _normalizeTypingUsers(dynamic rawValue) {
    if (rawValue == null) return <String>{};

    if (rawValue is List) {
      return rawValue
          .map((item) => item?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    // Handle Postgres array/string payloads from realtime like:
    // "{id1,id2}" or "[\"id1\",\"id2\"]"
    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) return <String>{};

      String body = trimmed;
      if (body.startsWith('{') && body.endsWith('}')) {
        body = body.substring(1, body.length - 1);
      } else if (body.startsWith('[') && body.endsWith(']')) {
        body = body.substring(1, body.length - 1);
      }
      if (body.trim().isEmpty) return <String>{};

      return body
          .split(',')
          .map((part) => part.replaceAll('"', '').trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    return <String>{};
  }

  /// بروزرسانی stream محلی
  void _notifyTypingUpdate(String conversationId) {
    final controller = _typingStreams[conversationId];
    if (controller == null || controller.isClosed) return;
    final users = Set<String>.from(_typingUsers[conversationId] ?? {});
    controller.add(users);
  }

  /// پاکسازی تایمرها و streamها
  void dispose() {
    for (var timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _lastTypingSyncAt.clear();
    _lastSyncedPayload.clear();
    for (final channel in _typingChannels.values) {
      unawaited(supabase.removeChannel(channel));
    }
    _typingChannels.clear();
    _streamListenersCount.clear();
    for (var controller in _typingStreams.values) {
      controller.close();
    }
    _typingStreams.clear();
    _typingUsers.clear();
  }
}

/// مدل نشانگر تایپ کردن
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
