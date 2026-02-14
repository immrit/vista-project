import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../model/publicPostModel.dart';

final savedPostsRepositoryProvider = Provider<SavedPostsRepository>((ref) {
  return SavedPostsRepository(Supabase.instance.client);
});

class SavedPostsRepository {
  final SupabaseClient _supabase;

  SavedPostsRepository(this._supabase);

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const AuthException('User not logged in');
    }
    return userId;
  }

  Future<void> savePost(String postId) async {
    final userId = _requireUserId();
    await _supabase.from('user_saved_posts').upsert(
      {
        'user_id': userId,
        'post_id': postId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,post_id',
    );
  }

  Future<void> unsavePost(String postId) async {
    final userId = _requireUserId();
    await _supabase
        .from('user_saved_posts')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  Future<Set<String>> getSavedPostIds({
    int limit = 500,
    int offset = 0,
  }) async {
    final userId = _requireUserId();
    final rows = await _supabase
        .from('user_saved_posts')
        .select('post_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .map((e) => (e['post_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<PublicPostModel>> getSavedPosts({
    required int limit,
    required int offset,
  }) async {
    final userId = _requireUserId();

    final savedRows = await _supabase
        .from('user_saved_posts')
        .select('post_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    if (savedRows.isEmpty) {
      return const [];
    }

    final postIds = savedRows
        .map((e) => (e['post_id'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (postIds.isEmpty) {
      return const [];
    }

    final postsResponse = await _supabase.from('posts').select('''
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
        ''').inFilter('id', postIds);

    final postsById = <String, PublicPostModel>{};
    for (final raw in postsResponse) {
      final post = raw;
      final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};
      final postLikes = post['likes'] as List<dynamic>? ?? const [];
      final comments = post['comments'] as List<dynamic>? ?? const [];
      final model = PublicPostModel.fromMap({
        ...post,
        'like_count': postLikes.length,
        'is_liked': postLikes.any((like) => like['user_id'] == userId),
        'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
        'avatar_url': profile['avatar_url'] ?? '',
        'is_verified': profile['is_verified'] ?? false,
        'comment_count': comments.length,
        'verification_type': profile['verification_type'],
      });
      postsById[model.id] = model;
    }

    final ordered = <PublicPostModel>[];
    for (final postId in postIds) {
      final model = postsById[postId];
      if (model != null) {
        ordered.add(model);
      }
    }
    return ordered;
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
