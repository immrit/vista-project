import 'dart:async';
import 'dart:collection';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// سیستم لاگ گذاری
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

/// نوع به‌روزرسانی پروفایل
enum ProfileUpdateType {
  created,
  updated,
  deleted,
  avatarChanged,
  statusChanged,
}

/// داده ساختار پروفایل
class ProfileData {
  final String userId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isOnline;
  final DateTime? lastOnline;
  final DateTime cachedAt;

  ProfileData({
    required this.userId,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.isOnline,
    this.lastOnline,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  String get displayName => username?.trim().isNotEmpty == true
      ? username!
      : fullName?.trim().isNotEmpty == true
          ? fullName!
          : 'کاربر ناشناس';

  String? get avatar => avatarUrl?.trim().isNotEmpty == true ? avatarUrl : null;

  ProfileData copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastOnline,
  }) {
    return ProfileData(
      userId: userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastOnline: lastOnline ?? this.lastOnline,
      cachedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'isOnline': isOnline,
        'lastOnline': lastOnline?.toIso8601String(),
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        userId: json['userId'],
        username: json['username'],
        fullName: json['fullName'],
        avatarUrl: json['avatarUrl'],
        isOnline: json['isOnline'],
        lastOnline: json['lastOnline'] != null
            ? DateTime.parse(json['lastOnline'])
            : null,
        cachedAt: DateTime.parse(json['cachedAt']),
      );
}

/// رویداد به‌روزرسانی پروفایل
class ProfileUpdateEvent {
  final String userId;
  final ProfileUpdateType type;
  final ProfileData? oldProfile;
  final ProfileData? newProfile;

  ProfileUpdateEvent({
    required this.userId,
    required this.type,
    this.oldProfile,
    this.newProfile,
  });
}

/// سرویس مرکزی مدیریت پروفایل‌ها با کشینگ پیشرفته
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static final supabase = Supabase.instance.client;

  // کشینگ سه لایه: Memory + Persistent + Network
  final Map<String, ProfileData> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Completer<ProfileData?>> _pendingRequests = {};
  final Queue<String> _recentUserIds = Queue<String>();

  // تنظیمات کشینگ
  static const Duration _cacheValidityDuration = Duration(hours: 6);
  static const int _maxMemoryCacheSize = 200;
  static const int _maxBatchSize = 50;
  static const Duration _batchDelay = Duration(milliseconds: 30);

  // Stream برای real-time updates
  final StreamController<ProfileUpdateEvent> _profileUpdates =
      StreamController.broadcast();

  Stream<ProfileUpdateEvent> get profileUpdates => _profileUpdates.stream;

  // Real-time subscription
  StreamSubscription? _profilesSubscription;

  // کنترل غیرفعال کردن real-time updates
  bool _disableRealtimeUpdates = false;

  /// دسترسی سریع به پروفایل کش‌شده
  ProfileData? getCachedProfile(String userId) {
    // پاکسازی کش منقضی‌شده
    _cleanupExpiredCache();

    // اضافه کردن به لیست اخیر
    _recentUserIds.remove(userId);
    _recentUserIds.addFirst(userId);
    if (_recentUserIds.length > _maxMemoryCacheSize) {
      _recentUserIds.removeLast();
    }

    return _memoryCache[userId];
  }

