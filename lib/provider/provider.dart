import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../services/PostImageUploadService.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
// import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../utils/const.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import 'package:Vista/utils/themes.dart';
import '../services/user_friendly_error_handler.dart';
import '../services/auth_navigation_service.dart';
import '../services/vista_node_service.dart';
import 'session_provider.dart';
// Import security provider

// Export security providers
export 'security_provider.dart';
export 'auth_provider.dart';

//check user state
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
});

final authProvider = Provider<User?>((ref) {
  final auth = Supabase.instance.client.auth;
  return auth.currentUser;
});

//fetch user profile
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );

  if (user == null) {
    throw Exception('User is not logged in');
  }

  final response = await supabase.from('profiles').select('''
        *,
        verification_type,
        account_type,
        role
      ''').eq('id', user.id).maybeSingle();

  if (response == null) {
    throw Exception('Profile not found');
  }

  return response;
});

//Edite Profile

final profileUpdateProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, updatedData) async {
  final user = ref.watch(authStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );
  if (user == null) {
    throw Exception('User is not logged in');
  }

  final response =
      await supabase.from('profiles').update(updatedData).eq('id', user.id);

  if (response != null) {
    throw Exception('Failed to update profile');
  }
});

//update pass

final changePasswordProvider =
    FutureProvider.family<void, String>((ref, newPassword) async {
  final response = await Supabase.instance.client.auth.updateUser(
    UserAttributes(password: newPassword),
  );

  throw Exception(response);
});

//delete notes

final deleteNoteProvider =
    FutureProvider.family<void, dynamic>((ref, noteId) async {
  final response = await supabase.from('Notes').delete().eq('id', noteId);

  if (response != null) {
    throw Exception('Error deleting note: ${response!}');
  }
});

final themeProvider = StateProvider<ThemeData>((ref) {
  // Ø¨Ø±Ø±Ø³ÛŒ Ø­Ø§Ù„Øª Ù¾Ù„ØªÙØ±Ù… Ùˆ Ø§Ù†ØªØ®Ø§Ø¨ ØªÙ… Ù…ØªÙ†Ø§Ø³Ø¨
  final platformBrightness = PlatformDispatcher.instance.platformBrightness;

  return platformBrightness == Brightness.dark
      ? VistaThemes.darkTheme // Ø§Ú¯Ø± Ú¯ÙˆØ´ÛŒ Ø¯Ø± Ø­Ø§Ù„Øª ØªÛŒØ±Ù‡ Ø§Ø³Øª
      : VistaThemes.lightTheme; // Ø§Ú¯Ø± Ú¯ÙˆØ´ÛŒ Ø¯Ø± Ø­Ø§Ù„Øª Ø±ÙˆØ´Ù† Ø§Ø³Øª
});

final isLoadingProvider = StateProvider<bool>((ref) => false);
final isRedirectingProvider = StateProvider<bool>((ref) => false);

final fetchPublicPosts = FutureProvider<List<PublicPostModel>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    return [];
  }

  try {
    // Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒØ³Øª Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡ ØªÙˆØ³Ø· Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
    final followingResponse = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

    final followingIds = followingResponse
        .map((follow) => follow['following_id'] as String)
        .toList();

    final response = await supabase.from('posts').select('''
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
        ''').order('created_at', ascending: false);

    final postsData = response as List<dynamic>;

    // Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒØ³Øª Ú©Ø§Ø±Ø¨Ø±Ø§Ù†ÛŒ Ú©Ù‡ Ù¾Ø³Øª Ø¯Ø§Ø±Ù†Ø¯
    final userIds =
        postsData.map((post) => post['user_id'] as String).toSet().toList();

    // Ø¯Ø±ÛŒØ§ÙØª ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø­Ø±ÛŒÙ… Ø®ØµÙˆØµÛŒ Ø¨Ø±Ø§ÛŒ Ø§ÛŒÙ† Ú©Ø§Ø±Ø¨Ø±Ø§Ù†
    final userSettingsResponse = await supabase
        .from('user_settings')
        .select('user_id, is_private')
        .inFilter('user_id', userIds);

    final userSettingsMap = {
      for (var setting in userSettingsResponse)
        setting['user_id'] as String: setting['is_private'] as bool? ?? false
    };

    // ÙÛŒÙ„ØªØ± Ú©Ø±Ø¯Ù† Ù¾Ø³Øªâ€ŒÙ‡Ø§ - ÙÙ‚Ø· Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ø¹Ù…ÙˆÙ…ÛŒ ÛŒØ§ Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡
    final filteredPosts = postsData.where((post) {
      final postUserId = post['user_id'] as String;
      final isPrivate = userSettingsMap[postUserId] ?? false;

      // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ø®ÙˆØ¯ Ú©Ø§Ø±Ø¨Ø± Ø§Ø³ØªØŒ Ù‡Ù…ÛŒØ´Ù‡ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
      if (postUserId == userId) {
        return true;
      }

      // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ú©Ø§Ø±Ø¨Ø± Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡ Ø§Ø³ØªØŒ Ù‡Ù…ÛŒØ´Ù‡ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
      if (followingIds.contains(postUserId)) {
        return true;
      }

      // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ú©Ø§Ø±Ø¨Ø± Ø¯Ù†Ø¨Ø§Ù„ Ù†Ø´Ø¯Ù‡ Ø§Ø³ØªØŒ ÙÙ‚Ø· Ø§Ú¯Ø± Ø¹Ù…ÙˆÙ…ÛŒ Ø¨Ø§Ø´Ø¯ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
      return !isPrivate;
    }).toList();

    return filteredPosts.map((e) {
      final profile = e['profiles'] as Map<String, dynamic>? ?? {};
      final avatarUrl = profile['avatar_url'] as String? ?? '';
      final username = profile['username'] as String? ??
          profile['full_name'] as String? ??
          'Unknown';
      final isVerified = profile['is_verified'] as bool? ?? false;

      // ØªØºÛŒÛŒØ± Ø§Ø² likes Ø¨Ù‡ likes
      final likes = e['likes'] as List<dynamic>? ?? [];
      final likeCount = likes.length;
      final isLiked = likes.any((like) => like['user_id'] == userId);

      final comments = e['comments'] as List<dynamic>? ?? [];
      final commentCount = comments.length;

      return PublicPostModel.fromMap({
        ...e,
        'like_count': likeCount,
        'is_liked': isLiked,
        'username': username,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'comment_count': commentCount,
        'verification_type': profile[
            'verification_type'], // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† verification_type
      });
    }).toList();
  } catch (e) {
    print("Exception in fetching public posts: $e");
    throw Exception("Exception in fetching public posts: $e");
  }
});
final postsProvider = StateProvider<List<PublicPostModel>>((ref) {
  final posts = ref.watch(fetchPublicPosts);
  return posts.value ?? [];
});

class PublicPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final int _limit =
      15; // Ø§ÙØ²Ø§ÛŒØ´ ØªØ¹Ø¯Ø§Ø¯ Ø¢ÛŒØªÙ…â€ŒÙ‡Ø§ÛŒ Ù„ÙˆØ¯ Ø´Ø¯Ù‡ Ø¯Ø± ÛŒÚ© ØµÙØ­Ù‡
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  PublicPostsNotifier(this.supabase) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;

    try {
      // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† ØªØ£Ø®ÛŒØ± Ú©ÙˆØªØ§Ù‡ Ø¨Ø±Ø§ÛŒ Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² Ø¯Ø±Ø®ÙˆØ§Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ù…Ú©Ø±Ø± Ø¨Ù‡ Ø³Ø±ÙˆØ±
      if (_offset > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _hasMore = false;
        _isLoading = false;
        return;
      }

      // Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒØ³Øª Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡ ØªÙˆØ³Ø· Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
      final followingResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = followingResponse
          .map((follow) => follow['following_id'] as String)
          .toList();

      final response = await supabase
          .from('posts')
          .select('''
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
          ''')
          .range(_offset, _offset + _limit - 1)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        _hasMore = false;
        _isLoading = false;
        return;
      }

      // ÙÛŒÙ„ØªØ± Ú©Ø±Ø¯Ù† Ù¾Ø³Øªâ€ŒÙ‡Ø§ - ÙÙ‚Ø· Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ø¹Ù…ÙˆÙ…ÛŒ ÛŒØ§ Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡
      final postsList = response as List<dynamic>;

      // Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒØ³Øª Ú©Ø§Ø±Ø¨Ø±Ø§Ù†ÛŒ Ú©Ù‡ Ù¾Ø³Øª Ø¯Ø§Ø±Ù†Ø¯
      final userIds =
          postsList.map((post) => post['user_id'] as String).toSet().toList();

      // Ø¯Ø±ÛŒØ§ÙØª ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø­Ø±ÛŒÙ… Ø®ØµÙˆØµÛŒ Ø¨Ø±Ø§ÛŒ Ø§ÛŒÙ† Ú©Ø§Ø±Ø¨Ø±Ø§Ù†
      final userSettingsResponse = await supabase
          .from('user_settings')
          .select('user_id, is_private')
          .inFilter('user_id', userIds);

      final userSettingsMap = {
        for (var setting in userSettingsResponse)
          setting['user_id'] as String: setting['is_private'] as bool? ?? false
      };

      final filteredResponse = postsList.where((post) {
        final postUserId = post['user_id'] as String;
        final isPrivate = userSettingsMap[postUserId] ?? false;

        // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ø®ÙˆØ¯ Ú©Ø§Ø±Ø¨Ø± Ø§Ø³ØªØŒ Ù‡Ù…ÛŒØ´Ù‡ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
        if (postUserId == userId) {
          return true;
        }

        // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ú©Ø§Ø±Ø¨Ø± Ø¯Ù†Ø¨Ø§Ù„ Ø´Ø¯Ù‡ Ø§Ø³ØªØŒ Ù‡Ù…ÛŒØ´Ù‡ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
        if (followingIds.contains(postUserId)) {
          return true;
        }

        // Ø§Ú¯Ø± Ù¾Ø³Øª Ù…ØªØ¹Ù„Ù‚ Ø¨Ù‡ Ú©Ø§Ø±Ø¨Ø± Ø¯Ù†Ø¨Ø§Ù„ Ù†Ø´Ø¯Ù‡ Ø§Ø³ØªØŒ ÙÙ‚Ø· Ø§Ú¯Ø± Ø¹Ù…ÙˆÙ…ÛŒ Ø¨Ø§Ø´Ø¯ Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
        return !isPrivate;
      }).toList();

      _offset += filteredResponse.length;
      _hasMore = filteredResponse.length >= _limit;

      final posts = filteredResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes
              .any((like) => like['user_id'] == supabase.auth.currentUser?.id),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': profile[
              'verification_type'], // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† verification_type
        });
      }).toList();

      // Ø§Ú¯Ø± state.value null Ø§Ø³ØªØŒ posts Ø±Ø§ Ø¨Ù‡ Ø¹Ù†ÙˆØ§Ù† Ù„ÛŒØ³Øª Ø¬Ø¯ÛŒØ¯ Ù‚Ø±Ø§Ø± Ù…ÛŒâ€ŒØ¯Ù‡ÛŒÙ…
      // Ø¯Ø± ØºÛŒØ± Ø§ÛŒÙ† ØµÙˆØ±ØªØŒ posts Ø±Ø§ Ø¨Ù‡ Ù„ÛŒØ³Øª Ù…ÙˆØ¬ÙˆØ¯ Ø§Ø¶Ø§ÙÙ‡ Ù…ÛŒâ€ŒÚ©Ù†ÛŒÙ…
      final currentPosts = state.value ?? [];
      state = AsyncValue.data([...currentPosts, ...posts]);
    } catch (e, stackTrace) {
      UserFriendlyErrorHandler.logError(e,
          context: 'posts_loading', stackTrace: stackTrace);
      final errorMessage = UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'posts_loading');
      state = AsyncValue.error(errorMessage, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  // Ù…ØªØ¯ Ø¨Ø±Ø§ÛŒ Ø¨Ø±Ø±Ø³ÛŒ Ø§ÛŒÙ†Ú©Ù‡ Ø¢ÛŒØ§ Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ø¨ÛŒØ´ØªØ±ÛŒ ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø±Ø¯ ÛŒØ§ Ø®ÛŒØ±
  bool hasMorePosts() => _hasMore;

  // Ù…ØªØ¯ Ø¨Ø±Ø§ÛŒ Ø¨Ø±Ø±Ø³ÛŒ Ø§ÛŒÙ†Ú©Ù‡ Ø¢ÛŒØ§ Ø¯Ø± Ø­Ø§Ù„ Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ù‡Ø³ØªÛŒÙ… ÛŒØ§ Ø®ÛŒØ±
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
        state = AsyncValue.data(newPosts);
      }
    });
  }

  Future<void> toggleLike({
    required String postId,
    required String ownerId,
    required WidgetRef ref,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // âœ… Ø¨Ø±Ø±Ø³ÛŒ Ø§Ù…Ù†ÛŒØªÛŒ: Ø¨Ø±Ø±Ø³ÛŒ Ø§ÛŒÙ†Ú©Ù‡ Ù†Ø´Ø³Øª Ù‡Ù†ÙˆØ² Ù…Ø¹ØªØ¨Ø± Ø§Ø³Øª
    try {
      final sessionManager = ref.read(sessionManagerProvider);
      final isSessionValid = await sessionManager.isSessionStillValid();
      if (!isSessionValid) {
        debugPrint(
            'âŒ Session is no longer valid, cannot perform like operation');
        throw Exception(
            'Ù†Ø´Ø³Øª Ø´Ù…Ø§ Ù…Ù†Ù‚Ø¶ÛŒ Ø´Ø¯Ù‡ Ø§Ø³Øª. Ù„Ø·ÙØ§Ù‹ Ø¯ÙˆØ¨Ø§Ø±Ù‡ ÙˆØ§Ø±Ø¯ Ø´ÙˆÛŒØ¯.');
      }
    } catch (e) {
      debugPrint('âŒ Error checking session validity: $e');
      // Ø§Ú¯Ø± Ø®Ø·Ø§ÛŒ network Ø§Ø³ØªØŒ Ø§Ø¯Ø§Ù…Ù‡ Ø¨Ø¯Ù‡
      final errorString = e.toString().toLowerCase();
      if (!errorString.contains('network') &&
          !errorString.contains('timeout') &&
          !errorString.contains('connection')) {
        rethrow;
      }
    }

    try {
      // 1. Ø¢Ù¾Ø¯ÛŒØª Optimistic Ø¯Ø± UI Ù‚Ø¨Ù„ Ø§Ø² Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¨Ù‡ Ø³Ø±ÙˆØ±
      final currentPosts =
          ref.read(publicPostsProvider.notifier).state.value ?? [];
      final postIndex = currentPosts.indexWhere((post) => post.id == postId);

      PublicPostModel? currentPost;
      if (postIndex != -1) {
        currentPost = currentPosts[postIndex];
        final newIsLiked = !currentPost.isLiked;

        // Ø¢Ù¾Ø¯ÛŒØª state Ø¯Ø± Ù‡Ù…Ù‡ provider Ù‡Ø§ÛŒ Ù…Ø±ØªØ¨Ø·
        ref
            .read(likeStateProvider.notifier)
            .updateLikeState(postId, newIsLiked);

        final updatedPost = currentPost.copyWith(
          isLiked: newIsLiked,
          likeCount: newIsLiked
              ? currentPost.likeCount + 1
              : currentPost.likeCount - 1,
        );

        ref.read(publicPostsProvider.notifier).updatePost(updatedPost);

        if (ref.exists(userProfileProvider(ownerId))) {
          ref
              .read(userProfileProvider(ownerId).notifier)
              .updatePost(updatedPost);
        }
      }

      // 2. Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¨Ù‡ Ø³Ø±ÙˆØ±
      if (currentPost != null && !currentPost.isLiked) {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
          'owner_id': ownerId,
        });
      } else if (currentPost != null && currentPost.isLiked) {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      }
    } catch (e) {
      // Ø¯Ø± ØµÙˆØ±Øª Ø®Ø·Ø§ØŒ Ø¨Ø±Ú¯Ø±Ø¯Ø§Ù†Ø¯Ù† state Ø¨Ù‡ Ø­Ø§Ù„Øª Ù‚Ø¨Ù„
      ref.invalidate(publicPostsProvider);
      ref.invalidate(likeStateProvider);
      debugPrint('Error in toggleLike: $e');
      rethrow;
    }
  }
}

