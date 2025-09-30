import 'dart:async';
import '../main.dart';
import '../model/typing_indicator.dart';

/// سرویس مدیریت نشانگر تایپ کردن مانند توییتر
class TypingService {
  static final TypingService _instance = TypingService._internal();
  factory TypingService() => _instance;
  TypingService._internal();

  // تایمرها برای مدیریت typing indicators
  final Map<String, Timer> _typingTimers = {};

  // وضعیت تایپ کاربران در مکالمات مختلف
  final Map<String, Set<String>> _typingUsers = {};

  // Stream controllers برای real-time updates
  final Map<String, StreamController<Set<String>>> _typingStreams = {};

  /// شروع تایپ کردن در یک مکالمه
  Future<void> startTyping(String conversationId, String userId) async {
    try {
      // لغو تایمر قبلی اگر وجود دارد
      _typingTimers[conversationId]?.cancel();

      // اضافه کردن کاربر به لیست تایپ‌کنندگان
      _typingUsers[conversationId] ??= {};
      _typingUsers[conversationId]!.add(userId);

      // ارسال typing indicator به سرور (Supabase realtime)
      await supabase.from('conversations').update({
        'typing_users': _typingUsers[conversationId]!.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);

      // بروزرسانی stream محلی
      _notifyTypingUpdate(conversationId);

      // تنظیم تایمر برای حذف خودکار بعد از ۳ ثانیه
      _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
        stopTyping(conversationId, userId);
      });
    } catch (e) {
      print('⚠️ خطا در شروع تایپ: $e');
    }
  }

  /// متوقف کردن تایپ کردن در یک مکالمه
  Future<void> stopTyping(String conversationId, String userId) async {
    try {
      // لغو تایمر
      _typingTimers[conversationId]?.cancel();

      // حذف کاربر از لیست تایپ‌کنندگان
      _typingUsers[conversationId]?.remove(userId);

      // ارسال بروزرسانی به سرور
      if (_typingUsers[conversationId]?.isNotEmpty ?? false) {
        await supabase.from('conversations').update({
          'typing_users': _typingUsers[conversationId]!.toList(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', conversationId);
      } else {
        // اگر هیچ‌کس تایپ نمی‌کند، لیست را خالی کن
        await supabase.from('conversations').update({
          'typing_users': [],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', conversationId);
        _typingUsers.remove(conversationId);
      }

      // بروزرسانی stream محلی
      _notifyTypingUpdate(conversationId);
    } catch (e) {
      print('⚠️ خطا در متوقف کردن تایپ: $e');
    }
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
    _typingTimers.values.forEach((timer) => timer.cancel());
    _typingTimers.clear();
    _typingStreams.values.forEach((controller) => controller.close());
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

