// lib/services/user_presence_service.dart
//
// سرویس مدیریت وضعیت آنلاین کاربران - Real-time با Supabase
//
// ویژگی‌ها:
// ✅ Real-time presence با Supabase Realtime
// ✅ به‌روزرسانی خودکار وضعیت آنلاین
// ✅ مدیریت چرخه حیات برنامه
// ✅ کشینگ هوشمند وضعیت
// ✅ رعایت تنظیمات حریم خصوصی
//

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/time_utils.dart';

/// وضعیت‌های مختلف کاربر
enum UserPresenceStatus {
  online, // آنلاین (فعال در برنامه)
  away, // دور (برنامه در پس‌زمینه)
  offline, // آفلاین
  typing, // در حال تایپ
  recording, // در حال ضبط صدا
}

/// تنظیمات نمایش آخرین بازدید
enum LastSeenVisibility {
  everyone, // همه
  myContacts, // فقط مخاطبین
  nobody, // هیچکس
}

/// مدل وضعیت آنلاین کاربر
class UserPresenceState {
  final String userId;
  final UserPresenceStatus status;
  final DateTime? lastOnline;
  final LastSeenVisibility visibility;
  final bool canViewLastSeen; // آیا کاربر فعلی اجازه دیدن دارد
  final DateTime updatedAt;

  const UserPresenceState({
    required this.userId,
    required this.status,
    this.lastOnline,
    this.visibility = LastSeenVisibility.everyone,
    this.canViewLastSeen = true,
    required this.updatedAt,
  });

  bool get isOnline => status == UserPresenceStatus.online;
  bool get isTyping => status == UserPresenceStatus.typing;
  bool get isRecording => status == UserPresenceStatus.recording;
  bool get isAway => status == UserPresenceStatus.away;

  /// فرمت نمایش وضعیت به سبک تلگرام
  String get displayText {
    // اگر اجازه نمایش ندارد
    if (!canViewLastSeen) {
      return _getApproximateLastSeen();
    }

    switch (status) {
      case UserPresenceStatus.online:
        return 'آنلاین';
      case UserPresenceStatus.typing:
        return 'در حال نوشتن...';
      case UserPresenceStatus.recording:
        return 'در حال ضبط صدا...';
      case UserPresenceStatus.away:
      case UserPresenceStatus.offline:
        return _formatLastSeen();
    }
  }

  /// فرمت تقریبی برای حالت مخفی (مثل تلگرام)
  String _getApproximateLastSeen() {
    if (lastOnline == null) return 'آخرین بازدید: اخیراً';

    final now = DateTime.now();
    final diff = now.difference(lastOnline!);

    if (diff.inDays < 1) {
      return 'آخرین بازدید: اخیراً';
    } else if (diff.inDays < 7) {
      return 'آخرین بازدید: این هفته';
    } else if (diff.inDays < 30) {
      return 'آخرین بازدید: این ماه';
    } else {
      return 'آخرین بازدید: مدتی پیش';
    }
  }

  /// فرمت دقیق آخرین بازدید
  String _formatLastSeen() {
    return TimeUtils.formatUserPresence(lastOnline);
  }

  UserPresenceState copyWith({
    UserPresenceStatus? status,
    DateTime? lastOnline,
    LastSeenVisibility? visibility,
    bool? canViewLastSeen,
  }) {
    return UserPresenceState(
      userId: userId,
      status: status ?? this.status,
      lastOnline: lastOnline ?? this.lastOnline,
      visibility: visibility ?? this.visibility,
      canViewLastSeen: canViewLastSeen ?? this.canViewLastSeen,
      updatedAt: DateTime.now(),
    );
  }
}

/// سرویس مرکزی مدیریت وضعیت آنلاین
class UserPresenceService with WidgetsBindingObserver {
  static final UserPresenceService _instance = UserPresenceService._internal();
  factory UserPresenceService() => _instance;
  UserPresenceService._internal();

  final _supabase = Supabase.instance.client;

  // کشینگ وضعیت کاربران
  final Map<String, UserPresenceState> _presenceCache = {};
  final Map<String, StreamController<UserPresenceState>> _presenceStreams = {};

  // Subscription‌های فعال
  final Map<String, RealtimeChannel> _userChannels = {};

  // تایمرها
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;

  // وضعیت سرویس
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _currentUserId;

  // تنظیمات
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _onlineThreshold = Duration(minutes: 2);
  static const Duration _cacheCleanupInterval = Duration(minutes: 5);

  /// راه‌اندازی سرویس
  Future<void> initialize() async {
    if (_isInitialized) return;

    _currentUserId = _supabase.auth.currentUser?.id;
    if (_currentUserId == null) {
      debugPrint('⚠️ UserPresenceService: کاربر وارد نشده');
      return;
    }

    // ثبت observer برای چرخه حیات
    WidgetsBinding.instance.addObserver(this);

    // شروع heartbeat
    _startHeartbeat();

    // شروع پاکسازی دوره‌ای کش
    _startCacheCleanup();

    // به‌روزرسانی اولیه وضعیت
    await _updateMyPresence(UserPresenceStatus.online);

    _isInitialized = true;
    debugPrint('✅ UserPresenceService initialized');
  }