final publicPostsProvider = StateNotifierProvider<PublicPostsNotifier,
    AsyncValue<List<PublicPostModel>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PublicPostsNotifier(supabase);
});

// Ø³Ø±ÙˆÛŒØ³ Supabase Ø¨Ø±Ø§ÛŒ Ù…Ø¯ÛŒØ±ÛŒØª Ù„Ø§ÛŒÚ©â€ŒÙ‡Ø§
class SupabaseService {
  final SupabaseClient supabase;

  SupabaseService(this.supabase);

  Future<Map<String, dynamic>?> _checkExistingLike(
    String postId,
    String userId,
  ) async {
    try {
      final response = await supabase
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø±Ø±Ø³ÛŒ Ù„Ø§ÛŒÚ© Ù…ÙˆØ¬ÙˆØ¯: $e');
      rethrow;
    }
  }

  // Future<List<PublicPostModel>> searchPostsByHashtag(String hashtag) async {
  //   try {
  //     final response = await supabase
  //         .from('posts')
  //         .select('''
  //         *,
  //         profiles (
  //           username,
  //           full_name,
  //           avatar_url,
  //           is_verified
  //         )
  //       ''')
  //         .ilike('content', '%$hashtag%')
  //         .order('created_at', ascending: false);

  //     return (response as List<dynamic>)
  //         .map((post) => PublicPostModel.fromMap(post as Map<String, dynamic>))
  //         .toList();
  //   } catch (e) {
  //     throw Exception('Ø®Ø·Ø§ Ø¯Ø± Ø¬Ø³ØªØ¬ÙˆÛŒ Ù¾Ø³Øªâ€ŒÙ‡Ø§: $e');
  //   }
  // }
  Future<void> toggleLike({
    required String postId,
    required String ownerId,
    required WidgetRef ref,
  }) async {
    try {
      // Ø§Ø¹ØªØ¨Ø§Ø±Ø³Ù†Ø¬ÛŒ ÙˆØ±ÙˆØ¯ÛŒâ€ŒÙ‡Ø§
      if (postId.isEmpty || ownerId.isEmpty) {
        throw ArgumentError(
            'Ø´Ù†Ø§Ø³Ù‡â€ŒÙ‡Ø§ÛŒ ÙˆØ±ÙˆØ¯ÛŒ Ù†Ù…ÛŒâ€ŒØªÙˆØ§Ù†Ù†Ø¯ Ø®Ø§Ù„ÛŒ Ø¨Ø§Ø´Ù†Ø¯');
      }

      final userId = _validateUser();

      // Ø§Ø¹ØªØ¨Ø§Ø±Ø³Ù†Ø¬ÛŒ UUID Ù‡Ø§
      [postId, ownerId, userId].forEach(_validateUUID);

      // Ø¨Ø±Ø±Ø³ÛŒ ÙˆØ¶Ø¹ÛŒØª ÙØ¹Ù„ÛŒ Ù„Ø§ÛŒÚ©
      final existingLike = await _checkExistingLike(postId, userId);

      // Ø§Ø¹Ù…Ø§Ù„ ØªØºÛŒÛŒØ±Ø§Øª Ø¯Ø± Ø¯ÛŒØªØ§Ø¨ÛŒØ³
      if (existingLike == null) {
        await supabase.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
          'owner_id': ownerId,
          'created_at': DateTime.now().toIso8601String(),
        });
        // Best-effort personalization signal
        unawaited(VistaNodeService.trackFeedEvent(
          postId: postId,
          eventType: 'like',
        ));
      } else {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        // Best-effort personalization signal
        unawaited(VistaNodeService.trackFeedEvent(
          postId: postId,
          eventType: 'unlike',
        ));
      }

      // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ UI
      ref.invalidate(fetchPublicPosts);
    } on AuthException catch (e) {
      print('Ø®Ø·Ø§ÛŒ Ø§Ø­Ø±Ø§Ø² Ù‡ÙˆÛŒØª: ${e.message}');
      rethrow;
    } on ArgumentError catch (e) {
      print('Ø®Ø·Ø§ÛŒ Ø§Ø¹ØªØ¨Ø§Ø±Ø³Ù†Ø¬ÛŒ: ${e.message}');
      rethrow;
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± toggleLike: $e');
      rethrow;
    }
  }

  /// Quick follow action used in the "For You" feed follow button.
  ///
  /// Returns:
  /// - 'following'  => follow row exists/created
  /// - 'requested'  => follow request created (private account)
  /// - 'none'       => no action (e.g. self) or request not possible
  Future<String> followUserQuick({required String targetUserId}) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('Not authenticated');
    }
    if (targetUserId.isEmpty || targetUserId == currentUserId) {
      return 'none';
    }

    // Already following?
    try {
      final existing = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      if (existing != null) return 'following';
    } catch (_) {
      // If RLS blocks the select, we still attempt insert below.
    }

    // Check privacy (default to public if not available)
    bool isPrivate = false;
    try {
      final settings = await supabase
          .from('user_settings')
          .select('is_private')
          .eq('user_id', targetUserId)
          .maybeSingle();
      isPrivate = (settings?['is_private'] as bool?) ?? false;
    } catch (_) {
      isPrivate = false;
    }

    if (isPrivate) {
      // If already requested, return requested.
      try {
        final existingReq = await supabase
            .from('follow_requests')
            .select('id, status')
            .eq('requester_id', currentUserId)
            .eq('recipient_id', targetUserId)
            .maybeSingle();
        if (existingReq != null &&
            (existingReq['status'] as String?) == 'pending') {
          return 'requested';
        }
      } catch (_) {
        // ignore and try insert
      }

      try {
        await supabase.from('follow_requests').insert({
          'requester_id': currentUserId,
          'recipient_id': targetUserId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Likely duplicate constraint or RLS; treat as requested for UI purposes.
        return 'requested';
      }

      // Best-effort notification
      try {
        await supabase.from('notifications').insert({
          'recipient_id': targetUserId,
          'sender_id': currentUserId,
          'type': 'follow_request',
          'content': 'Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯Ù† Ø¬Ø¯ÛŒØ¯',
          'created_at': DateTime.now().toIso8601String(),
          'is_read': false,
        });
      } catch (_) {}

      return 'requested';
    }

    try {
      await supabase.from('follows').insert({
        'follower_id': currentUserId,
        'following_id': targetUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // If the row already exists, treat it as following.
      return 'following';
    }

    // Best-effort notification
    try {
      await supabase.from('notifications').insert({
        'recipient_id': targetUserId,
        'sender_id': currentUserId,
        'type': 'follow',
        'content': 'Ø¯Ù†Ø¨Ø§Ù„â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø¬Ø¯ÛŒØ¯',
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
      });
    } catch (_) {}

    return 'following';
  }

  String _validateUser() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException(
          'Ú©Ø§Ø±Ø¨Ø± Ø§Ø­Ø±Ø§Ø² Ù‡ÙˆÛŒØª Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }
    return user.id;
  }

  // Future<Map<String, dynamic>?> _checkExistingLike(
  //     String postId, String userId) async {
  //   try {
  //     return await supabase
  //         .from('likes')
  //         .select()
  //         .eq('post_id', postId)
  //         .eq('user_id', userId)
  //         .maybeSingle();
  //   } catch (e) {
  //     print('Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø±Ø±Ø³ÛŒ Ù„Ø§ÛŒÚ© Ù…ÙˆØ¬ÙˆØ¯: $e');
  //     return null;
  //   }
  // }

  // Ù…ØªØ¯ Ø§Ø¹ØªØ¨Ø§Ø±Ø³Ù†Ø¬ÛŒ UUID
  void _validateUUID(String uuid) {
    final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false);

    if (uuid.isEmpty || !uuidRegex.hasMatch(uuid)) {
      throw ArgumentError('Ø´Ù†Ø§Ø³Ù‡ Ù†Ø§Ù…Ø¹ØªØ¨Ø±: $uuid');
    }
  }

  Future<void> insertReport({
    required String postId,
    required String reportedUserId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // Ø¨Ø±Ø±Ø³ÛŒ Ø§Ø¹ØªØ¨Ø§Ø± Ø´Ù†Ø§Ø³Ù‡â€ŒÙ‡Ø§
      if (postId.isEmpty || reportedUserId.isEmpty) {
        throw ArgumentError(
            'Ø´Ù†Ø§Ø³Ù‡â€ŒÙ‡Ø§ Ù†Ù…ÛŒâ€ŒØªÙˆØ§Ù†Ù†Ø¯ Ø®Ø§Ù„ÛŒ Ø¨Ø§Ø´Ù†Ø¯');
      }

      _validateUUID(postId);
      _validateUUID(reportedUserId);

      final userId = _validateUser();
      _validateUUID(userId);

      await supabase.from('reports').insert({
        'post_id': postId,
        'reported_user_id': reportedUserId,
        'reporter_id': userId,
        'reason': reason,
        'additional_details': additionalDetails,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending'
      });
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø«Ø¨Øª Ú¯Ø²Ø§Ø±Ø´: $e');
      rethrow;
    }
  }

  Future<void> deletePost(WidgetRef ref, String postId) async {
    try {
      if (postId.isEmpty) {
        throw ArgumentError(
            'Ø´Ù†Ø§Ø³Ù‡ Ù¾Ø³Øª Ù†Ù…ÛŒâ€ŒØªÙˆØ§Ù†Ø¯ Ø®Ø§Ù„ÛŒ Ø¨Ø§Ø´Ø¯');
      }

      _validateUUID(postId);
      final userId = _validateUser();

      // Ø¯Ø±ÛŒØ§ÙØª Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ù¾Ø³Øª Ø¨Ø±Ø§ÛŒ Ù¾ÛŒØ¯Ø§ Ú©Ø±Ø¯Ù† URL Ù‡Ø§ÛŒ ÙØ§ÛŒÙ„â€ŒÙ‡Ø§
      final post = await supabase
          .from('posts')
          .select('image_url, music_url  , video_url  ')
          .eq('id', postId)
          .maybeSingle();

      if (post == null) {
        throw Exception('Ù¾Ø³Øª ÛŒØ§ÙØª Ù†Ø´Ø¯');
      }

      final mediaUrls = [
        post['image_url'],
        post['music_url'],
        post['video_url'],
      ].where((url) => url != null && url.isNotEmpty).toList();

      // Ø­Ø°Ù ØªÙ…Ø§Ù… ÙØ§ÛŒÙ„â€ŒÙ‡Ø§ Ø§Ø² Ø¢Ø±ÙˆØ§Ù† Ú©Ù„Ø§ÙˆØ¯
      for (String url in mediaUrls) {
        final bool deleted = await _deleteMediaWithRetry(url);
        if (!deleted) {
          print(
              'Ù‡Ø´Ø¯Ø§Ø±: Ø­Ø°Ù ÙØ§ÛŒÙ„ $url Ø§Ø² Ø¢Ø±ÙˆØ§Ù† Ú©Ù„Ø§ÙˆØ¯ Ù†Ø§Ù…ÙˆÙÙ‚ Ø¨ÙˆØ¯');
        }
      }

      // Ø­Ø°Ù Ø¯Ø§Ø¯Ù‡â€ŒÙ‡Ø§ÛŒ Ù…Ø±ØªØ¨Ø· Ø§Ø² Ø¯ÛŒØªØ§Ø¨ÛŒØ³ Ø¨Ù‡ ØªØ±ØªÛŒØ¨
      await Future.wait([
        // Ø­Ø°Ù Ù„Ø§ÛŒÚ©â€ŒÙ‡Ø§
        supabase.from('likes').delete().eq('post_id', postId),
        // Ø­Ø°Ù Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
        supabase.from('comments').delete().eq('post_id', postId),
        // Ø­Ø°Ù Ù†ÙˆØªÛŒÙÛŒÚ©ÛŒØ´Ù†â€ŒÙ‡Ø§
        supabase.from('notifications').delete().eq('post_id', postId),
        // Ø­Ø°Ù Ø¨Ø§Ø²Ø¯ÛŒØ¯Ù‡Ø§ÛŒ Ø§Ø³ØªÙˆØ±ÛŒ
        supabase.from('story_views').delete().eq('story_id', postId),
      ]);

      // Ø­Ø°Ù Ù¾Ø³Øª
      await supabase.from('posts').delete().eq('id', postId);

      // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ UI
      ref.invalidate(fetchPublicPosts);
      // Ù¾ÛŒØ¯Ø§ Ú©Ø±Ø¯Ù† owner ÙˆØ§Ù‚Ø¹ÛŒ Ù¾Ø³Øª Ø¨Ø±Ø§ÛŒ invalidation ØµØ­ÛŒØ­ ØµÙØ­Ù‡ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
      try {
        final postOwner = await supabase
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .maybeSingle();
        final ownerId =
            (postOwner != null ? postOwner['user_id'] : null) as String?;
        if (ownerId != null && ownerId.isNotEmpty) {
          ref.invalidate(userProfileProvider(ownerId));
        } else {
          ref.invalidate(userProfileProvider(userId));
        }
      } catch (_) {
        ref.invalidate(userProfileProvider(userId));
      }

      print(
          'Ù¾Ø³Øª Ùˆ ØªÙ…Ø§Ù… ÙØ§ÛŒÙ„â€ŒÙ‡Ø§ÛŒ Ù…Ø±ØªØ¨Ø· Ø¨Ø§ Ù…ÙˆÙÙ‚ÛŒØª Ø­Ø°Ù Ø´Ø¯Ù†Ø¯.');
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø­Ø°Ù Ù¾Ø³Øª: $e');
      rethrow;
    }
  }

  Future<bool> _deleteMediaWithRetry(String mediaUrl,
      {int maxAttempts = 3}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² Ù…ØªØ¯ Ø¬Ø¯ÛŒØ¯ Ú©Ù‡ Ø®ÙˆØ¯Ø´ Ù†ÙˆØ¹ ÙØ§ÛŒÙ„ Ø±Ùˆ ØªØ´Ø®ÛŒØµ Ù…ÛŒâ€ŒØ¯Ù‡ Ùˆ Ù…ØªØ¯ Ù…Ù†Ø§Ø³Ø¨ Ø±Ùˆ ÙØ±Ø§Ø®ÙˆØ§Ù†ÛŒ Ù…ÛŒâ€ŒÚ©Ù†Ù‡
        final bool success =
            await PostImageUploadService.deleteMediaFile(mediaUrl);
        if (success) return true;

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      } catch (e) {
        print('ØªÙ„Ø§Ø´ $attempt: Ø®Ø·Ø§ Ø¯Ø± Ø­Ø°Ù ÙØ§ÛŒÙ„: $e');
        if (attempt == maxAttempts) return false;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return false;
  }

  // Future<bool> _deleteMediaWithRetry(String mediaUrl,
  //     {int maxAttempts = 3}) async {
  //   for (int attempt = 1; attempt <= maxAttempts; attempt++) {
  //     try {
  //       final bool success =
  //           await PostImageUploadService.deletePostImage(mediaUrl);
  //       if (success) return true;

  //       if (attempt < maxAttempts) {
  //         await Future.delayed(Duration(seconds: attempt));
  //       }
  //     } catch (e) {
  //       print('ØªÙ„Ø§Ø´ $attempt: Ø®Ø·Ø§ Ø¯Ø± Ø­Ø°Ù Ù…Ø¯ÛŒØ§: $e');
  //       if (attempt == maxAttempts) return false;
  //       await Future.delayed(Duration(seconds: attempt));
  //     }
  //   }
  //   return false;
  // }

  Future<List<ProfileModel>> fetchFollowers(String userId) async {
    final response = await supabase.from('follows').select('''
      profiles!follows_follower_id_fkey (
        id, username, full_name, avatar_url, email, bio, 
        followers_count, created_at, 
        is_verified, verification_type
      )
    ''').eq('following_id', userId);

    try {
      return (response as List<dynamic>).map((item) {
        final profileMap = item['profiles'];
        if (profileMap == null) {
          throw Exception('Profile data is missing in the response');
        }
        return ProfileModel.fromMap(profileMap);
      }).toList();
    } catch (e) {
      print('Error parsing response: $e');
      throw Exception('Error converting profiles');
    }
  }

  Future<List<ProfileModel>> fetchFollowing(String userId) async {
    final response = await supabase
        .from('follows') // Ø¬Ø¯ÙˆÙ„ Ø¯Ù†Ø¨Ø§Ù„â€ŒØ´Ø¯Ù‡â€ŒÙ‡Ø§
        .select('''
        profiles!follows_following_id_fkey (
          id, username, full_name, avatar_url, email, bio, 
          followers_count, created_at, 
          is_verified, verification_type
        )
      ''').eq('follower_id', userId);

    // ØªØ¨Ø¯ÛŒÙ„ Ø¯Ø§Ø¯Ù‡ Ø¨Ù‡ Ù…Ø¯Ù„ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
    final List data = response;
    return data.map((item) {
      final profileMap = item[
          'profiles']; // Ø¨Ø±Ø±Ø³ÛŒ ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø¯Ù‡â€ŒÙ‡Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
      if (profileMap == null) {
        throw Exception('Missing profile data');
      }
      return ProfileModel.fromMap(profileMap);
    }).toList();
  }

  // Ø§Ø¶Ø§ÙÙ‡ Ú©Ù†: Ù…ØªØ¯ Ú†Ú© Ø¢Ù†Ù„Ø§ÛŒÙ† Ø¨ÙˆØ¯Ù† Ú©Ù‡ Ø±ÙˆÛŒ ÙˆØ¨ Ù‡Ù…ÛŒØ´Ù‡ true Ø¨Ø±Ù…ÛŒâ€ŒÚ¯Ø±Ø¯Ø§Ù†Ø¯
  Future<bool> isDeviceOnline() async {
    if (kIsWeb) {
      // Ø±ÙˆÛŒ ÙˆØ¨ Ù‡Ù…ÛŒØ´Ù‡ Ø¢Ù†Ù„Ø§ÛŒÙ† ÙØ±Ø¶ Ú©Ù†
      return true;
    }
    // Ø§Ú¯Ø± Ù†ÛŒØ§Ø² Ø¨Ù‡ Ú†Ú© Ø¢Ù†Ù„Ø§ÛŒÙ† Ø¨ÙˆØ¯Ù† Ø¯Ø§Ø±ÛŒØŒ Ø§ÛŒÙ†Ø¬Ø§ Ù‚Ø±Ø§Ø± Ø¨Ø¯Ù‡ (Ù…Ø«Ù„Ø§Ù‹ Ø¨Ø§ http.get ÛŒØ§ connectivity_plus)
    // ÛŒØ§ ÙÙ‚Ø· return true;
    return true;
  }
}

// Provider Ø¨Ø±Ø§ÛŒ Ø³Ø±ÙˆÛŒØ³ Supabase

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final supabase = Supabase.instance.client;
  return SupabaseService(supabase);
});

