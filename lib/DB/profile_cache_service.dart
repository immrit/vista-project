import 'dart:async';
import 'package:isar/isar.dart';
import '../../DB/isar_database_manager.dart';
import '../../features/profile/data/entities/profile_entity.dart' hide fastHash;
import '../../features/posts/data/entities/post_entity.dart' hide fastHash;
import '../../model/ProfileModel.dart';
import '../../model/publicPostModel.dart';
import '../../security/logging_utility.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/posts/data/go_posts_repository.dart';

// Import fastHash from one source or define locally to avoid conflicts
import '../../features/profile/data/entities/profile_entity.dart' show fastHash;

/// سرویس کش مدرن با استفاده از دیتابیس Isar
/// جایگزین نسخه قدیمی که از SharedPreferences استفاده می‌کرد
class ProfileCacheService {
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  // اعتبار کش: 2 ساعت
  static const Duration cacheValidityDuration = Duration(hours: 2);
  static const int maxCachedPostsPerUser = 50;

  Future<Isar> get _db async => await IsarDatabaseManager().instance;

  /// مقداردهی اولیه (دیگر نیازی به لود کردن همه چیز در رم نیست)
  Future<void> initialize() async {
    logInfo('✅ Profile Cache Service (Isar) ready');
  }

  // ===========================================================================
  // PROFILE OPERATIONS
  // ===========================================================================

  /// دریافت پروفایل از کش
  Future<ProfileModel?> getCachedProfile(String userId) async {
    try {
      final isar = await _db;
      final entity = await isar.profileEntitys.getByUserId(userId);

      if (entity == null) return null;

      // بررسی اعتبار زمانی
      final isExpired =
          DateTime.now().difference(entity.lastUpdated) > cacheValidityDuration;
      if (isExpired) {
        logInfo('⚠️ Cached profile for $userId is expired, fetching fresh...');
      }

      return entity.toModel();
    } catch (e) {
      logInfo('❌ Error reading profile from Isar: $e');
      return null;
    }
  }

  /// دریافت پروفایل (اول از کش، اگر نبود/منقضی بود از سرور)
  Future<ProfileModel> getProfile(String userId) async {
    // 1. تلاش برای خواندن از کش
    final cachedProfile = await getCachedProfile(userId);

    // اگر کش معتبر است، برگردان
    if (cachedProfile != null && (await isCacheValidAsync(userId))) {
      logInfo('📱 Using cached profile for user: $userId');
      return cachedProfile;
    }

    // 2. اگر در کش نبود یا منقضی بود، از سرور بگیر
    logInfo('🌐 Fetching profile from server for user: $userId');
    await cacheProfileAndPosts(userId);

    // 3. دوباره از کش بخوان (که الان آپدیت شده)
    final freshProfile = await getCachedProfile(userId);
    if (freshProfile == null) {
      throw Exception('Failed to fetch profile for user: $userId');
    }
    return freshProfile;
  }

  /// به‌روزرسانی یا ذخیره پروفایل در کش
  Future<void> updateCachedProfile(ProfileModel profile) async {
    final isar = await _db;
    final entity = ProfileEntity.fromModel(profile);

    await isar.writeTxn(() async {
      await isar.profileEntitys.put(entity);
    });
    logInfo('✅ Updated cached profile for user: ${profile.id}');
  }

  // ===========================================================================
  // POSTS OPERATIONS
  // ===========================================================================

  /// دریافت پست‌های کش شده
  Future<List<PublicPostModel>> getCachedPosts(String userId) async {
    try {
      final isar = await _db;

      // توجه: چون فایل .g.dart تولید نشده، متدهای filter و sortBy ممکن است خطا دهند
      // اما پس از اجرای build_runner درست می‌شوند.
      // اگر هنوز خطا بود، باید با کوئری خام یا اصلاح کد جنریت شده پیش رفت.
      // فعلاً از روش استاندارد Isar استفاده می‌کنیم.

      final entities = await isar.postEntitys
          .filter()
          .userIdEqualTo(userId)
          .sortByCreatedAtDesc()
          .limit(maxCachedPostsPerUser)
          .findAll();

      return entities.map((e) => e.toModel()).toList();
    } catch (e) {
      logInfo('❌ Error reading posts from Isar: $e');
      return [];
    }
  }

