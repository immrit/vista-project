import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:shimmer/shimmer.dart';

import '../../../model/ProfileModel.dart';
import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../utils/directional_navigation.dart';
import '../../../utils/profile_zoom_policy.dart';
import 'package:Vista/widgets/profile_avatar_widget.dart'; // NEW IMPORT
import '../providers/saved_posts_provider.dart';
import '../widgets/post_action_buttons.dart';
import '../widgets/post_moderation_banner.dart';
import '../widgets/post_feed_video.dart';
import '../widgets/post_image_carousel.dart';
import '../services/reels_viewer_launcher.dart';

// Imports for existing functionality
import '../../../features/chat/screens/modern_chat_screen.dart';
import '../../../services/smart_share_service.dart';
import '../../../services/current_user_service.dart';
import 'package:Vista/features/profile/screens/editeProfile.dart';
import 'package:Vista/features/settings/screens/Settings.dart';
import 'package:Vista/features/profile/widgets/vista_id_card.dart';
import 'package:Vista/model/UserModel.dart' as user_model;
import 'followers_and_followings/FollowersScreen.dart';
import 'followers_and_followings/FollowingScreen.dart';

// Stories
import '../../stories/presentation/screens/story_creation_screen.dart'; // Stories Import

// Profile Notes (Status)
import '../../profile/widgets/content_type_picker_sheet.dart';
import '../../profile/widgets/note_input_sheet.dart';
import '../../profile/widgets/thought_bubble_widget.dart';
import '../../profile/data/models/profile_note_model.dart';
import '../../profile/providers/profile_note_provider.dart';
import '../../chat/widgets/notes_tray.dart';
import '../../chat/providers/chat_providers.dart';

import 'package:Vista/utils/comments_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:Vista/utils/premium_features_helper.dart';
import '../../../utils/user_friendly_error_utils.dart';
import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:Vista/features/posts/widgets/profile_lazy_tab_gate.dart';
import 'package:Vista/features/posts/navigation/content_routes.dart';
import 'package:Vista/features/posts/screens/AddPost.dart';
import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/features/posts/data/go_posts_repository.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/features/posts/widgets/hashtag_rich_text.dart';
import 'package:Vista/features/posts/widgets/post_music_bubble.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import 'package:Vista/features/profile/screens/account_details_screen.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';