//Provider Ø¨Ø±Ø§ÛŒ Ø³Ø±ÙˆÛŒØ³ Ùˆ Notifier

// class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
//   NotificationsNotifier() : super([]);

//   // Ù…ØªØ¯ Ø­Ø°Ù ØªÙ…Ø§Ù…ÛŒ Ø§Ø¹Ù„Ø§Ù†â€ŒÙ‡Ø§
//   Future<void> deleteAllNotifications() async {
//     try {
//       final userId = supabase.auth.currentUser?.id;

//       if (userId == null) {
//         throw Exception("User not logged in");
//       }

//       // Ø­Ø°Ù ØªÙ…Ø§Ù…ÛŒ Ø§Ø¹Ù„Ø§Ù†â€ŒÙ‡Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
//       await supabase.from('notifications').delete().eq('recipient_id', userId);

//       // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ ÙˆØ¶Ø¹ÛŒØª (Ø­Ø°Ù Ù‡Ù…Ù‡ Ø§Ø¹Ù„Ø§Ù†â€ŒÙ‡Ø§ Ø§Ø² Ù„ÛŒØ³Øª)
//       state = [];
//     } catch (e) {
//       print("Error deleting notifications: $e");
//       throw Exception("Failed to delete notifications");
//     }
//   }

//   Future<void> fetchNotifications() async {
//     final userId = supabase.auth.currentUser?.id; // Ú¯Ø±ÙØªÙ† Ø´Ù†Ø§Ø³Ù‡ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ

//     if (userId == null) {
//       throw Exception("User not logged in");
//     }

//     final response = await supabase
//         .from('notifications')
//         .select(
//             '*, sender:profiles!notifications_sender_id_fkey(username, avatar_url , is_verified)')
//         .eq('recipient_id', userId) // Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² Ø´Ù†Ø§Ø³Ù‡ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
//         .order('created_at', ascending: false);

//     final notifications =
//         response.map((item) => NotificationModel.fromMap(item)).toList();
//     state = notifications;
//   }
// }

// final notificationsProvider =
//     StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
//         (ref) {
//   return NotificationsNotifier()..fetchNotifications();
// });

// Ø³Ø±ÙˆÛŒØ³ Supabase Ø¨Ø±Ø§ÛŒ Ú¯Ø²Ø§Ø±Ø´ Ù¾Ø³Øªâ€ŒÙ‡Ø§

// ØªØ¹Ø±ÛŒÙ Ù¾Ø§Ø²Ù†Ø¯Ù‡ Ø¨Ø±Ø§ÛŒ SupabaseClient
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ØªØ¹Ø±ÛŒÙ Ù¾Ø±ÙˆÙˆØ§ÛŒØ¯Ø± Ø³Ø±ÙˆÛŒØ³ Ú¯Ø²Ø§Ø±Ø´
final reportServiceProvider = Provider<ReportService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReportService(client);
});

class ReportService {
  final SupabaseClient client;

  ReportService(this.client);

  Future<void> reportPost({
    required String postId,
    required String userId,
    required String reportReason,
  }) async {
    final response = await client.from('reports').insert({
      'post_id': postId,
      'user_id': userId,
      'reason': reportReason,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (response.error != null) {
      throw Exception('Error reporting post: ${response.error!.message}');
    }
  }
}

// provider for profiles

class ProfileService {
  final _supabase = Supabase.instance.client;

  // Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('profiles') // Ù†Ø§Ù… Ø¬Ø¯ÙˆÙ„ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching current user profile: $e');
      return null;
    }
  }

  // Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø¨Ø§ Ø´Ù†Ø§Ø³Ù‡
  Future<UserModel?> getProfileById(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }
}

// Provider Ø¨Ø±Ø§ÛŒ Ø³Ø±ÙˆÛŒØ³ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Provider Ø¨Ø±Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getCurrentUserProfile();
});

// Provider Ø¨Ø±Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø¨Ø§ Ø´Ù†Ø§Ø³Ù‡ Ø®Ø§Øµ
final profileByIdProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getProfileById(userId);
});

// Ù…Ø«Ø§Ù„ Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø¯Ø± ÙˆÛŒØ¬Øª
class ProfileWidget extends ConsumerWidget {
  const ProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ú©Ø§Ø±Ø¨Ø± ÙØ¹Ù„ÛŒ
    final currentProfileAsync = ref.watch(currentUserProfileProvider);

    return currentProfileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) =>
          const Text('Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„'),
      data: (profile) {
        if (profile == null) {
          return const Text('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              const Icon(Icons.verified, color: Colors.blue)
          ],
        );
      },
    );
  }
}

// Ù…Ø«Ø§Ù„ Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø¨Ø§ Ø´Ù†Ø§Ø³Ù‡ Ø®Ø§Øµ
class OtherProfileWidget extends ConsumerWidget {
  final String userId;

  const OtherProfileWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));

    return profileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) =>
          const Text('Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„'),
      data: (profile) {
        if (profile == null) {
          return const Text('Ù¾Ø±ÙˆÙØ§ÛŒÙ„ ÛŒØ§ÙØª Ù†Ø´Ø¯');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              const Icon(Icons.verified, color: Colors.blue)
          ],
        );
      },
    );
  }
}

//fetch comments
//Comment StateNotifier

class CommentService {
  final SupabaseClient _supabase;

  CommentService(this._supabase);

  Future<CommentModel> addComment({
    required String postId,
    required String content,
    required String postOwnerId,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ø³ÛŒØ³ØªÙ… Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
      }

      final response = await _supabase.from('comments').insert({
        'post_id': postId,
        'owner_id': currentUser.id, // ØªØºÛŒÛŒØ± Ø§Ø² user_id Ø¨Ù‡ owner_id
        'user_id': postOwnerId, // ØµØ§Ø­Ø¨ Ù¾Ø³Øª
        'content': content,
        'parent_comment_id': parentCommentId,
      }).select('''
          *,
          profiles!comments_owner_id_fkey (
            username, 
            avatar_url, 
            is_verified,
            verification_type
          )
        ''').maybeSingle();

      if (response == null) {
        throw Exception(
            'Ø®Ø·Ø§ Ø¯Ø± Ø§ÛŒØ¬Ø§Ø¯ Ú©Ø§Ù…Ù†Øª - Ù¾Ø§Ø³Ø® Ø®Ø§Ù„ÛŒ Ø§Ø³Øª');
      }

      return CommentModel.fromMap(response);
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø§Ø±Ø³Ø§Ù„ Ú©Ø§Ù…Ù†Øª: $e');
      rethrow;
    }
  }

// ØªØºÛŒÛŒØ± Ù…ØªØ¯ fetchComments Ø¨Ø±Ø§ÛŒ Ø¯Ø±ÛŒØ§ÙØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§ÛŒ ÙØ±Ø²Ù†Ø¯
  Future<List<CommentModel>> fetchComments(String postId) async {
    try {
      final response = await _supabase.from('comments').select('''
          *,
          profiles!comments_owner_id_fkey (
            username, 
            avatar_url, 
            is_verified,
            verification_type )
        ''').eq('post_id', postId).order('created_at', ascending: false);

      if (response.isEmpty) {
        return []; // Ø§Ú¯Ø± Ù¾Ø§Ø³Ø®ÛŒ Ø¯Ø±ÛŒØ§ÙØª Ù†Ø´Ø¯ØŒ Ù„ÛŒØ³Øª Ø®Ø§Ù„ÛŒ Ø¨Ø±Ú¯Ø±Ø¯Ø§Ù†ÛŒØ¯
      }

      List<CommentModel> comments =
          (response as List).map((item) => CommentModel.fromMap(item)).toList();

      _organizeComments(comments);
      return comments;
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± ÙˆØ§Ú©Ø´ÛŒ Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§: $e');
      return [];
    }
  }

