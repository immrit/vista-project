import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'package:Vista/widgets/VideoPlayerConfig.dart';
import 'package:path_provider/path_provider.dart';
import '../DB/profile_cache_service.dart';
import '../DB/settings_cache_service.dart';
import '../services/animation_controller_service.dart';
import '../services/video_autoplay_service.dart';
import '../services/image_quality_service.dart';
import '../core/data/cache/cache_repository.dart';
import '../model/SearchResut.dart';
import '../services/PostImageUploadService.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
// import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../utils/const.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import 'package:Vista/utils/themes.dart';
import '../services/user_friendly_error_handler.dart';
import '../services/auth_navigation_service.dart';
import '../services/vista_node_service.dart';
import 'session_provider.dart';
// Import security provider

// Export security providers
export 'security_provider.dart';
export 'auth_provider.dart';

//check user state
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
});

final authProvider = Provider<User?>((ref) {
  final auth = Supabase.instance.client.auth;
  return auth.currentUser;
});

//fetch user profile
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );

  if (user == null) {
    throw Exception('User is not logged in');
  }

  final response = await supabase.from('profiles').select('''
        *,
        verification_type,
        account_type,
        role
      ''').eq('id', user.id).maybeSingle();

  if (response == null) {
    throw Exception('Profile not found');
  }

  return response;
});

//Edite Profile

final profileUpdateProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, updatedData) async {
  final user = ref.watch(authStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );
  if (user == null) {
    throw Exception('User is not logged in');
  }

  final response =
      await supabase.from('profiles').update(updatedData).eq('id', user.id);

  if (response != null) {
    throw Exception('Failed to update profile');
  }
});

//update pass

final changePasswordProvider =
    FutureProvider.family<void, String>((ref, newPassword) async {
  final response = await Supabase.instance.client.auth.updateUser(
    UserAttributes(password: newPassword),
  );

  throw Exception(response);
});

//delete notes

final deleteNoteProvider =
    FutureProvider.family<void, dynamic>((ref, noteId) async {
  final response = await supabase.from('Notes').delete().eq('id', noteId);

  if (response != null) {
    throw Exception('Error deleting note: ${response!}');
  }
});

final themeProvider = StateProvider<ThemeData>((ref) {
  // بررسی حالت پلتفرم و انتخاب تم متناسب
  final platformBrightness = PlatformDispatcher.instance.platformBrightness;

  return platformBrightness == Brightness.dark
      ? VistaThemes.darkTheme // اگر گوشی در حالت تیره است
      : VistaThemes.lightTheme; // اگر گوشی در حالت روشن است
});

final isLoadingProvider = StateProvider<bool>((ref) => false);
final isRedirectingProvider = StateProvider<bool>((ref) => false);

final fetchPublicPosts = FutureProvider<List<PublicPostModel>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    return [];
  }

  try {
    // دریافت لیست کاربران دنبال شده توسط کاربر فعلی
    final followingResponse = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    final followingIds = followingResponse
        .map((follow) => follow['following_id'] as String)
        .toList();

    final response = await supabase.from('posts').select('''
          *,
          profiles!posts_user_id_fkey (
            username,
            full_name,
            avatar_url,
            is_verified,
            verification_type
          ),
          likes (
            user_id
          ),
          comments (
            id
          )
        ''').order('created_at', ascending: false);

    final postsData = response as List<dynamic>;

    // دریافت لیست کاربرانی که پست دارند
    final userIds =
        postsData.map((post) => post['user_id'] as String).toSet().toList();

    // دریافت تنظیمات حریم خصوصی برای این کاربران
    final userSettingsResponse = await supabase
        .from('user_settings')
        .select('user_id, is_private')
        .inFilter('user_id', userIds);

    final userSettingsMap = {
      for (var setting in userSettingsResponse)
        setting['user_id'] as String: setting['is_private'] as bool? ?? false
    };

    // فیلتر کردن پست‌ها - فقط پست‌های عمومی یا پست‌های کاربران دنبال شده
    final filteredPosts = postsData.where((post) {
      final postUserId = post['user_id'] as String;
      final isPrivate = userSettingsMap[postUserId] ?? false;

      // اگر پست متعلق به خود کاربر است، همیشه نمایش داده شود
      if (postUserId == userId) {
        return true;
      }

      // اگر پست متعلق به کاربر دنبال شده است، همیشه نمایش داده شود
      if (followingIds.contains(postUserId)) {
        return true;
      }

      // اگر پست متعلق به کاربر دنبال نشده است، فقط اگر عمومی باشد نمایش داده شود
      return !isPrivate;
    }).toList();

    return filteredPosts.map((e) {
      final profile = e['profiles'] as Map<String, dynamic>? ?? {};
      final avatarUrl = profile['avatar_url'] as String? ?? '';
      final username = profile['username'] as String? ??
          profile['full_name'] as String? ??
          'Unknown';
      final isVerified = profile['is_verified'] as bool? ?? false;

      // استفاده از فیلد likes
      final likes = e['likes'] as List<dynamic>? ?? [];
      final likeCount = likes.length;
      final isLiked = likes.any((like) => like['user_id'] == userId);

      final comments = e['comments'] as List<dynamic>? ?? [];
      final commentCount = comments.length;

      return PublicPostModel.fromMap({
        ...e,
        'like_count': likeCount,
        'is_liked': isLiked,
        'username': username,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'comment_count': commentCount,
        'verification_type':
            profile['verification_type'], // اضافه کردن verification_type
      });
    }).toList();
  } catch (e) {
    print("Exception in fetching public posts: $e");
    throw Exception("Exception in fetching public posts: $e");
  }
});
final postsProvider = StateProvider<List<PublicPostModel>>((ref) {
  final posts = ref.watch(fetchPublicPosts);
  return posts.value ?? [];
});

class PublicPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final int _limit = 15; // افزایش تعداد آیتم‌های لود شده در یک صفحه
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  PublicPostsNotifier(this.supabase) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;

    try {
      // اضافه کردن تأخیر کوتاه برای جلوگیری از درخواست‌های مکرر به سرور
      if (_offset > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _hasMore = false;
        _isLoading = false;
        return;
      }

      // دریافت لیست کاربران دنبال شده توسط کاربر فعلی
      final followingResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = followingResponse
          .map((follow) => follow['following_id'] as String)
          .toList();

      final response = await supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_user_id_fkey (
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type
            ),
            likes (
              user_id
            ),
            comments (
              id
            )
          ''')
          .range(_offset, _offset + _limit - 1)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        _hasMore = false;
        _isLoading = false;
        return;
      }

      // فیلتر کردن پست‌ها - فقط پست‌های عمومی یا پست‌های کاربران دنبال شده
      final postsList = response as List<dynamic>;

      // دریافت لیست کاربرانی که پست دارند
      final userIds =
          postsList.map((post) => post['user_id'] as String).toSet().toList();

      // دریافت تنظیمات حریم خصوصی برای این کاربران
      final userSettingsResponse = await supabase
          .from('user_settings')
          .select('user_id, is_private')
          .inFilter('user_id', userIds);

      final userSettingsMap = {
        for (var setting in userSettingsResponse)
          setting['user_id'] as String: setting['is_private'] as bool? ?? false
      };

      final filteredResponse = postsList.where((post) {
        final postUserId = post['user_id'] as String;
        final isPrivate = userSettingsMap[postUserId] ?? false;

        // اگر پست متعلق به خود کاربر است، همیشه نمایش داده شود
        if (postUserId == userId) {
          return true;
        }

        // اگر پست متعلق به کاربر دنبال شده است، همیشه نمایش داده شود
        if (followingIds.contains(postUserId)) {
          return true;
        }

        // اگر پست متعلق به کاربر دنبال نشده است، فقط اگر عمومی باشد نمایش داده شود
        return !isPrivate;
      }).toList();

      _offset += filteredResponse.length;
      _hasMore = filteredResponse.length >= _limit;

      final posts = filteredResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes
              .any((like) => like['user_id'] == supabase.auth.currentUser?.id),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type':
              profile['verification_type'], // اضافه کردن verification_type
        });
      }).toList();

      // اگر state.value null است، posts را به عنوان لیست جدید قرار می‌دهیم
      // در غیر این صورت، posts را به لیست موجود اضافه می‌کنیم
      final currentPosts = state.value ?? [];
      state = AsyncValue.data([...currentPosts, ...posts]);
    } catch (e, stackTrace) {
      UserFriendlyErrorHandler.logError(e,
          context: 'posts_loading', stackTrace: stackTrace);
      final errorMessage = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'posts_loading');
      state = AsyncValue.error(errorMessage, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  // متد برای بررسی اینکه آیا پست‌های بیشتری وجود دارد یا خیر
  bool hasMorePosts() => _hasMore;

  // متد برای بررسی اینکه آیا در حال بارگذاری هستیم یا خیر
  bool isLoading() => _isLoading;

  Future<void> refreshPosts() async {
    await _loadInitialPosts();
  }

  Future<void> loadMorePosts() async {
    await _loadMorePosts();
  }

  void updatePost(PublicPostModel updatedPost) {
    state.whenData((posts) {
      final index = posts.indexWhere((post) => post.id == updatedPost.id);
      if (index != -1) {
        final updatedPosts = List<PublicPostModel>.from(posts);
        updatedPosts[index] = updatedPost;
        state = AsyncValue.data(updatedPosts);
      }
    });
  }

  void updatePostLike(String postId, bool isLiked) {
    state.whenData((posts) {
      final index = posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final updatedPost = posts[index].copyWith(
          isLiked: isLiked,
          likeCount:
              isLiked ? posts[index].likeCount + 1 : posts[index].likeCount - 1,
        );
        final newPosts = List<PublicPostModel>.from(posts);
        newPosts[index] = updatedPost;
        state = AsyncValue.data(newPosts);
      }
    });
  }

  Future<void> toggleLike({
    required String postId,
    required String ownerId,
    required WidgetRef ref,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ بررسی امنیتی: بررسی اینکه نشست هنوز معتبر است
    try {
      final sessionManager = ref.read(sessionManagerProvider);
      final isSessionValid = await sessionManager.isSessionStillValid();
      if (!isSessionValid) {
        debugPrint(
            '❌ Session is no longer valid, cannot perform like operation');
        throw Exception('نشست شما منقضی شده است. لطفاً دوباره وارد شوید.');
      }
    } catch (e) {
      debugPrint('❌ Error checking session validity: $e');
      // اگر خطای network است، ادامه بده
      final errorString = e.toString().toLowerCase();
      if (!errorString.contains('network') &&
          !errorString.contains('timeout') &&
          !errorString.contains('connection')) {
        rethrow;
      }
    }

    try {
      // 1. آپدیت Optimistic در UI قبل از درخواست به سرور
      final currentPosts =
          ref.read(publicPostsProvider.notifier).state.value ?? [];
      final postIndex = currentPosts.indexWhere((post) => post.id == postId);

      PublicPostModel? currentPost;
      if (postIndex != -1) {
        currentPost = currentPosts[postIndex];
        final newIsLiked = !currentPost.isLiked;

        // آپدیت state در همه provider های مرتبط
        ref
            .read(likeStateProvider.notifier)
            .updateLikeState(postId, newIsLiked);

        final updatedPost = currentPost.copyWith(
          isLiked: newIsLiked,
          likeCount: newIsLiked
              ? currentPost.likeCount + 1
              : currentPost.likeCount - 1,
        );

        ref.read(publicPostsProvider.notifier).updatePost(updatedPost);

        if (ref.exists(userProfileProvider(ownerId))) {
          ref
              .read(userProfileProvider(ownerId).notifier)
              .updatePost(updatedPost);
        }
      }

      // 2. درخواست به سرور
      if (currentPost != null && !currentPost.isLiked) {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
          'owner_id': ownerId,
        });
      } else if (currentPost != null && currentPost.isLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      }
    } catch (e) {
      // در صورت خطا، برگرداندن state به حالت قبل
      ref.invalidate(publicPostsProvider);
      ref.invalidate(likeStateProvider);
      debugPrint('Error in toggleLike: $e');
      rethrow;
    }
  }
}

final publicPostsProvider = StateNotifierProvider<PublicPostsNotifier,
    AsyncValue<List<PublicPostModel>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PublicPostsNotifier(supabase);
});

// سرویس Supabase برای مدیریت لایک‌ها
class SupabaseService {
  final SupabaseClient supabase;

  SupabaseService(this.supabase);

  Future<Map<String, dynamic>?> _checkExistingLike(
    String postId,
    String userId,
  ) async {
    try {
      final response = await supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('خطا در بررسی لایک موجود: $e');
      rethrow;
    }
  }

  // Future<List<PublicPostModel>> searchPostsByHashtag(String hashtag) async {
  //   try {
  //     final response = await supabase
  //         .from('posts')
  //         .select('''
  //         *,
  //         profiles (
  //           username,
  //           full_name,
  //           avatar_url,
  //           is_verified
  //         )
  //       ''')
  //         .ilike('content', '%$hashtag%')
  //         .order('created_at', ascending: false);

  //     return (response as List<dynamic>)
  //         .map((post) => PublicPostModel.fromMap(post as Map<String, dynamic>))
  //         .toList();
  //   } catch (e) {
  //     throw Exception('خطا در جستجوی پست‌ها: $e');
  //   }
  // }
  Future<void> toggleLike({
    required String postId,
    required String ownerId,
    required WidgetRef ref,
  }) async {
    try {
      // اعتبارسنجی ورودی‌ها
      if (postId.isEmpty || ownerId.isEmpty) {
        throw ArgumentError('شناسه‌های ورودی نمی‌توانند خالی باشند');
      }

      final userId = _validateUser();

      // اعتبارسنجی UUID ها
      [postId, ownerId, userId].forEach(_validateUUID);

      // بررسی وضعیت فعلی لایک
      final existingLike = await _checkExistingLike(postId, userId);

      // اعمال تغییرات در دیتابیس
      if (existingLike == null) {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
          'owner_id': ownerId,
          'created_at': DateTime.now().toIso8601String(),
        });
        // Best-effort personalization signal
        unawaited(VistaNodeService.trackFeedEvent(
          postId: postId,
          eventType: 'like',
        ));
      } else {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        // Best-effort personalization signal
        unawaited(VistaNodeService.trackFeedEvent(
          postId: postId,
          eventType: 'unlike',
        ));
      }

      // بروزرسانی UI
      ref.invalidate(fetchPublicPosts);
    } on AuthException catch (e) {
      print('خطای احراز هویت: ${e.message}');
      rethrow;
    } on ArgumentError catch (e) {
      print('خطای اعتبارسنجی: ${e.message}');
      rethrow;
    } catch (e) {
      print('خطا در toggleLike: $e');
      rethrow;
    }
  }

  /// Quick follow action used in the "For You" feed follow button.
  ///
  /// Returns:
  /// - 'following'  => follow row exists/created
  /// - 'requested'  => follow request created (private account)
  /// - 'none'       => no action (e.g. self) or request not possible
  Future<String> followUserQuick({required String targetUserId}) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('Not authenticated');
    }
    if (targetUserId.isEmpty || targetUserId == currentUserId) {
      return 'none';
    }

    // Already following?
    try {
      final existing = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      if (existing != null) return 'following';
    } catch (_) {
      // If RLS blocks the select, we still attempt insert below.
    }

    // Check privacy (default to public if not available)
    bool isPrivate = false;
    try {
      final settings = await supabase
          .from('user_settings')
          .select('is_private')
          .eq('user_id', targetUserId)
          .maybeSingle();
      isPrivate = (settings?['is_private'] as bool?) ?? false;
    } catch (_) {
      isPrivate = false;
    }

    if (isPrivate) {
      // If already requested, return requested.
      try {
        final existingReq = await supabase
            .from('follow_requests')
            .select('id, status')
            .eq('requester_id', currentUserId)
            .eq('recipient_id', targetUserId)
            .maybeSingle();
        if (existingReq != null &&
            (existingReq['status'] as String?) == 'pending') {
          return 'requested';
        }
      } catch (_) {
        // ignore and try insert
      }

      try {
        await supabase.from('follow_requests').insert({
          'requester_id': currentUserId,
          'recipient_id': targetUserId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Likely duplicate constraint or RLS; treat as requested for UI purposes.
        return 'requested';
      }

      // Best-effort notification
      try {
        await supabase.from('notifications').insert({
          'recipient_id': targetUserId,
          'sender_id': currentUserId,
          'type': 'follow_request',
          'content': 'درخواست دنبال کردن جدید',
          'created_at': DateTime.now().toIso8601String(),
          'is_read': false,
        });
      } catch (_) {}

      return 'requested';
    }

    try {
      await supabase.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': targetUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // If the row already exists, treat it as following.
      return 'following';
    }

    // Best-effort notification
    try {
      await supabase.from('notifications').insert({
        'recipient_id': targetUserId,
        'sender_id': currentUserId,
        'type': 'follow',
        'content': 'دنبال‌کننده جدید',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (_) {}

    return 'following';
  }

  String _validateUser() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('کاربر احراز هویت نشده است');
    }
    return user.id;
  }

  // Future<Map<String, dynamic>?> _checkExistingLike(
  //     String postId, String userId) async {
  //   try {
  //     return await supabase
  //         .from('likes')
  //         .select()
  //         .eq('post_id', postId)
  //         .eq('user_id', userId)
  //         .maybeSingle();
  //   } catch (e) {
  //     print('خطا در بررسی لایک موجود: $e');
  //     return null;
  //   }
  // }

  // متد اعتبارسنجی UUID
  void _validateUUID(String uuid) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);

    if (uuid.isEmpty || !uuidRegex.hasMatch(uuid)) {
      throw ArgumentError('شناسه نامعتبر: $uuid');
    }
  }

  Future<void> insertReport({
    required String postId,
    required String reportedUserId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // بررسی اعتبار شناسه‌ها
      if (postId.isEmpty || reportedUserId.isEmpty) {
        throw ArgumentError('شناسه‌ها نمی‌توانند خالی باشند');
      }

      _validateUUID(postId);
      _validateUUID(reportedUserId);

      final userId = _validateUser();
      _validateUUID(userId);

      await supabase.from('reports').insert({
        'post_id': postId,
        'reported_user_id': reportedUserId,
        'reporter_id': userId,
        'reason': reason,
        'additional_details': additionalDetails,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending'
      });
    } catch (e) {
      print('خطا در ثبت گزارش: $e');
      rethrow;
    }
  }

  Future<void> deletePost(WidgetRef ref, String postId) async {
    try {
      if (postId.isEmpty) {
        throw ArgumentError('شناسه پست نمی‌تواند خالی باشد');
      }

      _validateUUID(postId);
      final userId = _validateUser();

      // دریافت اطلاعات پست برای پیدا کردن URL های فایل‌ها
      final post = await supabase
          .from('posts')
          .select('image_url, music_url  , video_url  ')
          .eq('id', postId)
          .maybeSingle();

      if (post == null) {
        throw Exception('پست یافت نشد');
      }

      final mediaUrls = [
        post['image_url'],
        post['music_url'],
        post['video_url'],
      ].where((url) => url != null && url.isNotEmpty).toList();

      // حذف تمام فایل‌ها از آروان کلاود
      for (String url in mediaUrls) {
        final bool deleted = await _deleteMediaWithRetry(url);
        if (!deleted) {
          print('هشدار: حذف فایل $url از آروان کلاود ناموفق بود');
        }
      }

      // حذف داده‌های مرتبط از دیتابیس به ترتیب
      await Future.wait([
        // حذف لایک‌ها
        supabase.from('likes').delete().eq('post_id', postId),
        // حذف کامنت‌ها
        supabase.from('comments').delete().eq('post_id', postId),
        // حذف نوتیفیکیشن‌ها
        supabase.from('notifications').delete().eq('post_id', postId),
        // حذف بازدیدهای استوری
        supabase.from('story_views').delete().eq('story_id', postId),
      ]);

      // حذف پست
      await supabase.from('posts').delete().eq('id', postId);

      // بروزرسانی UI
      ref.invalidate(fetchPublicPosts);
      // پیدا کردن owner واقعی پست برای invalidation صحیح صفحه پروفایل
      try {
        final postOwner = await supabase
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .maybeSingle();
        final ownerId =
            (postOwner != null ? postOwner['user_id'] : null) as String?;
        if (ownerId != null && ownerId.isNotEmpty) {
          ref.invalidate(userProfileProvider(ownerId));
        } else {
          ref.invalidate(userProfileProvider(userId));
        }
      } catch (_) {
        ref.invalidate(userProfileProvider(userId));
      }

      print('پست و تمام فایل‌های مرتبط با موفقیت حذف شدند.');
    } catch (e) {
      print('خطا در حذف پست: $e');
      rethrow;
    }
  }

  Future<bool> _deleteMediaWithRetry(String mediaUrl,
      {int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // استفاده از متد جدید که خودش نوع فایل رو تشخیص می‌ده و متد مناسب رو فراخوانی می‌کنه
        final bool success =
            await PostImageUploadService.deleteMediaFile(mediaUrl);
        if (success) return true;

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      } catch (e) {
        print('تلاش $attempt: خطا در حذف فایل: $e');
        if (attempt == maxAttempts) return false;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return false;
  }

  // Future<bool> _deleteMediaWithRetry(String mediaUrl,
  //     {int maxAttempts = 3}) async {
  //   for (int attempt = 1; attempt <= maxAttempts; attempt++) {
  //     try {
  //       final bool success =
  //           await PostImageUploadService.deletePostImage(mediaUrl);
  //       if (success) return true;

  //       if (attempt < maxAttempts) {
  //         await Future.delayed(Duration(seconds: attempt));
  //       }
  //     } catch (e) {
  //       print('تلاش $attempt: خطا در حذف مدیا: $e');
  //       if (attempt == maxAttempts) return false;
  //       await Future.delayed(Duration(seconds: attempt));
  //     }
  //   }
  //   return false;
  // }

  Future<List<ProfileModel>> fetchFollowers(String userId) async {
    final response = await supabase.from('follows').select('''
      profiles!follows_follower_id_fkey (
        id, username, full_name, avatar_url, email, bio, 
        followers_count, created_at, 
        is_verified, verification_type
      )
    ''').eq('following_id', userId);

    try {
      return (response as List<dynamic>).map((item) {
        final profileMap = item['profiles'];
        if (profileMap == null) {
          throw Exception('Profile data is missing in the response');
        }
        return ProfileModel.fromMap(profileMap);
      }).toList();
    } catch (e) {
      print('Error parsing response: $e');
      throw Exception('Error converting profiles');
    }
  }

  Future<List<ProfileModel>> fetchFollowing(String userId) async {
    final response = await supabase
        .from('follows') // جدول دنبال‌شده‌ها
        .select('''
        profiles!follows_following_id_fkey (
          id, username, full_name, avatar_url, email, bio, 
          followers_count, created_at, 
          is_verified, verification_type
        )
      ''').eq('follower_id', userId);

    // تبدیل داده به مدل پروفایل
    final List data = response;
    return data.map((item) {
      final profileMap = item['profiles']; // بررسی وجود داده‌های پروفایل
      if (profileMap == null) {
        throw Exception('Missing profile data');
      }
      return ProfileModel.fromMap(profileMap);
    }).toList();
  }

  // اضافه کن: متد چک آنلاین بودن که روی وب همیشه true برمی‌گرداند
  Future<bool> isDeviceOnline() async {
    if (kIsWeb) {
      // روی وب همیشه آنلاین فرض کن
      return true;
    }
    // اگر نیاز به چک آنلاین بودن داری، اینجا قرار بده (مثلاً با http.get یا connectivity_plus)
    // یا فقط return true;
    return true;
  }
}