/// صفحه پروفایل ویستا - طراحی مدرن Social/Threads
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isStartingConversation = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    TokenStorage.getUserId().then((value) {
      if (!mounted) return;
      setState(() => _currentUserId = value);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
      try {
        unawaited(
            ProfileCacheService().refreshCacheInBackground(widget.userId));
      } catch (e) {
        // ignore background refresh errors
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider(widget.userId));
    final currentUserId =
        ref.watch(authProvider.select((user) => user?.id)) ?? _currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isCurrentUserProfile =
        profileState != null && profileState.id == currentUserId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isCurrentUserProfile
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const AddPublicPostScreen()),
                    );
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  highlightElevation: 0,
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            )
          : null,
      appBar: _buildAppBar(profileState, isDark, isCurrentUserProfile),
      body: profileState == null
          ? _ProfilePageShimmer(isDark: isDark)
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              color: isDark ? Colors.white : Colors.black,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _ProfileHeader(
                            profile: profileState,
                            isCurrentUser: isCurrentUserProfile,
                            isPrivate: _isPrivateAccount(profileState),
                            onFollowersTap: () => _navigateToFollowers(context),
                            onFollowingTap: () => _navigateToFollowing(context),
                          ),
                          const SizedBox(height: 12),
                          _ProfileActionBar(
                            profile: profileState,
                            isCurrentUser: isCurrentUserProfile,
                            onFollowTap: () => _toggleFollow(profileState.id),
                            onMessageTap: () => _startConversation(
                              profileState.id,
                              profileState.username,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    // Tab Bar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileTabBarDelegate(
                        tabController: _tabController,
                        isDark: isDark,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    ProfileLazyTabGate(
                      tabController: _tabController,
                      tabIndex: 0,
                      child: _buildPostsGrid(
                        profileState,
                        isCurrentUserProfile,
                        isDark,
                      ),
                    ),
                    ProfileLazyTabGate(
                      tabController: _tabController,
                      tabIndex: 1,
                      child: _buildReelsGrid(
                        profileState,
                        isCurrentUserProfile,
                        isDark,
                      ),
                    ),
                    ProfileLazyTabGate(
                      tabController: _tabController,
                      tabIndex: 2,
                      child: _buildMusicTab(
                        profileState,
                        isCurrentUserProfile,
                        isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  AppBar _buildAppBar(ProfileModel? profile, bool isDark, bool isOwnProfile) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile?.username ?? widget.username,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ) ??
                const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
          ),
          if (profile != null && profile.isVerified) ...[
            const SizedBox(width: 4),
            _buildVerificationBadge(profile),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_horiz,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => _showOptionsMenu(context, isDark),
        ),
        if (isOwnProfile)
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Settings()),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationBadge(ProfileModel profile) {
    return VerificationBadgeIcon(
      isVerified: profile.isVerified,
      verificationType: profile.verificationType,
      role: profile.role,
      size: 18,
    );
  }

  bool _isPrivateAccount(ProfileModel profile) {
    final settingsAsync = ref.read(userSettingsByIdProvider(profile.id));
    return settingsAsync.maybeWhen(
      data: (settings) => (settings?['is_private'] as bool?) ?? false,
      orElse: () => false,
    );
  }

  void _navigateToFollowers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowersScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToFollowing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowingScreen(userId: widget.userId),
      ),
    );
  }

  // ========== Posts Grid ==========

  Widget _buildPostsGrid(
      ProfileModel profile, bool isCurrentUser, bool isDark) {
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    final postsAsync = ref.watch(profilePostsProvider(profile.id));

    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;

        if (blockedView) {
          return _PrivateAccountPlaceholder(isDark: isDark);
        }

        return postsAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return _EmptyPlaceholder(
                title: AppLocalizations.of(context)?.noPostsYet ??
                    'هنوز پستی نیست',
                subtitle: isCurrentUser
                    ? (AppLocalizations.of(context)?.shareFirstPost ??
                        'اولین پست خود را به اشتراک بگذارید')
                    : (AppLocalizations.of(context)?.userHasNoPosts ??
                        'این کاربر هنوز پستی منتشر نکرده'),
                icon: Icons.camera_alt_outlined,
                isDark: isDark,
              );
            }

            return _PostsGridView(
              posts: posts,
              isDark: isDark,
              profileId: profile.id,
            );
          },
          loading: () => Center(
            child: _PostsTabShimmer(isDark: isDark),
          ),
          error: (_, __) => Center(
              child: Text(AppLocalizations.of(context)?.errorLoadingPosts ??
                  'خطا در بارگذاری پست‌ها')),
        );
      },
      loading: () => Center(
        child: _PostsTabShimmer(isDark: isDark),
      ),
      error: (_, __) => Center(
          child: Text(
              AppLocalizations.of(context)?.errorLoading ?? 'خطا در بارگذاری')),
    );
  }

  // ========== Reels Grid ==========

  Widget _buildReelsGrid(
      ProfileModel profile, bool isCurrentUser, bool isDark) {
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    final postsAsync = ref.watch(profilePostsProvider(profile.id));

    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;

        if (blockedView) {
          return _PrivateAccountPlaceholder(isDark: isDark);
        }

        return postsAsync.when(
          data: (posts) {
            final reels = posts.where((p) => p.hasVideo).toList();
            if (reels.isEmpty) {
              return _EmptyPlaceholder(
                title: AppLocalizations.of(context)?.noReelsYet ??
                    'هنوز کلیپی نیست',
                subtitle: isCurrentUser
                    ? (AppLocalizations.of(context)?.shareFirstReel ??
                        'اولین کلیپ خود را به اشتراک بگذارید')
                    : (AppLocalizations.of(context)?.userHasNoReels ??
                        'این کاربر هنوز کلیپی منتشر نکرده'),
                icon: Icons.play_circle_outline,
                isDark: isDark,
              );
            }
            return _ReelsGridView(reels: reels, isDark: isDark);
          },
          loading: () => Center(
            child: _ReelsTabShimmer(isDark: isDark),
          ),
          error: (_, __) => Center(
              child: Text(AppLocalizations.of(context)?.errorLoadingReels ??
                  'خطا در بارگذاری کلیپ‌ها')),
        );
      },
      loading: () => Center(
        child: _ReelsTabShimmer(isDark: isDark),
      ),
      error: (_, __) => Center(
          child: Text(
              AppLocalizations.of(context)?.errorLoading ?? 'خطا در بارگذاری')),
    );
  }

  // ========== Music Grid ==========

  Widget _buildMusicTab(ProfileModel profile, bool isCurrentUser, bool isDark) {
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    final postsAsync = ref.watch(profilePostsProvider(profile.id));

    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;

        if (blockedView) {
          return _PrivateAccountPlaceholder(isDark: isDark);
        }

        return postsAsync.when(
          data: (posts) {
            final musicPosts = posts
                .where((p) =>
                    (p.musicUrl ?? '').trim().isNotEmpty ||
                    (p.title ?? '').trim().isNotEmpty)
                .toList();
            if (musicPosts.isEmpty) {
              return _EmptyPlaceholder(
                title: AppLocalizations.of(context)?.noMusicYet ??
                    'هنوز موزیکی نیست',
                subtitle: isCurrentUser
                    ? (AppLocalizations.of(context)?.addMusicToPosts ??
                        'برای پست‌هایتان موزیک اضافه کنید')
                    : (AppLocalizations.of(context)?.userHasNoMusic ??
                        'این کاربر هنوز موزیکی منتشر نکرده'),
                icon: Icons.music_note_outlined,
                isDark: isDark,
              );
            }
            return _MusicListView(posts: musicPosts, isDark: isDark);
          },
          loading: () => Center(
            child: _MusicTabShimmer(isDark: isDark),
          ),
          error: (_, __) => Center(
              child: Text(AppLocalizations.of(context)?.errorLoadingMusic ??
                  'خطا در بارگذاری موزیک‌ها')),
        );
      },
      loading: () => Center(
        child: _MusicTabShimmer(isDark: isDark),
      ),
      error: (_, __) => Center(
          child: Text(
              AppLocalizations.of(context)?.errorLoading ?? 'خطا در بارگذاری')),
    );
  }

  // ========== Actions ==========

  Future<void> _refreshProfile() async {
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .clearUserCache(widget.userId);
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
      await ref.read(profilePostsProvider(widget.userId).notifier).refresh();
      ref.invalidate(userProfileProvider(widget.userId));
      ref.invalidate(userSettingsByIdProvider(widget.userId));
      ref.invalidate(profilePostsProvider(widget.userId));
    } catch (e) {
      // handle error silently
    }
  }

  void _toggleFollow(String userId) async {
    try {
      final notifier = ref.read(userProfileProvider(userId).notifier);
      await notifier.toggleFollow(userId);
      ref.invalidate(followRequestPendingProvider(userId));
      ref.invalidate(userProfileProvider(userId));
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _startConversation(String userId, String username) async {
    if (_isStartingConversation) return;
    setState(() => _isStartingConversation = true);

    try {
      final myId = await CurrentUserService.instance.resolveUserId();
      if (myId != null && myId == userId) return;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernChatScreen(
              args: ChatScreenArgs(
                conversationId: '',
                otherUserId: userId,
                otherUserName: username,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isStartingConversation = false);
    }
  }

  void _showOptionsMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.share_outlined,
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Text(
                AppLocalizations.of(context)?.shareProfile ??
                    'اشتراک‌گذاری پروفایل',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                final username =
                    (ref.read(userProfileProvider(widget.userId))?.username ??
                            widget.username)
                        .trim();
                if (username.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context)
                                ?.usernameNotAvailable ??
                            'نام کاربری در دسترس نیست')),
                  );
                  return;
                }
                SmartShareService().shareProfile(username, context: context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.link,
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Text(
                AppLocalizations.of(context)?.copyProfileLink ??
                    'کپی لینک پروفایل',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                final username =
                    (ref.read(userProfileProvider(widget.userId))?.username ??
                            widget.username)
                        .trim();
                if (username.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('نام کاربری در دسترس نیست')),
                  );
                  return;
                }
                final profileUrl = 'https://cafevista.ir/profile/$username';
                Clipboard.setData(ClipboardData(text: profileUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppLocalizations.of(context)?.profileLinkCopied ??
                              'لینک پروفایل کپی شد')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: Text(AppLocalizations.of(context)?.report ?? 'گزارش',
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppLocalizations.of(context)?.userReportSubmitted ??
                              'گزارش کاربر ثبت شد')),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// INTERNAL WIDGETS
