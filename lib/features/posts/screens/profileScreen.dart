import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import '../../../model/ProfileModel.dart';
import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../utils/const.dart';
import 'package:Vista/widgets/profile_avatar_widget.dart'; // NEW IMPORT

// Imports for existing functionality
import '../../../features/chat/screens/modern_chat_screen.dart';
import '../../../services/smart_share_service.dart';
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
import '../../profile/widgets/note_viewer_sheet.dart';
import '../../profile/providers/profile_note_provider.dart';

import 'package:Vista/utils/comments_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:Vista/utils/premium_features_helper.dart';
import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/features/posts/widgets/hashtag_rich_text.dart';

/// صفحه پروفایل ویستا - طراحی مدرن Instagram/Threads
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
    final currentUser = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isCurrentUserProfile = profileState != null &&
        currentUser != null &&
        profileState.id == currentUser.id;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(profileState, isDark, isCurrentUserProfile),
      body: profileState == null
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              color: isDark ? Colors.white : Colors.black,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    // Header Section
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
                    _buildPostsGrid(profileState, isCurrentUserProfile, isDark),
                    _buildReelsGrid(profileState, isCurrentUserProfile, isDark),
                    _buildTaggedGrid(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  AppBar _buildAppBar(ProfileModel? profile, bool isDark, bool isOwnProfile) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Theme.of(context).iconTheme.color,
      elevation: 0,
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
          if (profile?.isVerified == true) ...[
            const SizedBox(width: 4),
            _buildVerificationBadge(profile!),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () => _showOptionsMenu(context, isDark),
        ),
        if (isOwnProfile)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Settings()),
            ),
          ),
      ],
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تنظیمات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.person_outline,
                  color: isDark ? Colors.grey[400] : Colors.grey[700]),
              title: Text('ویرایش پروفایل',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfile()));
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_outline,
                  color: isDark ? Colors.grey[400] : Colors.grey[700]),
              title: Text('ذخیره شده‌ها',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('به‌زودی...')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.history,
                  color: isDark ? Colors.grey[400] : Colors.grey[700]),
              title: Text('فعالیت‌ها',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('به‌زودی...')),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red[400]),
              title: Text('خروج', style: TextStyle(color: Colors.red[400])),
              onTap: () async {
                Navigator.pop(context);
                await supabase.auth.signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(ProfileModel profile) {
    if (profile.hasBlueBadge) {
      return const Icon(Icons.verified, color: Colors.blue, size: 18);
    } else if (profile.hasGoldBadge) {
      return const Icon(Icons.verified, color: Colors.amber, size: 18);
    } else if (profile.hasBlackBadge) {
      return Container(
        padding: const EdgeInsets.all(0.5),
        decoration: const BoxDecoration(
          color: Colors.white60,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.verified, color: Colors.black, size: 16),
      );
    }
    return const Icon(Icons.verified, color: Colors.blue, size: 18);
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
                title: 'هنوز پستی نیست',
                subtitle: isCurrentUser
                    ? 'اولین پست خود را به اشتراک بگذارید'
                    : 'این کاربر هنوز پستی منتشر نکرده',
                icon: Icons.camera_alt_outlined,
                isDark: isDark,
              );
            }

            return _PostsGridView(posts: posts, isDark: isDark);
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          error: (_, __) => const Center(child: Text('خطا در بارگذاری پست‌ها')),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      error: (_, __) => const Center(child: Text('خطا در بارگذاری')),
    );
  }

  // ========== Reels Grid ==========

  Widget _buildReelsGrid(
      ProfileModel profile, bool isCurrentUser, bool isDark) {
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;

    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;

        if (blockedView) {
          return _PrivateAccountPlaceholder(isDark: isDark);
        }

        final reels = profile.posts.where((p) => p.hasVideo).toList();

        if (reels.isEmpty) {
          return _EmptyPlaceholder(
            title: 'هنوز کلیپی نیست',
            subtitle: isCurrentUser
                ? 'اولین کلیپ خود را به اشتراک بگذارید'
                : 'این کاربر هنوز کلیپی منتشر نکرده',
            icon: Icons.play_circle_outline,
            isDark: isDark,
          );
        }

        return _ReelsGridView(reels: reels, isDark: isDark);
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      error: (_, __) => const Center(child: Text('خطا در بارگذاری')),
    );
  }

  // ========== Tagged Grid ==========

  Widget _buildTaggedGrid(bool isDark) {
    return _EmptyPlaceholder(
      title: 'بدون تگ',
      subtitle: 'هنوز در پستی تگ نشده‌اید',
      icon: Icons.person_pin_outlined,
      isDark: isDark,
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
      ref.invalidate(userProfileProvider(widget.userId));
      ref.invalidate(userSettingsByIdProvider(widget.userId));
    } catch (e) {
      // handle error silently
    }
  }

  void _toggleFollow(String userId) async {
    try {
      final notifier = ref.read(userProfileProvider(userId).notifier);
      await notifier.toggleFollow(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startConversation(String userId, String username) async {
    if (_isStartingConversation) return;
    setState(() => _isStartingConversation = true);

    try {
      final myId = supabase.auth.currentUser?.id;
      if (myId != null && myId != userId) {
        try {
          final res = await supabase.rpc(
            'can_message_user',
            params: {'target_user_id': userId},
          );
          final canMessage = res == true;
          if (!canMessage && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('این کاربر دریافت پیام را محدود کرده است'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } catch (_) {
          // If the RPC isn't deployed yet (or fails), fall back to existing flow.
        }
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
                'اشتراک‌گذاری پروفایل',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                // Share profile
              },
            ),
            ListTile(
              leading: Icon(
                Icons.link,
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Text(
                'کپی لینک پروفایل',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                // Copy link
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title: const Text('گزارش', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Report user
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
                    return Positioned(
                      // حالت متن بلند: پایین، کنار دکمه پلاس
                      // حالت متن کوتاه: برمی‌گردیم به سمت راست (left: 55) اما خیلی بالاتر (top: -40)
                      // تا بالای عدد پست‌ها قرار گیرد و تداخل نکند.
                      top: isLong ? 65 : -16,
                      left: isLong ? 70 : 60,
                      child: ThoughtBubbleWidget(
                        note: note,
                        isCurrentUser: isCurrentUser,
                        tailAtTop: isLong,
                        onTap: () {
                          if (isCurrentUser) {
                            _showNoteInputSheet(context, ref, note.content);
                          } else {
                            NoteViewerSheet.show(
                              context,
                              note: note,
                              userProfile: profile,
                              isCurrentUser: isCurrentUser,
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
                      ),
                      if (isCurrentUser)
                        Positioned(
                          bottom: 0,
                          right: 0,
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
                          label: 'پست',
                          textColor: textColor,
                          subtitleColor: subtitleColor!,
                        ),
                        GestureDetector(
                          onTap: onFollowersTap,
                          child: _StatItem(
                            count: _formatCount(profile.followersCount),
                            label: 'دنبال‌کننده',
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: onFollowingTap,
                          child: _StatItem(
                            count: _formatCount(profile.followingCount),
                            label: 'دنبال‌شونده',
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
            Text(
              profile.bio!,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
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
    if (profile.hasBlueBadge) {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    } else if (profile.hasGoldBadge) {
      return const Icon(Icons.verified, color: Colors.amber, size: 16);
    } else if (profile.hasBlackBadge) {
      return Container(
        padding: const EdgeInsets.all(0.5),
        decoration: const BoxDecoration(
          color: Colors.white60,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.verified, color: Colors.black, size: 14),
      );
    }
    return const Icon(Icons.verified, color: Colors.blue, size: 16);
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
    final pendingAsync = ref.watch(followRequestPendingProvider(profile.id));

    return pendingAsync.when(
      data: (isPending) {
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
        );
      },
      loading: () => Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: '...',
              isDark: isDark,
              enabled: false,
            ),
          ),
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
      ),
      error: (_, __) => Row(
        children: [
          Expanded(
            child: _FollowButton(
              isFollowed: false,
              isPending: false,
              isDark: isDark,
              onTap: onFollowTap,
            ),
          ),
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
      ),
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
                  color: enabled ? textColor : textColor.withOpacity(0.5),
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
          Tab(icon: Icon(Icons.person_pin_outlined, size: 24)),
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

/// گرید پست‌ها
class _PostsGridView extends StatelessWidget {
  final List<PublicPostModel> posts;
  final bool isDark;

  const _PostsGridView({required this.posts, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: isDark ? const Color(0xFF303D4F) : const Color(0xFFE4E6E9),
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return _PostListItem(post: post, isDark: isDark);
      },
    );
  }
}

/// آیتم لیست پست (طراحی شبیه توییتر/تردز)
class _PostListItem extends ConsumerWidget {
  final PublicPostModel post;
  final bool isDark;

  const _PostListItem({required this.post, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailsPage(postId: post.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // آواتار کاربر
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
            // محتوای پست
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // هدر: نام کاربر و زمان
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.username ?? 'کاربر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${_getTimeAgo(post.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // متن پست
                  if (post.content.isNotEmpty) ...[
                    Directionality(
                      textDirection: _getTextDirection(post.content),
                      child: HashtagRichText(
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
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // تصویر پست
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 280,
                          minWidth: double.infinity,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 180,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 180,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // دکمه‌های اکشن
                  Row(
                    children: [
                      // دکمه لایک
                      Consumer(
                        builder: (context, ref, child) {
                          final isLiked =
                              ref.watch(likeStateProvider)[post.id] ??
                                  post.isLiked;
                          final likeCount = post.likeCount +
                              (isLiked != post.isLiked
                                  ? (isLiked ? 1 : -1)
                                  : 0);

                          return GestureDetector(
                            onTap: () async {
                              ref
                                  .read(likeStateProvider.notifier)
                                  .updateLikeState(post.id, !isLiked);
                              try {
                                await ref
                                    .read(supabaseServiceProvider)
                                    .toggleLike(
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
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 20,
                                  color: isLiked
                                      ? Colors.red
                                      : (isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                                if (likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatCount(likeCount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      // دکمه کامنت
                      GestureDetector(
                        onTap: () => _showCommentsSheet(context, ref),
                        child: Row(
                          children: [
                            Image.asset(
                              'lib/utils/images/component/comment.png',
                              width: 20,
                              height: 20,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            if (post.commentCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                _formatCount(post.commentCount),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // دکمه اشتراک‌گذاری
                      GestureDetector(
                        onTap: () =>
                            SmartShareService().showShareOptions(post, context),
                        child: Image.asset(
                          'lib/utils/images/component/send.png',
                          width: 20,
                          height: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // دکمه ذخیره
                      _buildAction(
                        icon: Icons.bookmark_border,
                        count: null,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('به‌زودی...')),
                          );
                        },
                      ),
                      const Spacer(),
                      // دکمه منو (۳ نقطه)
                      _buildPostMenu(context, ref),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Text(
              _formatCount(count),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  TextDirection _getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.rtl;
    final firstChar = text.trim().isNotEmpty ? text.trim()[0] : '';
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(firstChar)
        ? TextDirection.rtl
        : TextDirection.ltr;
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

        final currentUserId = supabase.auth.currentUser?.id;
        final isCurrentUserPost = post.userId == currentUserId;

        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
            final hasPremiumEdit = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;

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
                    .read(supabaseServiceProvider)
                    .deletePost(ref, post.id);
                ref.invalidate(profilePostsProvider(post.userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('پست حذف شد')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطا در حذف: $e')),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
        return _ReelGridItem(reel: reel, isDark: isDark);
      },
    );
  }
}

/// آیتم گرید پست
class _PostGridItem extends StatelessWidget {
  final PublicPostModel post;
  final bool isDark;

  const _PostGridItem({required this.post, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasVideo = post.videoUrl != null && post.videoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        // Navigate to post detail
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: post.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            )
          else
            Container(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    post.content.length > 50
                        ? '${post.content.substring(0, 50)}...'
                        : post.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

          // Video indicator
          if (hasVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
        ],
      ),
    );
  }
}

/// آیتم گرید کلیپ
class _ReelGridItem extends StatelessWidget {
  final PublicPostModel reel;
  final bool isDark;

  const _ReelGridItem({required this.reel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to reel
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (reel.imageUrl != null)
            CachedNetworkImage(
              imageUrl: reel.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            )
          else
            Container(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
            ),

          // Play icon overlay
          Positioned(
            bottom: 8,
            left: 8,
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

  String _formatViewCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