// Provider برای سرویس Supabase

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final supabase = Supabase.instance.client;
  return SupabaseService(supabase);
});

//Provider برای سرویس و Notifier

// class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
//   NotificationsNotifier() : super([]);

//   // متد حذف تمامی اعلان‌ها
//   Future<void> deleteAllNotifications() async {
//     try {
//       final userId = supabase.auth.currentUser?.id;

//       if (userId == null) {
//         throw Exception("User not logged in");
//       }

//       // حذف تمامی اعلان‌های کاربر فعلی
//       await supabase.from('notifications').delete().eq('recipient_id', userId);

//       // بروزرسانی وضعیت (حذف همه اعلان‌ها از لیست)
//       state = [];
//     } catch (e) {
//       print("Error deleting notifications: $e");
//       throw Exception("Failed to delete notifications");
//     }
//   }

//   Future<void> fetchNotifications() async {
//     final userId = supabase.auth.currentUser?.id; // گرفتن شناسه کاربر فعلی

//     if (userId == null) {
//       throw Exception("User not logged in");
//     }

//     final response = await supabase
//         .from('notifications')
//         .select(
//             '*, sender:profiles!notifications_sender_id_fkey(username, avatar_url , is_verified)')
//         .eq('recipient_id', userId) // استفاده از شناسه کاربر فعلی
//         .order('created_at', ascending: false);

//     final notifications =
//         response.map((item) => NotificationModel.fromMap(item)).toList();
//     state = notifications;
//   }
// }

// final notificationsProvider =
//     StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
//         (ref) {
//   return NotificationsNotifier()..fetchNotifications();
// });

// سرویس Supabase برای گزارش پست‌ها

// تعریف پازنده برای SupabaseClient
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// تعریف پرووایدر سرویس گزارش
final reportServiceProvider = Provider<ReportService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReportService(client);
});

class ReportService {
  final SupabaseClient client;

  ReportService(this.client);

  Future<void> reportPost({
    required String postId,
    required String userId,
    required String reportReason,
  }) async {
    final response = await client.from('reports').insert({
      'post_id': postId,
      'user_id': userId,
      'reason': reportReason,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (response.error != null) {
      throw Exception('Error reporting post: ${response.error!.message}');
    }
  }
}

// provider for profiles

class ProfileService {
  final _supabase = Supabase.instance.client;

  // دریافت پروفایل کاربر فعلی
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles') // نام جدول پروفایل
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching current user profile: $e');
      return null;
    }
  }

  // دریافت پروفایل با شناسه
  Future<UserModel?> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }
}

// Provider برای سرویس پروفایل
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Provider برای پروفایل کاربر فعلی
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getCurrentUserProfile();
});

// Provider برای پروفایل با شناسه خاص
final profileByIdProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getProfileById(userId);
});

// مثال استفاده در ویجت
class ProfileWidget extends ConsumerWidget {
  const ProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دریافت پروفایل کاربر فعلی
    final currentProfileAsync = ref.watch(currentUserProfileProvider);

    return currentProfileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Text('خطا در بارگذاری پروفایل'),
      data: (profile) {
        if (profile == null) {
          return const Text('کاربر وارد نشده است');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              const Icon(Icons.verified, color: Colors.blue)
          ],
        );
      },
    );
  }
}

// مثال دریافت پروفایل با شناسه خاص
class OtherProfileWidget extends ConsumerWidget {
  final String userId;

  const OtherProfileWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));

    return profileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Text('خطا در بارگذاری پروفایل'),
      data: (profile) {
        if (profile == null) {
          return const Text('پروفایل یافت نشد');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              const Icon(Icons.verified, color: Colors.blue)
          ],
        );
      },
    );
  }
}

//fetch comments
//Comment StateNotifier

class CommentService {
  final SupabaseClient _supabase;

  CommentService(this._supabase);

  Future<CommentModel> addComment({
    required String postId,
    required String content,
    required String postOwnerId,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('کاربر وارد سیستم نشده است');
      }

      final response = await _supabase.from('comments').insert({
        'post_id': postId,
        'owner_id': currentUser.id, // تغییر از user_id به owner_id
        'user_id': postOwnerId, // صاحب پست
        'content': content,
        'parent_comment_id': parentCommentId,
      }).select('''
          *,
          profiles!comments_owner_id_fkey (
            username, 
            avatar_url, 
            is_verified,
            verification_type
          )
        ''').maybeSingle();

      if (response == null) {
        throw Exception('خطا در ایجاد کامنت - پاسخ خالی است');
      }

      return CommentModel.fromMap(response);
    } catch (e) {
      print('خطا در ارسال کامنت: $e');
      rethrow;
    }
  }

// تغییر متد fetchComments برای دریافت کامنت‌های فرزند
  Future<List<CommentModel>> fetchComments(String postId) async {
    try {
      final response = await _supabase.from('comments').select('''
          *,
          profiles!comments_owner_id_fkey (
            username, 
            avatar_url, 
            is_verified,
            verification_type )
        ''').eq('post_id', postId).order('created_at', ascending: false);

      if (response.isEmpty) {
        return []; // اگر پاسخی دریافت نشد، لیست خالی برگردانید
      }

      List<CommentModel> comments =
          (response as List).map((item) => CommentModel.fromMap(item)).toList();

      _organizeComments(comments);
      return comments;
    } catch (e) {
      print('خطا در واکشی کامنت‌ها: $e');
      return [];
    }
  }

