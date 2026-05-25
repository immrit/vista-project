import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/services/video_preload_service.dart';
// import 'package:Vista/view/widgets/VideoPlayerConfig.dart';
import 'package:Vista/model/ProfileModel.dart';
// import 'package:Vista/model/notificationModel.dart';
import 'package:Vista/model/publicPostModel.dart';
import 'package:Vista/services/user_friendly_error_handler.dart';
import 'package:Vista/features/profile/data/profile_repository.dart';
import 'package:Vista/features/posts/data/go_posts_repository.dart';
// Import security provider

import 'package:Vista/provider/general_provider.dart';
import 'package:Vista/features/profile/providers/user_profile_provider.dart';
export 'package:Vista/provider/security_provider.dart';
export 'package:Vista/features/auth/providers/auth_controller.dart';

export 'package:Vista/features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

final fetchPublicPosts = FutureProvider<List<PublicPostModel>>((ref) async {
  return GoPostsRepository().getFeed(limit: 50, offset: 0);
});

final postsProvider = StateProvider<List<PublicPostModel>>((ref) {
  final posts = ref.watch(fetchPublicPosts);
  return posts.value ?? [];
});

class PublicPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final int _limit = 15;
  dynamic _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  PublicPostsNotifier() : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    await _loadMorePosts(replace: true);
  }

  Future<void> _loadMorePosts({bool replace = false}) async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;

    try {
      final posts = await _postsRepository.getFeed(
        limit: _limit,
        offset: _offset,
      );
      if (posts.isNotEmpty) {
        _offset = posts.last.createdAt.toUtc().toIso8601String();
      }
      _hasMore = posts.length == _limit;

      if (replace) {
        state = AsyncValue.data(posts);
      } else {
        final currentPosts = state.value ?? [];
        state = AsyncValue.data([...currentPosts, ...posts]);
      }

      // پیش‌بارگذاری ویدیوها در پس‌زمینه
      final videoUrls = posts
          .map((p) => p.videoUrl)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();
      VideoPreloadService().preloadVideos(videoUrls);
    } catch (e, stackTrace) {
      UserFriendlyErrorHandler.logError(
        e,
        context: 'posts_loading',
        stackTrace: stackTrace,
      );
      final errorMessage = UserFriendlyErrorHandler.getFriendlyMessage(
        e,
        context: 'posts_loading',
      );
      state = AsyncValue.error(errorMessage, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  bool hasMorePosts() => _hasMore;
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
        final current = posts[index];
        final updatedPost = current.copyWith(
          isLiked: isLiked,
          likeCount: isLiked
              ? current.likeCount + 1
              : (current.likeCount > 0 ? current.likeCount - 1 : 0),
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
    PublicPostModel? currentPost;
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      currentPost = currentPosts[postIndex];
      final optimisticLiked = !currentPost.isLiked;
      ref.read(likeStateProvider.notifier).updateLikeState(
            postId,
            optimisticLiked,
          );
      updatePost(
        currentPost.copyWith(
          isLiked: optimisticLiked,
          likeCount: optimisticLiked
              ? currentPost.likeCount + 1
              : (currentPost.likeCount > 0 ? currentPost.likeCount - 1 : 0),
        ),
      );
    }

    try {
      final result = await _postsRepository.toggleLike(
        postId: postId,
        ownerId: ownerId,
      );
      ref.read(likeStateProvider.notifier).updateLikeState(
            postId,
            result.isLiked,
          );

      if (currentPost != null) {
        final updatedPost = currentPost.copyWith(
          isLiked: result.isLiked,
          likeCount: result.likeCount,
        );
        updatePost(updatedPost);
        if (ref.exists(userProfileProvider(ownerId))) {
          ref
              .read(userProfileProvider(ownerId).notifier)
              .updatePost(updatedPost);
        }
      }
    } catch (e) {
      if (currentPost != null) {
        updatePost(currentPost);
        ref.read(likeStateProvider.notifier).updateLikeState(
              postId,
              currentPost.isLiked,
            );
      }
      debugPrint('Error in toggleLike: $e');
      rethrow;
    }
  }
}

final publicPostsProvider = StateNotifierProvider<PublicPostsNotifier,
    AsyncValue<List<PublicPostModel>>>((ref) {
  return PublicPostsNotifier();
});

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
    ref.invalidate(fetchPublicPosts);
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
    ref.invalidate(fetchPublicPosts);
    ref.invalidate(publicPostsProvider);
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

  FollowingPostsNotifier() : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    await _loadMorePosts(replace: true);
  }

  Future<void> _loadMorePosts({bool replace = false}) async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;
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
      state = AsyncValue.error(e, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() => _loadMorePosts();
  Future<void> refresh() => _loadInitialPosts();
  Future<void> loadMorePosts() => _loadMorePosts();
  Future<void> refreshPosts() => _loadInitialPosts();
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