  /// اتصال به کانال Presence یک کاربر خاص
  Stream<UserPresenceState> watchUserPresence(String userId) {
    // اگر استریم وجود دارد، برگردان
    if (_presenceStreams.containsKey(userId)) {
      return _presenceStreams[userId]!.stream;
    }

    // ایجاد استریم جدید
    final controller = StreamController<UserPresenceState>.broadcast(
      onListen: () => _subscribeToUser(userId),
      onCancel: () => _unsubscribeFromUser(userId),
    );

    _presenceStreams[userId] = controller;

    // دریافت وضعیت اولیه
    _fetchInitialPresence(userId);

    return controller.stream;
  }

  /// دریافت وضعیت اولیه کاربر
  Future<void> _fetchInitialPresence(String userId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      // دریافت پروفایل و تنظیمات
      final responses = await Future.wait([
        _supabase
            .from('profiles')
            .select('is_online, last_online, last_seen_status')
            .eq('id', userId)
            .maybeSingle(),
        _supabase
            .from('user_settings')
            .select('last_seen_visibility')
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      final profileData = responses[0];
      final settingsData = responses[1];

      if (profileData == null) return;

      // بررسی اجازه نمایش
      final visibility = _parseVisibility(
        settingsData?['last_seen_visibility'] as String? ?? 'everyone',
      );
      final canView = await _checkCanViewLastSeen(userId, visibility);

      // پارس وضعیت
      final isOnline = profileData['is_online'] as bool? ?? false;
      final lastOnlineStr = profileData['last_online'] as String?;
      final lastOnline = lastOnlineStr != null
          ? DateTime.parse(lastOnlineStr).toLocal()
          : null;

      // تعیین وضعیت واقعی
      UserPresenceStatus status;
      if (isOnline && lastOnline != null) {
        final diff = DateTime.now().difference(lastOnline);
        status = diff < _onlineThreshold
            ? UserPresenceStatus.online
            : UserPresenceStatus.offline;
      } else {
        status = UserPresenceStatus.offline;
      }

      final state = UserPresenceState(
        userId: userId,
        status: status,
        lastOnline: lastOnline,
        visibility: visibility,
        canViewLastSeen: canView,
        updatedAt: DateTime.now(),
      );

      _presenceCache[userId] = state;
      _presenceStreams[userId]?.add(state);
    } catch (e) {
      debugPrint('❌ Error fetching presence for $userId: $e');
    }
  }

  /// اشتراک در تغییرات وضعیت یک کاربر
  Future<void> _subscribeToUser(String userId) async {
    if (_userChannels.containsKey(userId)) return;

    // ✅ گوش دادن به هر دو جدول: profiles و user_settings
    final channel = _supabase
        .channel('presence:$userId')
        // تغییرات profiles (is_online, last_online)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) =>
              _handleProfileUpdate(userId, payload.newRecord),
        )
        // ✅ تغییرات user_settings (last_seen_visibility)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) =>
              _handleSettingsUpdate(userId, payload.newRecord),
        )
        .subscribe();