// ========================================================================

/// هدر پروفایل
class _ProfileHeader extends ConsumerWidget {
  final ProfileModel profile;
  final bool isCurrentUser;
  final bool isPrivate;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _ProfileHeader({
    required this.profile,
    required this.isCurrentUser,
    required this.isPrivate,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Watch profile note for this user
    final noteAsync = ref.watch(profileNoteProvider(profile.id));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar & Stats Row with Floating Bubble
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Floating Note Bubble (Positioned absolutely)
              noteAsync.when(
                data: (note) {
                  if (note != null && !note.isExpired) {
                    final isLong = note.content.length > 20;
                    return PositionedDirectional(
                      // حالت متن بلند: پایین، کنار دکمه پلاس
                      // حالت متن کوتاه: نزدیک آواتار و کمی بالاتر
                      // تا بالای عدد پست‌ها قرار گیرد و تداخل نکند.
                      top: isLong ? 65 : -16,
                      start: isLong ? 70 : 60,
                      child: ThoughtBubbleWidget(
                        note: note,
                        isCurrentUser: isCurrentUser,
                        tailAtTop: isLong,
                        tailOnRight: isRtl,
                        onTap: () {
                          if (isCurrentUser) {
                            _showNoteInputSheet(context, ref, note.content);
                          } else {
                            _openNoteReplySheet(
                              context: context,
                              ref: ref,
                              note: note,
                              conversationsState:
                                  ref.read(optimizedConversationsProvider),
                            );
                          }
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              // 2. Main Base Layout (Avatar + Stats) - FIXED POSITION
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with Story Ring
                  Stack(
                    children: [
                      ProfileAvatar(
                        userId: profile.id,
                        size: 84,
                        imageUrl: profile.avatarUrl,
                        showOnlineStatus: false,
                        onTap: profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? () {
                                ProfileZoomPolicy.openEnlargedAvatar(
                                  context: context,
                                  ref: ref,
                                  targetUserId: profile.id,
                                  avatarUrl: profile.avatarUrl,
                                  viewerUserId: ref.read(authProvider)?.id,
                                );
                              }
                            : null,
                      ),
                      if (isCurrentUser)
                        PositionedDirectional(
                          bottom: 0,
                          end: 0,
                          child: GestureDetector(
                            onTap: () => _showContentTypePicker(context, ref),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 28),

                  // Stats
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                          count: _formatCount(profile.postsCount),
                          label: AppLocalizations.of(context)?.post ?? 'پست',
                          textColor: textColor,
                          subtitleColor: subtitleColor!,
                        ),
                        GestureDetector(
                          onTap: onFollowersTap,
                          child: _StatItem(
                            count: _formatCount(profile.followersCount),
                            label: AppLocalizations.of(context)?.followers ??
                                'دنبال‌کننده',
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: onFollowingTap,
                          child: _StatItem(
                            count: _formatCount(profile.followingCount),
                            label:
                                AppLocalizations.of(context)?.followingCount ??
                                    'دنبال‌شونده',
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name with verification badge
          Row(
            children: [
              Flexible(
                child: Text(
                  profile.fullName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 4),
                _buildVerificationBadge(),
              ],
              if (isPrivate) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock_outline, size: 14, color: subtitleColor),
              ],
            ],
          ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final text = profile.bio!;
                final firstChar = text.trim().isNotEmpty ? text.trim()[0] : '';
                final isPersian =
                    RegExp(r'[\u0600-\u06FF]').hasMatch(firstChar);
                return Directionality(
                  textDirection:
                      isPersian ? TextDirection.rtl : TextDirection.ltr,
                  child: HashtagRichText(
                    text: text,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      height: 1.4,
                    ),
                    hashtagStyle: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    onHashtagTap: (tag) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SearchPage(initialHashtag: '#$tag'),
                        ),
                      );
                    },
                    onMentionTap: (username) {
                      ContentNavigation.pushProfileByUsername(
                        context,
                        username: username,
                      );
                    },
                  ),
                );
              },
            ),
          ],

          // Member order badge — tappable → AccountDetailsScreen
          if (profile.joinOrder != null && profile.joinOrder! > 0) ...[
            const SizedBox(height: 10),
            _MemberOrderBadge(
              joinOrder: profile.joinOrder!,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountDetailsScreen(profile: profile),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Widget _buildVerificationBadge() {
    return VerificationBadgeIcon(
      isVerified: profile.isVerified,
      verificationType: profile.verificationType,
      role: profile.role,
      size: 16,
    );
  }

  /// نمایش باتم‌شیت انتخاب نوع محتوا
  void _showContentTypePicker(BuildContext context, WidgetRef ref) {
    ContentTypePickerSheet.show(
      context,
      onStorySelected: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StoryCreationScreen(),
          ),
        );
      },
      onNoteSelected: () {
        _showNoteInputSheet(context, ref, null);
      },
    );
  }

  /// نمایش باتم‌شیت ورود متن وضعیت
  void _showNoteInputSheet(
      BuildContext context, WidgetRef ref, String? currentNote) async {
    final result = await NoteInputSheet.show(context, currentNote: currentNote);
    if (result == true) {
      // Refresh the note provider
      ref.invalidate(profileNoteProvider(profile.id));
    }
  }

  Future<void> _openNoteReplySheet({
    required BuildContext context,
    required WidgetRef ref,
    required ProfileNoteModel note,
    required ConversationsState conversationsState,
  }) async {
    String? conversationId;
    for (final conversation in conversationsState.conversations) {
      if (conversation.otherUserId == profile.id) {
        conversationId = conversation.id;
        break;
      }
    }

    if (conversationId == null || conversationId.isEmpty) {
      final createResult =
          await ref.read(chatRepositoryProvider).createConversation(profile.id);
      if (!context.mounted) return;
      if (!createResult.isSuccess || createResult.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult.error ?? 'خطا در ایجاد گفتگو')),
        );
        return;
      }
      conversationId = createResult.data!.id;
      await ref.read(optimizedConversationsProvider.notifier).refresh();
    }

    if (!context.mounted) return;
    final sent = await showNoteQuickReplyBottomSheet(
      context,
      conversationId: conversationId,
      userId: profile.id,
      username: profile.username,
      avatarUrl: profile.avatarUrl ?? '',
      noteContent: note.content,
    );
    if (sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاسخ شما ارسال شد')),
      );
    }
  }
}

