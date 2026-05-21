import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/publicPostModel.dart';
import '../data/go_posts_repository.dart';

final savedPostsRepositoryProvider = Provider<SavedPostsRepository>((ref) {
  return SavedPostsRepository(ref.read(goPostsRepositoryProvider));
});

class SavedPostsRepository {
  final GoPostsRepository _postsRepository;

  SavedPostsRepository(this._postsRepository);

  Future<void> savePost(String postId) async {
    await _postsRepository.setSaved(postId, true);
  }

  Future<void> unsavePost(String postId) async {
    await _postsRepository.setSaved(postId, false);
  }

  Future<Set<String>> getSavedPostIds({
    int limit = 500,
    int offset = 0,
  }) async {
    return _postsRepository.getSavedPostIds(limit: limit, offset: offset);
  }

  Future<List<PublicPostModel>> getSavedPosts({
    required int limit,
    required int offset,
  }) async {
    return _postsRepository.getSavedPosts(limit: limit, offset: offset);
  }
}

class SavedPostsState {
  final List<PublicPostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const SavedPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  SavedPostsState copyWith({
    List<PublicPostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return SavedPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SavedPostsNotifier extends StateNotifier<SavedPostsState> {
  final Ref _ref;
  static const int _pageSize = 20;
  int _offset = 0;

  SavedPostsNotifier(this._ref)
      : super(const SavedPostsState(isLoading: true)) {
    refresh();
  }

  SavedPostsRepository get _repo => _ref.read(savedPostsRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      clearError: true,
      posts: const [],
    );
    _offset = 0;
    try {
      final posts = await _repo.getSavedPosts(limit: _pageSize, offset: 0);
      _offset = posts.length;
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final next = await _repo.getSavedPosts(limit: _pageSize, offset: _offset);
      _offset += next.length;
      state = state.copyWith(
        isLoadingMore: false,
        hasMore: next.length == _pageSize,
        posts: [...state.posts, ...next],
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void removePostLocally(String postId) {
    state = state.copyWith(
      posts: state.posts.where((post) => post.id != postId).toList(),
    );
  }

  void prependPostLocally(PublicPostModel post) {
    if (state.posts.any((item) => item.id == post.id)) return;
    state = state.copyWith(posts: [post, ...state.posts]);
  }
}

final savedPostsProvider =
    StateNotifierProvider<SavedPostsNotifier, SavedPostsState>((ref) {
  return SavedPostsNotifier(ref);
});

class SavedPostIdsNotifier extends StateNotifier<AsyncValue<Set<String>>> {
  final Ref _ref;

  SavedPostIdsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  SavedPostsRepository get _repo => _ref.read(savedPostsRepositoryProvider);

  Future<void> load() async {
    try {
      final ids = await _repo.getSavedPostIds();
      state = AsyncValue.data(ids);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  bool isSaved(String postId) {
    final value = state.value;
    return value?.contains(postId) ?? false;
  }

  Future<bool> toggle(String postId, {PublicPostModel? post}) async {
    final currentIds = {...?state.value};
    final shouldSave = !currentIds.contains(postId);
    if (shouldSave) {
      currentIds.add(postId);
    } else {
      currentIds.remove(postId);
    }
    state = AsyncValue.data(currentIds);

    try {
      if (shouldSave) {
        await _repo.savePost(postId);
        if (post != null) {
          _ref.read(savedPostsProvider.notifier).prependPostLocally(post);
        }
      } else {
        await _repo.unsavePost(postId);
        _ref.read(savedPostsProvider.notifier).removePostLocally(postId);
      }
      return true;
    } catch (e) {
      final rollback = {...?state.value};
      if (shouldSave) {
        rollback.remove(postId);
      } else {
        rollback.add(postId);
      }
      state = AsyncValue.data(rollback);
      return false;
    }
  }
}

final savedPostIdsProvider =
    StateNotifierProvider<SavedPostIdsNotifier, AsyncValue<Set<String>>>((ref) {
  return SavedPostIdsNotifier(ref);
});
