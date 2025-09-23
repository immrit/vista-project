import '../main.dart';
import '../model/conversation_model.dart';
import 'profile_cache_manager.dart';

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
      print('⚠️ Error fetching other user in conversation $conversationId: $e');
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
    // If already has proper user info (and not placeholder), return as is
    final hasValidName = (conversation.otherUserName?.isNotEmpty == true) &&
        (conversation.otherUserName != 'کاربر ناشناس') &&
        (conversation.otherUserName != 'Unknown User');
    if (hasValidName) {
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

    return conversation.copyWith(
      otherUserName: enrichedName,
      otherUserAvatar: otherUserInfo['avatar_url'],
      otherUserId: otherUserInfo['user_id'],
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
      print('⚠️ Error preloading profiles: $e');
    }
  }

  /// آمار کشینگ
  Map<String, dynamic> getCacheStats() {
    return _cacheManager.getCacheStats();
  }
}