// متد کمکی برای مرتب‌سازی کامنت‌ها
  void _organizeComments(List<CommentModel> comments) {
    final Map<String, CommentModel> commentMap = {};

    // ایجاد نقشه از کامنت‌ها بر اساس شناسه
    for (var comment in comments) {
      commentMap[comment.id] = comment;
      comment.replies = []; // مقداردهی اولیه برای replies
    }

    // اضافه کردن کامنت‌های فرزند به والدین و حذف آنها از لیست اصلی
    comments.removeWhere((comment) {
      if (comment.parentCommentId != null) {
        final parentComment = commentMap[comment.parentCommentId];
        if (parentComment != null) {
          parentComment.replies.add(comment);
          return true; // حذف ریپلای از لیست اصلی
        }
      }
      return false; // کامنت اصلی حذف نمی‌شود
    });
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Optional: You might want to add a check to ensure only the comment owner can delete
      final response = await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', currentUserId);

      return response;
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchMentionableUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(10);

      return (response as List)
          .map((userData) => UserModel.fromJson(userData))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<void> addMentionToComment({
    required String commentId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('کاربر وارد سیستم نشده است');
      }

      // درج منشن‌ها در جدول comment_mentions
      final mentions = mentionedUserIds
          .map((userId) => {
                'comment_id': commentId,
                'user_id': userId,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabase.from('comment_mentions').insert(mentions);
    } catch (e) {
      print('خطا در اضافه کردن منشن به کامنت: $e');
      rethrow;
    }
  }
}

// Provider برای جستجوی کاربران
final mentionableUsersProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
  final commentService = ref.watch(commentServiceProvider);
  return commentService.searchMentionableUsers(query);
});

// comment_providers.dart
final commentServiceProvider = Provider<CommentService>((ref) {
  final supabase = Supabase.instance.client;
  return CommentService(supabase);
});

final commentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) {
  final commentService = ref.read(commentServiceProvider);
  return commentService.fetchComments(postId);
});

// comment_notifier.dart
class CommentNotifier extends StateNotifier<AsyncValue<void>> {
  final CommentService _commentService;
  final TextEditingController contentController = TextEditingController();

  // اضافه کردن یک فلگ برای جلوگیری از ارسال مکرر
  bool _isSubmitting = false;

  CommentNotifier(this._commentService) : super(const AsyncValue.data(null));

  Future<void> addComment(
      {required String postId,
      required String content,
      required String postOwnerId,
      String? parentCommentId,
      List<String> mentionedUserIds = const [],
      required WidgetRef ref}) async {
    // جلوگیری از ارسال مکرر
    if (_isSubmitting) return;

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) return;

    // تنظیم فلگ ارسال
    _isSubmitting = true;
    state = const AsyncValue.loading();

