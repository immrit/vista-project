// lib/features/chat/services/user_moderation_service.dart
//
// سرویس مدیریت مسدودیت و گزارش کاربران
//
// ویژگی‌ها:
// ✅ مسدود/رفع مسدودیت کاربر
// ✅ گزارش کاربر با دلایل مختلف
// ✅ بررسی وضعیت مسدودیت
// ✅ کش هوشمند برای عملکرد بهتر
// ✅ Error handling حرفه‌ای
//

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/const.dart';
import '../../../security/logging_utility.dart';

/// دلایل مختلف گزارش کاربر
enum ModerationReason {
  inappropriateContent('محتوای نامناسب'),
  harassment('آزار و اذیت'),
  spam('اسپم'),
  impersonation('جعل هویت'),
  scam('کلاهبرداری'),
  hateSpeech('سخنان نفرت‌انگیز'),
  violence('خشونت'),
  other('سایر موارد');

  final String persianLabel;
  const ModerationReason(this.persianLabel);
}

/// نتیجه عملیات مدیریتی
class ModerationResult {
  final bool success;
  final String? error;
  final String? message;

  const ModerationResult({
    required this.success,
    this.error,
    this.message,
  });

  factory ModerationResult.success([String? message]) {
    return ModerationResult(
      success: true,
      message: message,
    );
  }

  factory ModerationResult.failure(String error) {
    return ModerationResult(
      success: false,
      error: error,
    );
  }
}

/// وضعیت مسدودیت کاربر
class BlockStatus {
  final bool isBlocked;
  final bool isBlockedBy;
  final DateTime? blockedAt;
  final DateTime? blockedByAt;

  const BlockStatus({
    required this.isBlocked,
    required this.isBlockedBy,
    this.blockedAt,
    this.blockedByAt,
  });

  bool get hasAnyBlock => isBlocked || isBlockedBy;
  bool get canSendMessage => !hasAnyBlock;

  factory BlockStatus.noBlock() {
    return const BlockStatus(
      isBlocked: false,
      isBlockedBy: false,
    );
  }
}

/// سرویس مدیریت مسدودیت و گزارش
class UserModerationService {
  final SupabaseClient _supabase = supabase;

