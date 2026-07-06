import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/SearchResut.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
// import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../model/UserModel.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../services/comment_repository.dart';
import '../utils/user_friendly_error_utils.dart';
// Import security provider

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';

export '../features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

final mentionUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final profiles = await ProfileRepository().searchProfiles(
    query: '',
    limit: 20,
  );
  return profiles.map(_profileToUser).toList(growable: false);
});

class MentionService {
  final ProfileRepository _profileRepository = ProfileRepository();
  final CommentRepository _commentRepository = CommentRepository();

  Future<List<UserModel>> searchUsers(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final profiles = await _profileRepository.searchProfiles(
      query: normalizedQuery,
      limit: 10,
    );
    return profiles.map(_profileToUser).toList(growable: false);
  }

  Future<void> addMentions({
    required String commentId,
    required List<String> mentionedUserIds,
  }) {
    return _commentRepository.addMentions(
      commentId: commentId,
      userIds: mentionedUserIds,
    );
  }
}

class MentionNotifier extends StateNotifier<List<UserModel>> {
  final MentionService _mentionService;

  MentionNotifier(this._mentionService) : super([]);

  Future<void> searchMentionableUsers(String query) async {
    state = await _mentionService.searchUsers(query);
  }

  void clearMentions() {
    state = [];
  }
}

final mentionServiceProvider = Provider<MentionService>((ref) {
  return MentionService();
});

final mentionNotifierProvider =
    StateNotifierProvider<MentionNotifier, List<UserModel>>((ref) {
  return MentionNotifier(ref.read(mentionServiceProvider));
});

UserModel _profileToUser(ProfileModel profile) {
  return UserModel.fromMap(profile.toMap());
}

class SearchService {
  final GoPostsRepository _postsRepository = GoPostsRepository();

  Future<List<PublicPostModel>> searchHashtag(String hashtag) async {
    var tag = hashtag.trim();
    tag = tag.replaceFirst(RegExp(r'^#+'), '');
    tag = tag.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (tag.isEmpty) return const [];

    return _postsRepository.searchPostsByHashtag(
      hashtag: tag,
      limit: 60,
    );
  }
}

// lib/providers/search_provider.dart
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  final SearchService _searchService;
  final int _userLimit = 20;

  /// Monotonic token: each search() bumps it, and responses only apply if
  /// they still own the latest token. Without this, a slow response for an
  /// older query overwrote the results of a newer one (type "عل" → "علی";
  /// the late "عل" payload replaced the "علی" results on screen).
  int _searchRequestId = 0;

  SearchNotifier(this.ref)
      : _searchService = SearchService(),
        super(const SearchState());

  void setTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      clearAll();
      return;
    }

    final requestId = ++_searchRequestId;
    final isHashtagQuery = normalizedQuery.startsWith('#');
    state = state.copyWith(
      isLoading: true,
      isLoadingMoreUsers: false,
      currentQuery: normalizedQuery,
      userOffset: 0,
      hasMoreUsers: true,
      selectedTab: isHashtagQuery ? 2 : state.selectedTab,
      userResults: [],
      hashtagResults: [],
      clearError: true,
    );

    try {
      if (isHashtagQuery) {
        final posts = await _searchService.searchHashtag(normalizedQuery);
        if (requestId != _searchRequestId) return; // stale response
        state = state.copyWith(
          hashtagResults: posts,
          isLoading: false,
          selectedTab: 2,
        );
      } else {
        var users = const <ProfileModel>[];
        var hashtags = const <PublicPostModel>[];
        var userSearchSucceeded = true;
        String? error;

        try {
          users = await _fetchUsersPage(normalizedQuery, 0);
        } catch (e) {
          userSearchSucceeded = false;
          error = UserFriendlyErrorUtils.getUserFriendlyMessage(e);
        }

        if (_canSearchAsTag(normalizedQuery)) {
          try {
            hashtags = await _searchService.searchHashtag(normalizedQuery);
          } catch (_) {
            // Hashtag lookup is supplementary for non-# searches.
          }
        }

        if (requestId != _searchRequestId) return; // stale response
        state = state.copyWith(
          userResults: users,
          hashtagResults: hashtags,
          isLoading: false,
          selectedTab: 0,
          userOffset: users.length,
          hasMoreUsers: userSearchSucceeded && users.length >= _userLimit,
          error: error,
          clearError: error == null,
        );
      }
    } catch (e) {
      if (requestId != _searchRequestId) return; // stale response
      state = state.copyWith(
        error: UserFriendlyErrorUtils.getUserFriendlyMessage(e),
        isLoading: false,
        isLoadingMoreUsers: false,
      );
    }
  }

  Future<void> loadMoreUsers() async {
    if (!state.hasMoreUsers ||
        state.isLoading ||
        state.isLoadingMoreUsers ||
        state.currentQuery.isEmpty ||
        state.currentQuery.startsWith('#')) {
      return;
    }

    final requestId = _searchRequestId;
    final queryAtRequest = state.currentQuery;
    state = state.copyWith(isLoadingMoreUsers: true, clearError: true);
    try {
      final newUsers =
          await _fetchUsersPage(queryAtRequest, state.userOffset);
      // A newer search replaced the results while this page was in flight —
      // appending would mix result sets from two different queries.
      if (requestId != _searchRequestId ||
          state.currentQuery != queryAtRequest) {
        return;
      }
      final allUsers = [...state.userResults, ...newUsers];

      state = state.copyWith(
        userResults: allUsers,
        isLoadingMoreUsers: false,
        userOffset: state.userOffset + newUsers.length,
        hasMoreUsers: newUsers.length >= _userLimit,
      );
    } catch (e) {
      if (requestId != _searchRequestId) return;
      state = state.copyWith(
        isLoadingMoreUsers: false,
        error: UserFriendlyErrorUtils.getUserFriendlyMessage(e),
      );
    }
  }

  Future<List<ProfileModel>> _fetchUsersPage(String query, int offset) async {
    // ترتیب relevance سرور را دست‌نخورده نگه می‌داریم. مرتب‌سازی per-page بر
    // اساس تیک، ترتیب صفحات را می‌شکست: تیک‌دارِ صفحه‌ی ۲ زیر عادی‌های
    // صفحه‌ی ۱ می‌نشست و لیست موقع load-more می‌پرید.
    return ProfileRepository().searchProfiles(
      query: query,
      limit: _userLimit,
      offset: offset,
    );
  }

  bool _canSearchAsTag(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return false;
    if (normalized.startsWith('#')) return true;
    if (normalized.contains(' ')) return false;
    return RegExp(r'^[\u0600-\u06FFA-Za-z0-9_]+$').hasMatch(normalized);
  }

  void clearAll() {
    _searchRequestId++; // invalidate any in-flight responses
    state = state.copyWith(
      hashtagResults: [],
      userResults: [],
      isLoading: false,
      isLoadingMoreUsers: false,
      currentQuery: '',
      userOffset: 0,
      hasMoreUsers: true,
      selectedTab: 0,
      clearError: true,
    );
  }

  Future<void> retry() async {
    final query = state.currentQuery;
    if (query.isEmpty) return;
    await search(query);
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