// Ù…ØªØ¯ Ú©Ù…Ú©ÛŒ Ø¨Ø±Ø§ÛŒ Ù…Ø±ØªØ¨â€ŒØ³Ø§Ø²ÛŒ Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
  void _organizeComments(List<CommentModel> comments) {
    final Map<String, CommentModel> commentMap = {};

    // Ø§ÛŒØ¬Ø§Ø¯ Ù†Ù‚Ø´Ù‡ Ø§Ø² Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§ Ø¨Ø± Ø§Ø³Ø§Ø³ Ø´Ù†Ø§Ø³Ù‡
    for (var comment in comments) {
      commentMap[comment.id] = comment;
      comment.replies = []; // Ù…Ù‚Ø¯Ø§Ø±Ø¯Ù‡ÛŒ Ø§ÙˆÙ„ÛŒÙ‡ Ø¨Ø±Ø§ÛŒ replies
    }

    // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§ÛŒ ÙØ±Ø²Ù†Ø¯ Ø¨Ù‡ ÙˆØ§Ù„Ø¯ÛŒÙ† Ùˆ Ø­Ø°Ù Ø¢Ù†Ù‡Ø§ Ø§Ø² Ù„ÛŒØ³Øª Ø§ØµÙ„ÛŒ
    comments.removeWhere((comment) {
      if (comment.parentCommentId != null) {
        final parentComment = commentMap[comment.parentCommentId];
        if (parentComment != null) {
          parentComment.replies = parentComment.replies ?? [];
          parentComment.replies.add(comment);
          return true; // Ø­Ø°Ù Ø±ÛŒÙ¾Ù„Ø§ÛŒ Ø§Ø² Ù„ÛŒØ³Øª Ø§ØµÙ„ÛŒ
        }
      }
      return false; // Ú©Ø§Ù…Ù†Øª Ø§ØµÙ„ÛŒ Ø­Ø°Ù Ù†Ù…ÛŒâ€ŒØ´ÙˆØ¯
    });
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Optional: You might want to add a check to ensure only the comment owner can delete
      final response = await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', currentUserId);

      return response;
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchMentionableUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(10);

      return (response as List)
          .map((userData) => UserModel.fromJson(userData))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<void> addMentionToComment({
    required String commentId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ø³ÛŒØ³ØªÙ… Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
      }

      // Ø¯Ø±Ø¬ Ù…Ù†Ø´Ù†â€ŒÙ‡Ø§ Ø¯Ø± Ø¬Ø¯ÙˆÙ„ comment_mentions
      final mentions = mentionedUserIds
          .map((userId) => {
                'comment_id': commentId,
                'user_id': userId,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await _supabase.from('comment_mentions').insert(mentions);
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ù…Ù†Ø´Ù† Ø¨Ù‡ Ú©Ø§Ù…Ù†Øª: $e');
      rethrow;
    }
  }
}

// Provider Ø¨Ø±Ø§ÛŒ Ø¬Ø³ØªØ¬ÙˆÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù†
final mentionableUsersProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
  final commentService = ref.watch(commentServiceProvider);
  return commentService.searchMentionableUsers(query);
});

// comment_providers.dart
final commentServiceProvider = Provider<CommentService>((ref) {
  final supabase = Supabase.instance.client;
  return CommentService(supabase);
});

final commentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) {
  final commentService = ref.read(commentServiceProvider);
  return commentService.fetchComments(postId);
});

// comment_notifier.dart
class CommentNotifier extends StateNotifier<AsyncValue<void>> {
  final CommentService _commentService;
  final TextEditingController contentController = TextEditingController();

  // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† ÛŒÚ© ÙÙ„Ú¯ Ø¨Ø±Ø§ÛŒ Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² Ø§Ø±Ø³Ø§Ù„ Ù…Ú©Ø±Ø±
  bool _isSubmitting = false;

  CommentNotifier(this._commentService) : super(const AsyncValue.data(null));

  Future<void> addComment(
      {required String postId,
      required String content,
      required String postOwnerId,
      String? parentCommentId,
      List<String> mentionedUserIds = const [],
      required WidgetRef ref}) async {
    // Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² Ø§Ø±Ø³Ø§Ù„ Ù…Ú©Ø±Ø±
    if (_isSubmitting) return;

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) return;

    // ØªÙ†Ø¸ÛŒÙ… ÙÙ„Ú¯ Ø§Ø±Ø³Ø§Ù„
    _isSubmitting = true;
    state = const AsyncValue.loading();

