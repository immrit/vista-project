import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/post_service.dart';

final postServiceProvider = Provider<PostService>((ref) {
  return PostService();
});

final postsWithEngagementProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, page) async {
  final postService = ref.read(postServiceProvider);
  final limit = 20;
  final offset = page * limit;

  // استفاده از VIEW برای بهترین عملکرد
  return await postService.getPostsWithEngagement(limit: limit, offset: offset);
});

// Provider برای مدیریت وضعیت بارگذاری
final postsLoadingProvider = StateProvider<bool>((ref) => false);

// Provider برای مدیریت خطاها
final postsErrorProvider = StateProvider<String?>((ref) => null);

// Provider برای مدیریت صفحه فعلی
final currentPageProvider = StateProvider<int>((ref) => 0);

// Provider برای مدیریت پست‌های کش شده
final cachedPostsProvider =
    StateNotifierProvider<CachedPostsNotifier, List<Map<String, dynamic>>>(
        (ref) {
  return CachedPostsNotifier();
});

class CachedPostsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CachedPostsNotifier() : super([]);

  void addPosts(List<Map<String, dynamic>> newPosts) {
    state = [...state, ...newPosts];
  }

  void clearPosts() {
    state = [];
  }

  void updatePost(Map<String, dynamic> updatedPost) {
    final index = state.indexWhere((post) => post['id'] == updatedPost['id']);
    if (index != -1) {
      final newState = List<Map<String, dynamic>>.from(state);
      newState[index] = updatedPost;
      state = newState;
    }
  }
}
