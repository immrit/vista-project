import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../provider/post_provider.dart';

/// Controller برای مدیریت پست‌ها
class PostController {
  final PostService _postService;
  final Ref _ref;

  PostController(this._postService, this._ref);

  /// دریافت پست‌ها با صفحه‌بندی
  Future<List<Map<String, dynamic>>> getPosts({
    int page = 0,
    int limit = 20,
  }) async {
    try {
      _ref.read(postsLoadingProvider.notifier).state = true;
      _ref.read(postsErrorProvider.notifier).state = null;

      final offset = page * limit;
      final posts = await _postService.getPostsWithEngagement(
        limit: limit,
        offset: offset,
      );

      // اضافه کردن پست‌ها به کش
      if (page == 0) {
        _ref.read(cachedPostsProvider.notifier).clearPosts();
      }
      _ref.read(cachedPostsProvider.notifier).addPosts(posts);

      return posts;
    } catch (e) {
      _ref.read(postsErrorProvider.notifier).state = e.toString();
      debugPrint('خطا در دریافت پست‌ها: $e');
      rethrow;
    } finally {
      _ref.read(postsLoadingProvider.notifier).state = false;
    }
  }

  /// دریافت پست‌های trend
  Future<List<Map<String, dynamic>>> getTrendingPosts({
    int limit = 10,
  }) async {
    try {
      // استفاده از متد Complex که امتیاز engagement را محاسبه می‌کند
      final posts = await _postService.getPostsWithEngagementComplex(
        limit: limit,
        offset: 0,
      );

      // فیلتر کردن پست‌هایی که امتیاز engagement بالایی دارند
      final trendingPosts = posts.where((post) {
        final score = post['engagement_score'] as int? ?? 0;
        return score > 0; // حداقل یک تعامل داشته باشد
      }).toList();

      return trendingPosts;
    } catch (e) {
      debugPrint('خطا در دریافت پست‌های ترند: $e');
      rethrow;
    }
  }

  /// رفرش کردن پست‌ها
  Future<void> refreshPosts() async {
    try {
      _ref.read(currentPageProvider.notifier).state = 0;
      await getPosts(page: 0);
    } catch (e) {
      debugPrint('خطا در رفرش پست‌ها: $e');
      rethrow;
    }
  }

  /// بارگذاری پست‌های بیشتر
  Future<void> loadMorePosts() async {
    try {
      final currentPage = _ref.read(currentPageProvider);
      final nextPage = currentPage + 1;

      final newPosts = await getPosts(page: nextPage);

      if (newPosts.isNotEmpty) {
        _ref.read(currentPageProvider.notifier).state = nextPage;
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری پست‌های بیشتر: $e');
      rethrow;
    }
  }

  /// جستجو در پست‌ها
  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    try {
      if (query.isEmpty) {
        return _ref.read(cachedPostsProvider);
      }

      final supabase = Supabase.instance.client;

      // جستجو در محتوای پست‌ها
      final response = await supabase
          .from('posts')
          .select('*')
          .textSearch('content', query)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('خطا در جستجوی پست‌ها: $e');
      return [];
    }
  }

  /// دریافت پست با ID
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final supabase = Supabase.instance.client;

      final response =
          await supabase.from('posts').select('*').eq('id', postId).single();