  /// دریافت پروفایل با باتچینگ هوشمند
  Future<ProfileData?> getProfile(String userId) async {
    // 1. بررسی کش حافظه
    final cached = getCachedProfile(userId);
    if (cached != null && _isCacheValid(userId)) {
      return cached;
    }

    // 2. بررسی درخواست‌های در حال انتظار
    if (_pendingRequests.containsKey(userId)) {
      return _pendingRequests[userId]!.future;
    }

    // 3. ایجاد درخواست جدید
    final completer = Completer<ProfileData?>();
    _pendingRequests[userId] = completer;

    try {
      // باتچ با درخواست‌های دیگر
      final batch = await _collectBatch(userId);
      final results = await _fetchBatchProfiles(batch);

      // پردازش نتایج
      for (final entry in results.entries) {
        final uid = entry.key;
        final profile = entry.value;

        if (profile != null) {
          _memoryCache[uid] = profile;
          _cacheTimestamps[uid] = DateTime.now();
        }

        // تکمیل درخواست
        final pendingCompleter = _pendingRequests.remove(uid);
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.complete(profile);
        }
      }

      // اعلام به‌روزرسانی
      if (results.isNotEmpty) {
        _broadcastUpdate(ProfileUpdateEvent(
          userId: userId,
          type: ProfileUpdateType.updated,
          newProfile: results[userId],
        ));
      }

      return completer.future;
    } catch (e) {
      logger.e('⚠️ خطا در دریافت پروفایل $userId: $e');
      _pendingRequests.remove(userId);
      completer.complete(null);
      return null;
    }
  }

  /// دریافت چندین پروفایل به صورت باتچ
  Future<Map<String, ProfileData?>> getMultipleProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    // جداسازی IDهای کش‌شده و غیرکش‌شده
    final cachedProfiles = <String, ProfileData>{};
    final uncachedIds = <String>[];

    for (final userId in userIds) {
      final cached = getCachedProfile(userId);
      if (cached != null && _isCacheValid(userId)) {
        cachedProfiles[userId] = cached;
      } else {
        uncachedIds.add(userId);
      }
    }

    // دریافت پروفایل‌های غیرکش‌شده
    final fetchedProfiles = await _fetchBatchProfiles(uncachedIds);

    // ترکیب نتایج
    final result = <String, ProfileData?>{...cachedProfiles};
    result.addAll(fetchedProfiles);

    return result;
  }

  /// پیش‌بارگذاری پروفایل‌ها برای عملکرد بهتر
  Future<void> preloadProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return;

    // فیلتر IDهایی که نیاز به پیش‌بارگذاری دارند
    final uncachedIds = userIds.where((userId) {
      final cached = getCachedProfile(userId);
      return cached == null || !_isCacheValid(userId);
    }).toList();

    if (uncachedIds.isNotEmpty) {
      await getMultipleProfiles(uncachedIds);
    }
  }

  /// جمع‌آوری باتچ از درخواست‌های در حال انتظار
  Future<List<String>> _collectBatch(String initialUserId) async {
    final batch = <String>[initialUserId];

    // انتظار برای جمع‌آوری درخواست‌های بیشتر
    await Future.delayed(_batchDelay);

    // اضافه کردن درخواست‌های دیگر تا سقف اندازه باتچ
    final pendingIds = _pendingRequests.keys.toList();
    for (final userId in pendingIds) {
      if (batch.length >= _maxBatchSize) break;
      if (!batch.contains(userId)) {
        batch.add(userId);
      }
    }

    return batch;
  }

  /// دریافت باتچ پروفایل‌ها از سرور
  Future<Map<String, ProfileData?>> _fetchBatchProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      logger.d('دریافت باتچ پروفایل‌ها برای ${userIds.length} کاربر');

      final response = await supabase
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_online, last_online')
          .inFilter('id', userIds)
          .timeout(const Duration(seconds: 30));

      final results = <String, ProfileData?>{};

      for (final userId in userIds) {
        final profileData = response.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['id'] == userId,
              orElse: () => null,
            );

        if (profileData != null) {
          results[userId] = ProfileData(
            userId: userId,
            username: profileData['username'] as String?,
            fullName: profileData['full_name'] as String?,
            avatarUrl: profileData['avatar_url'] as String?,
            isOnline: profileData['is_online'] as bool?,
            lastOnline: profileData['last_online'] != null
                ? DateTime.parse(profileData['last_online'])
                : null,
          );
        } else {
          results[userId] = null;
        }
      }

      logger.d('باتچ پروفایل‌ها دریافت شد: ${results.length} مورد');
      return results;
    } catch (e) {
      logger.e('⚠️ خطا در دریافت باتچ پروفایل‌ها: $e');
      return {for (final userId in userIds) userId: null};
    }
  }

  /// بررسی اعتبار کش
  bool _isCacheValid(String userId) {
    final timestamp = _cacheTimestamps[userId];
    return timestamp != null &&
        DateTime.now().difference(timestamp) <= _cacheValidityDuration;
  }

  /// پاکسازی کش منقضی‌شده
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheValidityDuration) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// به‌روزرسانی پروفایل از real-time
  void updateProfileFromRealtime(String userId, Map<String, dynamic> data) {
    final oldProfile = _memoryCache[userId];

    final newProfile = ProfileData(
      userId: userId,
      username: data['username'] as String? ?? oldProfile?.username,
      fullName: data['full_name'] as String? ?? oldProfile?.fullName,
      avatarUrl: data['avatar_url'] as String? ?? oldProfile?.avatarUrl,
      isOnline: data['is_online'] as bool? ?? oldProfile?.isOnline,
      lastOnline: data['last_online'] != null
          ? DateTime.parse(data['last_online'])
          : oldProfile?.lastOnline,
    );

    _memoryCache[userId] = newProfile;
    _cacheTimestamps[userId] = DateTime.now();

    // اعلام به‌روزرسانی
    _broadcastUpdate(ProfileUpdateEvent(
      userId: userId,
      type: ProfileUpdateType.updated,
      oldProfile: oldProfile,
      newProfile: newProfile,
    ));
  }

  /// اعلام به‌روزرسانی پروفایل
  void _broadcastUpdate(ProfileUpdateEvent event) {
    if (!_profileUpdates.isClosed) {
      _profileUpdates.add(event);
    }
  }

  /// تغییر وضعیت آنلاین کاربر
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await supabase.from('profiles').update({
        'is_online': isOnline,
        'last_online': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      // به‌روزرسانی کش محلی
      final cached = _memoryCache[userId];
      if (cached != null) {
        _memoryCache[userId] = cached.copyWith(
          isOnline: isOnline,
          lastOnline: isOnline ? null : DateTime.now(),
        );
        _cacheTimestamps[userId] = DateTime.now();
      }
    } catch (e) {
      logger.e('⚠️ خطا در به‌روزرسانی وضعیت آنلاین: $e');
    }
  }

  /// دریافت وضعیت آنلاین کاربر
  Future<bool> isUserOnline(String userId) async {
    final profile = await getProfile(userId);
    return profile?.isOnline ?? false;
  }

  /// دریافت زمان آخرین فعالیت کاربر
  Future<DateTime?> getUserLastOnline(String userId) async {
    final profile = await getProfile(userId);
    return profile?.lastOnline;
  }

  /// آمار کشینگ
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_profiles': _memoryCache.length,
      'pending_requests': _pendingRequests.length,
      'recent_users': _recentUserIds.length,
      'cache_hit_rate': _calculateHitRate(),
    };
  }

  double _calculateHitRate() {
    if (_recentUserIds.isEmpty) return 0.0;
    int hits = 0;
    for (final userId in _recentUserIds) {
      if (_memoryCache.containsKey(userId) && _isCacheValid(userId)) {
        hits++;
      }
    }
    return hits / _recentUserIds.length;
  }

  /// پاک کردن کش
  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _recentUserIds.clear();

    // لغو درخواست‌های در حال انتظار
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pendingRequests.clear();
  }

  /// شروع شنود تغییرات real-time پروفایل‌ها
  Future<void> startRealtimeUpdates() async {
    if (_profilesSubscription != null) return; // Already subscribed
    if (_disableRealtimeUpdates) {
      logger.w('⚠️ Real-time updates غیرفعال شده است');
      return;
    }

    try {
      // چک کردن اینکه آیا Supabase initialize شده یا نه
      try {
        Supabase
            .instance; // این خط اگر Supabase initialize نشده باشد، exception می‌دهد
      } catch (e) {
        logger.w('⚠️ Supabase initialize نشده، real-time updates شروع نمی‌شود');
        return;
      }

      // چک کردن اتصال به دیتابیس قبل از شروع stream
      try {
        await supabase.from('profiles').select().limit(1).timeout(
              const Duration(seconds: 2),
              onTimeout: () =>
                  throw TimeoutException('Database connection timeout'),
            );
      } catch (e) {
        logger.w(
            '⚠️ اتصال به دیتابیس در دسترس نیست، real-time updates غیرفعال می‌شود: $e');
        // غیرفعال کردن real-time updates برای جلوگیری از تلاش‌های مکرر
        _disableRealtimeUpdates = true;
        return;
      }

      _profilesSubscription = supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .timeout(const Duration(seconds: 30))
          .listen(
            (data) {
              for (final row in data) {
                final userId = row['id'] as String;
                updateProfileFromRealtime(userId, row);
              }
            },
            onError: (error) {
              // مدیریت خطاهای real-time بدون کرش
              if (error.toString().contains('RealtimeSubscribeException') ||
                  error.toString().contains('PostgrestException') ||
                  error.toString().contains('could not translate host name') ||
                  error.toString().contains('Database connection error')) {
                logger.w('⚠️ Real-time subscription error (handled): $error');
                // تلاش مجدد بعد از 10 ثانیه (کمتر تلاش کنیم)
                Future.delayed(const Duration(seconds: 10), () async {
                  if (_profilesSubscription == null &&
                      !_disableRealtimeUpdates) {
                    await startRealtimeUpdates();
                  }
                });
              } else {
                logger.e('خطا در دریافت real-time updates پروفایل: $error');
              }
            },
            onDone: () {
              logger.w(
                  'Real-time subscription closed, attempting to reconnect...');
              _profilesSubscription = null;
              // تلاش مجدد بعد از 15 ثانیه (کمتر تلاش کنیم)
              Future.delayed(const Duration(seconds: 15), () async {
                if (_profilesSubscription == null && !_disableRealtimeUpdates) {
                  await startRealtimeUpdates();
                }
              });
            },
          );

      logger.d('Real-time subscription برای پروفایل‌ها شروع شد');
    } catch (e) {
      logger.e('خطا در شروع real-time subscription: $e');
      // تلاش مجدد بعد از 30 ثانیه در صورت خطای کلی
      Future.delayed(const Duration(seconds: 30), () async {
        if (_profilesSubscription == null && !_disableRealtimeUpdates) {
          await startRealtimeUpdates();
        }
      });
    }
  }

  /// متوقف کردن شنود real-time
  void stopRealtimeUpdates() {
    _profilesSubscription?.cancel();
    _profilesSubscription = null;
    logger.d('Real-time subscription برای پروفایل‌ها متوقف شد');
  }

  /// فعال کردن مجدد real-time updates
  void enableRealtimeUpdates() {
    _disableRealtimeUpdates = false;
    logger.i('✅ Real-time updates فعال شد');
  }

  /// غیرفعال کردن real-time updates
  void disableRealtimeUpdates() {
    _disableRealtimeUpdates = true;
    stopRealtimeUpdates();
    logger.w('⚠️ Real-time updates غیرفعال شد');
  }

  /// پاکسازی منابع
  void dispose() {
    stopRealtimeUpdates();
    _profileUpdates.close();
    clearCache();
  }

  // متدهای قدیمی برای سازگاری

  /// دریافت پروفایل کاربر از جدول profiles (سازگار با API قدیمی)
  static Future<Map<String, dynamic>?> getProfileStatic(String userId) async {
    final profile = await _instance.getProfile(userId);
    return profile?.toJson();
  }

  /// ایجاد یا به‌روزرسانی پروفایل کاربر
  static Future<void> upsertProfile(Map<String, dynamic> updates) async {
    try {
      logger.d('شروع ذخیره‌سازی/بروزرسانی پروفایل با داده: $updates');

      // تبدیل کلیدها به فرمت snake_case برای پایگاه داده
      final payload = {
        ...updates,
        // اطمینان از وجود کلیدهای ضروری
        'id': updates['id'],
        'username': updates['username'],
        'full_name': updates['full_name'],
        'bio': updates['bio'] ?? '',
        'birth_date': updates['birth_date'] ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('profiles')
          .upsert(payload)
          .timeout(const Duration(seconds: 30));

      // به‌روزرسانی کش محلی
      if (updates['id'] != null) {
        _instance._memoryCache.remove(updates['id']);
        _instance._cacheTimestamps.remove(updates['id']);
      }

      logger.i('پروفایل با موفقیت ذخیره شد');
      return;
    } on Exception catch (e) {
      logger.e('خطای در ذخیره‌سازی پروفایل ${e.toString()}');

      // بررسی خطاهای رایج
      if (e.toString().contains('23505')) {
        throw 'نام کاربری قبلاً انتخاب شده است. لطفاً نام کاربری دیگری را امتحان کنید.';
      }

      throw 'خطا در ذخیره پروفایل: ${e.toString()}';
    }
  }

  /// بروزرسانی تصویر پروفایل
  static Future<void> updateAvatar(String userId, String avatarUrl) async {
    try {
      logger.d(
          'شروع بروزرسانی تصویر پروفایل برای کاربر: $userId با URL: $avatarUrl');

      await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId)
          .timeout(const Duration(seconds: 30));

      // به‌روزرسانی کش محلی
      _instance._memoryCache.remove(userId);
      _instance._cacheTimestamps.remove(userId);

      logger.i('تصویر پروفایل با موفقیت به‌روزرسانی شد');
      return;
    } catch (e) {
      logger.e('$e خطا در بروزرسانی تصویر پروفایل');
      throw 'خطا در به‌روزرسانی تصویر پروفایل: $e';
    }
  }

  /// بررسی کامل بودن پروفایل
  static Future<bool> isProfileComplete(String userId) async {
    try {
      logger.d('بررسی تکمیل بودن پروفایل برای کاربر: $userId');

      final profile = await _instance.getProfile(userId);
      final isComplete = profile != null &&
          profile.username != null &&
          profile.username!.isNotEmpty &&
          profile.fullName != null &&
          profile.fullName!.isNotEmpty;

      logger.d('نتیجه بررسی تکمیل پروفایل: $isComplete');
      return isComplete;
    } catch (e) {
      logger.e('$e خطا در بررسی تکمیل پروفایل');
      return false;
    }
  }
}