  /// دریافت پست‌ها (استراتژی Cache-First)
  Future<List<PublicPostModel>> getUserPosts(String userId) async {
    // 1. بررسی وضعیت کش
    if (await isCacheValidAsync(userId)) {
      final cachedPosts = await getCachedPosts(userId);
      if (cachedPosts.isNotEmpty) {
        logInfo('📱 Using cached posts for user: $userId');
        return cachedPosts;
      }
    }

    // 2. دریافت از سرور
    logInfo('🌐 Fetching posts from server for user: $userId');
    await cacheProfileAndPosts(userId);

    return await getCachedPosts(userId);
  }

  /// اضافه کردن یک پست جدید به کش
  Future<void> addPostToCache(String userId, PublicPostModel post) async {
    final isar = await _db;
    final entity = PostEntity.fromModel(post);

    await isar.writeTxn(() async {
      await isar.postEntitys.put(entity);

      final count =
          await isar.postEntitys.filter().userIdEqualTo(userId).count();
      if (count > maxCachedPostsPerUser) {
        final overduePosts = await isar.postEntitys
            .filter()
            .userIdEqualTo(userId)
            .sortByCreatedAt()
            .limit(count - maxCachedPostsPerUser)
            .findAll();

        await isar.postEntitys
            .deleteAll(overduePosts.map((e) => e.isarId).toList());
      }
    });
    logInfo('✅ Added post to cache for user: $userId');
  }

  /// حذف پست از کش
  Future<void> removePostFromCache(String userId, String postId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.postEntitys.filter().idEqualTo(postId).deleteAll();
    });
    logInfo('✅ Removed post from cache for user: $userId');
  }

  // ===========================================================================
  // SYNC & FETCH LOGIC
  // ===========================================================================

  Future<void> cacheProfileAndPosts(String userId) async {
    try {
      final currentUserId = await TokenStorage.getUserId();
      if (currentUserId == null || currentUserId.isEmpty) return;

      final profileData = await ProfileRepository().fetchProfileById(userId);
      final profile = ProfileModel.fromMap(profileData);

      final posts = await GoPostsRepository().getUserPosts(
        userId: userId,
        limit: maxCachedPostsPerUser,
        offset: 0,
      );
      final postEntities = posts.map(PostEntity.fromModel).toList();

      final isar = await _db;
      await isar.writeTxn(() async {
        await isar.profileEntitys.put(ProfileEntity.fromModel(profile));
        await isar.postEntitys.filter().userIdEqualTo(userId).deleteAll();
        await isar.postEntitys.putAll(postEntities);
      });

      logInfo(
          '✅ Synced profile and ${postEntities.length} posts to Isar for user: $userId');
    } catch (e) {
      logInfo('❌ Failed to sync profile/posts for user $userId: $e');
      rethrow;
    }
  }

  Future<bool> isCacheValidAsync(String userId) async {
    final isar = await _db;
    final profile = await isar.profileEntitys.getByUserId(userId);
    if (profile == null) return false;
    return DateTime.now().difference(profile.lastUpdated) <
        cacheValidityDuration;
  }

  Future<void> clearUserCache(String userId) async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.profileEntitys.filter().idEqualTo(userId).deleteAll();
      await isar.postEntitys.filter().userIdEqualTo(userId).deleteAll();
    });
    logInfo('🧹 Cleared cache for user: $userId');
  }

  Future<void> clearAllCache() async {
    final isar = await _db;
    await isar.writeTxn(() async {
      await isar.profileEntitys.clear();
      await isar.postEntitys.clear();
    });
    logInfo('🧹 Cleared ALL profile cache');
  }

  Future<void> refreshCacheInBackground(String userId) async {
    try {
      await cacheProfileAndPosts(userId);
    } catch (e) {
      // Ignore
    }
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'status': 'Migrated to Isar DB',
      'note': 'Stats require async DB access'
    };
  }
}

// Extension to allow hashing in lookups
extension ProfileEntityQuery on IsarCollection<ProfileEntity> {
  Future<ProfileEntity?> getByUserId(String userId) {
    return get(fastHash(userId));
  }
}