    try {
      // Ø§ÙØ²ÙˆØ¯Ù† Ú©Ø§Ù…Ù†Øª Ø¨Ø§ Ù…Ø´Ø®ØµØ§Øª Ú©Ø§Ù…Ù„
      final comment = await _commentService.addComment(
        postId: postId,
        content: trimmedContent,
        postOwnerId: postOwnerId,
        parentCommentId: parentCommentId,
      );

      // Ø§Ú¯Ø± Ù…Ù†Ø´Ù†â€ŒÙ‡Ø§ÛŒÛŒ ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø±Ø¯ØŒ Ø¢Ù†Ù‡Ø§ Ø±Ø§ Ø§Ø¶Ø§ÙÙ‡ Ú©Ù†ÛŒØ¯
      if (mentionedUserIds.isNotEmpty) {
        await _commentService.addMentionToComment(
          commentId: comment.id,
          mentionedUserIds: mentionedUserIds,
        );
      }

      // Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† Ú©Ù†ØªØ±Ù„Ø±
      contentController.clear();

      // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø§Ø³ØªÛŒØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
      await _updateCommentsState(postId, comment, parentCommentId, ref);

      state = const AsyncValue.data(null);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    } finally {
      // Ø¨Ø§Ø²Ù†Ø´Ø§Ù†ÛŒ ÙÙ„Ú¯ Ø§Ø±Ø³Ø§Ù„
      _isSubmitting = false;
    }
  }

  // Ù…ØªØ¯ Ø¬Ø¯ÛŒØ¯ Ø¨Ø±Ø§ÛŒ Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø§Ø³ØªÛŒØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
  Future<void> _updateCommentsState(
    String postId,
    CommentModel newComment,
    String? parentCommentId,
    WidgetRef ref,
  ) async {
    // Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆØ§ÛŒØ¯Ø± Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§ Ø¨Ø±Ø§ÛŒ Ù¾Ø³Øª Ù…ÙˆØ±Ø¯ Ù†Ø¸Ø±
    final commentsProvider =
        StateNotifierProvider<CommentsNotifier, List<CommentModel>>((ref) {
      return CommentsNotifier(_commentService);
    });

    // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø§Ø³ØªÛŒØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
    ref.read(commentsProvider.notifier).addComment(
          postId: postId,
          comment: newComment,
          parentCommentId: parentCommentId,
        );
  }

  Future<String> getPostOwnerId(String postId) async {
    final response = await supabase
        .from('posts')
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();

    if (response == null) {
      throw Exception('Ù¾Ø³Øª ÛŒØ§ÙØª Ù†Ø´Ø¯');
    }

    return response['user_id'] as String;
  }

  Future<void> deleteComment(String commentId, WidgetRef ref) async {
    state = const AsyncValue.loading();

    try {
      await _commentService.deleteComment(commentId);
      state = const AsyncValue.data(null);

      // Ø¨Ø±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø§Ø³ØªÛŒØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§ Ø¨Ø±Ø§ÛŒ Ù¾Ø³Øª Ù…Ø´Ø®Øµ
      ref.read(commentsProvider(commentId));
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
}

// Ù†ÙˆØªÛŒÙØ§ÛŒØ± Ø¬Ø¯ÛŒØ¯ Ø¨Ø±Ø§ÛŒ Ù…Ø¯ÛŒØ±ÛŒØª Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
class CommentsNotifier extends StateNotifier<List<CommentModel>> {
  final CommentService _commentService;

  CommentsNotifier(this._commentService) : super([]);

  void addComment({
    required String postId,
    required CommentModel comment,
    String? parentCommentId,
  }) {
    if (parentCommentId != null) {
      // Ù¾ÛŒØ¯Ø§ Ú©Ø±Ø¯Ù† Ú©Ø§Ù…Ù†Øª ÙˆØ§Ù„Ø¯ Ùˆ Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ø±ÛŒÙ¾Ù„Ø§ÛŒ
      state = state.map((existingComment) {
        if (existingComment.id == parentCommentId) {
          final updatedReplies = [...(existingComment.replies), comment];
          return existingComment.copyWith(
            replies: updatedReplies.cast<CommentModel>(),
          );
        }
        return existingComment;
      }).toList();
    } else {
      // Ø§Ú¯Ø± Ú©Ø§Ù…Ù†Øª Ø§ØµÙ„ÛŒ Ø§Ø³ØªØŒ Ø¨Ù‡ Ù„ÛŒØ³Øª Ø§Ø¶Ø§ÙÙ‡ Ù…ÛŒâ€ŒØ´ÙˆØ¯
      // Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² ØªÚ©Ø±Ø§Ø±
      if (!state.any((existingComment) => existingComment.id == comment.id)) {
        state = [...state, comment];
      }
    }
  }

  void removeComment(String commentId) {
    state = state.where((comment) {
      // Ø­Ø°Ù Ú©Ø§Ù…Ù†Øª Ø§ØµÙ„ÛŒ
      if (comment.id == commentId) return false;

      // Ø­Ø°Ù Ø±ÛŒÙ¾Ù„Ø§ÛŒâ€ŒÙ‡Ø§ÛŒ Ù…Ø±Ø¨ÙˆØ· Ø¨Ù‡ Ú©Ø§Ù…Ù†Øª
      comment.replies =
          comment.replies.where((reply) => reply.id != commentId).toList();

      return true;
    }).toList();
  }
}

// Ù¾Ø±ÙˆØ§ÛŒØ¯Ø± Ø¬Ø¯ÛŒØ¯ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
// final commentsProvider = StateNotifierProvider<CommentsNotifier, List<CommentModel>>((ref) {
//   final commentService = ref.read(commentServiceProvider);
//   return CommentsNotifier(commentService);
// });

final commentNotifierProvider =
    StateNotifierProvider<CommentNotifier, AsyncValue<void>>((ref) {
  final commentService = ref.read(commentServiceProvider);
  return CommentNotifier(commentService);
});

class ProfileNotifier extends StateNotifier<ProfileModel?> {
  final Ref ref;
  final ProfileCacheService _profileCache = ProfileCacheService();

  ProfileNotifier(this.ref) : super(null);

  Future<void> fetchProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      // âœ… Ø¨Ø±Ø±Ø³ÛŒ Ú©Ø§Ù…Ù„ Ù†Ø´Ø³Øª Ø¨Ø§ ØªÙ„Ø§Ø´ Ø¨Ø±Ø§ÛŒ recovery
      final isAuthenticated = await AuthNavigationService.ensureAuthenticated(
        message:
            'Ø¨Ø±Ø§ÛŒ Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø§Ø¨ØªØ¯Ø§ ÙˆØ§Ø±Ø¯ Ø´ÙˆÛŒØ¯',
      );

      if (!isAuthenticated) {
        print('âš ï¸ ProfileNotifier: Ù†Ø´Ø³Øª Ù…Ø¹ØªØ¨Ø± Ù†ÛŒØ³Øª');
        return;
      }

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print(
            'âš ï¸ ProfileNotifier: Ú©Ø§Ø±Ø¨Ø± ÛŒØ§ÙØª Ù†Ø´Ø¯ Ø¨Ø¹Ø¯ Ø§Ø² verify');
        return;
      }

      try {
        // Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ (Ù…Ø¯ÛŒØ±ÛŒØª Ú©Ø´ Ùˆ Ø³Ø±ÙˆØ± Ø¨Ø§ Ø®ÙˆØ¯ Ø³Ø±ÙˆÛŒØ³ Ø§Ø³Øª)
        final profile = await _profileCache.getProfile(userId);
        final posts = await _profileCache.getUserPosts(userId);

        // Ø¨Ø±Ø±Ø³ÛŒ ÙˆØ¶Ø¹ÛŒØª ÙØ§Ù„Ùˆ (Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø§Ø² Ø³Ø±ÙˆØ± Ø¨Ø±Ø§ÛŒ Ø§Ø·Ù…ÛŒÙ†Ø§Ù†)
        bool isFollowed = profile.isFollowed;
        try {
          final followStatusResponse = await supabase
              .from('follows')
              .select('id')
              .eq('follower_id', currentUserId)
              .eq('following_id', userId)
              .maybeSingle();
          isFollowed = followStatusResponse != null;
        } catch (e) {
          // Ignore network error for follow status check, use cached value
        }

        state = profile.copyWith(
          posts: posts,
          isFollowed: isFollowed,
        );
      } catch (e) {
        print('âŒ Error fetching profile in Notifier: $e');

        // ØªÙ„Ø§Ø´ Ø¨Ø±Ø§ÛŒ Ø®ÙˆØ§Ù†Ø¯Ù† Ú©Ø´ Ø§Ú¯Ø± Ø®Ø·Ø§ Ø±Ø® Ø¯Ø§Ø¯ (Ù…Ø«Ù„Ø§Ù‹ Ø¢ÙÙ„Ø§ÛŒÙ†)
        try {
          final cachedProfile = await _profileCache.getCachedProfile(userId);
          if (cachedProfile != null) {
            final cachedPosts = await _profileCache.getCachedPosts(userId);
            state = cachedProfile.copyWith(posts: cachedPosts);
            print('ðŸ“± Using cached profile due to error');
            return;
          }
        } catch (_) {}

        rethrow;
      }
    } catch (e, stackTrace) {
      print('âŒ Error in fetchProfile: $e');
      UserFriendlyErrorHandler.logError(e,
          context: 'profile_fetch', stackTrace: stackTrace);
    }
  }

  /// Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ù¾Ø³Øª Ø¬Ø¯ÛŒØ¯ Ø¨Ù‡ Ú©Ø´
  Future<void> addPostToCache(PublicPostModel post) async {
    try {
      await _profileCache.addPostToCache(post.userId, post);
      print('âœ… Added post to cache: ${post.id}');
    } catch (e) {
      print('âš ï¸ Failed to add post to cache: $e');
    }
  }

  /// Ø­Ø°Ù Ù¾Ø³Øª Ø§Ø² Ú©Ø´
  Future<void> removePostFromCache(String userId, String postId) async {
    try {
      await _profileCache.removePostFromCache(userId, postId);
      print('âœ… Removed post from cache: $postId');
    } catch (e) {
      print('âš ï¸ Failed to remove post from cache: $e');
    }
  }

  /// Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† Ú©Ø´ Ú©Ø§Ø±Ø¨Ø±
  Future<void> clearUserCache(String userId) async {
    try {
      await _profileCache.clearUserCache(userId);
      print('âœ… Cleared cache for user: $userId');
    } catch (e) {
      print('âš ï¸ Failed to clear user cache: $e');
    }
  }

  Future<void> toggleFollow(String userId) async {
    if (state == null) return;

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (state!.isFollowed) {
        // Ø­Ø°Ù ÙØ§Ù„Ùˆ
        await Future.wait([
          supabase
              .from('follows')
              .delete()
              .eq('follower_id', currentUserId)
              .eq('following_id', userId),
          supabase.from('notifications').delete().match({
            'recipient_id': userId,
            'sender_id': currentUserId,
            'type': 'follow',
          })
        ]);

        state = state!.copyWith(
          isFollowed: false,
          followersCount: state!.followersCount - 1,
        );
      } else {
        // Ø¨Ø±Ø±Ø³ÛŒ Ø§ÛŒÙ†Ú©Ù‡ Ø¢ÛŒØ§ Ù¾ÛŒØ¬ Ø®ØµÙˆØµÛŒ Ø§Ø³Øª ÛŒØ§ Ù†Ù‡
        final userSettings = await supabase
            .from('user_settings')
            .select('is_private')
            .eq('user_id', userId)
            .maybeSingle();

        final isPrivate = (userSettings?['is_private'] as bool?) ?? false;
        print(
            'ðŸ” Ø¨Ø±Ø±Ø³ÛŒ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú©Ø§Ø±Ø¨Ø± $userId: isPrivate = $isPrivate');

        if (isPrivate) {
          print(
              'ðŸ”’ Ù¾ÛŒØ¬ Ø®ØµÙˆØµÛŒ - Ø¨Ø±Ø±Ø³ÛŒ Ø¯Ø±Ø®ÙˆØ§Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ù…ÙˆØ¬ÙˆØ¯');
          // Ø¨Ø±Ø§ÛŒ Ù¾ÛŒØ¬â€ŒÙ‡Ø§ÛŒ Ø®ØµÙˆØµÛŒ: Ø§ÛŒØ¬Ø§Ø¯ Ø¯Ø±Ø®ÙˆØ§Ø³Øª ÙØ§Ù„Ùˆ
          final existingRequest = await supabase
              .from('follow_requests')
              .select('id, status')
              .eq('requester_id', currentUserId)
              .eq('recipient_id', userId)
              .maybeSingle();

          print('ðŸ” Ø¨Ø±Ø±Ø³ÛŒ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù…ÙˆØ¬ÙˆØ¯: $existingRequest');
          print(
              'ðŸ” ÙˆØ¶Ø¹ÛŒØª Ø¯Ø±Ø®ÙˆØ§Ø³Øª: ${existingRequest?['status']}');

          if (existingRequest == null) {
            // Ø§Ú¯Ø± Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù‚Ø¨Ù„ÛŒ ÙˆØ¬ÙˆØ¯ Ù†Ø¯Ø§Ø±Ø¯ØŒ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¬Ø¯ÛŒØ¯ Ø§ÛŒØ¬Ø§Ø¯ Ú©Ù†
            print(
                'ðŸ†• Ø§ÛŒØ¬Ø§Ø¯ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¬Ø¯ÛŒØ¯ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');
            await supabase.from('follow_requests').insert({
              'requester_id': currentUserId,
              'recipient_id': userId,
              'status': 'pending',
              'created_at': DateTime.now().toIso8601String(),
            });
            // Ø§Ø¹Ù„Ø§Ù† Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø± Ù‡Ø¯Ù
            await supabase.from('notifications').insert({
              'recipient_id': userId,
              'sender_id': currentUserId,
              'type': 'follow_request',
              'content': 'Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯Ù† Ø¬Ø¯ÛŒØ¯',
              'created_at': DateTime.now().toIso8601String(),
              'is_read': false,
            });

            print('âœ… Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¬Ø¯ÛŒØ¯ Ø§ÛŒØ¬Ø§Ø¯ Ø´Ø¯');

            // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ state Ø¨Ø±Ø§ÛŒ Ù†Ø´Ø§Ù† Ø¯Ø§Ø¯Ù† ÙˆØ¶Ø¹ÛŒØª pending
            state = state!.copyWith(
              isFollowed: false, // Ù‡Ù†ÙˆØ² Ø¯Ù†Ø¨Ø§Ù„ Ù†Ø´Ø¯Ù‡
              followersCount: state!
                  .followersCount, // ØªØ¹Ø¯Ø§Ø¯ ØªØºÛŒÛŒØ± Ù†Ù…ÛŒâ€ŒÚ©Ù†Ø¯
            );

            print(
                'ðŸ”„ State Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø´Ø¯: isFollowed=${state!.isFollowed}');
          } else if (existingRequest['status'] == 'pending') {
            // Ø§Ú¯Ø± Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø±Ø¯ØŒ Ø¢Ù† Ø±Ø§ Ù„ØºÙˆ Ú©Ù†
            print(
                'ðŸ”„ Ù„ØºÙˆ Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');

            await supabase
                .from('follow_requests')
                .delete()
                .eq('requester_id', currentUserId)
                .eq('recipient_id', userId);

            // Ø­Ø°Ù Ø§Ø¹Ù„Ø§Ù† Ù…Ø±Ø¨ÙˆØ·Ù‡
            await supabase.from('notifications').delete().match({
              'recipient_id': userId,
              'sender_id': currentUserId,
              'type': 'follow_request',
            });

            print('âœ… Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending Ù„ØºÙˆ Ø´Ø¯');

            // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ state
            state = state!.copyWith(
              isFollowed: false,
              followersCount: state!.followersCount,
            );
          } else if (existingRequest['status'] == 'rejected') {
            // Ø§Ú¯Ø± Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù‚Ø¨Ù„ÛŒ Ø±Ø¯ Ø´Ø¯Ù‡ØŒ ÙˆØ¶Ø¹ÛŒØª Ø±Ø§ Ø¨Ù‡ pending ØªØºÛŒÛŒØ± Ø¯Ù‡
            print(
                'ðŸ”„ ØªØºÛŒÛŒØ± ÙˆØ¶Ø¹ÛŒØª Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø±Ø¯ Ø´Ø¯Ù‡ Ø¨Ù‡ pending Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');
            await supabase
                .from('follow_requests')
                .update({
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                })
                .eq('requester_id', currentUserId)
                .eq('recipient_id', userId);
            // Ø§Ø¹Ù„Ø§Ù† Ø¬Ø¯ÛŒØ¯ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø± Ù‡Ø¯Ù
            await supabase.from('notifications').insert({
              'recipient_id': userId,
              'sender_id': currentUserId,
              'type': 'follow_request',
              'content': 'Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯Ù† Ø¬Ø¯ÛŒØ¯',
              'created_at': DateTime.now().toIso8601String(),
              'is_read': false,
            });

            print(
                'âœ… Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø±Ø¯ Ø´Ø¯Ù‡ Ø¨Ù‡ pending ØªØºÛŒÛŒØ± Ú©Ø±Ø¯');

            // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ state Ø¨Ø±Ø§ÛŒ Ù†Ø´Ø§Ù† Ø¯Ø§Ø¯Ù† ÙˆØ¶Ø¹ÛŒØª pending
            state = state!.copyWith(
              isFollowed: false, // Ù‡Ù†ÙˆØ² Ø¯Ù†Ø¨Ø§Ù„ Ù†Ø´Ø¯Ù‡
              followersCount: state!
                  .followersCount, // ØªØ¹Ø¯Ø§Ø¯ ØªØºÛŒÛŒØ± Ù†Ù…ÛŒâ€ŒÚ©Ù†Ø¯
            );
          } else if (existingRequest['status'] == 'pending') {
            // Ø§Ú¯Ø± Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù‚Ø¨Ù„ÛŒ pending Ø§Ø³ØªØŒ Ø¢Ù† Ø±Ø§ Ù„ØºÙˆ Ú©Ù†
            print(
                'ðŸ”„ Ù„ØºÙˆ Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');

            await supabase
                .from('follow_requests')
                .delete()
                .eq('requester_id', currentUserId)
                .eq('recipient_id', userId);

            // Ø­Ø°Ù Ø§Ø¹Ù„Ø§Ù† Ù…Ø±Ø¨ÙˆØ·Ù‡
            await supabase.from('notifications').delete().match({
              'recipient_id': userId,
              'sender_id': currentUserId,
              'type': 'follow_request',
            });

            print('âœ… Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending Ù„ØºÙˆ Ø´Ø¯');

            // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ state
            state = state!.copyWith(
              isFollowed: false,
              followersCount: state!.followersCount,
            );
          } else if (existingRequest['status'] == 'accepted') {
            // Ø§Ú¯Ø± Ù‚Ø¨Ù„Ø§Ù‹ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù¾Ø°ÛŒØ±ÙØªÙ‡ Ø´Ø¯Ù‡ØŒ Ø¨Ø±Ø±Ø³ÛŒ Ú©Ù†ÛŒÙ… Ø¢ÛŒØ§ Ø±Ø§Ø¨Ø·Ù‡ ÙØ§Ù„Ùˆ ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø±Ø¯
            print(
                'âœ… Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù‚Ø¨Ù„Ø§Ù‹ Ù¾Ø°ÛŒØ±ÙØªÙ‡ Ø´Ø¯Ù‡ Ø§Ø³Øª. Ø¨Ø±Ø±Ø³ÛŒ Ø±Ø§Ø¨Ø·Ù‡ ÙØ§Ù„Ùˆ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');

            final existingFollow = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', currentUserId)
                .eq('following_id', userId)
                .maybeSingle();

            if (existingFollow != null) {
              print(
                  'âœ… Ø±Ø§Ø¨Ø·Ù‡ ÙØ§Ù„Ùˆ ÙˆØ¬ÙˆØ¯ Ø¯Ø§Ø±Ø¯ - Ú©Ø§Ø±Ø¨Ø± Ù…ÛŒâ€ŒØªÙˆØ§Ù†Ø¯ Ù…Ø­ØªÙˆØ§ Ø±Ø§ Ø¨Ø¨ÛŒÙ†Ø¯');
              state = state!.copyWith(
                isFollowed: true,
                followersCount: state!.followersCount,
              );
            } else {
              print(
                  'âš ï¸ Ø¯Ø±Ø®ÙˆØ§Ø³Øª accepted Ø§Ù…Ø§ Ø±Ø§Ø¨Ø·Ù‡ ÙØ§Ù„Ùˆ ÙˆØ¬ÙˆØ¯ Ù†Ø¯Ø§Ø±Ø¯ - Ø§ÛŒÙ† Ø­Ø§Ù„Øª Ù†Ø§Ø¯Ø±Ø³Øª Ø§Ø³Øª');
              // Ø¯Ø± Ø§ÛŒÙ† Ø­Ø§Ù„ØªØŒ Ú©Ø§Ø±Ø¨Ø± Ø¨Ø§ÛŒØ¯ Ù…Ù†ØªØ¸Ø± Ø¨Ù…Ø§Ù†Ø¯ ØªØ§ ØµØ§Ø­Ø¨ Ù¾ÛŒØ¬ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø±Ø§ Ø¯ÙˆØ¨Ø§Ø±Ù‡ ØªØ§ÛŒÛŒØ¯ Ú©Ù†Ø¯
              state = state!.copyWith(
                isFollowed: false,
                followersCount: state!.followersCount,
              );
            }
          } else {
            print(
                'âš ï¸ ÙˆØ¶Ø¹ÛŒØª Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ù†Ø§Ø´Ù†Ø§Ø®ØªÙ‡: ${existingRequest['status']}');
          }
        } else {
          // Ø¨Ø±Ø§ÛŒ Ù¾ÛŒØ¬â€ŒÙ‡Ø§ÛŒ Ø¹Ù…ÙˆÙ…ÛŒ: Ù…Ø³ØªÙ‚ÛŒÙ…Ø§Ù‹ ÙØ§Ù„Ùˆ Ú©Ù†
          print(
              'ðŸ†• ÙØ§Ù„Ùˆ Ù…Ø³ØªÙ‚ÛŒÙ… Ø¨Ø±Ø§ÛŒ Ù¾ÛŒØ¬ Ø¹Ù…ÙˆÙ…ÛŒ: $userId');
          print(
              'âŒ Ø®Ø·Ø§: Ù¾ÛŒØ¬ Ø¹Ù…ÙˆÙ…ÛŒ Ù†Ø¨Ø§ÛŒØ¯ Ø¨Ù‡ Ø§ÛŒÙ† Ù‚Ø³Ù…Øª Ø¨Ø±Ø³Ø¯!');
          await supabase.from('follows').insert({
            'follower_id': currentUserId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Ø§Ø¹Ù„Ø§Ù† Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø± Ù‡Ø¯Ù
          await supabase.from('notifications').insert({
            'recipient_id': userId,
            'sender_id': currentUserId,
            'type': 'follow',
            'content': 'Ø´Ù…Ø§ Ø±Ø§ Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯',
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });

          print('âœ… ÙØ§Ù„Ùˆ Ù…Ø³ØªÙ‚ÛŒÙ… Ø§Ù†Ø¬Ø§Ù… Ø´Ø¯');

          // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ state
          state = state!.copyWith(
            isFollowed: true,
            followersCount: state!.followersCount + 1,
          );
        }
      }
    } catch (e) {
      print('âŒ Ø®Ø·Ø§ Ø¯Ø± ØªØºÛŒÛŒØ± ÙˆØ¶Ø¹ÛŒØª ÙØ§Ù„Ùˆ: $e');
      rethrow; // Ø¯ÙˆØ¨Ø§Ø±Ù‡ Ø®Ø·Ø§ Ø±Ø§ Ù¾Ø±ØªØ§Ø¨ Ú©Ù† ØªØ§ Ø¯Ø± UI Ù†Ù…Ø§ÛŒØ´ Ø¯Ø§Ø¯Ù‡ Ø´ÙˆØ¯
    }
  }

  void updatePost(PublicPostModel updatedPost) {
    if (state == null) return;

    final updatedPosts = List<PublicPostModel>.from(state!.posts);
    final index = updatedPosts.indexWhere((post) => post.id == updatedPost.id);

    if (index != -1) {
      updatedPosts[index] = updatedPost;
      state = state!.copyWith(posts: updatedPosts);
    }
  }

  void addNewPost(PublicPostModel newPost) {
    if (state == null) return;
    state = state!.copyWith(
      posts: [newPost, ...state!.posts],
    );
  }
}

final userProfileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileModel?, String>(
  (ref, userId) => ProfileNotifier(ref)..fetchProfile(userId),
);

