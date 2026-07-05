import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../model/publicPostModel.dart';

class FeedDisplayError implements Exception {
  final String message;
  final bool retriable;
  final bool requiresReauth;

  const FeedDisplayError({
    required this.message,
    this.retriable = true,
    this.requiresReauth = false,
  });

  factory FeedDisplayError.from(Object error) {
    return const FeedDisplayError(
      message: 'بارگذاری پست‌ها با خطا مواجه شد. لطفا دوباره تلاش کنید.',
      retriable: true,
    );
  }

  @override
  String toString() => message;
}

/// "For You" feed powered by vista-backend.
///
/// Pagination model (v1):
/// - Each request returns up to `_limit` NEW items (server dedupes via user_feed_seen)
/// - Client simply asks for "more" and appends.
class PersonalizedFeedNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final GoPostsRepository _repo;

  PersonalizedFeedNotifier(this._repo) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  final int _limit = 15;
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  FeedDisplayError? _loadMoreError;

  bool hasMorePosts() => _hasMore;
  bool isLoading() => _isLoading;

  /// Non-null when a *pagination* (load-more) request failed while the feed
  /// already had content. The loaded posts are kept; the UI shows an inline
  /// retry row instead of wiping the feed. See [retryLoadMore].
  FeedDisplayError? get loadMoreError => _loadMoreError;

  /// Update follow status for all posts by a specific author in the current feed.
  /// This is used for optimistic UI updates on the "Follow" button in the For You tab.
  void setAuthorFollowStatus(String authorId, String status) {
    final current = state.value;
    if (current == null || current.isEmpty) return;

    final updated = current
        .map((p) =>
            p.userId == authorId ? p.copyWith(authorFollowStatus: status) : p)
        .toList();
    state = AsyncValue.data(updated);
  }

  Future<void> _loadInitial() async {
    state = const AsyncValue.loading();
    _hasMore = true;
    _isLoading = false;
    _offset = 0;
    _loadMoreError = null;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _loadMoreError = null;

    try {
      final items = await _repo.exploreFeed(limit: _limit, offset: _offset);
      _offset += items.length;
      _hasMore = items.length == _limit;

      final current = state.value ?? const <PublicPostModel>[];
      state = AsyncValue.data([...current, ...items]);
    } catch (e, st) {
      final current = state.value ?? const <PublicPostModel>[];
      if (current.isEmpty) {
        // Initial load failed and nothing is shown — a full error state is
        // the correct UX here.
        state = AsyncValue.error(FeedDisplayError.from(e), st);
      } else {
        // Pagination failed but we already have a populated feed. NEVER wipe
        // loaded content (§3.2/§8.3): keep it and flag an inline, retriable
        // tail error.
        _loadMoreError = FeedDisplayError.from(e);
        state = AsyncValue.data(current);
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshPosts() async {
    await _loadInitial();
  }

  /// Locally inserts a just-created post at the top of the feed.
  ///
  /// The `/explore` backend query explicitly excludes the viewer's own posts
  /// (it's a recommendation feed), so a freshly published post would never
  /// show up here on its own — this is the client-side workaround so authors
  /// immediately see their own post like they would on Instagram/Twitter.
  void prependOwnPost(PublicPostModel post) {
    final current = state;
    if (current is! AsyncData<List<PublicPostModel>>) return;
    final posts = current.value;
    if (posts.any((p) => p.id == post.id)) return;
    state = AsyncValue.data([post, ...posts]);
  }

  Future<void> loadMorePosts() async {
    // Don't auto-hammer the backend after a tail failure; wait for explicit
    // retry via [retryLoadMore].
    if (_loadMoreError != null) return;
    await _loadMore();
  }

  /// Retry a failed pagination request, keeping the already-loaded feed.
  Future<void> retryLoadMore() async {
    _loadMoreError = null;
    final current = state.value ?? const <PublicPostModel>[];
    state = AsyncValue.data(current); // re-emit so the row shows a spinner
    await _loadMore();
  }
}

final personalizedFeedProvider = StateNotifierProvider<PersonalizedFeedNotifier,
    AsyncValue<List<PublicPostModel>>>((ref) {
  final repo = ref.watch(goPostsRepositoryProvider);
  return PersonalizedFeedNotifier(repo);
});
