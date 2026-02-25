import '../security/logging_utility.dart';
import 'dart:async';
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
      'updated_at': DateTime.now().toIso8601String(),
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
      _typingStreams[conversationId] =
          StreamController<Set<String>>.broadcast();
    }
    return _typingStreams[conversationId]!.stream;
  }

  /// بروزرسانی stream محلی
  void _notifyTypingUpdate(String conversationId) {
    if (_typingStreams.containsKey(conversationId)) {
      _typingStreams[conversationId]!.add(_typingUsers[conversationId] ?? {});
    }
  }

  /// پاکسازی تایمرها و streamها
  void dispose() {
    for (var timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _lastTypingSyncAt.clear();
    _lastSyncedPayload.clear();
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
