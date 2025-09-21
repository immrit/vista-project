import '../main.dart';
import '../model/conversation_model.dart';

/// سرویس برای دریافت اطلاعات پروفایل کاربران
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  // Cache برای اطلاعات کاربران
  final Map<String, Map<String, String?>> _userProfileCache = {};

  /// دریافت اطلاعات پروفایل کاربر
  Future<Map<String, String?>> getUserProfile(String userId) async {
    // Check cache first
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url, full_name')
          .eq('id', userId)
          .maybeSingle();

      final profile = {
        'username': response?['username'] as String?,
        'avatar_url': response?['avatar_url'] as String?,
        'full_name': response?['full_name'] as String?,
      };

      // Cache the result
      _userProfileCache[userId] = profile;
      return profile;
    } catch (e) {
      print('⚠️ Error fetching user profile for $userId: $e');

      // Return default profile
      final defaultProfile = {
        'username': 'کاربر ${userId.substring(0, 8)}',
        'avatar_url': null,
        'full_name': null,
      };

      _userProfileCache[userId] = defaultProfile;
      return defaultProfile;
    }
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
          'username': 'کاربر ناشناس',
          'avatar_url': null,
          'full_name': null,
          'user_id': null,
        };
      }

      // 2) سپس پروفایل را مستقیماً از جدول profiles می‌خوانیم
      final profile = await getUserProfile(otherUserId);
      return {
        ...profile,
        'user_id': otherUserId,
      };
    } catch (e) {
      print('⚠️ Error fetching other user in conversation $conversationId: $e');
      return {
        'username': 'کاربر ناشناس',
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
    // If already has user info, return as is
    if (conversation.otherUserName?.isNotEmpty == true &&
        conversation.otherUserName != 'کاربر ناشناس') {
      return conversation;
    }

    // Get other user info
    final otherUserInfo =
        await getOtherUserInConversation(conversation.id, currentUserId);

    return conversation.copyWith(
      otherUserName: otherUserInfo['username'] ??
          otherUserInfo['full_name'] ??
          'کاربر ناشناس',
      otherUserAvatar: otherUserInfo['avatar_url'],
      otherUserId: otherUserInfo['user_id'],
    );
  }

  /// پاک کردن cache
  void clearCache() {
    _userProfileCache.clear();
  }

  /// Pre-load profiles برای چندین کاربر
  Future<void> preloadProfiles(List<String> userIds) async {
    final uncachedUserIds =
        userIds.where((id) => !_userProfileCache.containsKey(id)).toList();
    if (uncachedUserIds.isEmpty) return;

    try {
      // به جای استفاده از in_ از چند درخواست یا بهینه‌سازی‌های بعدی استفاده می‌شود
      for (final id in uncachedUserIds) {
        await getUserProfile(id);
      }
    } catch (e) {
      print('⚠️ Error preloading profiles: $e');
    }
  }
}