    _userChannels[userId] = channel;
    debugPrint('📡 Subscribed to presence & settings: $userId');
  }

  /// ✅ پردازش تغییرات تنظیمات حریم خصوصی
  Future<void> _handleSettingsUpdate(
      String userId, Map<String, dynamic> data) async {
    try {
      final cached = _presenceCache[userId];
      if (cached == null) {
        await _fetchInitialPresence(userId);
        return;
      }

      // خواندن visibility جدید
      final visibilityStr =
          data['last_seen_visibility'] as String? ?? 'everyone';
      final newVisibility = _parseVisibility(visibilityStr);

      // بررسی مجدد دسترسی با visibility جدید
      final canView = await _checkCanViewLastSeen(userId, newVisibility);

      final newState = UserPresenceState(
        userId: userId,
        status: cached.status,
        lastOnline: cached.lastOnline,
        visibility: newVisibility,
        canViewLastSeen: canView,
        updatedAt: DateTime.now(),
      );

      _presenceCache[userId] = newState;
      _presenceStreams[userId]?.add(newState);

      debugPrint(
          '🔐 Privacy settings updated: $userId -> $newVisibility (canView: $canView)');
    } catch (e) {
      debugPrint('❌ Error handling settings update: $e');
    }
  }

  /// لغو اشتراک از کاربر
  Future<void> _unsubscribeFromUser(String userId) async {
    final channel = _userChannels.remove(userId);
    if (channel != null) {
      await _supabase.removeChannel(channel);
      debugPrint('📴 Unsubscribed from presence: $userId');
    }

    _presenceStreams.remove(userId)?.close();
    _presenceCache.remove(userId);
  }

  /// پردازش به‌روزرسانی پروفایل
  Future<void> _handleProfileUpdate(
      String userId, Map<String, dynamic> data) async {
    try {
      final cached = _presenceCache[userId];
      if (cached == null) {
        await _fetchInitialPresence(userId);
        return;
      }

      final isOnline = data['is_online'] as bool? ?? false;
      final lastOnlineStr = data['last_online'] as String?;
      final lastOnline = lastOnlineStr != null
          ? DateTime.parse(lastOnlineStr).toLocal()
          : cached.lastOnline;

      // تعیین وضعیت
      UserPresenceStatus status;
      if (isOnline && lastOnline != null) {
        final diff = DateTime.now().difference(lastOnline);
        status = diff < _onlineThreshold
            ? UserPresenceStatus.online
            : UserPresenceStatus.offline;
      } else {
        status = UserPresenceStatus.offline;
      }

      final newState = cached.copyWith(
        status: status,
        lastOnline: lastOnline,
      );

      _presenceCache[userId] = newState;
      _presenceStreams[userId]?.add(newState);

      debugPrint('🔄 Presence updated: $userId -> $status');
    } catch (e) {
      debugPrint('❌ Error handling profile update: $e');
    }
  }

  /// بررسی اجازه نمایش آخرین بازدید
  Future<bool> _checkCanViewLastSeen(
    String userId,
    LastSeenVisibility visibility,
  ) async {
    if (visibility == LastSeenVisibility.everyone) return true;
    if (visibility == LastSeenVisibility.nobody) return false;

    // برای my_contacts باید فالو دوطرفه باشد
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    try {
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
      debugPrint('❌ Error checking follow status: $e');
      return false; // deny-by-default on error
    }
  }

  LastSeenVisibility _parseVisibility(String value) {
    switch (value) {
      case 'nobody':
        return LastSeenVisibility.nobody;
      case 'my_contacts':
        return LastSeenVisibility.myContacts;
      default:
        return LastSeenVisibility.everyone;
    }
  }

  /// به‌روزرسانی وضعیت کاربر فعلی
  Future<void> _updateMyPresence(UserPresenceStatus status) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase.from('profiles').update({
        'is_online': status == UserPresenceStatus.online,
        'last_online': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ My presence updated: $status');
    } catch (e) {
      debugPrint('❌ Error updating presence: $e');
    }
  }

  /// شروع heartbeat برای حفظ وضعیت آنلاین
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isDisposed) {
        _updateMyPresence(UserPresenceStatus.online);
      }
    });
  }

  /// شروع پاکسازی دوره‌ای کش
  void _startCacheCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupCache();
    });
  }

  /// پاکسازی کش
  void _cleanupCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _presenceCache.forEach((userId, state) {
      // اگر بیش از 10 دقیقه آپدیت نشده، حذف کن
      if (now.difference(state.updatedAt).inMinutes > 10) {
        keysToRemove.add(userId);
      }
    });

    for (final key in keysToRemove) {
      _presenceCache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned ${keysToRemove.length} cached presence states');
    }
  }

  /// تنظیم وضعیت تایپ
  Future<void> setTyping(String conversationId, bool isTyping) async {
    // این از طریق typing_provider مدیریت می‌شود
    // اینجا فقط برای آپدیت وضعیت نمایشی است
  }

  /// دریافت وضعیت کش شده
  UserPresenceState? getCachedPresence(String userId) {
    return _presenceCache[userId];
  }

  /// ✅ رفرش کردن وضعیت یک کاربر (برای استفاده بعد از تغییر تنظیمات)
  Future<void> refreshUserPresence(String userId) async {
    await _fetchInitialPresence(userId);
  }

  /// ✅ پاک کردن کش یک کاربر (برای force refresh)
  void invalidateCache(String userId) {
    _presenceCache.remove(userId);
    // اگر استریم فعال دارد، وضعیت جدید را دریافت کن
    if (_presenceStreams.containsKey(userId)) {
      _fetchInitialPresence(userId);
    }
  }

  /// ✅ پاک کردن همه کش‌ها
  void invalidateAllCaches() {
    final userIds = _presenceCache.keys.toList();
    _presenceCache.clear();

    // رفرش همه استریم‌های فعال
    for (final userId in userIds) {
      if (_presenceStreams.containsKey(userId)) {
        _fetchInitialPresence(userId);
      }
    }
  }

  /// مدیریت چرخه حیات برنامه
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _updateMyPresence(UserPresenceStatus.online);
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _updateMyPresence(UserPresenceStatus.away);
        _heartbeatTimer?.cancel();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateMyPresence(UserPresenceStatus.offline);
        _heartbeatTimer?.cancel();
        break;
    }
  }

  /// آزادسازی منابع
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // تنظیم آفلاین
    _updateMyPresence(UserPresenceStatus.offline);

    // لغو تایمرها
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();

    // بستن استریم‌ها
    for (final controller in _presenceStreams.values) {
      controller.close();
    }
    _presenceStreams.clear();

    // لغو subscription‌ها
    for (final channel in _userChannels.values) {
      _supabase.removeChannel(channel);
    }
    _userChannels.clear();

    // حذف observer
    WidgetsBinding.instance.removeObserver(this);

    _presenceCache.clear();
    _isInitialized = false;

    debugPrint('🔴 UserPresenceService disposed');
  }
}
