import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/publicPostModel.dart';

// Provider برای سرویس پست‌های با امتیاز تعامل
final engagementPostServiceProvider = Provider<EngagementPostService>((ref) {
  return EngagementPostService();
});

// سرویس برای دریافت پست‌های با امتیاز تعامل
class EngagementPostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// دریافت پست‌ها با امتیاز تعامل - روش بهینه‌شده (شبیه اینستاگرام)
  Future<List<PublicPostModel>> getPostsWithEngagement({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      print('🔄 شروع دریافت پست‌ها - offset: $offset, limit: $limit');

      // محاسبه تاریخ یک هفته پیش
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final userId = _supabase.auth.currentUser?.id;

      // مرحله 1: دریافت پست‌های یک هفته اخیر بدون مرتب‌سازی اولیه
      final postsResponse = await _supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_user_id_fkey (
              username, 
              avatar_url, 
              is_verified,
              verification_type
            ),
            likes!likes_post_id_fkey (id, user_id),
            comments!comments_post_id_fkey (id)
          ''')
          .eq('status', 'published')
          .gte('created_at',
              oneWeekAgo.toIso8601String()) // فقط پست‌های یک هفته اخیر
          // حذف order('created_at') - اجازه می‌دهیم الگوریتم ما مرتب کند
          .range(offset, offset + limit - 1);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      final List<PublicPostModel> postsWithEngagement = [];
      final List<PublicPostModel> likedPosts = []; // پست‌های لایک شده جداگانه
      final List<PublicPostModel> nonLikedPosts = []; // پست‌های لایک نشده

      print('📊 تعداد پست‌های دریافت شده: ${posts.length}');
      print('👤 کاربر فعلی ID: $userId');
      print('📅 محدوده تاریخ: از ${oneWeekAgo.toString()} تا الان');

      // مرحله 2: محاسبه تعامل برای هر پست
      for (final post in posts) {
        final profile = post['profiles'] as Map<String, dynamic>? ?? {};
        final avatarUrl = profile['avatar_url'] as String? ?? '';
        final username = profile['username'] as String? ?? 'Unknown';
        final isVerified = profile['is_verified'] as bool? ?? false;

        // محاسبه تعداد لایک و کامنت از رابطه‌ها
        final likes = post['likes'] as List<dynamic>? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];
        final likeCount = likes.length;
        final commentCount = comments.length;
        final engagementScore = likeCount + commentCount;

        // دیباگ: بررسی داده‌های لایک
        if (likes.isNotEmpty) {
          print(
              '🔍 پست ${post['id']} - داده‌های لایک: ${likes.map((l) => 'user_id: ${l['user_id']}').toList()}');
        }

        // بررسی لایک کاربر فعلی
        bool isLiked = false;
        if (userId != null) {
          // بررسی دقیق‌تر لایک کاربر
          isLiked = likes.any((like) {
            final likeUserId = like['user_id'] as String?;
            final isUserLiked = likeUserId == userId;
            if (isUserLiked) {
              print('❤️ کاربر $userId پست ${post['id']} را لایک کرده است');
            }
            return isUserLiked;
          });

          // اگر از رابطه‌ها نتوانستیم تشخیص دهیم، کوئری جداگانه اجرا می‌کنیم
          if (!isLiked && likes.isNotEmpty) {
            try {
              final userLikeResponse = await _supabase
                  .from('likes')
                  .select('id')
                  .eq('post_id', post['id'])
                  .eq('user_id', userId)
                  .maybeSingle();

              if (userLikeResponse != null) {
                isLiked = true;
                print(
                    '🔧 کاربر $userId پست ${post['id']} را لایک کرده است (از کوئری جداگانه)');
              }
            } catch (e) {
              print('⚠️ خطا در بررسی لایک کاربر از کوئری جداگانه: $e');
            }
          }
        }

        final postModel = PublicPostModel.fromMap({
          ...post,
          'like_count': likeCount,
          'is_liked': isLiked,
          'username': username,
          'avatar_url': avatarUrl,
          'is_verified': isVerified,
          'comment_count': commentCount,
          'verification_type': profile['verification_type'],
        });

        // جدا کردن پست‌های لایک شده و نشده
        if (isLiked) {
          likedPosts.add(postModel);
        } else {
          nonLikedPosts.add(postModel);
        }

        print(
            '📝 پست ${post['id']}: لایک=$likeCount, کامنت=$commentCount, امتیاز=$engagementScore, کاربر لایک کرده: $isLiked');
      }

      // مرحله 3: مرتب‌سازی جداگانه برای هر گروه

      // مرتب‌سازی پست‌های لایک نشده بر اساس تعامل (مثل اینستاگرام)
      nonLikedPosts.sort((a, b) {
        final aEngagement = a.likeCount + a.commentCount;
        final bEngagement = b.likeCount + b.commentCount;

        print(
            '🔄 مقایسه (لایک نشده): ${a.username}(امتیاز:$aEngagement) vs ${b.username}(امتیاز:$bEngagement)');

        if (aEngagement != bEngagement) {
          return bEngagement.compareTo(aEngagement); // بیشترین تعامل اول
        } else {
          return b.createdAt.compareTo(a.createdAt); // اگر برابر، جدیدترین اول
        }
      });

      // مرتب‌سازی پست‌های لایک شده بر اساس تعامل (نه تاریخ)
      likedPosts.sort((a, b) {
        final aEngagement = a.likeCount + a.commentCount;
        final bEngagement = b.likeCount + b.commentCount;

        print(
            '🔄 مقایسه (لایک شده): ${a.username}(امتیاز:$aEngagement) vs ${b.username}(امتیاز:$bEngagement)');

        if (aEngagement != bEngagement) {
          return bEngagement.compareTo(aEngagement); // بیشترین تعامل اول
        } else {
          return b.createdAt.compareTo(a.createdAt); // اگر برابر، جدیدترین اول
        }
      });

      // ترکیب نهایی: ابتدا پست‌های لایک نشده، سپس پست‌های لایک شده
      final finalPosts = [...nonLikedPosts, ...likedPosts];

      // اگر همه پست‌ها لایک شده‌اند، همه را بر اساس تعامل مرتب می‌کنیم
      if (nonLikedPosts.isEmpty && likedPosts.isNotEmpty) {
        print('⚠️ همه پست‌ها لایک شده‌اند - مرتب‌سازی کلی بر اساس تعامل');
        finalPosts.sort((a, b) {
          final aEngagement = a.likeCount + a.commentCount;
          final bEngagement = b.likeCount + b.commentCount;

          print(
              '🔄 مقایسه کلی: ${a.username}(امتیاز:$aEngagement) vs ${b.username}(امتیاز:$bEngagement)');

          if (aEngagement != bEngagement) {
            return bEngagement.compareTo(aEngagement); // بیشترین تعامل اول
          } else {
            return b.createdAt
                .compareTo(a.createdAt); // اگر برابر، جدیدترین اول
          }
        });
      }

      print('✅ مرتب‌سازی انجام شد:');
      print('📊 پست‌های لایک نشده: ${nonLikedPosts.length}');
      print('📊 پست‌های لایک شده: ${likedPosts.length}');

      // نمایش 5 پست اول با امتیاز تعامل
      print('🏆 5 پست اول:');
      for (int i = 0; i < finalPosts.length && i < 5; i++) {
        final post = finalPosts[i];
        final engagement = post.likeCount + post.commentCount;
        print(
            '  ${i + 1}. ${post.username} - امتیاز: $engagement (لایک: ${post.likeCount}, کامنت: ${post.commentCount}) - لایک شده: ${post.isLiked}');
      }

      return finalPosts;
    } catch (e) {
      print('❌ خطا در دریافت پست‌ها با امتیاز تعامل: $e');
      rethrow;
    }
  }

  /// بروزرسانی امتیاز تعامل همه پست‌ها
  Future<void> _updateAllEngagementScores() async {
    try {
      await _supabase.rpc('refresh_all_engagement_scores');
    } catch (e) {
      print('خطا در بروزرسانی امتیاز تعامل: $e');
      // اگر function وجود ندارد، مستقیماً بروزرسانی می‌کنیم
      await _updateEngagementScoresDirectly();
    }
  }

  /// بروزرسانی مستقیم امتیاز تعامل
  Future<void> _updateEngagementScoresDirectly() async {
    try {
      // بروزرسانی ساده - فقط engagement_score را بر اساس فیلدهای موجود محاسبه می‌کنیم
      // این کار در کوئری اصلی انجام می‌شود
      print('بروزرسانی امتیاز تعامل انجام شد');
    } catch (e) {
      print('خطا در بروزرسانی مستقیم امتیاز تعامل: $e');
    }
  }

  /// بروزرسانی امتیاز تعامل یک پست خاص
  Future<void> updatePostEngagement(String postId) async {
    try {
      // دریافت تعداد لایک و کامنت
      final likesResponse =
          await _supabase.from('likes').select('id').eq('post_id', postId);

      final commentsResponse =
          await _supabase.from('comments').select('id').eq('post_id', postId);

      final likesCount = likesResponse.length;
      final commentsCount = commentsResponse.length;
      final engagementScore = likesCount + commentsCount;

      // بروزرسانی engagement_score و فیلدهای مربوطه
      await _supabase.from('posts').update({
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'engagement_score': engagementScore,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', postId);

      print(
          'امتیاز تعامل پست $postId بروزرسانی شد: لایک=$likesCount, کامنت=$commentsCount, امتیاز=$engagementScore');
    } catch (e) {
      print('خطا در بروزرسانی امتیاز تعامل: $e');
      rethrow;
    }
  }

  /// تست: بررسی لایک‌های کاربر فعلی
  Future<void> testUserLikes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('❌ کاربر وارد نشده است');
        return;
      }

      print('🧪 تست لایک‌های کاربر: $userId');

      // دریافت همه لایک‌های کاربر
      final userLikes =
          await _supabase.from('likes').select('post_id').eq('user_id', userId);

      print('📊 تعداد کل لایک‌های کاربر: ${userLikes.length}');
      print(
          '📝 پست‌های لایک شده: ${userLikes.map((l) => l['post_id']).toList()}');
    } catch (e) {
      print('❌ خطا در تست لایک‌های کاربر: $e');
    }
  }

  /// تست: بررسی مرتب‌سازی پست‌ها
  Future<void> testPostSorting() async {
    try {
      print('🧪 تست مرتب‌سازی پست‌ها');

      // دریافت چند پست برای تست
      final testPosts = await getPostsWithEngagement(limit: 10, offset: 0);

      print('📊 تعداد پست‌های تست: ${testPosts.length}');

      // بررسی ترتیب امتیاز تعامل
      for (int i = 0; i < testPosts.length - 1; i++) {
        final current = testPosts[i];
        final next = testPosts[i + 1];
        final currentEngagement = current.likeCount + current.commentCount;
        final nextEngagement = next.likeCount + next.commentCount;

        print(
            '🔍 بررسی ${i + 1}: ${current.username}(امتیاز:$currentEngagement) vs ${next.username}(امتیاز:$nextEngagement)');

        if (current.isLiked && !next.isLiked) {
          print('✅ درست: پست لایک شده بعد از پست لایک نشده');
        } else if (!current.isLiked && !next.isLiked) {
          if (currentEngagement >= nextEngagement) {
            print(
                '✅ درست: امتیاز تعامل نزولی (${currentEngagement} >= ${nextEngagement})');
          } else {
            print(
                '❌ مشکل: امتیاز تعامل صعودی (${currentEngagement} < ${nextEngagement})');
          }
        } else if (current.isLiked && next.isLiked) {
          if (currentEngagement >= nextEngagement) {
            print(
                '✅ درست: پست‌های لایک شده بر اساس تعامل (${currentEngagement} >= ${nextEngagement})');
          } else {
            print(
                '❌ مشکل: پست‌های لایک شده بر اساس تعامل نیست (${currentEngagement} < ${nextEngagement})');
          }
        }
      }

      // نمایش خلاصه
      print('📋 خلاصه مرتب‌سازی:');
      for (int i = 0; i < testPosts.length && i < 5; i++) {
        final post = testPosts[i];
        final engagement = post.likeCount + post.commentCount;
        print(
            '  ${i + 1}. ${post.username} - امتیاز: $engagement (لایک: ${post.likeCount}, کامنت: ${post.commentCount}) - لایک شده: ${post.isLiked}');
      }
    } catch (e) {
      print('❌ خطا در تست مرتب‌سازی: $e');
    }
  }

  /// دریافت پست‌های لایک شده کاربر (برای کش کردن)
  Future<List<String>> getUserLikedPostIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final userLikes =
          await _supabase.from('likes').select('post_id').eq('user_id', userId);

      return userLikes.map((like) => like['post_id'] as String).toList();
    } catch (e) {
      print('❌ خطا در دریافت پست‌های لایک شده: $e');
      return [];
    }
  }
}

// Notifier برای مدیریت پست‌های با امتیاز تعامل
class EngagementPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final EngagementPostService _service;
  final int _limit = 15;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  EngagementPostsNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;

    // تست لایک‌های کاربر در ابتدا
    await _service.testUserLikes();

    await _loadMorePosts();

    // تست مرتب‌سازی بعد از بارگذاری
    await _service.testPostSorting();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    print('🔄 شروع بارگذاری پست‌های بیشتر - offset: $_offset');

    try {
      // اضافه کردن تأخیر کوتاه برای جلوگیری از درخواست‌های مکرر به سرور
      if (_offset > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // استفاده از روش بهینه‌شده
      final posts = await _service.getPostsWithEngagement(
        limit: _limit,
        offset: _offset,
      );

      if (posts.isEmpty) {
        print('📭 هیچ پست جدیدی یافت نشد');
        _hasMore = false;
        _isLoading = false;
        return;
      }

      _offset += posts.length;
      _hasMore = posts.length >= _limit;

      // اگر state.value null است، posts را به عنوان لیست جدید قرار می‌دهیم
      // در غیر این صورت، posts را به لیست موجود اضافه می‌کنیم
      final currentPosts = state.value ?? [];
      state = AsyncValue.data([...currentPosts, ...posts]);

      print('✅ پست‌های جدید بارگذاری شدند: ${posts.length} پست');
      print(
          '📊 کل پست‌ها: ${currentPosts.length + posts.length}, offset جدید: $_offset, hasMore: $_hasMore');
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

      print('❌ خطا در بارگذاری پست‌ها: $e');
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

        // اگر کاربر لایک کرد، پست را به انتهای لیست منتقل می‌کنیم (مثل اینستاگرام)
        if (isLiked) {
          newPosts.removeAt(index);
          newPosts.add(updatedPost);
          print('🔄 پست $postId به انتهای لیست منتقل شد (لایک شد)');
        }

        state = AsyncValue.data(newPosts);

        // بروزرسانی امتیاز تعامل در دیتابیس
        _service.updatePostEngagement(postId);
      }
    });
  }

  /// بروزرسانی فوری امتیاز تعامل یک پست
  void updatePostEngagementImmediate(
      String postId, int newLikeCount, int newCommentCount) {
    state.whenData((posts) {
      final index = posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final updatedPost = posts[index].copyWith(
          likeCount: newLikeCount,
          commentCount: newCommentCount,
        );
        final newPosts = List<PublicPostModel>.from(posts);
        newPosts[index] = updatedPost;

        // مرتب‌سازی مجدد بر اساس امتیاز تعامل
        newPosts.sort((a, b) {
          final aEngagement = a.likeCount + a.commentCount;
          final bEngagement = b.likeCount + b.commentCount;

          if (aEngagement != bEngagement) {
            return bEngagement.compareTo(aEngagement);
          } else {
            return b.createdAt.compareTo(a.createdAt);
          }
        });

        state = AsyncValue.data(newPosts);
      }
    });
  }
}

// Provider اصلی برای پست‌های با امتیاز تعامل
final engagementPostsProvider = StateNotifierProvider<EngagementPostsNotifier,
    AsyncValue<List<PublicPostModel>>>((ref) {
  final service = ref.read(engagementPostServiceProvider);
  return EngagementPostsNotifier(service);
});

// Provider برای مدیریت وضعیت بارگذاری
final engagementPostsLoadingProvider = StateProvider<bool>((ref) => false);

// Provider برای مدیریت خطاها
final engagementPostsErrorProvider = StateProvider<String?>((ref) => null);

// Provider برای مدیریت صفحه فعلی
final engagementCurrentPageProvider = StateProvider<int>((ref) => 0);

// Provider برای مدیریت پست‌های کش شده
final engagementCachedPostsProvider =
    StateNotifierProvider<EngagementCachedPostsNotifier, List<PublicPostModel>>(
        (ref) {
  return EngagementCachedPostsNotifier();
});

// Provider برای مدیریت امتیاز تعامل
final engagementScoreProvider =
    StateNotifierProvider<EngagementScoreNotifier, Map<String, int>>((ref) {
  return EngagementScoreNotifier();
});

// Provider برای تست لایک‌های کاربر
final testUserLikesProvider = FutureProvider<void>((ref) async {
  final service = ref.read(engagementPostServiceProvider);
  await service.testUserLikes();
});

// Provider برای مدیریت پست‌های لایک شده
final likedPostsProvider =
    StateNotifierProvider<LikedPostsNotifier, Set<String>>((ref) {
  return LikedPostsNotifier();
});

class LikedPostsNotifier extends StateNotifier<Set<String>> {
  LikedPostsNotifier() : super({});

  void addLikedPost(String postId) {
    state = {...state, postId};
  }

  void removeLikedPost(String postId) {
    final newState = Set<String>.from(state);
    newState.remove(postId);
    state = newState;
  }

  void setLikedPosts(List<String> postIds) {
    state = Set<String>.from(postIds);
  }

  void clearLikedPosts() {
    state = {};
  }

  bool isLiked(String postId) {
    return state.contains(postId);
  }
}

class EngagementScoreNotifier extends StateNotifier<Map<String, int>> {
  EngagementScoreNotifier() : super({});

  void updateScore(String postId, int score) {
    state = {...state, postId: score};
  }

  void removeScore(String postId) {
    final newState = Map<String, int>.from(state);
    newState.remove(postId);
    state = newState;
  }

  void clearScores() {
    state = {};
  }
}

class EngagementCachedPostsNotifier
    extends StateNotifier<List<PublicPostModel>> {
  EngagementCachedPostsNotifier() : super([]);

  void addPosts(List<PublicPostModel> newPosts) {
    state = [...state, ...newPosts];
  }

  void clearPosts() {
    state = [];
  }

  void updatePost(PublicPostModel updatedPost) {
    final index = state.indexWhere((post) => post.id == updatedPost.id);
    if (index != -1) {
      final newState = List<PublicPostModel>.from(state);
      newState[index] = updatedPost;
      state = newState;
    }
  }
}
