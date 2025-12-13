import '../security/logging_utility.dart';
import '../main.dart';
import '../model/conversation_model.dart';
import 'profile_cache_manager.dart';
import '../DB/settings_cache_service.dart';

/// سرویس برای دریافت اطلاعات پروفایل کاربران با کشینگ مرکزی
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  final ProfileCacheManager _cacheManager = ProfileCacheManager();

  /// دسترسی سریع به پروفایل کش‌شده (Memory)
  Map<String, String?>? getCachedProfile(String userId) {
    return _cacheManager.getCachedProfile(userId);
  }

  /// دریافت اطلاعات پروفایل کاربر از کش مرکزی
  Future<Map<String, String?>?> getUserProfile(String userId) async {
    return _cacheManager.getProfile(userId);
  }

  /// دریافت اطلاعات کاربر دیگر در مکالمه (بدون join روی FK)
  Future<Map<String, String?>> getOtherUserInConversation(
      String conversationId, String currentUserId) async {
    try {
      // 1) ابتدا user_id طرف مقابل را از جدول conversation_participants می‌گیریم
      final otherParticipant = await supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', currentUserId)
          .limit(1)
          .maybeSingle();

      final otherUserId = otherParticipant?['user_id'] as String?;
      if (otherUserId == null) {
        return {
          'username': null,
          'avatar_url': null,
          'full_name': null,
          'user_id': null,
        };
      }

      // 2) پروفایل را از کش مرکزی دریافت کنیم
      final profile = await getUserProfile(otherUserId);
      return {
        'username': profile?['username'],
        'avatar_url': profile?['avatar_url'],
        'full_name': profile?['full_name'],
        'user_id': otherUserId,
      };
    } catch (e) {
      logInfo(
          '⚠️ Error fetching other user in conversation $conversationId: $e');
      return {
        'username': null,
        'avatar_url': null,
        'full_name': null,
        'user_id': null,
      };
    }
  }

  /// بهبود ConversationModel با اطلاعات کاربران
  Future<ConversationModel> enrichConversationWithUserData(
    ConversationModel conversation,
    String currentUserId,
  ) async {
    // ✅ اگر allowProfileZoom قبلاً set شده، نیازی به fetch مجدد نیست
    final needsEnrichment = conversation.allowProfileZoom == null ||
        (conversation.otherUserName?.isEmpty == true ||
            conversation.otherUserName == 'کاربر ناشناس' ||
            conversation.otherUserName == 'Unknown User');

    if (!needsEnrichment && conversation.allowProfileZoom != null) {
      return conversation;
    }

    // Get other user info
    final otherUserInfo =
        await getOtherUserInConversation(conversation.id, currentUserId);

    final enrichedName = (otherUserInfo['username']?.isNotEmpty == true)
        ? otherUserInfo['username']
        : (otherUserInfo['full_name']?.isNotEmpty == true
            ? otherUserInfo['full_name']
            : null);

    // ✅ دریافت allow_profile_zoom از settings cache
    bool? allowProfileZoom = conversation.allowProfileZoom;
    if (allowProfileZoom == null && otherUserInfo['user_id'] != null) {
      try {
        final settingsCache = SettingsCacheService();
        final userSettings = await settingsCache
            .getUserSettings(otherUserInfo['user_id'] as String);
        allowProfileZoom =
            (userSettings?['allow_profile_zoom'] as bool?) ?? true;
      } catch (e) {
        logInfo('⚠️ Error fetching allow_profile_zoom: $e');
        allowProfileZoom = true; // default to true on error
      }
    }

    // ✅ دریافت اطلاعات پروفایل کامل برای صفحه جزئیات چت
    String? bio = conversation.otherUserBio;
    DateTime? createdAt = conversation.otherUserCreatedAt;
    bool? isVerified = conversation.isVerified;
    bool? isBlocked = conversation.isBlocked;

    if (otherUserInfo['user_id'] != null) {
      final userId = otherUserInfo['user_id'] as String;

      // دریافت اطلاعات پروفایل از cache یا سرور (فقط اگر null است)
      if (bio == null || createdAt == null || isVerified == null) {
        try {
          final profile = await getUserProfile(userId);
          if (profile != null) {
            bio = bio ?? profile['bio'];
            if (createdAt == null) {
              final createdAtStr = profile['created_at'];
              if (createdAtStr != null) {
                try {
                  createdAt = DateTime.parse(createdAtStr);
                } catch (e) {
                  logInfo('⚠️ Error parsing created_at: $e');
                }
              }
            }
            isVerified =
                isVerified ?? (profile['is_verified'] as bool? ?? false);
          }
        } catch (e) {
          logInfo('⚠️ Error fetching profile details: $e');
        }
      }

      // دریافت وضعیت بلاک (فقط اگر null است)
      if (isBlocked == null) {
        try {
          final currentUserId = supabase.auth.currentUser?.id;
          if (currentUserId != null) {
            final blockResponse = await supabase
                .from('blocked_users')
                .select()
                .eq('user_id', currentUserId)
                .eq('blocked_user_id', userId)
                .maybeSingle();
            isBlocked = blockResponse != null;
          }
        } catch (e) {
          logInfo('⚠️ Error fetching block status: $e');
        }
      }
    }

    return conversation.copyWith(
      otherUserName: enrichedName,
      otherUserAvatar: otherUserInfo['avatar_url'],
      otherUserId: otherUserInfo['user_id'],
      allowProfileZoom: allowProfileZoom,
      otherUserBio: bio,
      otherUserCreatedAt: createdAt,
      isBlocked: isBlocked,
      isVerified: isVerified,
    );
  }

  /// دریافت stream بروزرسانی‌های پروفایل
  Stream<Map<String, Map<String, String?>>> get profileUpdates =>
      _cacheManager.profileUpdates;

  /// پاک کردن cache
  void clearCache() {
    _cacheManager.clearCache();
  }

  /// Pre-load profiles برای چندین کاربر (با batching)
  Future<void> preloadProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return;

    try {
      // کش مرکزی خودش batching انجام می‌ده
      await Future.wait(
        userIds.map((userId) => _cacheManager.getProfile(userId)),
      );
    } catch (e) {
      logInfo('⚠️ Error preloading profiles: $e');
    }
  }

  /// آمار کشینگ
  Map<String, dynamic> getCacheStats() {
    return _cacheManager.getCacheStats();
  }
}