      return response;
    } catch (e) {
      debugPrint('خطا در دریافت پست: $e');
      return null;
    }
  }

  /// پاک کردن کش پست‌ها
  void clearCache() {
    _ref.read(cachedPostsProvider.notifier).clearPosts();
    _ref.read(currentPageProvider.notifier).state = 0;
    _ref.read(postsErrorProvider.notifier).state = null;
  }

  /// گرفتن تعداد کل پست‌ها
  Future<int> getTotalPostsCount() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.from('posts').select('id').count();

      return response.count;
    } catch (e) {
      debugPrint('خطا در دریافت تعداد پست‌ها: $e');
      return 0;
    }
  }

  /// به‌روزرسانی یک پست در کش
  void updatePostInCache(Map<String, dynamic> updatedPost) {
    _ref.read(cachedPostsProvider.notifier).updatePost(updatedPost);
  }

  /// حذف پست از کش
  void removePostFromCache(String postId) {
    final currentPosts = _ref.read(cachedPostsProvider);
    final updatedPosts =
        currentPosts.where((post) => post['id'] != postId).toList();

    // استفاده از clearPosts و addPosts برای اجتناب از دسترسی مستقیم به state
    _ref.read(cachedPostsProvider.notifier).clearPosts();
    _ref.read(cachedPostsProvider.notifier).addPosts(updatedPosts);
  }

  /// دریافت پست‌های کاربر
  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('خطا در دریافت پست‌های کاربر: $e');
      return [];
    }
  }

  /// مشاهده تعداد view یک پست
  Future<void> incrementPostView(String postId) async {
    try {
      final supabase = Supabase.instance.client;

      // افزایش view count پست
      await supabase.rpc('increment_post_views', params: {
        'post_id': postId,
      });

      // به‌روزرسانی کش محلی
      final cachedPosts = _ref.read(cachedPostsProvider);
      final postIndex = cachedPosts.indexWhere((post) => post['id'] == postId);

      if (postIndex != -1) {
        final updatedPost = Map<String, dynamic>.from(cachedPosts[postIndex]);
        updatedPost['views_count'] = (updatedPost['views_count'] ?? 0) + 1;
        updatePostInCache(updatedPost);
      }
    } catch (e) {
      debugPrint('خطا در افزایش تعداد مشاهده: $e');
    }
  }
}

/// Provider برای PostController
final postControllerProvider = Provider<PostController>((ref) {
  final postService = ref.read(postServiceProvider);
  return PostController(postService, ref);
});

/// Provider برای مدیریت وضعیت صفحه اصلی پست‌ها
final homePostsProvider =
    StateNotifierProvider<HomePostsNotifier, HomePostsState>((ref) {
  return HomePostsNotifier(ref);
});

/// State برای مدیریت پست‌های صفحه اصلی
class HomePostsState {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const HomePostsState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  HomePostsState copyWith({
    List<Map<String, dynamic>>? posts,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return HomePostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Notifier برای مدیریت وضعیت پست‌های صفحه اصلی
class HomePostsNotifier extends StateNotifier<HomePostsState> {
  final Ref _ref;

  HomePostsNotifier(this._ref) : super(const HomePostsState());

  /// بارگذاری پست‌های اولیه
  Future<void> loadInitialPosts() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final controller = _ref.read(postControllerProvider);
      final posts = await controller.getPosts(page: 0);

      state = state.copyWith(
        posts: posts,
        isLoading: false,
        currentPage: 0,
        hasMore: posts.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// بارگذاری پست‌های بیشتر
  Future<void> loadMorePosts() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final controller = _ref.read(postControllerProvider);
      final nextPage = state.currentPage + 1;
      final newPosts = await controller.getPosts(page: nextPage);

      if (newPosts.isNotEmpty) {
        state = state.copyWith(
          posts: [...state.posts, ...newPosts],
          isLoading: false,
          currentPage: nextPage,
          hasMore: newPosts.length >= 20,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          hasMore: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// رفرش پست‌ها
  Future<void> refreshPosts() async {
    state = const HomePostsState(isLoading: true);
    await loadInitialPosts();
  }

  /// به‌روزرسانی یک پست
  void updatePost(Map<String, dynamic> updatedPost) {
    final posts = List<Map<String, dynamic>>.from(state.posts);
    final index = posts.indexWhere((post) => post['id'] == updatedPost['id']);

    if (index != -1) {
      posts[index] = updatedPost;
      state = state.copyWith(posts: posts);
    }
  }

  /// حذف یک پست
  void removePost(String postId) {
    final posts = state.posts.where((post) => post['id'] != postId).toList();
    state = state.copyWith(posts: posts);
  }
}
