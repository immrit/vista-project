import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:Vista/DB/isar_database_manager.dart';
import 'package:Vista/DB/entities/app_settings_entity.dart';
import 'package:Vista/widgets/VideoPlayerConfig.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Vista/DB/profile_cache_service.dart';
import 'package:Vista/DB/settings_cache_service.dart';
import 'package:Vista/services/animation_controller_service.dart';
import 'package:Vista/services/video_autoplay_service.dart';
import 'package:Vista/services/image_quality_service.dart';
import 'package:Vista/core/data/cache/cache_repository.dart';
import 'package:Vista/model/SearchResut.dart';
// import 'package:Vista/view/widgets/VideoPlayerConfig.dart';
import 'package:Vista/model/ProfileModel.dart';
// import 'package:Vista/model/notificationModel.dart';
import 'package:Vista/model/publicPostModel.dart';
import 'package:Vista/model/CommentModel.dart';
import 'package:Vista/model/UserModel.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import 'package:Vista/utils/themes.dart';
import 'package:Vista/services/user_friendly_error_handler.dart';
import 'package:Vista/services/voice_cache_service.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/features/profile/data/profile_repository.dart';
import 'package:Vista/features/profile/data/services/profile_note_service.dart';
import 'package:Vista/features/posts/data/go_posts_repository.dart';
import 'package:Vista/features/stories/data/repositories/story_repository.dart';
import 'package:Vista/services/comment_repository.dart';
import 'package:Vista/provider/notification_provider.dart' as go_notifications;
// Import security provider

export 'package:Vista/provider/security_provider.dart';
export 'package:Vista/features/auth/providers/auth_controller.dart';

export 'package:Vista/features/profile/providers/profile_controller.dart';
import 'package:Vista/features/profile/providers/profile_controller.dart';
import 'package:Vista/features/posts/providers/posts_provider.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

class ProfileService {
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.isEmpty) return null;

      final response = await ProfileRepository().fetchProfileById(userId);

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching current user profile: $e');
      return null;
    }
  }

  Future<UserModel?> getProfileById(String userId) async {
    try {
      final response = await ProfileRepository().fetchProfileById(userId);

      return UserModel.fromMap(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getCurrentUserProfile();
});

final profileByIdProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.getProfileById(userId);
});

class ProfileWidget extends ConsumerWidget {
  const ProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfileAsync = ref.watch(currentUserProfileProvider);

    return currentProfileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Text('Error loading profile'),
      data: (profile) {
        if (profile == null) {
          return const Text('No profile data');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              VerificationBadgeIcon(
                isVerified: profile.isVerified,
                verificationType: profile.verificationType,
                role: profile.role,
                size: 18,
              ),
          ],
        );
      },
    );
  }
}

class OtherProfileWidget extends ConsumerWidget {
  final String userId;

  const OtherProfileWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));

    return profileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Text('Error loading profile'),
      data: (profile) {
        if (profile == null) {
          return const Text('No profile data');
        }
        return Column(
          children: [
            Text(profile.username),
            if (profile.isVerified)
              VerificationBadgeIcon(
                isVerified: profile.isVerified,
                verificationType: profile.verificationType,
                role: profile.role,
                size: 18,
              ),
          ],
        );
      },
    );
  }
}

final userFollowersProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final postActionsService = ref.read(postActionsServiceProvider);
  return await postActionsService.fetchFollowers(userId);
});

final userFollowingProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, userId) async {
  final postActionsService = ref.read(postActionsServiceProvider);

  return await postActionsService.fetchFollowing(userId);
});
final currentUserMapProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = await TokenStorage.getUserId();
  if (userId == null || userId.isEmpty) {
    return null;
  }

  return ProfileRepository().fetchProfileById(userId);
});

class UserProfileNotifier extends StateNotifier<ProfileModel?> {
  UserProfileNotifier(this._userId) : super(null) {
    loadProfile();
  }

  final String _userId;
  final ProfileRepository _profileRepository = ProfileRepository();

  Future<void> loadProfile() async {
    await fetchProfile(_userId);
  }

  Future<void> fetchProfile(String userId) async {
    if (userId.isEmpty) return;
    final data = await _profileRepository.fetchProfileById(userId);
    state = ProfileModel.fromMap(data);
  }

  Future<void> clearUserCache(String userId) async {
    if (userId == _userId) {
      state = null;
    }
  }

  Future<void> toggleFollow(String userId) async {
    if (userId.isEmpty) return;

    final current = state;
    if (current?.isFollowed == true) {
      await _profileRepository.unfollow(userId);
      state = current?.copyWith(
        isFollowed: false,
        followersCount: current.followersCount > 0
            ? current.followersCount - 1
            : current.followersCount,
      );
      return;
    }

    final status = await _profileRepository.follow(userId);
    final isFollowing = status == 'following';
    if (current != null) {
      state = current.copyWith(
        isFollowed: isFollowing,
        followersCount:
            isFollowing ? current.followersCount + 1 : current.followersCount,
      );
    } else {
      await fetchProfile(userId);
    }
  }

  void updatePost(PublicPostModel post) {
    final current = state;
    if (current == null) return;

    final posts = [...current.posts];
    final index = posts.indexWhere((item) => item.id == post.id);
    if (index == -1) {
      posts.insert(0, post);
    } else {
      posts[index] = post;
    }
    state = current.copyWith(posts: posts);
  }
}

final userProfileProvider =
    StateNotifierProvider.family<UserProfileNotifier, ProfileModel?, String>(
  (ref, userId) => UserProfileNotifier(userId),
);

final followRequestPendingProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  if (userId.isEmpty) return false;
  final data = await ProfileRepository().fetchProfileById(userId);
  return data['follow_status']?.toString() == 'requested';
});
// Provider to get the current user's UserModel based on profileProvider
final userProvider = Provider<UserModel?>((ref) {
  final profileDataAsync = ref.watch(currentUserMapProvider);

  return profileDataAsync.when(
    data: (dataMap) {
      if (dataMap != null) {
        try {
          return UserModel.fromMap(dataMap);
        } catch (e, stackTrace) {
          debugPrint('Error parsing user model: $e');
          debugPrint('StackTrace: $stackTrace');
          debugPrint('Data map: $dataMap');
        }
      }
      return null;
    },
    loading: () {
      return null;
    },
    error: (error, stackTrace) {
      debugPrint('Error loading current user: $error');
      debugPrint('StackTrace: $stackTrace');
      return null;
    },
  );
});
