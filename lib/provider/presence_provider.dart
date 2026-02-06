// lib/provider/presence_provider.dart
//
// پرووایدرهای وضعیت آنلاین - Real-time
//
// ویژگی‌ها:
// ✅ استریم Real-time وضعیت آنلاین
// ✅ کشینگ هوشمند
// ✅ رعایت تنظیمات حریم خصوصی
// ✅ پشتیبانی از تایپ و ضبط صدا
//

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_presence_service.dart';

final _supabase = Supabase.instance.client;

/// پرووایدر سرویس Presence
final presenceServiceProvider = Provider<UserPresenceService>((ref) {
  final service = UserPresenceService();

  // راه‌اندازی سرویس
  service.initialize();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// استریم وضعیت آنلاین یک کاربر
final userPresenceStreamProvider =
    StreamProvider.family.autoDispose<UserPresenceState, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.watchUserPresence(userId);
});

/// وضعیت کش شده یک کاربر (برای دسترسی سریع)
final cachedPresenceProvider =
    Provider.family<UserPresenceState?, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.getCachedPresence(userId);
});

/// آیا کاربر آنلاین است؟ (ساده شده)
final isUserOnlineProvider =
    Provider.family.autoDispose<bool, String>((ref, userId) {
  final presenceAsync = ref.watch(userPresenceStreamProvider(userId));
  return presenceAsync.maybeWhen(
    data: (state) => state.isOnline,
    orElse: () => false,
  );
});

/// متن وضعیت کاربر
final userStatusTextProvider =
    Provider.family.autoDispose<String, String>((ref, userId) {
  final presenceAsync = ref.watch(userPresenceStreamProvider(userId));
  return presenceAsync.maybeWhen(
    data: (state) => state.displayText,
    orElse: () => 'در حال بررسی...',
  );
});

/// وضعیت کامل آنلاین برای AppBar چت
class ChatHeaderPresenceState {
  final UserPresenceState? presence;
  final bool isTyping;
  final bool isRecording;
  final String? typingUserName;
  final bool isLoading;
  final String? error;

  const ChatHeaderPresenceState({
    this.presence,
    this.isTyping = false,
    this.isRecording = false,
    this.typingUserName,
    this.isLoading = false,
    this.error,
  });

  /// متن نمایشی برای AppBar
  String get displayText {
    if (isTyping) return 'در حال نوشتن...';
    if (isRecording) return 'در حال ضبط صدا...';
    if (isLoading) return 'در حال بررسی...';
    if (error != null) return 'نامشخص';
    return presence?.displayText ?? 'آفلاین';
  }

  /// وضعیت برای انیمیشن
  UserPresenceStatus get effectiveStatus {
    if (isTyping) return UserPresenceStatus.typing;
    if (isRecording) return UserPresenceStatus.recording;
    return presence?.status ?? UserPresenceStatus.offline;
  }

  bool get isOnline => presence?.isOnline ?? false;
}

/// پرووایدر ترکیبی برای هدر چت
final chatHeaderPresenceProvider = Provider.family.autoDispose<
    ChatHeaderPresenceState,
    ({String userId, String conversationId})>((ref, params) {
  // وضعیت آنلاین
  final presenceAsync = ref.watch(userPresenceStreamProvider(params.userId));

  // وضعیت تایپ (از typing_provider موجود)
  // اینجا فقط placeholder است - باید با typing_provider یکپارچه شود
  const isTyping = false;
  const isRecording = false;

  return presenceAsync.when(
    data: (presence) => ChatHeaderPresenceState(
      presence: presence,
      isTyping: isTyping,
      isRecording: isRecording,
    ),
    loading: () => const ChatHeaderPresenceState(isLoading: true),
    error: (e, _) => ChatHeaderPresenceState(error: e.toString()),
  );
});

/// پرووایدر برای آخرین بازدید با رعایت حریم خصوصی
final lastSeenProvider =
    FutureProvider.family<DateTime?, String>((ref, userId) async {
  final currentUserId = _supabase.auth.currentUser?.id;
  if (currentUserId == null) return null;

  try {
    // دریافت تنظیمات حریم خصوصی کاربر مقابل
    final settings = await _supabase
        .from('user_settings')
        .select('last_seen_visibility')
        .eq('user_id', userId)
        .maybeSingle();

    final visibility =
        settings?['last_seen_visibility'] as String? ?? 'everyone';

    // بررسی دسترسی
    if (visibility == 'nobody') return null;

    if (visibility == 'my_contacts') {
      // بررسی فالو دوطرفه
      final results = await Future.wait([
        _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUserId)
            .eq('following_id', userId)
            .maybeSingle(),
        _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', userId)
            .eq('following_id', currentUserId)
            .maybeSingle(),
      ]);

      if (results[0] == null || results[1] == null) return null;
    }

    // دریافت آخرین بازدید
    final profile = await _supabase
        .from('profiles')
        .select('last_online')
        .eq('id', userId)
        .maybeSingle();

    final lastOnlineStr = profile?['last_online'] as String?;
    return lastOnlineStr != null
        ? DateTime.parse(lastOnlineStr).toLocal()
        : null;
  } catch (e) {
    debugPrint('❌ Error getting last seen: $e');
    return null;
  }
});

/// آیا می‌توانیم آخرین بازدید را ببینیم؟
final canViewLastSeenProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final currentUserId = _supabase.auth.currentUser?.id;
  if (currentUserId == null) return false;

  try {
    final settings = await _supabase
        .from('user_settings')
        .select('last_seen_visibility')
        .eq('user_id', userId)
        .maybeSingle();

    final visibility =
        settings?['last_seen_visibility'] as String? ?? 'everyone';

    if (visibility == 'everyone') return true;
    if (visibility == 'nobody') return false;

    // بررسی فالو دوطرفه برای my_contacts
    final results = await Future.wait([
      _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle(),
      _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', currentUserId)
          .maybeSingle(),
    ]);

    return results[0] != null && results[1] != null;
  } catch (e) {
    debugPrint('❌ Error checking can view last seen: $e');
    return false; // deny-by-default on error
  }
});

/// مدیریت به‌روزرسانی وضعیت آنلاین کاربر فعلی
class CurrentUserPresenceNotifier extends StateNotifier<UserPresenceStatus> {
  Timer? _heartbeatTimer;

  CurrentUserPresenceNotifier(Ref ref) : super(UserPresenceStatus.online) {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateStatus();
    });
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'is_online': state == UserPresenceStatus.online,
        'last_online': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('❌ Error updating current user status: $e');
    }
  }

  void setOnline() {
    state = UserPresenceStatus.online;
    _updateStatus();
  }

  void setAway() {
    state = UserPresenceStatus.away;
    _updateStatus();
  }

  void setOffline() {
    state = UserPresenceStatus.offline;
    _heartbeatTimer?.cancel();
    _updateStatus();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    setOffline();
    super.dispose();
  }
}

final currentUserPresenceProvider =
    StateNotifierProvider<CurrentUserPresenceNotifier, UserPresenceStatus>(
        (ref) {
  return CurrentUserPresenceNotifier(ref);
});