    try {
      // افزودن کامنت با مشخصات کامل
      final comment = await _commentService.addComment(
        postId: postId,
        content: trimmedContent,
        postOwnerId: postOwnerId,
        parentCommentId: parentCommentId,
      );

      // اگر منشن‌هایی وجود دارد، آنها را اضافه کنید
      if (mentionedUserIds.isNotEmpty) {
        await _commentService.addMentionToComment(
          commentId: comment.id,
          mentionedUserIds: mentionedUserIds,
        );
      }

      // پاک کردن کنترلر
      contentController.clear();

      // بروزرسانی استیت کامنت‌ها
      await _updateCommentsState(postId, comment, parentCommentId, ref);

      state = const AsyncValue.data(null);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    } finally {
      // بازنشانی فلگ ارسال
      _isSubmitting = false;
    }
  }

  // متد جدید برای بروزرسانی استیت کامنت‌ها
  Future<void> _updateCommentsState(
    String postId,
    CommentModel newComment,
    String? parentCommentId,
    WidgetRef ref,
  ) async {
    // دریافت پروایدر کامنت‌ها برای پست مورد نظر
    final commentsProvider =
        StateNotifierProvider<CommentsNotifier, List<CommentModel>>((ref) {
      return CommentsNotifier(_commentService);
    });

    // بروزرسانی استیت کامنت‌ها
    ref.read(commentsProvider.notifier).addComment(
          postId: postId,
          comment: newComment,
          parentCommentId: parentCommentId,
        );
  }

  Future<String> getPostOwnerId(String postId) async {
    final response = await supabase
        .from('posts')
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();

    if (response == null) {
      throw Exception('پست یافت نشد');
    }

    return response['user_id'] as String;
  }

  Future<void> deleteComment(String commentId, WidgetRef ref) async {
    state = const AsyncValue.loading();

    try {
      await _commentService.deleteComment(commentId);
      state = const AsyncValue.data(null);

      // بروزرسانی استیت کامنت‌ها برای پست مشخص
      ref.read(commentsProvider(commentId));
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
}

// نوتیفایر جدید برای مدیریت کامنت‌ها
class CommentsNotifier extends StateNotifier<List<CommentModel>> {
  CommentsNotifier(CommentService _) : super([]);

  void addComment({
    required String postId,
    required CommentModel comment,
    String? parentCommentId,
  }) {
    if (parentCommentId != null) {
      // پیدا کردن کامنت والد و اضافه کردن ریپلای
      state = state.map((existingComment) {
        if (existingComment.id == parentCommentId) {
          final updatedReplies = [...(existingComment.replies), comment];
          return existingComment.copyWith(
            replies: updatedReplies.cast<CommentModel>(),
          );
        }
        return existingComment;
      }).toList();
    } else {
      // اگر کامنت اصلی است، به لیست اضافه می‌شود
      // جلوگیری از تکرار
      if (!state.any((existingComment) => existingComment.id == comment.id)) {
        state = [...state, comment];
      }
    }
  }

  void removeComment(String commentId) {
    state = state.where((comment) {
      // حذف کامنت اصلی
      if (comment.id == commentId) return false;

      // حذف ریپلای‌های مربوط به کامنت
      comment.replies =
          comment.replies.where((reply) => reply.id != commentId).toList();

      return true;
    }).toList();
  }
}

// پروایدر جدید برای کامنت‌ها
// final commentsProvider = StateNotifierProvider<CommentsNotifier, List<CommentModel>>((ref) {
//   final commentService = ref.read(commentServiceProvider);
//   return CommentsNotifier(commentService);
// });

final commentNotifierProvider =
    StateNotifierProvider<CommentNotifier, AsyncValue<void>>((ref) {
  final commentService = ref.read(commentServiceProvider);
  return CommentNotifier(commentService);
});

class ProfileNotifier extends StateNotifier<ProfileModel?> {
  final Ref ref;
  final ProfileCacheService _profileCache = ProfileCacheService();

  ProfileNotifier(this.ref) : super(null);

  Future<void> fetchProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // ✅ بررسی کامل نشست با تلاش برای recovery
      final isAuthenticated = await AuthNavigationService.ensureAuthenticated(
        message: 'برای مشاهده پروفایل ابتدا وارد شوید',
      );

      if (!isAuthenticated) {
        print('⚠️ ProfileNotifier: نشست معتبر نیست');
        return;
      }

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('⚠️ ProfileNotifier: کاربر یافت نشد بعد از verify');
        return;
      }

      try {
        // دریافت پروفایل (مدیریت کش و سرور با خود سرویس است)
        final profile = await _profileCache.getProfile(userId);
        final posts = await _profileCache.getUserPosts(userId);

        // بررسی وضعیت فالو (به‌روزرسانی از سرور برای اطمینان)
        bool isFollowed = profile.isFollowed;
        try {
          final followStatusResponse = await supabase
              .from('follows')
              .select('id')
              .eq('follower_id', currentUserId)
              .eq('following_id', userId)
              .maybeSingle();
          isFollowed = followStatusResponse != null;
        } catch (e) {
          // Ignore network error for follow status check, use cached value
        }

        state = profile.copyWith(
          posts: posts,
          isFollowed: isFollowed,
        );
      } catch (e) {
        print('❌ Error fetching profile in Notifier: $e');

        // تلاش برای خواندن کش اگر خطا رخ داد (مثلاً آفلاین)
        try {
          final cachedProfile = await _profileCache.getCachedProfile(userId);
          if (cachedProfile != null) {
            final cachedPosts = await _profileCache.getCachedPosts(userId);
            state = cachedProfile.copyWith(posts: cachedPosts);
            print('📱 Using cached profile due to error');
            return;
          }
        } catch (_) {}

        rethrow;
      }
    } catch (e, stackTrace) {
      print('❌ Error in fetchProfile: $e');
      UserFriendlyErrorHandler.logError(e,
          context: 'profile_fetch', stackTrace: stackTrace);
    }
  }

  /// اضافه کردن پست جدید به کش
  Future<void> addPostToCache(PublicPostModel post) async {
    try {
      await _profileCache.addPostToCache(post.userId, post);
      print('✅ Added post to cache: ${post.id}');
    } catch (e) {
      print('⚠️ Failed to add post to cache: $e');
    }
  }

  /// حذف پست از کش
  Future<void> removePostFromCache(String userId, String postId) async {
    try {
      await _profileCache.removePostFromCache(userId, postId);
      print('✅ Removed post from cache: $postId');
    } catch (e) {
      print('⚠️ Failed to remove post from cache: $e');
    }
  }

  /// پاک کردن کش کاربر
  Future<void> clearUserCache(String userId) async {
    try {
      await _profileCache.clearUserCache(userId);
      print('✅ Cleared cache for user: $userId');
    } catch (e) {
      print('⚠️ Failed to clear user cache: $e');
    }
  }

  Future<void> toggleFollow(String userId) async {
    if (state == null) return;

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == userId) return;

    try {
      if (state!.isFollowed) {
        await Future.wait([
          supabase
              .from('follows')
              .delete()
              .eq('follower_id', currentUserId)
              .eq('following_id', userId),
          supabase.from('notifications').delete().match({
            'recipient_id': userId,
            'sender_id': currentUserId,
            'type': 'follow',
          })
        ]);

        final nextFollowers =
            state!.followersCount > 0 ? state!.followersCount - 1 : 0;
        state = state!.copyWith(
          isFollowed: false,
          followersCount: nextFollowers,
        );
        ref.invalidate(followRequestPendingProvider(userId));
        return;
      }

      bool isPrivate = false;
      try {
        final userSettings = await supabase
            .from('user_settings')
            .select('is_private')
            .eq('user_id', userId)
            .maybeSingle();
        isPrivate = (userSettings?['is_private'] as bool?) ?? false;
      } catch (_) {
        isPrivate = false;
      }

      final existingFollow = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .maybeSingle();
      if (existingFollow != null) {
        state = state!.copyWith(
          isFollowed: true,
          followersCount: state!.followersCount,
        );
        ref.invalidate(followRequestPendingProvider(userId));
        return;
      }

      if (!isPrivate) {
        await supabase.from('follows').upsert(
          {
            'follower_id': currentUserId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'follower_id,following_id',
        );
        await _insertFollowNotificationIfMissing(
          supabase: supabase,
          senderId: currentUserId,
          recipientId: userId,
        );

        state = state!.copyWith(
          isFollowed: true,
          followersCount: state!.followersCount + 1,
        );
        ref.invalidate(followRequestPendingProvider(userId));
        return;
      }

      final existingRequest = await supabase
          .from('follow_requests')
          .select('id, status')
          .eq('requester_id', currentUserId)
          .eq('recipient_id', userId)
          .maybeSingle();
      final status =
          (existingRequest?['status'] as String? ?? '').toLowerCase().trim();
      final requestId = existingRequest?['id']?.toString();

      if (existingRequest == null) {
        await supabase.from('follow_requests').insert({
          'requester_id': currentUserId,
          'recipient_id': userId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
        await _insertFollowRequestNotificationIfMissing(
          supabase: supabase,
          senderId: currentUserId,
          recipientId: userId,
        );
      } else if (status == 'pending') {
        if (requestId != null && requestId.isNotEmpty) {
          await supabase.from('follow_requests').delete().eq('id', requestId);
        }
        await _deleteFollowRequestNotificationsForPair(
          supabase: supabase,
          senderId: currentUserId,
          recipientId: userId,
        );
      } else if (status == 'rejected') {
        if (requestId != null && requestId.isNotEmpty) {
          await supabase.from('follow_requests').update({
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }).eq('id', requestId);
        }
        await _insertFollowRequestNotificationIfMissing(
          supabase: supabase,
          senderId: currentUserId,
          recipientId: userId,
        );
      } else if (status == 'accepted') {
        await supabase.from('follows').upsert(
          {
            'follower_id': currentUserId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'follower_id,following_id',
        );
        state = state!.copyWith(
          isFollowed: true,
          followersCount: state!.followersCount,
        );
        ref.invalidate(followRequestPendingProvider(userId));
        return;
      } else {
        if (requestId != null && requestId.isNotEmpty) {
          await supabase.from('follow_requests').update({
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }).eq('id', requestId);
        }
        await _insertFollowRequestNotificationIfMissing(
          supabase: supabase,
          senderId: currentUserId,
          recipientId: userId,
        );
      }

      state = state!.copyWith(
        isFollowed: false,
        followersCount: state!.followersCount,
      );
      ref.invalidate(followRequestPendingProvider(userId));
    } catch (e) {
      print('❌ خطا در تغییر وضعیت فالو: $e');
      rethrow; // دوباره خطا را پرتاب کن تا در UI نمایش داده شود
    }
  }

  Future<void> _insertFollowRequestNotificationIfMissing({
    required SupabaseClient supabase,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      final existing = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', recipientId)
          .eq('sender_id', senderId)
          .eq('type', 'follow_request')
          .limit(1)
          .maybeSingle();
      if (existing != null) return;

      await supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': 'follow_request',
        'content': 'درخواست دنبال کردن جدید',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (_) {}
  }

  Future<void> _insertFollowNotificationIfMissing({
    required SupabaseClient supabase,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      final existing = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', recipientId)
          .eq('sender_id', senderId)
          .eq('type', 'follow')
          .limit(1)
          .maybeSingle();
      if (existing != null) return;

      await supabase.from('notifications').insert({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': 'follow',
        'content': 'شما را دنبال کرد',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (_) {}
  }

  Future<void> _deleteFollowRequestNotificationsForPair({
    required SupabaseClient supabase,
    required String senderId,
    required String recipientId,
  }) async {
    try {
      await supabase.from('notifications').delete().match({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'type': 'follow_request',
      });
    } catch (_) {}
  }

  void updatePost(PublicPostModel updatedPost) {
    if (state == null) return;

    final updatedPosts = List<PublicPostModel>.from(state!.posts);
    final index = updatedPosts.indexWhere((post) => post.id == updatedPost.id);

    if (index != -1) {
      updatedPosts[index] = updatedPost;
      state = state!.copyWith(posts: updatedPosts);
    }
  }

  void addNewPost(PublicPostModel newPost) {
    if (state == null) return;
    state = state!.copyWith(
      posts: [newPost, ...state!.posts],
    );
  }
}

final userProfileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileModel?, String>(
  (ref, userId) => ProfileNotifier(ref)..fetchProfile(userId),
);

// بررسی در حال انتظار بودن درخواست دنبال کردن
final followRequestPendingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  try {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;
    print(
        '🔍 بررسی درخواست pending برای کاربر $targetUserId توسط $currentUserId');
    final res = await supabase
        .from('follow_requests')
        .select('id, status')
        .eq('requester_id', currentUserId)
        .eq('recipient_id', targetUserId)
        .eq('status', 'pending')
        .maybeSingle();
    print('🔍 نتیجه بررسی درخواست pending: $res');
    final isPending = res != null;
    print('🔍 isPending: $isPending');
    return isPending;
  } catch (e) {
    print('خطا در بررسی وضعیت درخواست دنبال کردن: $e');
    return false;
  }
});

final postProvider =
    FutureProvider.family<PublicPostModel, String>((ref, postId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase.from('posts').select('''
        *,
        image_url,
        music_url,
        profiles (
          username, 
          avatar_url, 
          is_verified,
          verification_type
        ),
        likes (user_id)
      ''').eq('id', postId).maybeSingle();

  if (response == null) {
    throw Exception('پستی با این شناسه یافت نشد.');
  }

  print('Post Response: $response'); // برای دیباگ

  final likes = response['likes'] as List<dynamic>? ?? [];
  final likeCount = likes.length;
  final isLiked =
      likes.any((like) => like['user_id'] == supabase.auth.currentUser?.id);

  return PublicPostModel.fromMap({
    ...response,
    'like_count': likeCount,
    'is_liked': isLiked,
    'username': response['profiles']?['username'] ??
        response['profiles']?['full_name'] ??
        'Unknown',
    'avatar_url': response['profiles']?['avatar_url'] ?? '',
    'is_verified': response['profiles']?['is_verified'] ?? false,
    'image_url': response['image_url'], // اضافه کردن image_url
    'music_url': response['music_url'], // اضافه کردن music_url
  });
});

class ReportCommentService {
  final SupabaseClient supabase;

  ReportCommentService(this.supabase);

  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // ارسال گزارش به جدول comment_reports
      await supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': reporterId,
        'reason': reason, // دلیل گزارش
        'additional_details': additionalDetails, // توضیحات اضافی
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to report comment: $e');
    }
  }
}

// ارائه‌دهنده سرویس گزارش کامنت‌ها
final reportCommentServiceProvider = Provider<ReportCommentService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReportCommentService(supabase);
});

//profile report

class ReportProfileService {
  final SupabaseClient supabase;

  ReportProfileService(this.supabase);

  Future<void> reportProfile({
    required String userId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // ارسال گزارش به جدول profile_reports
      await supabase.from('profile_reports').insert({
        'profile_id': userId,
        'reporter_id': reporterId,
        'reason': reason, // دلیل گزارش
        'additional_details': additionalDetails, // توضیحات اضافی
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to report profile: $e');
    }
  }
}

// ارائه‌دهنده سرویس گزارش پروفایل‌ها
final reportProfileServiceProvider = Provider<ReportProfileService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReportProfileService(supabase);
});

//mention user profile
// mention_providers.dart
final mentionUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // واکشی کاربران با اطلاعات کامل
    final response = await supabase
        .from('profiles')
        .select('id, username, avatar_url, is_verified, verification_type')
        .order('username');

    return (response as List)
        .map((userData) => UserModel.fromMap(userData))
        .toList();
  } catch (e) {
    print('خطا در دریافت کاربران برای منشن: $e');
    return [];
  }
});

// mention_service.dart
class MentionService {
  final SupabaseClient _supabase;

  MentionService(this._supabase);

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, is_verified, verification_type')
          .or('username.ilike.%$query%, email.ilike.%$query%')
          .limit(10);