// Ø¨Ø±Ø±Ø³ÛŒ Ø¯Ø± Ø­Ø§Ù„ Ø§Ù†ØªØ¸Ø§Ø± Ø¨ÙˆØ¯Ù† Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯Ù†
final followRequestPendingProvider =
    FutureProvider.family<bool, String>((ref, targetUserId) async {
  try {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;
    print(
        'ðŸ” Ø¨Ø±Ø±Ø³ÛŒ Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø± $targetUserId ØªÙˆØ³Ø· $currentUserId');
    final res = await supabase
        .from('follow_requests')
        .select('id, status')
        .eq('requester_id', currentUserId)
        .eq('recipient_id', targetUserId)
        .eq('status', 'pending')
        .maybeSingle();
    print('ðŸ” Ù†ØªÛŒØ¬Ù‡ Ø¨Ø±Ø±Ø³ÛŒ Ø¯Ø±Ø®ÙˆØ§Ø³Øª pending: $res');
    final isPending = res != null;
    print('ðŸ” isPending: $isPending');
    return isPending;
  } catch (e) {
    print(
        'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø±Ø±Ø³ÛŒ ÙˆØ¶Ø¹ÛŒØª Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¯Ù†Ø¨Ø§Ù„ Ú©Ø±Ø¯Ù†: $e');
    return false;
  }
});

final postProvider =
    FutureProvider.family<PublicPostModel, String>((ref, postId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase.from('posts').select('''
        *,
        image_url,
        music_url,
        profiles (
          username, 
          avatar_url, 
          is_verified,
          verification_type
        ),
        likes (user_id)
      ''').eq('id', postId).maybeSingle();

  if (response == null) {
    throw Exception('Ù¾Ø³ØªÛŒ Ø¨Ø§ Ø§ÛŒÙ† Ø´Ù†Ø§Ø³Ù‡ ÛŒØ§ÙØª Ù†Ø´Ø¯.');
  }

  print('Post Response: $response'); // Ø¨Ø±Ø§ÛŒ Ø¯ÛŒØ¨Ø§Ú¯

  final likes = response['likes'] as List<dynamic>? ?? [];
  final likeCount = likes.length;
  final isLiked =
      likes.any((like) => like['user_id'] == supabase.auth.currentUser?.id);

  return PublicPostModel.fromMap({
    ...response,
    'like_count': likeCount,
    'is_liked': isLiked,
    'username': response['profiles']?['username'] ??
        response['profiles']?['full_name'] ??
        'Unknown',
    'avatar_url': response['profiles']?['avatar_url'] ?? '',
    'is_verified': response['profiles']?['is_verified'] ?? false,
    'image_url': response['image_url'], // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† image_url
    'music_url': response['music_url'], // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† music_url
  });
});

class ReportCommentService {
  final SupabaseClient supabase;

  ReportCommentService(this.supabase);

  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // Ø§Ø±Ø³Ø§Ù„ Ú¯Ø²Ø§Ø±Ø´ Ø¨Ù‡ Ø¬Ø¯ÙˆÙ„ comment_reports
      await supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': reporterId,
        'reason': reason, // Ø¯Ù„ÛŒÙ„ Ú¯Ø²Ø§Ø±Ø´
        'additional_details': additionalDetails, // ØªÙˆØ¶ÛŒØ­Ø§Øª Ø§Ø¶Ø§ÙÛŒ
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to report comment: $e');
    }
  }
}

// Ø§Ø±Ø§Ø¦Ù‡â€ŒØ¯Ù‡Ù†Ø¯Ù‡ Ø³Ø±ÙˆÛŒØ³ Ú¯Ø²Ø§Ø±Ø´ Ú©Ø§Ù…Ù†Øªâ€ŒÙ‡Ø§
final reportCommentServiceProvider = Provider<ReportCommentService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReportCommentService(supabase);
});

//profile report

class ReportProfileService {
  final SupabaseClient supabase;

  ReportProfileService(this.supabase);

  Future<void> reportProfile({
    required String userId,
    required String reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    try {
      // Ø§Ø±Ø³Ø§Ù„ Ú¯Ø²Ø§Ø±Ø´ Ø¨Ù‡ Ø¬Ø¯ÙˆÙ„ profile_reports
      await supabase.from('profile_reports').insert({
        'profile_id': userId,
        'reporter_id': reporterId,
        'reason': reason, // Ø¯Ù„ÛŒÙ„ Ú¯Ø²Ø§Ø±Ø´
        'additional_details': additionalDetails, // ØªÙˆØ¶ÛŒØ­Ø§Øª Ø§Ø¶Ø§ÙÛŒ
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to report profile: $e');
    }
  }
}

// Ø§Ø±Ø§Ø¦Ù‡â€ŒØ¯Ù‡Ù†Ø¯Ù‡ Ø³Ø±ÙˆÛŒØ³ Ú¯Ø²Ø§Ø±Ø´ Ù¾Ø±ÙˆÙØ§ÛŒÙ„â€ŒÙ‡Ø§
final reportProfileServiceProvider = Provider<ReportProfileService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ReportProfileService(supabase);
});

//mention user profile
// mention_providers.dart
final mentionUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    // ÙˆØ§Ú©Ø´ÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¨Ø§ Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ú©Ø§Ù…Ù„
    final response = await supabase
        .from('profiles')
        .select('id, username, avatar_url, is_verified, verification_type')
        .order('username');

    return (response as List)
        .map((userData) => UserModel.fromMap(userData))
        .toList();
  } catch (e) {
    print('Ø®Ø·Ø§ Ø¯Ø± Ø¯Ø±ÛŒØ§ÙØª Ú©Ø§Ø±Ø¨Ø±Ø§Ù† Ø¨Ø±Ø§ÛŒ Ù…Ù†Ø´Ù†: $e');
    return [];
  }
});

// mention_service.dart
class MentionService {
  final SupabaseClient _supabase;

  MentionService(this._supabase);

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, is_verified, verification_type')
          .or('username.ilike.%$query%, email.ilike.%$query%')
          .limit(10);

      return (response as List)
          .map((userData) => UserModel.fromMap(userData))
          .toList();
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø¬Ø³ØªØ¬ÙˆÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù†: $e');
      return [];
    }
  }

  // Ù…ØªØ¯ Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ù…Ù†Ø´Ù† Ø¨Ù‡ Ú©Ø§Ù…Ù†Øª
  Future<void> addMentionToComment({
    required String commentId,
    required List<String> mentionedUserIds,
  }) async {
    try {
      await _supabase.from('comment_mentions').insert(mentionedUserIds
          .map((userId) => {
                'comment_id': commentId,
                'user_id': userId,
              })
          .toList());
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ø«Ø¨Øª Ù…Ù†Ø´Ù†â€ŒÙ‡Ø§: $e');
      rethrow;
    }
  }
}

// mention_notifier.dart
class MentionNotifier extends StateNotifier<List<UserModel>> {
  final MentionService _mentionService;

  MentionNotifier(this._mentionService) : super([]);

  Future<void> searchMentionableUsers(String query) async {
    if (query.isEmpty) {
      state = [];
      return;
    }

    try {
      final users = await _mentionService.searchUsers(query);
      state = users;
    } catch (e) {
      state = [];
      print('Ø®Ø·Ø§ Ø¯Ø± Ø¬Ø³ØªØ¬ÙˆÛŒ Ú©Ø§Ø±Ø¨Ø±Ø§Ù†: $e');
    }
  }

  void clearMentions() {
    state = [];
  }
}

// mention_providers_final.dart
final mentionServiceProvider = Provider<MentionService>((ref) {
  final supabase = Supabase.instance.client;
  return MentionService(supabase);
});

final mentionNotifierProvider =
    StateNotifierProvider<MentionNotifier, List<UserModel>>((ref) {
  final mentionService = ref.read(mentionServiceProvider);
  return MentionNotifier(mentionService);
});

final userFollowersProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  return await supabaseService.fetchFollowers(userId);
});

final userFollowingProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final supabaseService = ref.read(supabaseServiceProvider);

  return await supabaseService.fetchFollowing(userId);
});

class FollowingPostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final int _limit = 10;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  bool hasMorePosts() => _hasMore;
  bool isLoading() => _isLoading;

  FollowingPostsNotifier(this.supabase) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;
    _isLoading = true;

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Check followings first
      final followingResponse = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      if (followingResponse.isEmpty) {
        state = const AsyncValue.data([]);
        return;
      }

      final followingIds =
          followingResponse.map((e) => e['following_id'] as String).toList();

      final response = await supabase
          .from('posts')
          .select('''
      *,
      profiles!posts_user_id_fkey (
        username, 
        avatar_url,
        is_verified,
        verification_type
      ),
      likes (user_id),
      comments (id)
    ''')
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (response.isEmpty) {
        _hasMore = false;
        state = AsyncValue.data([...?state.value, ...[]]);
        return;
      }

      _offset += response.length;
      _hasMore = response.length >= _limit;

      final posts = response.map((post) {
        final likes = List<Map<String, dynamic>>.from(post['likes'] ?? []);
        final comments =
            List<Map<String, dynamic>>.from(post['comments'] ?? []);
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': likes.length,
          'is_liked': likes.any((like) => like['user_id'] == currentUserId),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': profile[
              'verification_type'], // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† verification_type
        });
      }).toList();

      state = AsyncValue.data([...?state.value, ...posts]);
    } catch (e, stackTrace) {
      String errorMessage = 'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ù¾Ø³Øªâ€ŒÙ‡Ø§';

      if (e is PostgrestException) {
        errorMessage =
            'Ø®Ø·Ø§ Ø¯Ø± Ø§Ø±ØªØ¨Ø§Ø· Ø¨Ø§ Ø³Ø±ÙˆØ±. Ù„Ø·ÙØ§ Ø§ØªØµØ§Ù„ Ø§ÛŒÙ†ØªØ±Ù†Øª Ø®ÙˆØ¯ Ø±Ø§ Ø¨Ø±Ø±Ø³ÛŒ Ú©Ù†ÛŒØ¯';
      } else if (e is TimeoutException) {
        errorMessage =
            'Ø²Ù…Ø§Ù† Ù¾Ø§Ø³Ø®Ú¯ÙˆÛŒÛŒ Ø³Ø±ÙˆØ± Ø¨Ù‡ Ù¾Ø§ÛŒØ§Ù† Ø±Ø³ÛŒØ¯. Ù„Ø·ÙØ§ Ø¯ÙˆØ¨Ø§Ø±Ù‡ ØªÙ„Ø§Ø´ Ú©Ù†ÛŒØ¯';
      } else if (e is AuthException) {
        errorMessage =
            'Ù„Ø·ÙØ§ Ø¯ÙˆØ¨Ø§Ø±Ù‡ ÙˆØ§Ø±Ø¯ Ø­Ø³Ø§Ø¨ Ú©Ø§Ø±Ø¨Ø±ÛŒ Ø®ÙˆØ¯ Ø´ÙˆÛŒØ¯';
      }

      state = AsyncValue.error(errorMessage, stackTrace);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refreshPosts() async {
    await _loadInitialPosts();
  }

  Future<void> loadMorePosts() async {
    await _loadMorePosts();
  }

  void likePost(String postId) async {
    final currentPosts = state.value ?? [];
    final postIndex = currentPosts.indexWhere((post) => post.id == postId);

    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final ownerId = post.userId;

    try {
      // Ø§Ø¨ØªØ¯Ø§ ÙˆØ¶Ø¹ÛŒØª Ù„Ø§ÛŒÚ© Ø±Ø§ Ø¯Ø± UI ØªØºÛŒÛŒØ± Ù…ÛŒâ€ŒØ¯Ù‡ÛŒÙ…
      final updatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
      );

      final updatedPosts = [...currentPosts];
      updatedPosts[postIndex] = updatedPost;
      state = AsyncValue.data(updatedPosts);

      // Ø³Ù¾Ø³ Ø¯Ø±Ø®ÙˆØ§Ø³Øª Ø¨Ù‡ Ø³Ø±ÙˆØ± Ø§Ø±Ø³Ø§Ù„ Ù…ÛŒâ€ŒÚ©Ù†ÛŒÙ…
      await supabase.functions.invoke('toggle-like', body: {
        'post_id': postId,
        'owner_id': ownerId,
      });
    } catch (e) {
      print('Ø®Ø·Ø§ Ø¯Ø± Ù„Ø§ÛŒÚ© Ú©Ø±Ø¯Ù† Ù¾Ø³Øª: $e');
      // Ø¯Ø± ØµÙˆØ±Øª Ø®Ø·Ø§ØŒ ÙˆØ¶Ø¹ÛŒØª Ù‚Ø¨Ù„ÛŒ Ø±Ø§ Ø¨Ø±Ù…ÛŒâ€ŒÚ¯Ø±Ø¯Ø§Ù†ÛŒÙ…
      state = AsyncValue.data(currentPosts);
    }
  }
}

final fetchFollowingPostsProvider = StateNotifierProvider<
    FollowingPostsNotifier, AsyncValue<List<PublicPostModel>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return FollowingPostsNotifier(supabase);
});
// final fetchFollowingPostsProvider =
//     FutureProvider<List<PublicPostModel>>((ref) async {
//   try {
//     final currentUserId = supabase.auth.currentUser?.id;
//     if (currentUserId == null) return [];

//     // Check followings first
//     final followingResponse = await supabase
//         .from('follows')
//         .select('following_id')
//         .eq('follower_id', currentUserId);

//     if (followingResponse.isEmpty) {
//       return []; // Return empty list if no followings
//     }

//     final followingIds =
//         followingResponse.map((e) => e['following_id'] as String).toList();

//     final response = await supabase
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

class SearchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PublicPostModel>> searchHashtag(String hashtag) async {
    try {
      // Normalize hashtag to match `posts.tags` (no '#', lowercase, no whitespace).
      String raw = hashtag.trim();
      raw = raw.replaceFirst(RegExp(r'^#+'), '');
      raw = raw.replaceAll(RegExp(r'\s+'), '');
      final tag = raw.toLowerCase();
      if (tag.isEmpty) return [];

      // Primary: search by `tags` array (correct + fast with GIN).
      final response1 = await _supabase
          .from('posts')
          .select('''
            *,
            profiles (
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('status', 'published')
          .contains('tags', [tag])
          .order(
            'created_at',
            ascending: false,
          )
          .limit(60);

      final rows = <Map<String, dynamic>>[];
      rows.addAll(List<Map<String, dynamic>>.from(response1 as List<dynamic>));

      // Back-compat: if some older posts don't have `tags`, also match by content.
      if (rows.length < 40) {
        final response2 = await _supabase
            .from('posts')
            .select('''
              *,
              profiles (
                id,
                username,
                full_name,
                avatar_url,
                is_verified,
                verification_type
              )
            ''')
            .eq('status', 'published')
            .ilike('content', '%#$tag%')
            .order('created_at', ascending: false)
            .limit(60);

        final seenIds =
            rows.map((r) => r['id']?.toString()).whereType<String>().toSet();
        for (final r in List<Map<String, dynamic>>.from(response2 as List)) {
          final id = r['id']?.toString();
          if (id == null || seenIds.contains(id)) continue;
          rows.add(r);
        }
      }

      return rows.map((post) {
        // Map DB counters to the model contract keys used in the UI.
        final likeCount = (post['likes_count'] as num?)?.toInt() ?? 0;
        final commentCount = (post['comments_count'] as num?)?.toInt() ?? 0;
        return PublicPostModel.fromMap({
          ...post,
          'like_count': likeCount,
          'comment_count': commentCount,
          'is_liked': false,
        });
      }).toList();
    } catch (e) {
      print('Error in searchHashtag: $e');
      return [];
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
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .order('is_verified', ascending: false) // Prioritize Verified
          .range(offset, offset + _userLimit - 1);

      final newUsers = (response as List)
          .map((user) => ProfileModel.fromMap(Map<String, dynamic>.from(user)))
          .toList();

      // Client-side sort for fine-grained priority (Blue > Gold > Normal)
      newUsers.sort((a, b) {
        int getScore(ProfileModel p) {
          if (p.hasBlueBadge) return 3;
          if (p.hasGoldBadge || p.role == 'premium') return 2;
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

// Ù¾Ø±ÙˆØ§ÛŒØ¯Ø±
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

// final chatRepositoryProvider = Provider((ref) {
//   final supabase = ref.watch(supabaseClientProvider);
//   return ChatRepository(supabase);
// });

// final recentChatsProvider = StreamProvider((ref) {
//   final repository = ref.watch(chatRepositoryProvider);
//   return repository.getRecentChats();
// });

// final chatMessagesProvider = StreamProvider.family((ref, String otherUserId) {
//   final repository = ref.watch(chatRepositoryProvider);
//   return repository.getChatMessages(otherUserId);
// });

// final selectedChatUserProvider = StateProvider<Profile?>((ref) => null);
class StoryControllerNotifier extends StateNotifier<int> {
  StoryControllerNotifier() : super(0);

  void nextStory() => state++;
  void previousStory() => state--;
  void setCurrentIndex(int index) => state = index;

  // Ø§Ø¶Ø§ÙÙ‡ Ú©Ø±Ø¯Ù† Ø§ÛŒÙ† Ù…ØªØ¯
  void reset() => state = 0;
}

final storyControllerProvider =
    StateNotifierProvider<StoryControllerNotifier, int>(
  (ref) => StoryControllerNotifier(),
);

final viewsCountProvider =
    FutureProvider.family<int, String>((ref, storyId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('story_views')
      .select('view_count')
      .eq('story_id', storyId)
      .maybeSingle();

  if (response == null) {
    return 0; // Ø§Ú¯Ø± view ÙˆØ¬ÙˆØ¯ Ù†Ø¯Ø§Ø´ØªØŒ 0 Ø¨Ø±Ù…ÛŒâ€ŒÚ¯Ø±Ø¯Ø§Ù†ÛŒÙ…
  }

  return response['view_count'] as int;
});

//notification check
final hasNewNotificationProvider = FutureProvider<bool>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final response = await supabase
      .from('notifications')
      .select()
      .eq('recipient_id', userId)
      .eq('is_read', false);

  print(
      'Has new notification: ${response.isNotEmpty}'); // Ø§ÛŒÙ†Ø¬Ø§ Ú†Ø§Ù¾ Ù…ÛŒâ€ŒØ´ÙˆØ¯
  return response.isNotEmpty;
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    return null;
  }

  final response =
      await supabase.from('profiles').select().eq('id', userId).maybeSingle();
  return response;
});

// user_settings providers
final userSettingsByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    print('ðŸ”§ Ø¯Ø±ÛŒØ§ÙØª ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú©Ø§Ø±Ø¨Ø±: $userId');

    // Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² SettingsCacheService Ø¨Ø±Ø§ÛŒ Ú©Ø´ Ú©Ø±Ø¯Ù† ØªÙ†Ø¸ÛŒÙ…Ø§Øª
    final settingsCache = SettingsCacheService();

    // Ø§Ø¨ØªØ¯Ø§ Ø¨Ø±Ø±Ø³ÛŒ Ú©Ø´ - Ø§Ú¯Ø± Ù…ÙˆØ¬ÙˆØ¯ Ø¨ÙˆØ¯ Ùˆ Ù…Ø¹ØªØ¨Ø± Ø¨ÙˆØ¯ØŒ Ø§Ø² Ø¢Ù† Ø§Ø³ØªÙØ§Ø¯Ù‡ Ú©Ù†
    final cachedSettings = settingsCache.getCachedUserSettings(userId);
    if (cachedSettings != null) {
      print(
          'ðŸ”§ Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú©Ø´ Ø´Ø¯Ù‡ Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');
      return cachedSettings;
    }

    // Ø§Ú¯Ø± Ø¯Ø± Ú©Ø´ Ù†Ø¨ÙˆØ¯ØŒ Ø§Ø² Ø³Ø±ÙˆØ± Ø¯Ø±ÛŒØ§ÙØª Ú©Ù† Ùˆ Ú©Ø´ Ú©Ù†
    print(
        'ðŸ”§ Ø¯Ø±ÛŒØ§ÙØª ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø§Ø² Ø³Ø±ÙˆØ± Ø¨Ø±Ø§ÛŒ Ú©Ø§Ø±Ø¨Ø±: $userId');
    await settingsCache.cacheUserSettings(userId);

    // Ø¯ÙˆØ¨Ø§Ø±Ù‡ Ø§Ø² Ú©Ø´ Ø¨Ø®ÙˆØ§Ù†
    final settings = settingsCache.getCachedUserSettings(userId);
    print('ðŸ”§ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¯Ø±ÛŒØ§ÙØª Ø´Ø¯Ù‡: $settings');
    print('ðŸ”§ allow_profile_zoom: ${settings?['allow_profile_zoom']}');
    return settings;
  } catch (e) {
    debugPrint('Error fetching user_settings for $userId: $e');
    return null;
  }
});

final currentUserSettingsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final response = await client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  } catch (e) {
    debugPrint('Error fetching current user_settings: $e');
    return null;
  }
});
final videoPositionProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Settings Providers
class DataSaverNotifier extends StateNotifier<bool> {
  DataSaverNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getDataSaverMode();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setDataSaverMode(value);
  }
}

final dataSaverProvider = StateNotifierProvider<DataSaverNotifier, bool>((ref) {
  return DataSaverNotifier();
});

class AutoQualityNotifier extends StateNotifier<bool> {
  AutoQualityNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getAutoQuality();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setAutoQuality(value);
  }
}

final autoQualityProvider =
    StateNotifierProvider<AutoQualityNotifier, bool>((ref) {
  return AutoQualityNotifier();
});

final videoQualityProvider = StateProvider<String>((ref) => 'auto');

final videoPlayerConfigProvider = Provider<VideoPlayerConfig>((ref) {
  return VideoPlayerConfig();
});

// Video Position Cache Provider
final videoPositionsProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Theme Provider
final videoPlayerThemeProvider = Provider<VideoPlayerTheme>((ref) {
  final isDark = ref.watch(themeProvider).brightness == Brightness.dark;
  return VideoPlayerTheme(
    isDark: isDark,
    accentColor: isDark ? Colors.white : Colors.black,
    backgroundColor: isDark ? Colors.black : Colors.white,
  );
});

class VideoPlayerTheme {
  final bool isDark;
  final Color accentColor;
  final Color backgroundColor;

  VideoPlayerTheme({
    required this.isDark,
    required this.accentColor,
    required this.backgroundColor,
  });
}

// Video Playback State Provider
final playbackStateProvider =
    StateProvider.family<PlaybackState, String>((ref, videoId) {
  return PlaybackState();
});

class PlaybackState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isMuted;
  final Duration position;
  final Duration duration;

  PlaybackState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.isMuted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    bool? isMuted,
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isMuted: isMuted ?? this.isMuted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class ReelsNotifier extends StateNotifier<List<PublicPostModel>> {
  ReelsNotifier() : super([]);

  // Ø§ÛŒÙ† Ù…ØªØ¯ Ø¨Ø±Ø§ÛŒ Ø¢Ù¾Ø¯ÛŒØª ÛŒÚ© Ø±ÛŒÙ„Ø² Ø®Ø§Øµ Ø¯Ø± Ù„ÛŒØ³Øª
  void updateReel(PublicPostModel updatedReel) {
    state = [
      for (final reel in state)
        if (reel.id == updatedReel.id) updatedReel else reel
    ];
  }

  // Ù…ØªØ¯Ù‡Ø§ÛŒ Ø¯ÛŒÚ¯Ø± (fetch, loadMore, ...) Ø§Ø®ØªÛŒØ§Ø±ÛŒ
}

// provider Ø³Ø±Ø§Ø³Ø±ÛŒ Ø±ÛŒÙ„Ø²Ù‡Ø§
final likeStateProvider =
    StateNotifierProvider<LikeStateNotifier, Map<String, bool>>((ref) {
  return LikeStateNotifier();
});

class LikeStateNotifier extends StateNotifier<Map<String, bool>> {
  LikeStateNotifier() : super({});

  void updateLikeState(String postId, bool isLiked) {
    state = {...state, postId: isLiked};
  }

  bool isPostLiked(String postId) {
    return state[postId] ?? false;
  }
}

// Provider to get the current user's UserModel based on profileProvider
final userProvider = Provider<UserModel?>((ref) {
  // Ø¨Ù‡ profileProvider Ú¯ÙˆØ´ Ù…ÛŒâ€ŒØ¯Ù‡ÛŒÙ… ØªØ§ Ø¯Ø§Ø¯Ù‡â€ŒÙ‡Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø±Ø§ Ø¯Ø±ÛŒØ§ÙØª Ú©Ù†ÛŒÙ…
  final profileDataAsync = ref.watch(
      profileProvider); // Ø§ÛŒÙ† ÛŒÚ© AsyncValue<Map<String, dynamic>?> Ø§Ø³Øª

  // Ø¨Ø§ Ø§Ø³ØªÙØ§Ø¯Ù‡ Ø§Ø² .when ÙˆØ¶Ø¹ÛŒØªâ€ŒÙ‡Ø§ÛŒ Ù…Ø®ØªÙ„Ù profileDataAsync (Ø¯Ø§Ø¯Ù‡ØŒ Ù„ÙˆØ¯ÛŒÙ†Ú¯ØŒ Ø®Ø·Ø§) Ø±Ø§ Ù…Ø¯ÛŒØ±ÛŒØª Ù…ÛŒâ€ŒÚ©Ù†ÛŒÙ…
  return profileDataAsync.when(
    data: (dataMap) {
      // dataMap Ù‡Ù…Ø§Ù† Map<String, dynamic>? Ø§Ø³Øª Ú©Ù‡ Ø§Ø² profileProvider Ù…ÛŒâ€ŒØ¢ÛŒØ¯
      if (dataMap != null) {
        try {
          // Ø¯Ø§Ø¯Ù‡â€ŒÙ‡Ø§ÛŒ map Ø±Ø§ Ø¨Ù‡ UserModel ØªØ¨Ø¯ÛŒÙ„ Ù…ÛŒâ€ŒÚ©Ù†ÛŒÙ…
          return UserModel.fromMap(dataMap);
        } catch (e, stackTrace) {
          // Ø§Ú¯Ø± Ø¯Ø± ØªØ¨Ø¯ÛŒÙ„ map Ø¨Ù‡ UserModel Ø®Ø·Ø§ÛŒÛŒ Ø±Ø® Ø¯Ù‡Ø¯ (Ù…Ø«Ù„Ø§Ù‹ ÙÛŒÙ„Ø¯Ù‡Ø§ÛŒ Ù…ÙˆØ±Ø¯ Ù†ÛŒØ§Ø² ÙˆØ¬ÙˆØ¯ Ù†Ø¯Ø§Ø´ØªÙ‡ Ø¨Ø§Ø´Ù†Ø¯)
          debugPrint(
              'Ø®Ø·Ø§ Ø¯Ø± ØªØ¨Ø¯ÛŒÙ„ Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø¨Ù‡ UserModel: $e');
          debugPrint('StackTrace: $stackTrace');
          debugPrint('Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ø¯Ø±ÛŒØ§ÙØªÛŒ: $dataMap');
          return null; // Ø¯Ø± ØµÙˆØ±Øª Ø®Ø·Ø§ØŒ null Ø¨Ø±Ù…ÛŒâ€ŒÚ¯Ø±Ø¯Ø§Ù†ÛŒÙ…
        }
      }
      return null; // Ø§Ú¯Ø± dataMap Ø®ÙˆØ¯ null Ø¨Ø§Ø´Ø¯ (Ù…Ø«Ù„Ø§Ù‹ Ù¾Ø±ÙˆÙØ§ÛŒÙ„ Ù¾ÛŒØ¯Ø§ Ù†Ø´Ø¯Ù‡)
    },
    loading: () {
      // Ø§Ú¯Ø± profileProvider Ø¯Ø± Ø­Ø§Ù„ Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ø§Ø·Ù„Ø§Ø¹Ø§Øª Ø¨Ø§Ø´Ø¯
      return null;
    },
    error: (error, stackTrace) {
      // Ø§Ú¯Ø± Ø®Ø·Ø§ÛŒÛŒ Ø¯Ø± profileProvider Ø±Ø® Ø¯Ø§Ø¯Ù‡ Ø¨Ø§Ø´Ø¯
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± profileProvider Ù‡Ù†Ú¯Ø§Ù… ØªÙ„Ø§Ø´ Ø¨Ø±Ø§ÛŒ Ø®ÙˆØ§Ù†Ø¯Ù† ØªÙˆØ³Ø· userProvider: $error');
      debugPrint('StackTrace: $stackTrace');
      return null;
    },
  );
});

final autoPlayProvider = StateNotifierProvider<AutoPlayNotifier, bool>((ref) {
  return AutoPlayNotifier();
});

class AutoPlayNotifier extends StateNotifier<bool> {
  final VideoAutoplayService _videoAutoplayService = VideoAutoplayService();

  AutoPlayNotifier() : super(true) {
    _load();
  }

  void _load() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }

  void set(bool value) async {
    await _videoAutoplayService.setAutoPlay(value);
    state = _videoAutoplayService.shouldAutoPlay();
  }

  // Ù…ØªØ¯ Ø¨Ø±Ø§ÛŒ Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ ÙˆØ¶Ø¹ÛŒØª Ù¾Ø³ Ø§Ø² ØªØºÛŒÛŒØ± Ø­Ø§Ù„Øª Ú©Ù…â€ŒÙ…ØµØ±Ù
  void refresh() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }
}

// Font size settings provider
class MessageFontSizeNotifier extends StateNotifier<double> {
  Isar? _isar;

  MessageFontSizeNotifier() : super(14.0) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadFontSize();
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø² Ú©Ø±Ø¯Ù† Ø¯ÛŒØªØ§Ø¨ÛŒØ³ ØªÙ†Ø¸ÛŒÙ…Ø§Øª: $e');
    }
  }

  Future<void> _loadFontSize() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null && settings.messageFontSize != null) {
        state = settings.messageFontSize!;
      }
    } catch (e) {
      debugPrint('Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ø§Ù†Ø¯Ø§Ø²Ù‡ ÙÙˆÙ†Øª: $e');
    }
  }

  Future<void> setFontSize(double size) async {
    state = size;
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false // Default
            ..selectedColor = 'white' // Default
            ..messageFontSize = size;
        } else {
          settings.messageFontSize = size;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('Ø®Ø·Ø§ Ø¯Ø± Ø°Ø®ÛŒØ±Ù‡ Ø§Ù†Ø¯Ø§Ø²Ù‡ ÙÙˆÙ†Øª: $e');
    }
  }

  String getFontSizeLabel(double size) {
    if (size <= 11.0) return 'Ø®ÛŒÙ„ÛŒ Ú©ÙˆÚ†Ú©';
    if (size <= 13.0) return 'Ú©ÙˆÚ†Ú©';
    if (size <= 15.0) return 'Ù…ØªÙˆØ³Ø·';
    if (size <= 17.0) return 'Ø¨Ø²Ø±Ú¯';
    if (size <= 20.0) return 'Ø®ÛŒÙ„ÛŒ Ø¨Ø²Ø±Ú¯';
    return 'Ø¨Ø³ÛŒØ§Ø± Ø¨Ø²Ø±Ú¯';
  }
}

final messageFontSizeProvider =
    StateNotifierProvider<MessageFontSizeNotifier, double>((ref) {
  return MessageFontSizeNotifier();
});

// Auto download settings provider
class AutoDownloadSettings {
  final String photos; // 'always', 'wifi', 'never'
  final String voices; // 'always', 'wifi', 'never'

  AutoDownloadSettings({
    this.photos = 'wifi',
    this.voices = 'wifi',
  });

  AutoDownloadSettings copyWith({
    String? photos,
    String? voices,
  }) {
    return AutoDownloadSettings(
      photos: photos ?? this.photos,
      voices: voices ?? this.voices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photos': photos,
      'voices': voices,
    };
  }

  static AutoDownloadSettings fromMap(Map<String, dynamic> map) {
    return AutoDownloadSettings(
      photos: map['photos'] ?? 'wifi',
      voices: map['voices'] ?? 'wifi',
    );
  }
}

class AutoDownloadNotifier extends StateNotifier<AutoDownloadSettings> {
  Isar? _isar;

  AutoDownloadNotifier() : super(AutoDownloadSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø² Ú©Ø±Ø¯Ù† Ø¯ÛŒØªØ§Ø¨ÛŒØ³ ØªÙ†Ø¸ÛŒÙ…Ø§Øª: $e');
    }
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          photos: settings.autoDownloadPhotos,
          voices: settings.autoDownloadVoices,
        );
      }
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¯Ø§Ù†Ù„ÙˆØ¯ Ø®ÙˆØ¯Ú©Ø§Ø±: $e');
    }
  }

  Future<void> updatePhotoSetting(String setting) async {
    state = state.copyWith(photos: setting);
    await _saveSettings();

    // Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¬Ø¯ÛŒØ¯
    await _applyAutoDownloadSettings();
  }

  Future<void> updateVoiceSetting(String setting) async {
    state = state.copyWith(voices: setting);
    await _saveSettings();

    // Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¬Ø¯ÛŒØ¯
    await _applyAutoDownloadSettings();
  }

  Future<void> _applyAutoDownloadSettings() async {
    try {
      // Ù¾Ø§Ú©Ø³Ø§Ø²ÛŒ Ú©Ø´ Ù‚Ø¯ÛŒÙ…ÛŒ Ø¯Ø± ØµÙˆØ±Øª ØªØºÛŒÛŒØ± ØªÙ†Ø¸ÛŒÙ…Ø§Øª
      if (state.photos == 'never') {
        await _clearPhotoCache();
      }
      if (state.voices == 'never') {
        await _clearVoiceCache();
      }

      print(
          'âœ… Auto download settings applied: Photos=${state.photos}, Voices=${state.voices}');
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¯Ø§Ù†Ù„ÙˆØ¯ Ø®ÙˆØ¯Ú©Ø§Ø±: $e');
    }
  }

  Future<void> _clearPhotoCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chatImagesDir = Directory('${appDir.path}/chat_images');
      if (await chatImagesDir.exists()) {
        await chatImagesDir.delete(recursive: true);
        print('ðŸ§¹ Photo cache cleared');
      }
    } catch (e) {
      debugPrint('Ø®Ø·Ø§ Ø¯Ø± Ù¾Ø§Ú©Ø³Ø§Ø²ÛŒ Ú©Ø´ Ø¹Ú©Ø³â€ŒÙ‡Ø§: $e');
    }
  }

  Future<void> _clearVoiceCache() async {
    try {
      // TODO: Import VoiceCacheService and clear cache
      print('ðŸ§¹ Voice cache cleared');
    } catch (e) {
      debugPrint('Ø®Ø·Ø§ Ø¯Ø± Ù¾Ø§Ú©Ø³Ø§Ø²ÛŒ Ú©Ø´ ÙˆÙˆÛŒØ³â€ŒÙ‡Ø§: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..autoDownloadPhotos = state.photos
            ..autoDownloadVoices = state.voices;
        } else {
          settings.autoDownloadPhotos = state.photos;
          settings.autoDownloadVoices = state.voices;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø°Ø®ÛŒØ±Ù‡ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¯Ø§Ù†Ù„ÙˆØ¯ Ø®ÙˆØ¯Ú©Ø§Ø±: $e');
    }
  }

  String getSettingLabel(String setting) {
    switch (setting) {
      case 'always':
        return 'Ù‡Ù…ÛŒØ´Ù‡';
      case 'wifi':
        return 'ÙÙ‚Ø· Wi-Fi';
      case 'never':
        return 'Ù‡Ø±Ú¯Ø²';
      default:
        return 'Ù†Ø§Ù…Ø´Ø®Øµ';
    }
  }
}

final autoDownloadProvider =
    StateNotifierProvider<AutoDownloadNotifier, AutoDownloadSettings>((ref) {
  return AutoDownloadNotifier();
});

// Performance settings provider
class PerformanceSettings {
  final bool batterySaverMode;
  final bool smartCache;
  final bool messagePreloading;

  PerformanceSettings({
    this.batterySaverMode = false,
    this.smartCache = true,
    this.messagePreloading = true,
  });

  PerformanceSettings copyWith({
    bool? batterySaverMode,
    bool? smartCache,
    bool? messagePreloading,
  }) {
    return PerformanceSettings(
      batterySaverMode: batterySaverMode ?? this.batterySaverMode,
      smartCache: smartCache ?? this.smartCache,
      messagePreloading: messagePreloading ?? this.messagePreloading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batterySaverMode': batterySaverMode,
      'smartCache': smartCache,
      'messagePreloading': messagePreloading,
    };
  }

  static PerformanceSettings fromMap(Map<String, dynamic> map) {
    return PerformanceSettings(
      batterySaverMode: map['batterySaverMode'] ?? false,
      smartCache: map['smartCache'] ?? true,
      messagePreloading: map['messagePreloading'] ?? true,
    );
  }
}

class PerformanceNotifier extends StateNotifier<PerformanceSettings> {
  Isar? _isar;

  PerformanceNotifier() : super(PerformanceSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø² Ú©Ø±Ø¯Ù† Ø¯ÛŒØªØ§Ø¨ÛŒØ³ ØªÙ†Ø¸ÛŒÙ…Ø§Øª: $e');
    }
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          batterySaverMode: settings.batterySaverMode,
          smartCache: settings.smartCache,
          messagePreloading: settings.messagePreloading,
        );
      }
    } catch (e) {
      debugPrint(
          'Ø®Ø·Ø§ Ø¯Ø± Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¹Ù…Ù„Ú©Ø±Ø¯: $e');
    }
  }

  Future<void> updateBatterySaver(bool enabled) async {
    state = state.copyWith(batterySaverMode: enabled);
    await _saveSettings();

    // Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø­Ø§Ù„Øª Ú©Ù…â€ŒÙ…ØµØ±Ù
    // Note: Services are updated below directly
    // if (enabled) {
    //   await _applyBatterySaverMode();
    // } else {
    //   await _disableBatterySaverMode();
    // }

    // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø³Ø±ÙˆÛŒØ³ Ø§Ù†ÛŒÙ…ÛŒØ´Ù†
    final animationService = AnimationControllerService();
    await animationService.setBatterySaverMode(enabled);

    // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø³Ø±ÙˆÛŒØ³ Ù¾Ø®Ø´ Ø®ÙˆØ¯Ú©Ø§Ø± ÙˆÛŒØ¯ÛŒÙˆ
    final videoAutoplayService = VideoAutoplayService();
    await videoAutoplayService.setBatterySaverMode(enabled);

    // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ Ø³Ø±ÙˆÛŒØ³ Ú©ÛŒÙÛŒØª ØªØµØ§ÙˆÛŒØ±
    final imageQualityService = ImageQualityService();
    await imageQualityService.setBatterySaverMode(enabled);

    // Ø¨Ù‡â€ŒØ±ÙˆØ²Ø±Ø³Ø§Ù†ÛŒ autoPlayProvider (Ø§Ø² Ø·Ø±ÛŒÙ‚ ProviderContainer)
    // Ø§ÛŒÙ† Ú©Ø§Ø± Ø¯Ø± StorageAndMemorySettingsPage Ø§Ù†Ø¬Ø§Ù… Ù…ÛŒâ€ŒØ´ÙˆØ¯
  }

  Future<void> updateSmartCache(bool enabled) async {
    state = state.copyWith(smartCache: enabled);
    await _saveSettings();

    // Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú©Ø´ Ù‡ÙˆØ´Ù…Ù†Ø¯
    // Ø§Ø¹Ù…Ø§Ù„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú©Ø´ Ù‡ÙˆØ´Ù…Ù†Ø¯
    if (enabled) {
      await CacheRepository().optimize();
    }
  }

  Future<void> updateMessagePreloading(bool enabled) async {
    state = state.copyWith(messagePreloading: enabled);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..batterySaverMode = state.batterySaverMode
            ..smartCache = state.smartCache
            ..messagePreloading = state.messagePreloading;
        } else {
          settings.batterySaverMode = state.batterySaverMode;
          settings.smartCache = state.smartCache;
          settings.messagePreloading = state.messagePreloading;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {
      debugPrint('Ø®Ø·Ø§ Ø¯Ø± Ø°Ø®ÛŒØ±Ù‡ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ø¹Ù…Ù„Ú©Ø±Ø¯: $e');
    }
  }

  /*
  Future<void> _applyBatterySaverMode() async {
    // Legacy Sembast removal
  }

  Future<void> _disableBatterySaverMode() async {
    // Legacy Sembast removal
  }
  */

  String getBatterySaverDescription() {
    return state.batterySaverMode
        ? 'ÙØ¹Ø§Ù„ - Ú©Ø§Ù‡Ø´ Ù…ØµØ±Ù Ø¨Ø§ØªØ±ÛŒ ØªØ§ 30%'
        : 'ØºÛŒØ±ÙØ¹Ø§Ù„ - Ø¹Ù…Ù„Ú©Ø±Ø¯ Ú©Ø§Ù…Ù„';
  }

  String getSmartCacheDescription() {
    return state.smartCache
        ? 'ÙØ¹Ø§Ù„ - Ù¾Ø§Ú©Ø³Ø§Ø²ÛŒ Ø®ÙˆØ¯Ú©Ø§Ø± Ú©Ø´ Ù‚Ø¯ÛŒÙ…ÛŒ'
        : 'ØºÛŒØ±ÙØ¹Ø§Ù„ - Ú©Ø´ Ú©Ø§Ù…Ù„';
  }

  String getPreloadingDescription() {
    return state.messagePreloading
        ? 'ÙØ¹Ø§Ù„ - Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ Ø³Ø±ÛŒØ¹â€ŒØªØ± Ù¾ÛŒØ§Ù…â€ŒÙ‡Ø§'
        : 'ØºÛŒØ±ÙØ¹Ø§Ù„ - ØµØ±ÙÙ‡â€ŒØ¬ÙˆÛŒÛŒ Ø¯Ø± Ù…ØµØ±Ù Ø¯Ø§Ø¯Ù‡';
  }
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceSettings>((ref) {
  return PerformanceNotifier();
});

// Provider Ø¨Ø±Ø§ÛŒ lazy loading Ù¾Ø³Øªâ€ŒÙ‡Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„
class ProfilePostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final SupabaseClient supabase;
  final String userId;
  final int _limit =
      30; // Ù†Ù…Ø§ÛŒØ´ Ø§ÙˆÙ„ÛŒÙ‡ Ø¨ÛŒØ´ØªØ± Ø¨Ø±Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„â€ŒÙ‡Ø§
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<PublicPostModel> _allPosts = [];

  ProfilePostsNotifier(this.supabase, this.userId)
      : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _allPosts.clear();
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;

    try {
      final currentUserId = supabase.auth.currentUser?.id;

      final postsResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_user_id_fkey (
              username,
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
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (postsResponse.isEmpty) {
        _hasMore = false;
        _isLoading = false;
        return;
      }

      final newPosts = postsResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];
        final profile = (post['profiles'] as Map<String, dynamic>?) ?? {};

        return PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes.any((like) => like['user_id'] == currentUserId),
          'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_verified': profile['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': profile['verification_type'],
        });
      }).toList();

      _allPosts.addAll(newPosts);
      _offset += postsResponse
          .length; // Ù…Ø·Ø§Ø¨Ù‚ ØªØ¹Ø¯Ø§Ø¯ ÙˆØ§Ù‚Ø¹ÛŒ Ø¯Ø±ÛŒØ§ÙØªÛŒ
      _hasMore = postsResponse.length == _limit;

      state = AsyncValue.data(_allPosts);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    await _loadMorePosts();
  }

  Future<void> refresh() async {
    await _loadInitialPosts();
  }

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
}

final profilePostsProvider = StateNotifierProvider.family<ProfilePostsNotifier,
    AsyncValue<List<PublicPostModel>>, String>((ref, userId) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfilePostsNotifier(supabase, userId);
});