// End of file

/// آیتم آمار
class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final Color textColor;
  final Color subtitleColor;

  const _StatItem({
    required this.count,
    required this.label,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }
}

/// بج ترتیب عضویت در ویستا
class _MemberOrderBadge extends StatelessWidget {
  final int joinOrder;
  final bool isDark;
  final VoidCallback? onTap;

  const _MemberOrderBadge({
    required this.joinOrder,
    required this.isDark,
    this.onTap,
  });

  /// تعریف تیرهای رنگ بر اساس ترتیب عضویت
  _BadgeTier get _tier {
    if (joinOrder <= 100) return _BadgeTier.founding;
    if (joinOrder <= 1000) return _BadgeTier.early;
    if (joinOrder <= 10000) return _BadgeTier.pioneer;
    return _BadgeTier.member;
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    final label = _buildLabel(tier);
    final icon = _buildIcon(tier);
    final colors = _buildColors(tier, isDark);
    const radius = BorderRadius.all(Radius.circular(20));

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: radius,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text,
              letterSpacing: 0.2,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              directionalForwardChevronIcon(context),
              size: 14,
              color: colors.text.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: badge,
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: colors.border.withValues(alpha: 0.3),
          highlightColor: colors.border.withValues(alpha: 0.1),
          child: badge,
        ),
      ),
    );
  }

  String _buildLabel(_BadgeTier tier) {
    final formatted = _formatNumber(joinOrder);
    switch (tier) {
      case _BadgeTier.founding:
        return 'عضو بنیان‌گذار ویستا  #$formatted';
      case _BadgeTier.early:
        return 'از اولین هزار نفر ویستا  #$formatted';
      case _BadgeTier.pioneer:
        return 'عضو پیشگام ویستا  #$formatted';
      case _BadgeTier.member:
        return 'عضو شماره  #$formatted  ویستا';
    }
  }

  String _buildIcon(_BadgeTier tier) {
    switch (tier) {
      case _BadgeTier.founding:
        return '👑';
      case _BadgeTier.early:
        return '🚀';
      case _BadgeTier.pioneer:
        return '⚡';
      case _BadgeTier.member:
        return '✦';
    }
  }

  _BadgeColors _buildColors(_BadgeTier tier, bool isDark) {
    switch (tier) {
      case _BadgeTier.founding:
        return _BadgeColors(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3D2800), const Color(0xFF5A3A00)]
                : [const Color(0xFFFFF3CD), const Color(0xFFFFE082)],
          ),
          border: isDark ? const Color(0xFFB8860B) : const Color(0xFFD4A017),
          text: isDark ? const Color(0xFFFFD700) : const Color(0xFF8B6914),
        );
      case _BadgeTier.early:
        return _BadgeColors(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF001A3D), const Color(0xFF002D6B)]
                : [const Color(0xFFE3EEFF), const Color(0xFFCCDFFF)],
          ),
          border: isDark ? const Color(0xFF1565C0) : const Color(0xFF90B8F8),
          text: isDark ? const Color(0xFF82BBFF) : const Color(0xFF1A5FBB),
        );
      case _BadgeTier.pioneer:
        return _BadgeColors(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A0030), const Color(0xFF2D0050)]
                : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)],
          ),
          border: isDark ? const Color(0xFF7B2FBE) : const Color(0xFFB794F4),
          text: isDark ? const Color(0xFFD08BFF) : const Color(0xFF6B21A8),
        );
      case _BadgeTier.member:
        return _BadgeColors(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1A1A), const Color(0xFF252525)]
                : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
          ),
          border: isDark ? const Color(0xFF404040) : const Color(0xFFCCCCCC),
          text: isDark ? const Color(0xFF999999) : const Color(0xFF666666),
        );
    }
  }
}

enum _BadgeTier { founding, early, pioneer, member }

class _BadgeColors {
  final LinearGradient gradient;
  final Color border;
  final Color text;
  const _BadgeColors({
    required this.gradient,
    required this.border,
    required this.text,
  });
}

