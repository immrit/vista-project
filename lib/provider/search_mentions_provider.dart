import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'package:Vista/widgets/VideoPlayerConfig.dart';
import 'package:path_provider/path_provider.dart';
import '../DB/profile_cache_service.dart';
import '../DB/settings_cache_service.dart';
import '../services/animation_controller_service.dart';
import '../services/video_autoplay_service.dart';
import '../services/image_quality_service.dart';
import '../core/data/cache/cache_repository.dart';
import '../model/SearchResut.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
// import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import '../widgets/verification_badge_icon.dart';
import 'package:Vista/utils/themes.dart';
import '../services/user_friendly_error_handler.dart';
import '../services/voice_cache_service.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/services/profile_note_service.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../features/stories/data/repositories/story_repository.dart';
import '../services/comment_repository.dart';
import 'notification_provider.dart' as go_notifications;
// Import security provider

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';

export '../features/profile/providers/profile_controller.dart';
import '../features/profile/providers/profile_controller.dart';
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
    try {
      var tag = hashtag.trim();
      tag = tag.replaceFirst(RegExp(r'^#+'), '');
      tag = tag.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      if (tag.isEmpty) return const [];

      return await _postsRepository.searchPostsByHashtag(
        hashtag: tag,
        limit: 60,
      );
    } catch (e) {
      print('Error in searchHashtag: $e');
      return const [];
    }
  }
}

// lib/providers/search_provider.dart
class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  final SearchService _searchService;
  final int _userLimit = 20;

  SearchNotifier(this.ref)
      : _searchService = SearchService(),
        super(const SearchState());

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
        userOffset: 0,
        hasMoreUsers: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      currentQuery: query,
      userOffset: 0,
      hasMoreUsers: true,
      userResults: [], // Clear previous results
    );

    try {
      if (query.startsWith('#')) {
        final posts = await _searchService.searchHashtag(query);
        state = state.copyWith(
          hashtagResults: posts,
          isLoading: false,
          selectedTab: 1,
        );
      } else {
        await _fetchUsers(query, 0);
        state = state.copyWith(selectedTab: 0);
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> loadMoreUsers() async {
    if (!state.hasMoreUsers || state.isLoading) return;

    // Avoid rapid duplicate calls (optional debouncing could go here)
    // For now relies on isLoading=true from search, but loadMore logic needs its own loading state?
    // Using simple approach: assume UI triggers carefully or we check if fetching.
    // Actually, 'isLoading' usually blocks the whole UI. For infinite scroll, we often want a bottom spinner.
    // Let's assume the UI handles the debounce.

    await _fetchUsers(state.currentQuery, state.userOffset);
  }

  Future<void> _fetchUsers(String query, int offset) async {
    try {
      final newUsers = await ProfileRepository().searchProfiles(
        query: query,
        limit: _userLimit,
        offset: offset,
      );

      // Client-side sort for fine-grained priority (Blue > Gold > Normal)
      newUsers.sort((a, b) {
        int getScore(ProfileModel p) {
          if (p.hasBlueBadge) return 3;
          if (p.hasGoldBadge) return 2;
          return 1;
        }

        return getScore(b).compareTo(getScore(a));
      });

      final allUsers = [...state.userResults, ...newUsers];
      // Re-sort entire list?
      // Ideally yes, to ensure if a high priority user comes in late (unlikely due to DB sort) they bubble up.
      // But DB sort 'is_verified' puts all verified first.
      // So 'newUsers' will mostly be unverified if we passed the verified block.
      // So simple append is fine.

      state = state.copyWith(
        userResults: allUsers,
        isLoading: false,
        userOffset: offset + newUsers.length,
        hasMoreUsers: newUsers.length >= _userLimit,
      );
    } catch (e) {
      print('Error fetching users: $e');
      // Update state to stop loading
      state = state.copyWith(isLoading: false);
    }
  }

  void clearHashtagResults() {
    state = state.copyWith(hashtagResults: []);
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
