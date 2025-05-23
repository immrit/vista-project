import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../model/SearchResut.dart';
import '../services/PostImageUploadService.dart';
import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../main.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import '../view/util/themes.dart';

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
      ? darkTheme // اگر گوشی در حالت تیره است
      : lightTheme; // اگر گوشی در حالت روشن است
});

final isLoadingProvider = StateProvider<bool>((ref) => false);
final isRedirectingProvider = StateProvider<bool>((ref) => false);

final fetchPublicPosts = FutureProvider<List<PublicPostModel>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;

  try {
    final response = await supabase.from('posts').select('''
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
        ''').order('created_at', ascending: false);

    final postsData = response as List<dynamic>;

    return postsData.map((e) {
      final profile = e['profiles'] as Map<String, dynamic>? ?? {};
      final avatarUrl = profile['avatar_url'] as String? ?? '';
      final username = profile['username'] as String? ?? 'Unknown';
      final isVerified = profile['is_verified'] as bool? ?? false;

      // تغییر از likes به likes
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

      _offset += response.length;
      _hasMore = response.length >= _limit;

      final posts = (response as List<dynamic>).map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes
              .any((like) => like['user_id'] == supabase.auth.currentUser?.id),
          'username': post['profiles']['username'] ?? 'Unknown',
          'avatar_url': post['profiles']['avatar_url'] ?? '',
          'is_verified': post['profiles']['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': post['profiles']
              ['verification_type'], // اضافه کردن verification_type
        });
      }).toList();

      // اگر state.value null است، posts را به عنوان لیست جدید قرار می‌دهیم
      // در غیر این صورت، posts را به لیست موجود اضافه می‌کنیم
      final currentPosts = state.value ?? [];
      state = AsyncValue.data([...currentPosts, ...posts]);
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
      } else {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
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

  Future<void> _addLike(String postId, String userId, String ownerId) async {
    try {
      await supabase.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
      });

      await _updateLikeCount(postId, increase: true);

      if (userId != ownerId) {
        await _createLikeNotification(postId, userId, ownerId);
      }
    } catch (e) {
      print('خطا در افزودن لایک: $e');
      rethrow;
    }
  }

  Future<void> _removeLike(String postId, String userId, String ownerId) async {
    try {
      await supabase.from('likes').delete().match({
        'post_id': postId,
        'user_id': userId,
      });

      await _updateLikeCount(postId, increase: false);
      await _removeLikeNotification(postId, userId, ownerId);
    } catch (e) {
      print('خطا در حذف لایک: $e');
      rethrow;
    }
  }

  Future<void> _createLikeNotification(
      String postId, String senderId, String recipientId) async {
    try {
      final existingNotification = await supabase
          .from('notifications')
          .select()
          .eq('recipient_id', recipientId)
          .eq('sender_id', senderId)
          .eq('post_id', postId)
          .eq('type', 'like')
          .maybeSingle();

      if (existingNotification == null) {
        await supabase.from('notifications').insert({
          'recipient_id': recipientId,
          'sender_id': senderId,
          'post_id': postId,
          'type': 'like',
          'content': '⭐',
          'is_read': false
        });
      }
    } catch (e) {
      print('خطا در ایجاد نوتیفیکیشن: $e');
      rethrow;
    }
  }

  Future<void> _removeLikeNotification(
      String postId, String senderId, String recipientId) async {
    try {
      await supabase.from('notifications').delete().match({
        'recipient_id': recipientId,
        'sender_id': senderId,
        'post_id': postId,
        'type': 'like'
      });
    } catch (e) {
      print('خطا در حذف نوتیفیکیشن: $e');
      rethrow;
    }
  }

  // متد اعتبارسنجی UUID
  void _validateUUID(String uuid) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);

    if (uuid.isEmpty || !uuidRegex.hasMatch(uuid)) {
      throw ArgumentError('شناسه نامعتبر: $uuid');
    }
  }

  Future<void> _updateLikeCount(String postId, {required bool increase}) async {
    try {
      await supabase.rpc('update_like_count',
          params: {'post_id_input': postId, 'increment': increase ? 1 : -1});
    } catch (e) {
      print('خطا در بروزرسانی تعداد لایک‌ها: $e');
      rethrow;
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
          .single();

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
      ref.invalidate(userProfileProvider(userId));

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
        final bool success =
            await PostImageUploadService.deletePostImage(mediaUrl);
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
    final List data = response ?? [];
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
          .single();

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
          .single();

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
        ''').single();

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
          parentComment.replies ??= [];
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
        .single();

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
  final CommentService _commentService;

  CommentsNotifier(this._commentService) : super([]);

  void addComment({
    required String postId,
    required CommentModel comment,
    String? parentCommentId,
  }) {
    if (parentCommentId != null) {
      // پیدا کردن کامنت والد و اضافه کردن ریپلای
      state = state.map((existingComment) {
        if (existingComment.id == parentCommentId) {
          final updatedReplies = [...(existingComment.replies ?? []), comment];
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

  ProfileNotifier(this.ref) : super(null);

  Future<void> fetchProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      // دریافت اطلاعات پروفایل
      final profileResponse = await supabase.from('profiles').select('''
            id,
            username,
            full_name,
            avatar_url,
            email,
            bio,
            created_at,
            is_verified,
            verification_type,
            account_type,
            role
          ''').eq('id', userId).single();

      // محاسبه تعداد دنبال‌کنندگان
      final followersResponse = await supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);

      final followersCount = followersResponse.length;

      // محاسبه تعداد دنبال‌شونده‌ها
      final followingResponse =
          await supabase.from('follows').select('id').eq('follower_id', userId);

      final followingCount = followingResponse.length;

      // دریافت پست‌ها
      final postsResponse = await supabase.from('posts').select('''
            *,
            profiles!posts_user_id_fkey (
              username,
              avatar_url,
              is_verified
            ),
            likes (
              user_id
            ),
            comments (
              id
            )
          ''').eq('user_id', userId).order('created_at', ascending: false);

      // ساخت مدل پروفایل با اطلاعات به‌روز شده
      final profile = ProfileModel.fromMap({
        ...profileResponse,
        'followers_count': followersCount,
        'following_count': followingCount,
      });

      final posts = postsResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes.any((like) => like['user_id'] == currentUserId),
          'username': post['profiles']['username'] ?? 'Unknown',
          'avatar_url': post['profiles']['avatar_url'] ?? '',
          'is_verified': post['profiles']['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': post['profiles']
              ['verification_type'], // اضافه کردن verification_type
        });
      }).toList();

      // بررسی وضعیت فالو
      final followStatusResponse = await supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId!)
          .eq('following_id', userId)
          .maybeSingle();

      // به‌روزرسانی استیت
      state = profile.copyWith(
        posts: posts,
        isFollowed: followStatusResponse != null,
      );
    } catch (e) {
      print('خطا در دریافت پروفایل: $e');
      rethrow;
    }
  }

  Future<void> toggleFollow(String userId) async {
    if (state == null) return;

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (state!.isFollowed) {
        // حذف فالو
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

        state = state!.copyWith(
          isFollowed: false,
          followersCount: state!.followersCount - 1,
        );
      } else {
        // اضافه کردن فالو
        await supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': userId,
        });

        state = state!.copyWith(
          isFollowed: true,
          followersCount: state!.followersCount + 1,
        );
      }
    } catch (e) {
      print('خطا در تغییر وضعیت فالو: $e');
    }
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
    'username': response['profiles']?['username'] ?? 'Unknown',
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
    if (!_hasMore) return;

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
        final profile = post['profiles'] as Map<String, dynamic>;

        return PublicPostModel.fromMap({
          ...post,
          'like_count': likes.length,
          'is_liked': likes.any((like) => like['user_id'] == currentUserId),
          'username': profile['username'],
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
    } catch (e, stackTrace) {
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
      // نرمال‌سازی هشتگ
      String searchTerm = hashtag.trim();
      if (!searchTerm.startsWith('#')) {
        searchTerm = '#$searchTerm';
      }

      // کوئری به دیتابیس
      final response = await _supabase
          .from('posts')
          .select('''
            id,
            content,
            created_at,
            profiles (
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .ilike('content', '%$searchTerm%')
          .order('created_at', ascending: false);

      print('Hashtag search response: $response');

      return (response as List<dynamic>)
          .map((post) {
            try {
              return PublicPostModel.fromMap(post as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing post: $e');
              return null;
            }
          })
          .whereType<PublicPostModel>()
          .toList();
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

  SearchNotifier(this.ref)
      : _searchService = SearchService(),
        super(SearchState());

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
      );
      return;
    }

    state = state.copyWith(isLoading: true, currentQuery: query);

    try {
      if (query.startsWith('#')) {
        final posts = await _searchService.searchHashtag(query);
        state = state.copyWith(
          hashtagResults: posts,
          isLoading: false,
          selectedTab: 1,
        );
      } else {
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .or('username.ilike.%$query%,full_name.ilike.%$query%')
            .limit(20);

        final users = (response as List)
            .map(
                (user) => ProfileModel.fromMap(Map<String, dynamic>.from(user)))
            .toList();

        state = state.copyWith(
          userResults: users,
          isLoading: false,
          selectedTab: 0,
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
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
      .single();

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

final currentUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = supabase.auth.currentUser!.id;
  final response =
      await supabase.from('profiles').select().eq('id', userId).single();
  return response;
});
final videoPositionProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Settings Providers
final dataSaverProvider = StateProvider<bool>((ref) => false);
final autoQualityProvider = StateProvider<bool>((ref) => true);
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
  AutoPlayNotifier() : super(true) {
    _load();
  }
  void _load() async {
    final value = await VideoPlayerConfig().getAutoPlay();
    state = value;
  }

  void set(bool value) async {
    state = value;
    await VideoPlayerConfig().setAutoPlay(value);
  }
}