/// نوار دکمه‌های عملیاتی
class _ProfileActionBar extends ConsumerWidget {
  final ProfileModel profile;
  final bool isCurrentUser;
  final VoidCallback? onFollowTap;
  final VoidCallback? onMessageTap;

  const _ProfileActionBar({
    required this.profile,
    required this.isCurrentUser,
    this.onFollowTap,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: isCurrentUser
          ? _buildCurrentUserButtons(context, isDark)
          : _buildOtherUserButtons(context, ref, isDark),
    );
  }

  Widget _buildCurrentUserButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'ویرایش پروفایل',
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfile()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            label: 'اشتراک‌گذاری',
            isDark: isDark,
            onTap: () {
              // Show Vista ID Card
              final userModel = user_model.UserModel(
                id: profile.id,
                username: profile.username,
                avatarUrl: profile.avatarUrl,
                isVerified: profile.isVerified,
                verificationType: profile.hasBlueBadge
                    ? user_model.VerificationType.blueTick
                    : profile.hasGoldBadge
                        ? user_model.VerificationType.goldTick
                        : profile.hasBlackBadge
                            ? user_model.VerificationType.blackTick
                            : user_model.VerificationType.none,
              );
              VistaIDCard.show(context, userModel);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUserButtons(
      BuildContext context, WidgetRef ref, bool isDark) {
    final isFollowed = profile.isFollowed;
    final isPending = ref.watch(
      followRequestPendingProvider(profile.id).select(
        (async) => async.maybeWhen(
          data: (pending) => pending,
          orElse: () => null,
        ),
      ),
    );

    final hideMessageButton = profile.messagePrivacy == 'nobody';

    if (isPending == null) {
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '...',
              isDark: isDark,
              enabled: false,
            ),
          ),
          if (!hideMessageButton) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                label: 'پیام',
                isDark: isDark,
                icon: Icons.mail_outline,
                onTap: onMessageTap,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _FollowButton(
            isFollowed: isFollowed,
            isPending: isPending,
            isDark: isDark,
            onTap: onFollowTap,
          ),
        ),
        if (!hideMessageButton) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              label: 'پیام',
              isDark: isDark,
              icon: Icons.mail_outline,
              onTap: onMessageTap,
            ),
          ),
        ],
      ],
    );
  }
}

/// دکمه عملیاتی
class _ActionButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;

  const _ActionButton({
    required this.label,
    required this.isDark,
    this.onTap,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor!, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? textColor : textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دکمه دنبال کردن
class _FollowButton extends StatelessWidget {
  final bool isFollowed;
  final bool isPending;
  final bool isDark;
  final VoidCallback? onTap;

  const _FollowButton({
    required this.isFollowed,
    required this.isPending,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return _buildPendingButton();
    }

    if (isFollowed) {
      return _buildFollowingButton();
    }

    return _buildFollowButton();
  }

  Widget _buildFollowButton() {
    return Material(
      color: isDark ? Colors.white : Colors.black,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(
            'دنبال کردن',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowingButton() {
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor!, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            'دنبال می‌کنید',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingButton() {
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final textColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor!, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        'در انتظار تایید',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// دلگیت تب‌بار
class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isDark;

  _ProfileTabBarDelegate({
    required this.tabController,
    required this.isDark,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.grey[600] : Colors.grey[400];
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: borderColor!, width: 0.5),
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: activeColor,
        unselectedLabelColor: inactiveColor,
        indicatorColor: activeColor,
        indicatorWeight: 1,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on, size: 24)),
          Tab(icon: Icon(Icons.play_arrow_outlined, size: 26)),
          Tab(icon: Icon(Icons.music_note_outlined, size: 24)),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

/// پلیسهولدر حساب خصوصی
class _PrivateAccountPlaceholder extends StatelessWidget {
  final bool isDark;

  const _PrivateAccountPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'حساب کاربری خصوصی است',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'برای مشاهده پست‌ها این حساب را دنبال کنید',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// پلیسهولدر خالی
class _EmptyPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;

  const _EmptyPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 10,
    this.shape = BoxShape.rectangle,
  });

  final double width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProfilePageShimmer extends StatelessWidget {
  const _ProfilePageShimmer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _ShimmerBox(
                      width: 84,
                      height: 84,
                      shape: BoxShape.circle,
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ShimmerBox(width: 52, height: 40),
                          _ShimmerBox(width: 52, height: 40),
                          _ShimmerBox(width: 52, height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _ShimmerBox(width: 140, height: 16),
                const SizedBox(height: 8),
                const _ShimmerBox(width: 210, height: 13),
                const SizedBox(height: 5),
                const _ShimmerBox(width: 170, height: 13),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                        child: _ShimmerBox(width: double.infinity, height: 36)),
                    SizedBox(width: 8),
                    Expanded(
                        child: _ShimmerBox(width: double.infinity, height: 36)),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ShimmerBox(width: 24, height: 24, radius: 6),
                _ShimmerBox(width: 24, height: 24, radius: 6),
                _ShimmerBox(width: 24, height: 24, radius: 6),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 8),
          const _PostsTabShimmer(
            isDark: false,
            useInheritedTheme: true,
            scrollable: false,
          ),
        ],
      ),
    );
  }
}

class _PostsTabShimmer extends StatelessWidget {
  const _PostsTabShimmer({
    required this.isDark,
    this.useInheritedTheme = false,
    this.scrollable = true,
  });

  final bool isDark;
  final bool useInheritedTheme;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final dark = useInheritedTheme
        ? Theme.of(context).brightness == Brightness.dark
        : isDark;
    final baseColor = dark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlightColor =
        dark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    final rows = List.generate(4, (_) => const SizedBox.shrink());
    final child = scrollable
        ? ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: dark ? Colors.white10 : Colors.black12,
            ),
            itemBuilder: (_, __) => const _PostTabShimmerRow(),
          )
        : Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                const _PostTabShimmerRow(),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    color: dark ? Colors.white10 : Colors.black12,
                  ),
              ],
            ],
          );

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class _PostTabShimmerRow extends StatelessWidget {
  const _PostTabShimmerRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(width: 44, height: 44, shape: BoxShape.circle),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 120, height: 14),
                SizedBox(height: 8),
                _ShimmerBox(width: double.infinity, height: 12),
                SizedBox(height: 6),
                _ShimmerBox(width: 170, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsTabShimmer extends StatelessWidget {
  const _ReelsTabShimmer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(1),
        itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          childAspectRatio: 9 / 16,
        ),
        itemBuilder: (_, __) => const _ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          radius: 0,
        ),
      ),
    );
  }
}

