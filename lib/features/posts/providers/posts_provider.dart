import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/services/video_preload_service.dart';
// import 'package:Vista/view/widgets/VideoPlayerConfig.dart';
import 'package:Vista/model/ProfileModel.dart';
// import 'package:Vista/model/notificationModel.dart';
import 'package:Vista/model/publicPostModel.dart';
import 'package:Vista/features/profile/data/profile_repository.dart';
import 'package:Vista/features/posts/data/go_posts_repository.dart';
// Import security provider

export 'package:Vista/provider/security_provider.dart';
export 'package:Vista/features/auth/providers/auth_controller.dart';

export 'package:Vista/features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

class PostActionsService {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  PostActionsService();

  Future<void> toggleLike({
    required String postId,
    required String ownerId,
    required WidgetRef ref,
  }) async {
    await _postsRepository.toggleLike(postId: postId, ownerId: ownerId);
  }

  Future<String> followUserQuick({required String targetUserId}) {
    return _postsRepository.followUserQuick(targetUserId: targetUserId);
  }

  Future<void> unfollowUser({required String targetUserId}) {
    return _postsRepository.unfollowUser(targetUserId: targetUserId);
  }

  Future<void> insertReport({
    required String postId,
    String? userId,
    String? reportedUserId,
    required String reason,
    String? additionalDetails,
  }) {
    final targetUserId = reportedUserId ?? userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      throw ArgumentError('reported user id is required');
    }
    return _postsRepository.reportPost(
      postId: postId,
      reportedUserId: targetUserId,
      reason: reason,
      additionalDetails: additionalDetails,
    );
  }

  Future<void> deletePost(WidgetRef ref, String postId) async {
    await _postsRepository.deletePost(postId);
  }

  Future<List<ProfileModel>> fetchFollowers(String userId) {
    return _profileRepository.fetchFollowers(userId);
  }

  Future<List<ProfileModel>> fetchFollowing(String userId) {
    return _profileRepository.fetchFollowing(userId);
  }

  Future<bool> isDeviceOnline() async => true;
}

final postActionsServiceProvider = Provider<PostActionsService>((ref) {
  return PostActionsService();
});

class FollowingPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final int _limit = 20;
  dynamic _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _loadMoreError;

  FollowingPostsNotifier() : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  /// Non-null when a load-more request failed while the feed already had
  /// content. Loaded posts are kept; UI shows an inline retry row instead of
  /// wiping the feed (§3.2/§8.3). See [retryLoadMore].
  Object? get loadMoreError => _loadMoreError;

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _loadMoreError = null;
    await _loadMorePosts(replace: true);
  }

  Future<void> _loadMorePosts({bool replace = false}) async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
    _loadMoreError = null;
    try {
      final posts = await _postsRepository.getFollowingFeed(
        limit: _limit,
        offset: _offset,
      );
      if (posts.isNotEmpty) {
        _offset = posts.last.createdAt.toUtc().toIso8601String();
      }
      _hasMore = posts.length == _limit;
      final current = replace ? <PublicPostModel>[] : state.value ?? [];
      state = AsyncValue.data([...current, ...posts]);

      // پیش‌بارگذاری ویدیوها در پس‌زمینه
      final videoUrls = posts
          .map((p) => p.videoUrl)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();
      VideoPreloadService().preloadVideos(videoUrls);
    } catch (e, stackTrace) {
      final current = state.value ?? const <PublicPostModel>[];
      if (current.isEmpty) {
        // Nothing loaded yet — a full error state is correct.
        state = AsyncValue.error(e, stackTrace);
      } else {
        // Keep the populated feed; surface a retriable inline tail error
        // instead of destroying loaded content.
        _loadMoreError = e;
        state = AsyncValue.data(current);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() {
    if (_loadMoreError != null) return Future.value();
    return _loadMorePosts();
  }

  Future<void> refresh() => _loadInitialPosts();

  Future<void> loadMorePosts() {
    // Don't auto-hammer the backend after a tail failure; wait for retry.
    if (_loadMoreError != null) return Future.value();
    return _loadMorePosts();
  }

  Future<void> refreshPosts() => _loadInitialPosts();

  /// Retry a failed pagination request, keeping the already-loaded feed.
  Future<void> retryLoadMore() async {
    _loadMoreError = null;
    final current = state.value ?? const <PublicPostModel>[];
    state = AsyncValue.data(current); // re-emit so the row shows a spinner
    await _loadMorePosts();
  }

  bool hasMorePosts() => _hasMore;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
}

final fetchFollowingPostsProvider = StateNotifierProvider<
    FollowingPostsNotifier, AsyncValue<List<PublicPostModel>>>((ref) {
  return FollowingPostsNotifier();
});
// final fetchFollowingPostsProvider =
//     FutureProvider<List<PublicPostModel>>((ref) async {
//   try {
//     if (currentUserId == null) return [];

//     // Check followings first
//         .from('follows')
//         .select('following_id')
//         .eq('follower_id', currentUserId);

//     if (followingResponse.isEmpty) {
//       return []; // Return empty list if no followings
//     }

//     final followingIds =
//         followingResponse.map((e) => e['following_id'] as String).toList();

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
final postProvider =
    FutureProvider.family<PublicPostModel, String>((ref, postId) async {
  return GoPostsRepository().getPost(postId);
});