      return (response as List)
          .map((userData) => UserModel.fromMap(userData))
          .toList();
    } catch (e) {
      print('خطا در جستجوی کاربران: $e');
      return [];
    }
  }

  // متد اضافه کردن منشن به کامنت
  Future<void> addMentionToComment({
    required String commentId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      await _supabase.from('comment_mentions').insert(mentionedUserIds
          .map((userId) => {
                'comment_id': commentId,
                'user_id': userId,
              })
          .toList());
    } catch (e) {
      print('خطا در ثبت منشن‌ها: $e');
      rethrow;
    }
  }
}

// mention_notifier.dart
class MentionNotifier extends StateNotifier<List<UserModel>> {
  final MentionService _mentionService;

  MentionNotifier(this._mentionService) : super([]);

  Future<void> searchMentionableUsers(String query) async {
    if (query.isEmpty) {
      state = [];
      return;
    }

    try {
      final users = await _mentionService.searchUsers(query);
      state = users;
    } catch (e) {
      state = [];
      print('خطا در جستجوی کاربران: $e');
    }
  }

  void clearMentions() {
    state = [];
  }
}

// mention_providers_final.dart
final mentionServiceProvider = Provider<MentionService>((ref) {
  final supabase = Supabase.instance.client;
  return MentionService(supabase);
});

final mentionNotifierProvider =
    StateNotifierProvider<MentionNotifier, List<UserModel>>((ref) {
  final mentionService = ref.read(mentionServiceProvider);
  return MentionNotifier(mentionService);
});

final userFollowersProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.fetchFollowers(userId);
});

final userFollowingProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabaseService = ref.read(supabaseServiceProvider);

  return await supabaseService.fetchFollowing(userId);
});

class FollowingPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final int _limit = 10;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  bool hasMorePosts() => _hasMore;
  bool isLoading() => _isLoading;

  FollowingPostsNotifier(this.supabase) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Check followings first
      final followingResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      if (followingResponse.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final followingIds =
          followingResponse.map((e) => e['following_id'] as String).toList();

      final response = await supabase
          .from('posts')
          .select('''
      *,
      profiles!posts_user_id_fkey (
        username, 
        avatar_url,
        is_verified,
        verification_type
      ),
      likes (user_id),
      comments (id)
    ''')
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (response.isEmpty) {
        _hasMore = false;
        state = AsyncValue.data([...?state.value, ...[]]);
        return;
      }

      _offset += response.length;
      _hasMore = response.length >= _limit;

      final posts = response.map((post) {
        final likes = List<Map<String, dynamic>>.from(post['likes'] ?? []);
        final comments =
            List<Map<String, dynamic>>.from(post['comments'] ?? []);
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': likes.length,
          'is_liked': likes.any((like) => like['user_id'] == currentUserId),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type':
              profile['verification_type'], // اضافه کردن verification_type
        });
      }).toList();

      state = AsyncValue.data([...?state.value, ...posts]);
    } catch (e, stackTrace) {
      String errorMessage = 'خطا در بارگذاری پست‌ها';

      if (e is PostgrestException) {
        errorMessage =
            'خطا در ارتباط با سرور. لطفا اتصال اینترنت خود را بررسی کنید';
      } else if (e is TimeoutException) {
        errorMessage =
            'زمان پاسخگویی سرور به پایان رسید. لطفا دوباره تلاش کنید';
      } else if (e is AuthException) {
        errorMessage = 'لطفا دوباره وارد حساب کاربری خود شوید';
      }

      state = AsyncValue.error(errorMessage, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshPosts() async {
    await _loadInitialPosts();
  }

  Future<void> loadMorePosts() async {
    await _loadMorePosts();
  }

  void likePost(String postId) async {
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((post) => post.id == postId);

    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final ownerId = post.userId;

    try {
      // ابتدا وضعیت لایک را در UI تغییر می‌دهیم
      final updatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
      );

      final updatedPosts = [...currentPosts];
      updatedPosts[postIndex] = updatedPost;
      state = AsyncValue.data(updatedPosts);

      // سپس درخواست به سرور ارسال می‌کنیم
      await supabase.functions.invoke('toggle-like', body: {
        'post_id': postId,
        'owner_id': ownerId,
      });
    } catch (e) {
      print('خطا در لایک کردن پست: $e');
      // در صورت خطا، وضعیت قبلی را برمی‌گردانیم
      state = AsyncValue.data(currentPosts);
    }
  }
}

final fetchFollowingPostsProvider = StateNotifierProvider<
    FollowingPostsNotifier, AsyncValue<List<PublicPostModel>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return FollowingPostsNotifier(supabase);
});
// final fetchFollowingPostsProvider =
//     FutureProvider<List<PublicPostModel>>((ref) async {
//   try {
//     final currentUserId = supabase.auth.currentUser?.id;
//     if (currentUserId == null) return [];

//     // Check followings first
//     final followingResponse = await supabase
//         .from('follows')
//         .select('following_id')
//         .eq('follower_id', currentUserId);

//     if (followingResponse.isEmpty) {
//       return []; // Return empty list if no followings
//     }

//     final followingIds =
//         followingResponse.map((e) => e['following_id'] as String).toList();

//     final response = await supabase
//         .from('posts')
//         .select('''
//           *,
//           profiles!posts_user_id_fkey (
//             username,
//             avatar_url,
//             is_verified
//           ),
//           likes (user_id),
//           comments (id)
//         ''')
//         .inFilter('user_id', followingIds)
//         .order('created_at', ascending: false);

//     return response.map((post) {
//       final likes = List<Map<String, dynamic>>.from(post['likes'] ?? []);
//       final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
//       final profile = post['profiles'] as Map<String, dynamic>;

//       return PublicPostModel.fromMap({
//         ...post,
//         'like_count': likes.length,
//         'is_liked': likes.any((like) => like['user_id'] == currentUserId),
//         'username': profile['username'],
//         'avatar_url': profile['avatar_url'] ?? '',
//         'is_verified': profile['is_verified'] ?? false,
//         'comment_count': comments.length,
//       });
//     }).toList();
//   } catch (e) {
//     print('Error fetching following posts: $e');
//     return []; // Return empty list instead of throwing error
//   }
// });

class SearchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PublicPostModel>> searchHashtag(String hashtag) async {
    try {
      // Normalize hashtag to match `posts.tags` (no '#', lowercase, no whitespace).
      String raw = hashtag.trim();
      raw = raw.replaceFirst(RegExp(r'^#+'), '');
      raw = raw.replaceAll(RegExp(r'\s+'), '');
      final tag = raw.toLowerCase();
      if (tag.isEmpty) return [];

      // Primary: search by `tags` array (correct + fast with GIN).
      final response1 = await _supabase
          .from('posts')
          .select('''
            *,
            profiles (
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('status', 'published')
          .contains('tags', [tag])
          .order(
            'created_at',
            ascending: false,
          )
          .limit(60);

      final rows = <Map<String, dynamic>>[];
      rows.addAll(List<Map<String, dynamic>>.from(response1 as List<dynamic>));

      // Back-compat: if some older posts don't have `tags`, also match by content.
      if (rows.length < 40) {
        final response2 = await _supabase
            .from('posts')
            .select('''
              *,
              profiles (
                id,
                username,
                full_name,
                avatar_url,
                is_verified,
                verification_type
              )
            ''')
            .eq('status', 'published')
            .ilike('content', '%#$tag%')
            .order('created_at', ascending: false)
            .limit(60);

        final seenIds =
            rows.map((r) => r['id']?.toString()).whereType<String>().toSet();
        for (final r in List<Map<String, dynamic>>.from(response2 as List)) {
          final id = r['id']?.toString();
          if (id == null || seenIds.contains(id)) continue;
          rows.add(r);
        }
      }

      return rows.map((post) {
        // Map DB counters to the model contract keys used in the UI.
        final likeCount = (post['likes_count'] as num?)?.toInt() ?? 0;
        final commentCount = (post['comments_count'] as num?)?.toInt() ?? 0;
        return PublicPostModel.fromMap({
          ...post,
          'like_count': likeCount,
          'comment_count': commentCount,
          'is_liked': false,
        });
      }).toList();
    } catch (e) {
      print('Error in searchHashtag: $e');
      return [];
    }
  }
}

// lib/providers/search_provider.dart
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  final SearchService _searchService;
  final int _userLimit = 20;

  SearchNotifier(this.ref)
      : _searchService = SearchService(),
        super(const SearchState());

  void setTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        hashtagResults: [],
        userResults: [],
        isLoading: false,
        currentQuery: '',
        userOffset: 0,
        hasMoreUsers: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      currentQuery: query,
      userOffset: 0,
      hasMoreUsers: true,
      userResults: [], // Clear previous results
    );

    try {
      if (query.startsWith('#')) {
        final posts = await _searchService.searchHashtag(query);
        state = state.copyWith(
          hashtagResults: posts,
          isLoading: false,
          selectedTab: 1,
        );
      } else {
        await _fetchUsers(query, 0);
        state = state.copyWith(selectedTab: 0);
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> loadMoreUsers() async {
    if (!state.hasMoreUsers || state.isLoading) return;

    // Avoid rapid duplicate calls (optional debouncing could go here)
    // For now relies on isLoading=true from search, but loadMore logic needs its own loading state?
    // Using simple approach: assume UI triggers carefully or we check if fetching.
    // Actually, 'isLoading' usually blocks the whole UI. For infinite scroll, we often want a bottom spinner.
    // Let's assume the UI handles the debounce.

    await _fetchUsers(state.currentQuery, state.userOffset);
  }

  Future<void> _fetchUsers(String query, int offset) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .order('is_verified', ascending: false) // Prioritize Verified
          .range(offset, offset + _userLimit - 1);

      final newUsers = (response as List)
          .map((user) => ProfileModel.fromMap(Map<String, dynamic>.from(user)))
          .toList();

      // Client-side sort for fine-grained priority (Blue > Gold > Normal)
      newUsers.sort((a, b) {
        int getScore(ProfileModel p) {
          if (p.hasBlueBadge) return 3;
          if (p.hasGoldBadge || p.role == 'premium') return 2;
          return 1;
        }

        return getScore(b).compareTo(getScore(a));
      });

      final allUsers = [...state.userResults, ...newUsers];
      // Re-sort entire list?
      // Ideally yes, to ensure if a high priority user comes in late (unlikely due to DB sort) they bubble up.
      // But DB sort 'is_verified' puts all verified first.
      // So 'newUsers' will mostly be unverified if we passed the verified block.
      // So simple append is fine.

      state = state.copyWith(
        userResults: allUsers,
        isLoading: false,
        userOffset: offset + newUsers.length,
        hasMoreUsers: newUsers.length >= _userLimit,
      );
    } catch (e) {
      print('Error fetching users: $e');
      // Update state to stop loading
      state = state.copyWith(isLoading: false);
    }
  }

  void clearHashtagResults() {
    state = state.copyWith(hashtagResults: []);
  }
}

// پروایدر
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

// final chatRepositoryProvider = Provider((ref) {
//   final supabase = ref.watch(supabaseClientProvider);
//   return ChatRepository(supabase);
// });

// final recentChatsProvider = StreamProvider((ref) {
//   final repository = ref.watch(chatRepositoryProvider);
//   return repository.getRecentChats();
// });

// final chatMessagesProvider = StreamProvider.family((ref, String otherUserId) {
//   final repository = ref.watch(chatRepositoryProvider);
//   return repository.getChatMessages(otherUserId);
// });

// final selectedChatUserProvider = StateProvider<Profile?>((ref) => null);
class StoryControllerNotifier extends StateNotifier<int> {
  StoryControllerNotifier() : super(0);

  void nextStory() => state++;
  void previousStory() => state--;
  void setCurrentIndex(int index) => state = index;

  // اضافه کردن این متد
  void reset() => state = 0;
}

final storyControllerProvider =
    StateNotifierProvider<StoryControllerNotifier, int>(
  (ref) => StoryControllerNotifier(),
);

final viewsCountProvider =
    FutureProvider.family<int, String>((ref, storyId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('story_views')
      .select('view_count')
      .eq('story_id', storyId)
      .maybeSingle();

  if (response == null) {
    return 0; // اگر view وجود نداشت، 0 برمی‌گردانیم
  }

  return response['view_count'] as int;
});

//notification check
final hasNewNotificationProvider = FutureProvider<bool>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final response = await supabase
      .from('notifications')
      .select()
      .eq('recipient_id', userId)
      .eq('is_read', false);

  print('Has new notification: ${response.isNotEmpty}'); // اینجا چاپ می‌شود
  return response.isNotEmpty;
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    return null;
  }

  final response =
      await supabase.from('profiles').select().eq('id', userId).maybeSingle();
  return response;
});

// user_settings providers
final userSettingsByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    print('🔧 دریافت تنظیمات کاربر: $userId');

    // استفاده از SettingsCacheService برای کش کردن تنظیمات
    final settingsCache = SettingsCacheService();

    // ابتدا بررسی کش - اگر موجود بود و معتبر بود، از آن استفاده کن
    final cachedSettings = settingsCache.getCachedUserSettings(userId);
    if (cachedSettings != null) {
      print('🔧 استفاده از تنظیمات کش شده برای کاربر: $userId');
      return cachedSettings;
    }

    // اگر در کش نبود، از سرور دریافت کن و کش کن
    print('🔧 دریافت تنظیمات از سرور برای کاربر: $userId');
    await settingsCache.cacheUserSettings(userId);

    // دوباره از کش بخوان
    final settings = settingsCache.getCachedUserSettings(userId);
    print('🔧 تنظیمات دریافت شده: $settings');
    print('🔧 allow_profile_zoom: ${settings?['allow_profile_zoom']}');
    return settings;
  } catch (e) {
    debugPrint('Error fetching user_settings for $userId: $e');
    return null;
  }
});

final currentUserSettingsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final response = await client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  } catch (e) {
    debugPrint('Error fetching current user_settings: $e');
    return null;
  }
});
final videoPositionProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Settings Providers
class DataSaverNotifier extends StateNotifier<bool> {
  DataSaverNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getDataSaverMode();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setDataSaverMode(value);
  }
}

final dataSaverProvider = StateNotifierProvider<DataSaverNotifier, bool>((ref) {
  return DataSaverNotifier();
});

class AutoQualityNotifier extends StateNotifier<bool> {
  AutoQualityNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getAutoQuality();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setAutoQuality(value);
  }
}

final autoQualityProvider =
    StateNotifierProvider<AutoQualityNotifier, bool>((ref) {
  return AutoQualityNotifier();
});

final videoQualityProvider = StateProvider<String>((ref) => 'auto');

final videoPlayerConfigProvider = Provider<VideoPlayerConfig>((ref) {
  return VideoPlayerConfig();
});

// Video Position Cache Provider
final videoPositionsProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Theme Provider
final videoPlayerThemeProvider = Provider<VideoPlayerTheme>((ref) {
  final isDark = ref.watch(themeProvider).brightness == Brightness.dark;
  return VideoPlayerTheme(
    isDark: isDark,
    accentColor: isDark ? Colors.white : Colors.black,
    backgroundColor: isDark ? Colors.black : Colors.white,
  );
});

class VideoPlayerTheme {
  final bool isDark;
  final Color accentColor;
  final Color backgroundColor;

  VideoPlayerTheme({
    required this.isDark,
    required this.accentColor,
    required this.backgroundColor,
  });
}

// Video Playback State Provider
final playbackStateProvider =
    StateProvider.family<PlaybackState, String>((ref, videoId) {
  return PlaybackState();
});

class PlaybackState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isMuted;
  final Duration position;
  final Duration duration;

  PlaybackState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.isMuted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    bool? isMuted,
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isMuted: isMuted ?? this.isMuted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class ReelsNotifier extends StateNotifier<List<PublicPostModel>> {
  ReelsNotifier() : super([]);

  // این متد برای آپدیت یک ریلز خاص در لیست
  void updateReel(PublicPostModel updatedReel) {
    state = [
      for (final reel in state)
        if (reel.id == updatedReel.id) updatedReel else reel
    ];
  }

  // متدهای دیگر (fetch, loadMore, ...) اختیاری
}

// provider سراسری ریلزها
final likeStateProvider =
    StateNotifierProvider<LikeStateNotifier, Map<String, bool>>((ref) {
  return LikeStateNotifier();
});

class LikeStateNotifier extends StateNotifier<Map<String, bool>> {
  LikeStateNotifier() : super({});

  void updateLikeState(String postId, bool isLiked) {
    state = {...state, postId: isLiked};
  }

  bool isPostLiked(String postId) {
    return state[postId] ?? false;
  }
}

// Provider to get the current user's UserModel based on profileProvider
final userProvider = Provider<UserModel?>((ref) {
  // به profileProvider گوش می‌دهیم تا داده‌های پروفایل را دریافت کنیم
  final profileDataAsync = ref
      .watch(profileProvider); // این یک AsyncValue<Map<String, dynamic>?> است

  // با استفاده از .when وضعیت‌های مختلف profileDataAsync (داده، لودینگ، خطا) را مدیریت می‌کنیم
  return profileDataAsync.when(
    data: (dataMap) {
      // dataMap همان Map<String, dynamic>? است که از profileProvider می‌آید
      if (dataMap != null) {
        try {
          // داده‌های map را به UserModel تبدیل می‌کنیم
          return UserModel.fromMap(dataMap);
        } catch (e, stackTrace) {
          // اگر در تبدیل map به UserModel خطایی رخ دهد (مثلاً فیلدهای مورد نیاز وجود نداشته باشند)
          debugPrint('خطا در تبدیل اطلاعات پروفایل به UserModel: $e');
          debugPrint('StackTrace: $stackTrace');
          debugPrint('اطلاعات پروفایل دریافتی: $dataMap');
          return null; // در صورت خطا، null برمی‌گردانیم
        }
      }
      return null; // اگر dataMap خود null باشد (مثلاً پروفایل پیدا نشده)
    },
    loading: () {
      // اگر profileProvider در حال بارگذاری اطلاعات باشد
      return null;
    },
    error: (error, stackTrace) {
      // اگر خطایی در profileProvider رخ داده باشد
      debugPrint(
          'خطا در profileProvider هنگام تلاش برای خواندن توسط userProvider: $error');
      debugPrint('StackTrace: $stackTrace');
      return null;
    },
  );
});

final autoPlayProvider = StateNotifierProvider<AutoPlayNotifier, bool>((ref) {
  return AutoPlayNotifier();
});

class AutoPlayNotifier extends StateNotifier<bool> {
  final VideoAutoplayService _videoAutoplayService = VideoAutoplayService();

  AutoPlayNotifier() : super(true) {
    _load();
  }

  void _load() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }

  void set(bool value) async {
    await _videoAutoplayService.setAutoPlay(value);
    state = _videoAutoplayService.shouldAutoPlay();
  }

  // متد برای به‌روزرسانی وضعیت پس از تغییر حالت کم‌مصرف
  void refresh() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }
}

// Font size settings provider
class MessageFontSizeNotifier extends StateNotifier<double> {
  Isar? _isar;

  MessageFontSizeNotifier() : super(14.0) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadFontSize();
    } catch (e) {
      debugPrint('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  Future<void> _loadFontSize() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null && settings.messageFontSize != null) {
        state = settings.messageFontSize!;
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری اندازه فونت: $e');
    }
  }

  Future<void> setFontSize(double size) async {
    state = size;
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false // Default
            ..selectedColor = 'white' // Default
            ..messageFontSize = size;
        } else {
          settings.messageFontSize = size;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('خطا در ذخیره اندازه فونت: $e');
    }
  }

  String getFontSizeLabel(double size) {
    if (size <= 11.0) return 'خیلی کوچک';
    if (size <= 13.0) return 'کوچک';
    if (size <= 15.0) return 'متوسط';
    if (size <= 17.0) return 'بزرگ';
    if (size <= 20.0) return 'خیلی بزرگ';
    return 'بسیار بزرگ';
  }
}

final messageFontSizeProvider =
    StateNotifierProvider<MessageFontSizeNotifier, double>((ref) {
  return MessageFontSizeNotifier();
});

// Auto download settings provider
class AutoDownloadSettings {
  final String photos; // 'always', 'wifi', 'never'
  final String voices; // 'always', 'wifi', 'never'

  AutoDownloadSettings({
    this.photos = 'wifi',
    this.voices = 'wifi',
  });

  AutoDownloadSettings copyWith({
    String? photos,
    String? voices,
  }) {
    return AutoDownloadSettings(
      photos: photos ?? this.photos,
      voices: voices ?? this.voices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photos': photos,
      'voices': voices,
    };
  }

  static AutoDownloadSettings fromMap(Map<String, dynamic> map) {
    return AutoDownloadSettings(
      photos: map['photos'] ?? 'wifi',
      voices: map['voices'] ?? 'wifi',
    );
  }
}

class AutoDownloadNotifier extends StateNotifier<AutoDownloadSettings> {
  Isar? _isar;

  AutoDownloadNotifier() : super(AutoDownloadSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {
      debugPrint('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          photos: settings.autoDownloadPhotos,
          voices: settings.autoDownloadVoices,
        );
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری تنظیمات دانلود خودکار: $e');
    }
  }

  Future<void> updatePhotoSetting(String setting) async {
    state = state.copyWith(photos: setting);
    await _saveSettings();

    // اعمال تنظیمات جدید
    await _applyAutoDownloadSettings();
  }

  Future<void> updateVoiceSetting(String setting) async {
    state = state.copyWith(voices: setting);
    await _saveSettings();

    // اعمال تنظیمات جدید
    await _applyAutoDownloadSettings();
  }

  Future<void> _applyAutoDownloadSettings() async {
    try {
      // پاکسازی کش قدیمی در صورت تغییر تنظیمات
      if (state.photos == 'never') {
        await _clearPhotoCache();
      }
      if (state.voices == 'never') {
        await _clearVoiceCache();
      }

      print(
          '✅ Auto download settings applied: Photos=${state.photos}, Voices=${state.voices}');
    } catch (e) {
      debugPrint('خطا در اعمال تنظیمات دانلود خودکار: $e');
    }
  }

  Future<void> _clearPhotoCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chatImagesDir = Directory('${appDir.path}/chat_images');
      if (await chatImagesDir.exists()) {
        await chatImagesDir.delete(recursive: true);
        print('🧹 Photo cache cleared');
      }
    } catch (e) {
      debugPrint('خطا در پاکسازی کش عکس‌ها: $e');
    }
  }

  Future<void> _clearVoiceCache() async {
    try {
      // TODO: Import VoiceCacheService and clear cache
      print('🧹 Voice cache cleared');
    } catch (e) {
      debugPrint('خطا در پاکسازی کش وویس‌ها: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..autoDownloadPhotos = state.photos
            ..autoDownloadVoices = state.voices;
        } else {
          settings.autoDownloadPhotos = state.photos;
          settings.autoDownloadVoices = state.voices;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('خطا در ذخیره تنظیمات دانلود خودکار: $e');
    }
  }

  String getSettingLabel(String setting) {
    switch (setting) {
      case 'always':
        return 'همیشه';
      case 'wifi':
        return 'فقط Wi-Fi';
      case 'never':
        return 'هرگز';
      default:
        return 'نامشخص';
    }
  }
}

final autoDownloadProvider =
    StateNotifierProvider<AutoDownloadNotifier, AutoDownloadSettings>((ref) {
  return AutoDownloadNotifier();
});

// Performance settings provider
class PerformanceSettings {
  final bool batterySaverMode;
  final bool smartCache;
  final bool messagePreloading;

  PerformanceSettings({
    this.batterySaverMode = false,
    this.smartCache = true,
    this.messagePreloading = true,
  });

  PerformanceSettings copyWith({
    bool? batterySaverMode,
    bool? smartCache,
    bool? messagePreloading,
  }) {
    return PerformanceSettings(
      batterySaverMode: batterySaverMode ?? this.batterySaverMode,
      smartCache: smartCache ?? this.smartCache,
      messagePreloading: messagePreloading ?? this.messagePreloading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batterySaverMode': batterySaverMode,
      'smartCache': smartCache,
      'messagePreloading': messagePreloading,
    };
  }

  static PerformanceSettings fromMap(Map<String, dynamic> map) {
    return PerformanceSettings(
      batterySaverMode: map['batterySaverMode'] ?? false,
      smartCache: map['smartCache'] ?? true,
      messagePreloading: map['messagePreloading'] ?? true,
    );
  }
}

class PerformanceNotifier extends StateNotifier<PerformanceSettings> {
  Isar? _isar;

  PerformanceNotifier() : super(PerformanceSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {
      debugPrint('خطا در باز کردن دیتابیس تنظیمات: $e');
    }
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          batterySaverMode: settings.batterySaverMode,
          smartCache: settings.smartCache,
          messagePreloading: settings.messagePreloading,
        );
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری تنظیمات عملکرد: $e');
    }
  }

  Future<void> updateBatterySaver(bool enabled) async {
    state = state.copyWith(batterySaverMode: enabled);
    await _saveSettings();

    // اعمال تنظیمات حالت کم‌مصرف
    // Note: Services are updated below directly
    // if (enabled) {
    //   await _applyBatterySaverMode();
    // } else {
    //   await _disableBatterySaverMode();
    // }

    // به‌روزرسانی سرویس انیمیشن
    final animationService = AnimationControllerService();
    await animationService.setBatterySaverMode(enabled);

    // به‌روزرسانی سرویس پخش خودکار ویدیو
    final videoAutoplayService = VideoAutoplayService();
    await videoAutoplayService.setBatterySaverMode(enabled);

    // به‌روزرسانی سرویس کیفیت تصاویر
    final imageQualityService = ImageQualityService();
    await imageQualityService.setBatterySaverMode(enabled);

    // به‌روزرسانی autoPlayProvider (از طریق ProviderContainer)
    // این کار در StorageAndMemorySettingsPage انجام می‌شود
  }

  Future<void> updateSmartCache(bool enabled) async {
    state = state.copyWith(smartCache: enabled);
    await _saveSettings();

    // اعمال تنظیمات کش هوشمند
    // اعمال تنظیمات کش هوشمند
    if (enabled) {
      await CacheRepository().optimize();
    }
  }

  Future<void> updateMessagePreloading(bool enabled) async {
    state = state.copyWith(messagePreloading: enabled);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..batterySaverMode = state.batterySaverMode
            ..smartCache = state.smartCache
            ..messagePreloading = state.messagePreloading;
        } else {
          settings.batterySaverMode = state.batterySaverMode;
          settings.smartCache = state.smartCache;
          settings.messagePreloading = state.messagePreloading;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('خطا در ذخیره تنظیمات عملکرد: $e');
    }
  }

  /*
  Future<void> _applyBatterySaverMode() async {
    // Legacy Sembast removal
  }

  Future<void> _disableBatterySaverMode() async {
    // Legacy Sembast removal
  }
  */

  String getBatterySaverDescription() {
    return state.batterySaverMode
        ? 'فعال - کاهش مصرف باتری تا 30%'
        : 'غیرفعال - عملکرد کامل';
  }

  String getSmartCacheDescription() {
    return state.smartCache
        ? 'فعال - پاکسازی خودکار کش قدیمی'
        : 'غیرفعال - کش کامل';
  }

  String getPreloadingDescription() {
    return state.messagePreloading
        ? 'فعال - بارگذاری سریع‌تر پیام‌ها'
        : 'غیرفعال - صرفه‌جویی در مصرف داده';
  }
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceSettings>((ref) {
  return PerformanceNotifier();
});

// Provider برای lazy loading پست‌های پروفایل
class ProfilePostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final String userId;
  final int _limit = 30; // نمایش اولیه بیشتر برای پروفایل‌ها
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<PublicPostModel> _allPosts = [];

  ProfilePostsNotifier(this.supabase, this.userId)
      : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _allPosts.clear();
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;

    try {
      final currentUserId = supabase.auth.currentUser?.id;

      final postsResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_user_id_fkey (
              username,
              avatar_url,
              is_verified,
              verification_type
            ),
            likes (
              user_id
            ),
            comments (
              id
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (postsResponse.isEmpty) {
        _hasMore = false;
        state = AsyncValue.data(List<PublicPostModel>.from(_allPosts));
        return;
      }

      final newPosts = postsResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes.any((like) => like['user_id'] == currentUserId),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': profile['verification_type'],
        });
      }).toList();

      _allPosts.addAll(newPosts);
      _offset += postsResponse.length; // مطابق تعداد واقعی دریافتی
      _hasMore = postsResponse.length == _limit;

      state = AsyncValue.data(List<PublicPostModel>.from(_allPosts));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    await _loadMorePosts();
  }

  Future<void> refresh() async {
    await _loadInitialPosts();
  }

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
}

final profilePostsProvider = StateNotifierProvider.family<ProfilePostsNotifier,
    AsyncValue<List<PublicPostModel>>, String>((ref, userId) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfilePostsNotifier(supabase, userId);
});