class _MusicTabShimmer extends StatelessWidget {
  const _MusicTabShimmer({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
        itemBuilder: (_, __) => const ListTile(
          leading: _ShimmerBox(width: 46, height: 46, radius: 12),
          title: _ShimmerBox(width: 150, height: 12),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 8),
            child: _ShimmerBox(width: 90, height: 10),
          ),
          trailing: _ShimmerBox(width: 22, height: 22, radius: 8),
        ),
      ),
    );
  }
}

class _MediaShimmer extends StatelessWidget {
  const _MediaShimmer({
    required this.isDark,
    this.borderRadius,
    this.height,
  });

  final bool isDark;
  final BorderRadius? borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// گرید پست‌ها
class _PostsGridView extends ConsumerStatefulWidget {
  final List<PublicPostModel> posts;
  final bool isDark;
  final String profileId;

  const _PostsGridView({
    required this.posts,
    required this.isDark,
    required this.profileId,
  });

  @override
  ConsumerState<_PostsGridView> createState() => _PostsGridViewState();
}

class _PostsGridViewState extends ConsumerState<_PostsGridView> {
  final ScrollController _scrollController = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    final threshold = _scrollController.position.maxScrollExtent * 0.75;
    if (_scrollController.position.pixels >= threshold) {
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    final notifier = ref.read(profilePostsProvider(widget.profileId).notifier);
    if (!notifier.hasMore || notifier.isLoading) return;
    _loadingMore = true;
    try {
      await notifier.loadMore();
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching provider keeps footer state up to date.
    ref.watch(profilePostsProvider(widget.profileId));
    final notifier = ref.read(profilePostsProvider(widget.profileId).notifier);
    final hasMore = notifier.hasMore;
    final isLoading = notifier.isLoading;

    // Deduplicate posts to prevent Hero tag collisions (duplicate IDs)
    final uniquePostsMap = <String, PublicPostModel>{};
    for (final p in widget.posts) {
      uniquePostsMap[p.id] = p;
    }
    final displayPosts = uniquePostsMap.values.toList();

    final reelsPlaylist = ReelsViewerLauncher.videoPlaylist(displayPosts);

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
      itemCount: displayPosts.length + 1,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color:
            widget.isDark ? const Color(0xFF303D4F) : const Color(0xFFE4E6E9),
      ),
      itemBuilder: (context, index) {
        if (index == displayPosts.length) {
          if (isLoading && hasMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!hasMore && displayPosts.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'پست دیگری وجود ندارد',
                  style: TextStyle(
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        final post = displayPosts[index];
        return KeyedSubtree(
          key: ValueKey<String>(post.id),
          child: _PostListItem(
            post: post,
            isDark: widget.isDark,
            reelsPlaylist: reelsPlaylist,
          ),
        );
      },
    );
  }
}

/// آیتم لیست پست (طراحی شبیه شبکه/تردز)
class _PostListItem extends ConsumerWidget {
  final PublicPostModel post;
  final bool isDark;
  final List<PublicPostModel> reelsPlaylist;

  const _PostListItem({
    required this.post,
    required this.isDark,
    required this.reelsPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasVideo = post.hasVideo;
    final hasMusic = post.musicUrl != null && post.musicUrl!.trim().isNotEmpty;
    final isSaved = ref.watch(
      savedPostIdsProvider.select(
        (async) => async.maybeWhen(
          data: (ids) => ids.contains(post.id),
          orElse: () => false,
        ),
      ),
    );

    return InkWell(
      onTap: () => ContentNavigation.pushPostDetail(
        context,
        postId: post.id,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  backgroundImage: post.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(post.avatarUrl)
                      : null,
                  child: post.avatarUrl.isEmpty
                      ? Icon(Icons.person,
                          size: 22,
                          color: isDark ? Colors.grey[400] : Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.username,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_shouldShowVerificationBadge()) ...[
                            const SizedBox(width: 4),
                            VerificationBadgeIcon(
                              isVerified: true,
                              verificationType: post.verificationType,
                              role: post.profiles?['role']?.toString(),
                              size: 15,
                            ),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            '• ${_getTimeAgo(post.createdAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      PostModerationBanner(post: post),
                      if (post.content.isNotEmpty) ...[
                        HashtagRichText(
                          text: post.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          hashtagStyle: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 6,
                          readMoreLabel: 'بیشتر...',
                          onReadMoreTap: () {
                            ContentNavigation.pushPostDetail(
                              context,
                              postId: post.id,
                            );
                          },
                          onHashtagTap: (tag) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SearchPage(initialHashtag: '#$tag'),
                              ),
                            );
                          },
                          onMentionTap: (username) {
                            ContentNavigation.pushProfileByUsername(
                              context,
                              username: username,
                            );
                          },
                        ),
                      ],
                      if (hasMusic)
                        PostMusicBubble(
                          postId: post.id,
                          musicUrl: post.musicUrl!,
                          createdAt: post.createdAt,
                          title: _resolveMusicTitle(),
                          avatarUrl: post.avatarUrl,
                          margin: EdgeInsets.only(
                            top: post.content.isNotEmpty ? 10 : 0,
                            bottom: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasImage) ...[
              const SizedBox(height: 10),
              if (post.hasMultipleImages)
                SizedBox(
                  height: 280,
                  child: PostImageCarousel(
                    imageUrls: post.galleryImages,
                    borderRadius: BorderRadius.circular(14),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 280,
                      minWidth: double.infinity,
                    ),
                    child: Hero(
                      tag: 'post_image_${post.id}',
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => _MediaShimmer(
                          isDark: isDark,
                          height: 180,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 180,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            if (hasVideo && !hasImage) ...[
              const SizedBox(height: 10),
              PostFeedVideo(
                post: post,
                maxHeight: 280,
                borderRadius: BorderRadius.circular(14),
                reelsPlaylist: reelsPlaylist,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final isLiked = ref.watch(
                            likeStateProvider.select((map) => map[post.id])) ??
                        post.isLiked;
                    final likeCount = post.likeCount +
                        (isLiked != post.isLiked ? (isLiked ? 1 : -1) : 0);

                    return PostLikeButton(
                      isLiked: isLiked,
                      likeCount: likeCount,
                      showCount: !post.hideLikeCount,
                      iconSize: 19,
                      gap: 4,
                      onTap: () async {
                        final willLike = !isLiked;
                        ref
                            .read(likeStateProvider.notifier)
                            .updateLikeState(post.id, willLike);
                        try {
                          await ref.read(postActionsServiceProvider).toggleLike(
                                postId: post.id,
                                ownerId: post.userId,
                                ref: ref,
                              );
                        } catch (e) {
                          if (context.mounted) {
                            ref
                                .read(likeStateProvider.notifier)
                                .updateLikeState(post.id, isLiked);
                          }
                        }
                      },
                    );
                  },
                ),
                const SizedBox(width: 14),
                PostCommentButton(
                  commentCount: post.commentCount,
                  showCount: !post.hideCommentCount,
                  iconSize: 19,
                  gap: 4,
                  onTap: () => _showCommentsSheet(context, ref),
                ),
                const SizedBox(width: 14),
                PostSaveButton(
                  isSaved: isSaved,
                  iconSize: 19,
                  onTap: () async {
                    final ok = await ref
                        .read(savedPostIdsProvider.notifier)
                        .toggle(post.id, post: post);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('خطا در ذخیره پست')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: () =>
                      SmartShareService().showShareOptions(post, context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    child: Image.asset(
                      'lib/utils/images/component/send.png',
                      width: 19,
                      height: 19,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                const Spacer(),
                _buildPostMenu(context, ref),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowVerificationBadge() {
    return post.isVerified || post.verificationType != VerificationType.none;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _resolveMusicTitle() {
    final direct = post.title?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final url = post.musicUrl?.trim() ?? '';
    if (url.isEmpty) return 'Music';

    final uri = Uri.tryParse(url);
    final lastSegment = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : url.split('/').last;

    final withoutExtension = lastSegment.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized = withoutExtension
        .replaceFirst(RegExp(r'^[^_]+_[0-9]+_'), '')
        .replaceAll('_', ' ')
        .trim();

    return normalized.isEmpty ? 'Music' : normalized;
  }

  void _showCommentsSheet(BuildContext context, WidgetRef ref) {
    showCommentsBottomSheet2(context,
        postId: post.id,
        postTitle: post.content.isNotEmpty
            ? post.content.substring(
                0, post.content.length > 30 ? 30 : post.content.length)
            : 'پست');
  }

  Widget _buildPostMenu(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        final isBlueTick = profile != null &&
            profile['is_verified'] == true &&
            profile['verification_type'] == 'blueTick';

        final currentUserId = ref.watch(activeUserProvider)?.id ??
            CurrentUserService.cachedUserId;
        final isCurrentUserPost = post.userId == currentUserId;

        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          icon: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.more_horiz,
              size: 20,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('گزارش پست'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('کپی متن'),
                  ],
                ),
              ),
            ];

            // صاحب پست یا مدیران (تیک آبی) مجاز به حذف هستند
            if (isCurrentUserPost || isBlueTick) {
              items.add(const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('حذف پست'),
                  ],
                ),
              ));
            }

            // منطق نمایش گزینه ویرایش
            final currentUserProfile = ref.read(currentUserProfileProvider);
            final canManagePrivacy = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                  currentUserProfile.value!,
                ) &&
                isCurrentUserPost;
            final hasPremiumEdit = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;

            if (isCurrentUserPost) {
              if (canManagePrivacy) {
                items.add(PopupMenuItem<String>(
                  value: 'toggle_like_count',
                  child: Row(
                    children: [
                      Icon(
                        post.hideLikeCount
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.hideLikeCount
                            ? 'نمایش تعداد لایک'
                            : 'مخفی کردن تعداد لایک',
                      ),
                    ],
                  ),
                ));
                items.add(PopupMenuItem<String>(
                  value: 'toggle_comment_count',
                  child: Row(
                    children: [
                      Icon(
                        post.hideCommentCount
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.hideCommentCount
                            ? 'نمایش تعداد کامنت'
                            : 'مخفی کردن تعداد کامنت',
                      ),
                    ],
                  ),
                ));
              } else {
                items.add(const PopupMenuItem<String>(
                  value: 'privacy_locked',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('کنترل آمار لایک/کامنت'),
                      Spacer(),
                      Icon(Icons.workspace_premium,
                          size: 18, color: Colors.amber),
                    ],
                  ),
                ));
              }
            }

            if (isBlueTick || hasPremiumEdit) {
              items.add(PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      isBlueTick ? Icons.admin_panel_settings : Icons.edit,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(isBlueTick ? 'ویرایش ناظر' : 'ویرایش پست'),
                  ],
                ),
              ));
            } else if (isCurrentUserPost) {
              items.add(const PopupMenuItem<String>(
                value: 'edit_locked',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('ویرایش پست'),
                    Spacer(),
                    Icon(Icons.workspace_premium,
                        size: 18, color: Colors.amber),
                  ],
                ),
              ));
            }

            return items;
          },
          onSelected: (value) async {
            if (value == 'report') {
              _showReportDialog(context, ref);
            } else if (value == 'copy') {
              await Clipboard.setData(ClipboardData(text: post.content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('متن پست کپی شد'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, ref);
            } else if (value == 'edit') {
              if (isBlueTick && !isCurrentUserPost) {
                showStandardEditDialog(
                  context: context,
                  ref: ref,
                  post: post,
                  onSuccess: () =>
                      ref.invalidate(profilePostsProvider(post.userId)),
                );
              } else {
                showStandardEditDialog(
                  context: context,
                  ref: ref,
                  post: post,
                  onSuccess: () =>
                      ref.invalidate(profilePostsProvider(post.userId)),
                );
              }
            } else if (value == 'edit_locked') {
              PremiumFeaturesHelper.showPremiumPromptDialog(context,
                  feature: 'ویرایش پست');
            } else if (value == 'privacy_locked') {
              PremiumFeaturesHelper.showPremiumPromptDialog(
                context,
                feature: 'مخفی‌سازی آمار لایک و کامنت',
              );
            } else if (value == 'toggle_like_count' ||
                value == 'toggle_comment_count') {
              final currentProfile = ref.read(currentUserProfileProvider).value;
              if (currentProfile == null ||
                  !PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                    currentProfile,
                  )) {
                PremiumFeaturesHelper.showPremiumPromptDialog(
                  context,
                  feature: 'مخفی‌سازی آمار لایک و کامنت',
                );
                return;
              }

              try {
                final hideLike =
                    value == 'toggle_like_count' ? !post.hideLikeCount : null;
                final hideComment = value == 'toggle_comment_count'
                    ? !post.hideCommentCount
                    : null;

                await ref
                    .read(goPostsRepositoryProvider)
                    .updateEngagementVisibility(
                      postId: post.id,
                      hideLikeCount: hideLike,
                      hideCommentCount: hideComment,
                    );

                ref.invalidate(profilePostsProvider(post.userId));

                if (context.mounted) {
                  final updatedLikeHidden = hideLike ?? post.hideLikeCount;
                  final updatedCommentHidden =
                      hideComment ?? post.hideCommentCount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'آمار لایک: ${updatedLikeHidden ? 'مخفی' : 'نمایش'} | '
                        'کامنت: ${updatedCommentHidden ? 'مخفی' : 'نمایش'}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(context, e);
                }
              }
            }
          },
        );
      },
      loading: () => Icon(Icons.more_horiz,
          size: 20, color: isDark ? Colors.grey[500] : Colors.grey[400]),
      error: (_, __) => Icon(Icons.more_horiz,
          size: 20, color: isDark ? Colors.grey[500] : Colors.grey[400]),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش پست'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پست را گزارش دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('گزارش شما ثبت شد')),
              );
            },
            child: const Text('گزارش', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پست'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پست را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(postActionsServiceProvider)
                    .deletePost(ref, post.id);
                ref.invalidate(profilePostsProvider(post.userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پست حذف شد')),
                );
              } catch (e) {
                UserFriendlyErrorUtils.showErrorSnackBar(context, e);
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MusicListView extends StatelessWidget {
  final List<PublicPostModel> posts;
  final bool isDark;

  const _MusicListView({
    required this.posts,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: posts.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF303D4F) : const Color(0xFFE4E6E9),
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        final title = _resolveMusicTitle(post);
        return ListTile(
          onTap: () => ContentNavigation.pushPostDetail(
            context,
            postId: post.id,
          ),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note_rounded),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            post.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          trailing: Icon(
            Icons.play_circle_outline_rounded,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        );
      },
    );
  }

  String _resolveMusicTitle(PublicPostModel post) {
    final direct = post.title?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final url = post.musicUrl?.trim() ?? '';
    if (url.isEmpty) return 'Music';

    final uri = Uri.tryParse(url);
    final lastSegment = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : url.split('/').last;

    final withoutExtension = lastSegment.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized = withoutExtension
        .replaceFirst(RegExp(r'^[^_]+_[0-9]+_'), '')
        .replaceAll('_', ' ')
        .trim();

    return normalized.isEmpty ? 'Music' : normalized;
  }
}