  // کش برای وضعیت مسدودیت (5 دقیقه)
  final Map<String, ({BlockStatus status, DateTime cachedAt})> _blockCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// مسدود کردن کاربر
  ///
  /// [userId] - شناسه کاربر مورد نظر برای مسدود کردن
  ///
  /// Returns: نتیجه عملیات
  Future<ModerationResult> blockUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return ModerationResult.failure('کاربر وارد نشده است');
      }

      // جلوگیری از مسدود کردن خودت
      if (currentUserId == userId) {
        return ModerationResult.failure('نمی‌توانید خودتان را مسدود کنید');
      }

      logInfo('🚫 Blocking user: $userId by $currentUserId');

      // بررسی وجود رکورد قبلی
      final existingRecord = await _supabase
          .from('blocked_users')
          .select()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      if (existingRecord != null) {
        logInfo('⚠️ User already blocked');
        return ModerationResult.success('کاربر قبلاً مسدود شده است');
      }

      // ایجاد رکورد مسدودیت
      await _supabase.from('blocked_users').insert({
        'user_id': currentUserId,
        'blocked_user_id': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // پاک کردن کش
      _invalidateCache(userId);

      logInfo('✅ User blocked successfully');
      return ModerationResult.success('کاربر با موفقیت مسدود شد');
    } catch (e, stackTrace) {
      logInfo('❌ Error blocking user: $e\n$stackTrace');
      return ModerationResult.failure(
          'خطا در مسدود کردن کاربر: ${e.toString()}');
    }
  }

  /// رفع مسدودیت کاربر
  ///
  /// [userId] - شناسه کاربر مورد نظر برای رفع مسدودیت
  ///
  /// Returns: نتیجه عملیات
  Future<ModerationResult> unblockUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return ModerationResult.failure('کاربر وارد نشده است');
      }

      logInfo('✅ Unblocking user: $userId by $currentUserId');

      // حذف رکورد مسدودیت
      final result = await _supabase
          .from('blocked_users')
          .delete()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .select();

      if (result.isEmpty) {
        logInfo('⚠️ No block record found');
        return ModerationResult.success('کاربر قبلاً مسدود نبوده است');
      }

      // پاک کردن کش
      _invalidateCache(userId);

      logInfo('✅ User unblocked successfully');
      return ModerationResult.success('مسدودیت کاربر با موفقیت برداشته شد');
    } catch (e, stackTrace) {
      logInfo('❌ Error unblocking user: $e\n$stackTrace');
      return ModerationResult.failure('خطا در رفع مسدودیت: ${e.toString()}');
    }
  }

  /// گزارش کاربر
  ///
  /// [userId] - شناسه کاربر مورد گزارش
  /// [reason] - دلیل گزارش
  /// [additionalInfo] - توضیحات اضافی (اختیاری)
  ///
  /// Returns: نتیجه عملیات
  Future<ModerationResult> reportUser({
    required String userId,
    required ModerationReason reason,
    String? additionalInfo,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return ModerationResult.failure('کاربر وارد نشده است');
      }

      // جلوگیری از گزارش خودت
      if (currentUserId == userId) {
        return ModerationResult.failure('نمی‌توانید خودتان را گزارش کنید');
      }

      logInfo('📢 Reporting user: $userId by $currentUserId');
      logInfo('   Reason: ${reason.name} - ${reason.persianLabel}');

      // ثبت گزارش در دیتابیس
      await _supabase.from('user_reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': userId,
        'reason': reason.name,
        'reason_text': reason.persianLabel,
        'additional_info': additionalInfo,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending', // pending, reviewed, dismissed, actioned
      });

      logInfo('✅ User reported successfully');
      return ModerationResult.success('گزارش شما با موفقیت ثبت شد');
    } catch (e, stackTrace) {
      logInfo('❌ Error reporting user: $e\n$stackTrace');
      return ModerationResult.failure('خطا در ثبت گزارش: ${e.toString()}');
    }
  }

  /// بررسی وضعیت مسدودیت کاربر
  ///
  /// [userId] - شناسه کاربر مورد نظر
  /// [useCache] - استفاده از کش (پیش‌فرض: true)
  ///
  /// Returns: وضعیت مسدودیت
  Future<BlockStatus> getBlockStatus(String userId,
      {bool useCache = true}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return BlockStatus.noBlock();
      }

      // بررسی کش
      if (useCache && _blockCache.containsKey(userId)) {
        final cached = _blockCache[userId]!;
        final age = DateTime.now().difference(cached.cachedAt);

        if (age < _cacheDuration) {
          // ✅ حذف لاگ cache hit برای بهبود performance
          return cached.status;
        } else {
          // کش منقضی شده
          _blockCache.remove(userId);
        }
      }

      // ✅ حذف لاگ info برای بهبود performance - فقط در حالت debug
      assert(() {
        logInfo('🔍 Checking block status for user: $userId');
        return true;
      }());

      // بررسی اینکه آیا کاربر فعلی این کاربر را مسدود کرده
      final iBlockedUser = await _supabase
          .from('blocked_users')
          .select('created_at')
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      // بررسی اینکه آیا این کاربر، کاربر فعلی را مسدود کرده
      final userBlockedMe = await _supabase
          .from('blocked_users')
          .select('created_at')
          .eq('user_id', userId)
          .eq('blocked_user_id', currentUserId)
          .maybeSingle();

      final status = BlockStatus(
        isBlocked: iBlockedUser != null,
        isBlockedBy: userBlockedMe != null,
        blockedAt: iBlockedUser != null
            ? DateTime.parse(iBlockedUser['created_at'] as String)
            : null,
        blockedByAt: userBlockedMe != null
            ? DateTime.parse(userBlockedMe['created_at'] as String)
            : null,
      );

      // ذخیره در کش
      _blockCache[userId] = (status: status, cachedAt: DateTime.now());

      // ✅ حذف لاگ success برای بهبود performance - فقط در حالت debug لاگ می‌کنیم
      assert(() {
        logInfo(
            '✅ Block status: isBlocked=${status.isBlocked}, isBlockedBy=${status.isBlockedBy}');
        return true;
      }());
      return status;
    } catch (e, stackTrace) {
      // ✅ فقط لاگ error ها را نگه می‌داریم
      logInfo('❌ Error checking block status: $e\n$stackTrace');
      return BlockStatus.noBlock();
    }
  }

  /// بررسی ساده آیا کاربر مسدود شده است
  Future<bool> isUserBlocked(String userId) async {
    final status = await getBlockStatus(userId);
    return status.isBlocked;
  }

  /// بررسی ساده آیا کاربر فعلی مسدود شده است
  Future<bool> isCurrentUserBlocked(String userId) async {
    final status = await getBlockStatus(userId);
    return status.isBlockedBy;
  }

  /// پاک کردن کش برای یک کاربر خاص
  void _invalidateCache(String userId) {
    _blockCache.remove(userId);
    logInfo('🗑️ Cache invalidated for user: $userId');
  }

  /// پاک کردن کل کش
  void clearCache() {
    _blockCache.clear();
    logInfo('🗑️ All block cache cleared');
  }

  /// دریافت لیست کاربران مسدود شده
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final result = await _supabase
          .from('blocked_users')
          .select('blocked_user_id, created_at')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      logInfo('❌ Error fetching blocked users: $e');
      return [];
    }
  }

  /// دریافت تعداد کاربران مسدود شده
  Future<int> getBlockedUsersCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      final result = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('user_id', currentUserId);

      return result.length;
    } catch (e) {
      logInfo('❌ Error counting blocked users: $e');
      return 0;
    }
  }
}