/// گرید کلیپ‌ها
class _ReelsGridView extends StatelessWidget {
  final List<PublicPostModel> reels;
  final bool isDark;

  const _ReelsGridView({required this.reels, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 9 / 16,
      ),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return _ReelGridItem(
          reel: reel,
          reels: reels,
          isDark: isDark,
        );
      },
    );
  }
}

/// آیتم گرید کلیپ
class _ReelGridItem extends ConsumerWidget {
  final PublicPostModel reel;
  final List<PublicPostModel> reels;
  final bool isDark;

  const _ReelGridItem({
    required this.reel,
    required this.reels,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ReelsViewerLauncher.open(
          context: context,
          ref: ref,
          post: reel,
          playlist: reels,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildThumbnail(),

          // Play icon overlay
          PositionedDirectional(
            bottom: 8,
            start: 8,
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatViewCount(reel.likeCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final fallback = _MediaShimmer(isDark: isDark);

    if (reel.imageUrl != null && reel.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: reel.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    }

    if (reel.videoUrl != null && reel.videoUrl!.isNotEmpty) {
      return FutureBuilder<Uint8List?>(
        future: VideoThumbnail.thumbnailData(
          video: reel.videoUrl!,
          quality: 70,
          maxWidth: 420,
        ),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return fallback;
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      );
    }

    return fallback;
  }

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
