// unused import removed
import 'package:Vista/view/screen/PublicPosts/publicPosts.dart';
import 'package:Vista/view/util/comments_bottom_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../main.dart';
import '../../../model/MusicModel.dart';
import '../../../model/ProfileModel.dart';
import '../../../provider/MusicProvider.dart';
import '../../../provider/chat_provider.dart' as chat_provider;
import '../../../services/secure_config.dart';
import '../../util/const.dart';
import '../../util/widgets.dart';
import '../../widgets/CustomVideoPlayer.dart';
import '../../widgets/ReelsScreen.dart';
import '../chat/ChatScreen.dart';
import '../ouathUser/editeProfile.dart';
import '../searchPage.dart';
import '/model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../services/smart_share_service.dart';
import 'MusicWaveform.dart';
import 'followers and followings/FollowersScreen.dart';
import 'followers and followings/FollowingScreen.dart';
// removed unused imports
import 'dart:async';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../../../DB/profile_cache_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const ProfileScreen(
      {super.key, required this.userId, required this.username});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isStartingConversation = false;
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
      // رفرش کش پروفایل و 10 پست آخر در پس‌زمینه برای نمایش بهتر در حالت آفلاین
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
    final getprofile = ref.watch(profileProvider);
    final currentcolor = ref.watch(themeProvider);

    final isCurrentUserProfile = profileState != null &&
        currentUser != null &&
        profileState.id == currentUser.id;

    return Scaffold(
      endDrawer: isCurrentUserProfile
          ? CustomDrawer(getprofile, currentcolor, context, ref)
          : null,
      body: profileState == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    _buildSliverAppBar(profileState, getprofile, currentcolor,
                        isCurrentUserProfile),
                    _buildTabBar(),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsList(profileState),
                    _buildMusicList(profileState),
                    _buildClipsList(profileState),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _refreshProfile() async {
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
      ref.read(postsProvider);
      ref.watch(commentServiceProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطا در به‌روزرسانی: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  SliverAppBar _buildSliverAppBar(ProfileModel profile, dynamic getprofile,
      ThemeData currentcolor, dynamic isCurrentUserProfile) {
    return SliverAppBar(
      expandedHeight: 370,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      foregroundColor: Colors.black,
      floating: false,
      pinned: true,
      actions: [
        if (!isCurrentUserProfile)
          PopupMenuButton(
            onSelected: (value) {
              showDialog(
                context: context,
                builder: (context) =>
                    ReportProfileDialog(userId: widget.userId),
              );
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                    value: 'report', child: Text('گزارش کردن')),
              ];
            },
          )
      ],
      title: _buildAppBarTitle(profile),
      flexibleSpace: FlexibleSpaceBar(background: _buildProfileHeader(profile)),
    );
  }

  Row _buildAppBarTitle(ProfileModel profile) {
    return Row(
      children: [
        Text(profile.username,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black)),
        const SizedBox(width: 5),
        if (profile.isVerified) _buildVerificationBadge(profile),
      ],
    );
  }

  Widget _buildVerificationBadge(ProfileModel profile) {
    // نمایش تیک مناسب براساس نوع تأیید
    if (profile.hasBlueBadge) {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    } else if (profile.hasGoldBadge) {
      return const Icon(Icons.verified, color: Colors.amber, size: 16);
    } else if (profile.hasBlackBadge) {
      return Container(
        padding: const EdgeInsets.all(.1), // فاصله باریک برای پس‌زمینه
        decoration: BoxDecoration(
          color: Colors.white60, // پس‌زمینه سفید
          shape: BoxShape.circle, // پس‌زمینه دایره‌ای
        ),
        child: const Icon(Icons.verified, color: Colors.black, size: 14),
      );
    } else {
      return const SizedBox.shrink(); // در صورت نداشتن تیک، چیزی نمایش نمی‌دهیم
    }
  }

  Widget _buildProfileHeader(ProfileModel profile) {
    final bool isCurrentUserProfile = profile.id == ref.read(authProvider)?.id;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: isDark ? colorScheme.surface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            _buildProfileInfo(profile, isCurrentUserProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(ProfileModel profile, bool isCurrentUserProfile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildProfileAvatar(profile),
            const Spacer(),
            _buildProfileActionButton(profile, isCurrentUserProfile),
          ],
        ),
        const SizedBox(height: 16),
        _buildProfileDetails(profile),
        const SizedBox(height: 12),
        // اگر خصوصی و دنبال نشده: پیام قفل + دکمه درخواست
        Consumer(builder: (context, ref, _) {
          final isPrivateAsync =
              ref.watch(userSettingsByIdProvider(profile.id));
          return isPrivateAsync.when(
            data: (settings) {
              final isPrivate = (settings?['is_private'] as bool?) ?? false;
              final isFollowed = profile.isFollowed;
              if (!isPrivate || isFollowed || isCurrentUserProfile) {
                return const SizedBox.shrink();
              }

              final pendingAsync =
                  ref.watch(followRequestPendingProvider(profile.id));
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'این حساب خصوصی است',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'برای مشاهده پست‌ها باید درخواست دنبال کردن شما تایید شود.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    pendingAsync.when(
                      loading: () => const SizedBox(
                        height: 36,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => _buildRequestButton(ref, profile),
                      data: (pending) {
                        if (pending) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent),
                            ),
                            child:
                                const Text('درخواست شما در انتظار تایید است'),
                          );
                        }
                        return _buildRequestButton(ref, profile);
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          );
        }),
      ],
    );
  }

  Widget _buildRequestButton(WidgetRef ref, ProfileModel profile) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.person_add, size: 16),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        onPressed: () async {
          try {
            await ref
                .read(userProfileProvider(widget.userId).notifier)
                .toggleFollow(profile.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('درخواست دنبال کردن ارسال شد'),
                backgroundColor: Colors.green,
              ));
              // رفرش وضعیت pending
              final _ = ref.refresh(followRequestPendingProvider(profile.id));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('خطا: $e'),
                backgroundColor: Colors.red,
              ));
            }
          }
        },
        label: const Text('ارسال درخواست دنبال کردن'),
      ),
    );
  }

  Widget _buildProfileAvatar(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: CircleAvatar(
        radius: 40,
        backgroundImage:
            profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
        child: profile.avatarUrl == null
            ? const CircleAvatar(
                backgroundImage: AssetImage(defaultAvatarUrl), radius: 40)
            : null,
      ),
    );
  }

  Widget _buildProfileActionButton(
      ProfileModel profile, bool isCurrentUserProfile) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // اگر پروفایل خود کاربر است، فقط دکمه ویرایش پروفایل را نمایش می‌دهیم
    if (isCurrentUserProfile) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const EditProfile())),
        child: const Text('ویرایش پروفایل'),
      );
    }

    // برای پروفایل دیگران، هم دکمه دنبال کردن و هم دکمه ارسال پیام را نمایش می‌دهیم
    return Row(
      children: [
        // دکمه ارسال پیام
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkTheme ? Colors.white24 : Colors.blue,
            foregroundColor: isDarkTheme ? Colors.white : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: _isStartingConversation
              ? null
              : () => _startConversation(profile.id, profile.username),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.message, size: 16),
              const SizedBox(width: 4),
              Text(_isStartingConversation ? 'در حال بررسی...' : 'ارسال پیام'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // دکمه دنبال کردن
        Consumer(builder: (context, ref, _) {
          final settingsAsync = ref.watch(userSettingsByIdProvider(profile.id));
          final pendingAsync =
              ref.watch(followRequestPendingProvider(profile.id));
          return settingsAsync.when(
            data: (settings) {
              final isPrivate = (settings?['is_private'] as bool?) ?? false;
              return pendingAsync.when(
                data: (pending) {
                  final isFollowed = profile.isFollowed;
                  final isPending = isPrivate && !isFollowed && pending;
                  final label = isFollowed
                      ? 'لغو دنبال کردن'
                      : (isPrivate
                          ? (isPending ? 'در انتظار تایید' : 'ارسال درخواست')
                          : 'دنبال کردن');
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowed
                          ? (isDarkTheme ? Colors.white : Colors.black)
                          : Colors.white,
                      foregroundColor: isFollowed
                          ? (isDarkTheme ? Colors.black : Colors.white)
                          : (isDarkTheme ? Colors.black : Colors.black),
                      side: BorderSide(
                        color: isFollowed
                            ? Colors.transparent
                            : (isDarkTheme ? Colors.black : Colors.black),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed:
                        isPending ? null : () => _toggleFollow(profile.id),
                    child: Text(label),
                  );
                },
                loading: () => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isDarkTheme ? Colors.black : Colors.black,
                    side: BorderSide(
                        color: isDarkTheme ? Colors.black : Colors.black),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: null,
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isDarkTheme ? Colors.black : Colors.black,
                    side: BorderSide(
                        color: isDarkTheme ? Colors.black : Colors.black),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _toggleFollow(profile.id),
                  child: Text(
                      profile.isFollowed ? 'لغو دنبال کردن' : 'دنبال کردن'),
                ),
              );
            },
            loading: () => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isDarkTheme ? Colors.black : Colors.black,
                side: BorderSide(
                    color: isDarkTheme ? Colors.black : Colors.black),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: null,
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isDarkTheme ? Colors.black : Colors.black,
                side: BorderSide(
                    color: isDarkTheme ? Colors.black : Colors.black),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _toggleFollow(profile.id),
              child: Text(profile.isFollowed ? 'لغو دنبال کردن' : 'دنبال کردن'),
            ),
          );
        }),
      ],
    );
  }

  // متد برای شروع گفتگو با کاربر دیگر
  void _startConversation(String otherUserId, String otherUsername) async {
    try {
      if (_isStartingConversation) return;
      setState(() {
        _isStartingConversation = true;
      });

      // تعریف تم تاریک/روشن
      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

      // دریافت اطلاعات پروفایل برای عکس
      final profileState = ref.read(userProfileProvider(otherUserId));
      final avatarUrl = profileState?.avatarUrl;

      // ابتدا بررسی کن که آیا مکالمه قبلی وجود دارد یا نه
      String? existingConversationId;
      bool isNewConversation = true;

      try {
        final chatService = ref.read(chat_provider.chatServiceProvider);
        // نمایش نشانگر بارگذاری
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'در حال بررسی مکالمات موجود...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لطفاً صبر کنید',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );

        // بررسی وجود مکالمه قبلی
        existingConversationId =
            await chatService.findExistingConversation(otherUserId);
        if (existingConversationId != null &&
            existingConversationId.isNotEmpty) {
          isNewConversation = false;
          print('مکالمه موجود یافت شد: $existingConversationId');
        } else {
          print('هیچ مکالمه موجودی یافت نشد');
        }

        // بستن نشانگر بارگذاری
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('خطا در بررسی وجود مکالمه: $e');
        // در صورت خطا، فرض بر جدید بودن مکالمه
        // بستن نشانگر بارگذاری
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }

      // انتقال به صفحه چت
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId:
                  existingConversationId ?? '', // اگر وجود داشت، آن را ارسال کن
              otherUserId: otherUserId,
              otherUserName: otherUsername,
              otherUserAvatar: avatarUrl, // اضافه شد: ارسال عکس پروفایل
              isNewConversation:
                  isNewConversation, // بر اساس وجود یا عدم وجود مکالمه
            ),
          ),
        );
      }
    } catch (e) {
      print("خطای انتقال به صفحه چت: $e");
      // بستن نشانگر بارگذاری در صورت وجود
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در انتقال به صفحه چت: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingConversation = false;
        });
      }
    }
  }

  String _getFormattedDate(DateTime date) {
    Jalali jalaliDate = Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  Widget _buildProfileDetails(ProfileModel profile) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerTextColor = isDark ? Colors.white : Colors.black;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(profile.fullName,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: headerTextColor)),
      if (profile.bio != null) ...[
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 80),
          child: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                profile.bio!,
                overflow: TextOverflow.fade,
                style: TextStyle(color: headerTextColor.withOpacity(0.85)),
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => FollowingScreen(userId: widget.userId)));
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: [
                Text(' ${profile.followingCount}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: headerTextColor)),
                Text('دنبال شونده ها ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: headerTextColor)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => FollowersScreen(userId: widget.userId)));
          },
          child: Column(
            children: [
              Text(' ${profile.followersCount}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: headerTextColor)),
              Text('دنبال کنندگان',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: headerTextColor)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                Text(' ${profile.posts.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: headerTextColor)),
                Text(' پست‌ها',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: headerTextColor)),
              ],
            ),
          ),
        )
      ])
    ]);
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          indicatorColor: isDark ? Colors.white : Colors.black,
          indicatorWeight: 2,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_on, size: 18),
                  SizedBox(width: 8),
                  Text('پست‌ها'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 18),
                  SizedBox(width: 8),
                  Text('آهنگ‌ها'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'lib/view/util/images/component/reels.png',
                    width: 18,
                    height: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  SizedBox(width: 8),
                  Text('کلیپ‌ها'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(ProfileModel profile) {
    // نمایش پیام «حساب کاربری خصوصی» در وسط صفحه شبیه اینستاگرام
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;
        if (blockedView) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'حساب کاربری خصوصی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        if (profile.posts.isEmpty) {
          return const Center(child: Text('هنوز پستی وجود ندارد'));
        }

        return ListView.builder(
          itemCount: profile.posts.length,
          itemBuilder: (context, index) {
            return _buildPostItem(profile, profile.posts[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('خطا در بارگذاری پست‌ها')),
    );
  }

  Widget _buildMusicList(ProfileModel profile) {
    // نمایش پیام «حساب کاربری خصوصی» در وسط صفحه شبیه اینستاگرام
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;
        if (blockedView) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'حساب کاربری خصوصی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        // فیلتر کردن پست‌هایی که موزیک دارند
        final musicPosts =
            profile.posts.where((post) => post.hasMusic).toList();

        if (musicPosts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'هنوز آهنگی وجود ندارد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: musicPosts.length,
          itemBuilder: (context, index) {
            return _buildPostItem(profile, musicPosts[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('خطا در بارگذاری آهنگ‌ها')),
    );
  }

  Widget _buildClipsList(ProfileModel profile) {
    // نمایش پیام «حساب کاربری خصوصی» در وسط صفحه شبیه اینستاگرام
    final isPrivateAsync = ref.watch(userSettingsByIdProvider(profile.id));
    final currentUserId = ref.read(authProvider)?.id;
    return isPrivateAsync.when(
      data: (settings) {
        final isPrivate = (settings?['is_private'] as bool?) ?? false;
        final blockedView =
            isPrivate && !profile.isFollowed && profile.id != currentUserId;
        if (blockedView) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'حساب کاربری خصوصی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        // فیلتر کردن پست‌هایی که ویدیو دارند
        final videoPosts =
            profile.posts.where((post) => post.hasVideo).toList();

        if (videoPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/view/util/images/component/reels.png',
                  width: 56,
                  height: 56,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'هنوز کلیپی وجود ندارد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: videoPosts.length,
          itemBuilder: (context, index) {
            return _buildPostItem(profile, videoPosts[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('خطا در بارگذاری کلیپ‌ها')),
    );
  }

  Widget _buildPostContent(PublicPostModel post, BuildContext context) {
    final pattern = RegExp(
      r'(#[\w\u0600-\u06FF]+)|((https?:\/\/)?([\w\-])+\.{1}([a-zA-Z]{2,63})([\/\w-]*)*\/?\??([^\s<>#]*))',
      multiLine: true,
      unicode: true,
    );
    List<TextSpan> spans = [];
    int start = 0;

    for (Match match in pattern.allMatches(post.content)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: post.content.substring(start, match.start),
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black),
        ));
      }
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: const TextStyle(
                color: Colors.blue, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SearchPage(initialHashtag: matchedText),
                  ),
                );
              },
          ),
        );
      } else {
        // فیلتر کردن لینک‌های Vista و پست‌های اشتراکی
        if (!_isVistaOrSharedPostLink(matchedText)) {
          spans.add(
            TextSpan(
              text: matchedText,
              style: const TextStyle(
                  color: Colors.blue, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final url = matchedText.startsWith('http')
                      ? matchedText
                      : 'https://$matchedText';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                },
            ),
          );
        } else {
          // نمایش لینک‌های Vista به صورت متن عادی
          spans.add(TextSpan(text: matchedText));
        }
      }
      start = match.end;
    }
    if (start < post.content.length) {
      spans.add(TextSpan(
        text: post.content.substring(start),
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Directionality(
            textDirection: getDirectionality(post.content),
            child: RichText(text: TextSpan(children: spans)),
          ),
        if (post.musicUrl != null && post.musicUrl!.isNotEmpty)
          Consumer(
            builder: (context, ref, child) {
              final isPlaying = ref.watch(isPlayingProvider);
              final currentlyPlaying =
                  ref.watch(currentlyPlayingProvider).value;
              final isThisPlaying = currentlyPlaying?.musicUrl == post.musicUrl;
              final position = ref.watch(musicPositionProvider);
              final duration = ref.watch(musicDurationProvider);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: MusicWaveform(
                  musicUrl: post.musicUrl!,
                  isPlaying: isPlaying && isThisPlaying,
                  position: position,
                  duration: duration,
                  onPlayPause: () {
                    if (isPlaying && isThisPlaying) {
                      ref.read(musicPlayerProvider.notifier).togglePlayPause();
                    } else {
                      final music = MusicModel(
                        id: post.id,
                        userId: post.userId,
                        title: post.title ?? 'موزیک',
                        artist: post.username,
                        musicUrl: post.musicUrl!,
                        createdAt: post.createdAt,
                        username: post.username,
                        avatarUrl: post.avatarUrl,
                        isVerified: post.isVerified,
                      );
                      ref.read(musicPlayerProvider.notifier).playMusic(music);
                    }
                  },
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        if (post.hashtags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: post.hashtags
                .map((tag) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SearchPage(initialHashtag: '#$tag'),
                        ),
                      ),
                      child: Text('#$tag',
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPostItem(ProfileModel profile, PublicPostModel post) {
    // final isLiked = ref.watch(likeStateProvider)[post.id] ?? post.isLiked; // unused

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              CircleAvatar(
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(profile.username,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 3),
                        _buildVerificationBadge(profile)
                      ],
                    ),
                    Text(_getFormattedDate(post.createdAt),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              _buildPostMenu(context, post),
            ],
          ),
          const SizedBox(height: 12),
          // Content and Music section
          _buildPostContent(post, context),
          // Image section
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: VisibilityDetector(
                key: Key('profile_video_${post.id}'),
                onVisibilityChanged: (visibilityInfo) {
                  // فقط برای لاگ: میزان قابل مشاهده بودن
                  print(
                      'Video ${post.id} visibility: ${visibilityInfo.visibleFraction}');
                },
                child: CustomVideoPlayer(
                  key: ValueKey('video_player_${post.id}'),
                  videoUrl: post.videoUrl!,
                  autoplay: ref.watch(autoPlayProvider),
                  muted: true,
                  showProgress: true,
                  looping: true,
                  postId: post.id,
                  username: post.username,
                  likeCount: post.likeCount,
                  commentCount: post.commentCount,
                  isLiked: post.isLiked,
                  content: post.content, // اضافه کردن محتوای پست
                  isVerified: post.isVerified, // حتما از post
                  verificationType: post.verificationType, // حتما از post
                  onLike: () async {
                    _handleLike(post);
                  },
                  onComment: () => showCommentsBottomSheet2(context,
                      postId: post.id, postTitle: post.title ?? ''),
                  onVideoPositionTap: (position) {
                    ref.read(videoPositionProvider(post.id).notifier).state =
                        position;
                  },
                  onTap: () {
                    final profile =
                        ref.read(userProfileProvider(widget.userId));
                    final videoPosts = profile?.posts
                            .where((p) =>
                                p.videoUrl != null && p.videoUrl!.isNotEmpty)
                            .toList() ??
                        [];
                    final initialIndex =
                        videoPosts.indexWhere((p) => p.id == post.id);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReelsScreen(
                          posts: videoPosts,
                          initialIndex: initialIndex < 0 ? 0 : initialIndex,
                          initialPositions: {
                            post.id: ref.read(videoPositionProvider(post.id)),
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // نمایش تصویر اگر پست دارای imageUrl باشد
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showFullScreenImage(context, post.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => const ShimmerLoading(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Actions section
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLikeButton(post),
              const SizedBox(width: 16),
              _buildCommentButton(post),
              const SizedBox(width: 16),
              _buildShareButton(post),
            ],
          ),
          Divider(
            endIndent: 1,
            indent: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton(PublicPostModel post) {
    return Consumer(
      builder: (context, ref, child) {
        final isLiked = ref.watch(likeStateProvider)[post.id] ?? post.isLiked;
        final likeCount =
            post.likeCount + (isLiked != post.isLiked ? (isLiked ? 1 : -1) : 0);

        // Debug logging
        print('🔍 UI Like Button Debug - Post ID: ${post.id}');
        print('🔍 Base likeCount: ${post.likeCount}, isLiked: ${post.isLiked}');
        print(
            '🔍 LikeStateProvider value: ${ref.watch(likeStateProvider)[post.id]}');
        print('🔍 Final likeCount: $likeCount, final isLiked: $isLiked');

        return Row(
          children: [
            IconButton(
              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null),
              onPressed: () => _handleLike(post),
            ),
            Text('$likeCount'),
          ],
        );
      },
    );
  }

  Widget _buildCommentButton(PublicPostModel post) {
    // Debug logging
    print('🔍 UI Comment Button Debug - Post ID: ${post.id}');
    print('🔍 Comment count: ${post.commentCount}');

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showComments(post),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Image.asset(
              'lib/view/util/images/component/comment.png',
              width: 20,
              height: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        Text('${post.commentCount}'),
      ],
    );
  }

  Widget _buildShareButton(PublicPostModel post) {
    return IconButton(
        icon: Image.asset(
          'lib/view/util/images/component/send.png',
          width: 20,
          height: 20,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
        onPressed: () => _sharePost(post));
  }

  void _handleLike(PublicPostModel post) async {
    try {
      final currentLikeState = !post.isLiked;

      // آپدیت وضعیت در provider (optimistic update)
      ref
          .read(likeStateProvider.notifier)
          .updateLikeState(post.id, currentLikeState);

      // ارسال به سرور
      await ref.watch(supabaseServiceProvider).toggleLike(
            postId: post.id,
            ownerId: post.userId,
            ref: ref,
          );

      // Invalidate profile provider to refresh the data
      ref.invalidate(userProfileProvider(widget.userId));
    } catch (e) {
      // برگرداندن وضعیت در صورت خطا
      final previousLikeState = post.isLiked;
      ref
          .read(likeStateProvider.notifier)
          .updateLikeState(post.id, previousLikeState);

      debugPrint('Error in handleLike: $e');
    }
  }

  void _toggleFollow(String userId) async {
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .toggleFollow(userId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در تغییر وضعیت فالو: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _showComments(PublicPostModel post) {
    showCommentsBottomSheet2(context,
        postId: post.id, postTitle: post.title ?? '');
  }

  void _sharePost(PublicPostModel post) {
    // استفاده از قابلیت جدید اشتراک‌گذاری تصویری
    SmartShareService().showShareOptions(post, context);
  }

  void showEditPostDialog(
      BuildContext context, WidgetRef ref, PublicPostModel post) {
    final TextEditingController contentController =
        TextEditingController(text: post.content);
    String? imageUrl = post.imageUrl;
    String? videoUrl = post.videoUrl;
    bool imageRemoved = false;
    bool videoRemoved = false;
    bool isLoading = false;

    // جملات آماده برای ادمین‌ها
    final List<String> adminTemplates = [
      'این محتوا مناسب نیست و حذف شده است.',
      'تبلیغات در ویستا ممنوع است.',
      'این پست بر اساس قوانین ویستا حذف شده است.',
      'محتوای نامناسب شناسایی و حذف شد.',
      'این پست نقض قوانین محسوب می‌شود.',
      'لطفاً محتوای مناسب ارسال کنید.',
      'این محتوا با قوانین ویستا سازگار نیست.',
    ];

    // تابع تشخیص جهت متن
    TextDirection getTextDirection(String text) {
      final persianRegex = RegExp(r'[\u0600-\u06FF]');
      final englishRegex = RegExp(r'[a-zA-Z]');

      int persianCount = persianRegex.allMatches(text).length;
      int englishCount = englishRegex.allMatches(text).length;

      if (persianCount > englishCount) {
        return TextDirection.rtl;
      } else {
        return TextDirection.ltr;
      }
    }

    // تابع حذف فایل از آروان کلود
    Future<void> deleteFileFromArvan(String fileUrl) async {
      try {
        if (fileUrl.contains('storage.389346.ir.cdn.ir')) {
          final uri = Uri.parse(fileUrl);
          final key = uri.pathSegments.sublist(1).join('/');

          final s3 = S3(
            region: SecureConfig.awsRegion,
            credentials: AwsClientCredentials(
              accessKey: SecureConfig.awsAccessKey,
              secretKey: SecureConfig.awsSecretKey,
            ),
            endpointUrl: SecureConfig.awsEndpointUrl,
          );

          await s3.deleteObject(
            bucket: SecureConfig.awsBucketName,
            key: key,
          );
          print('فایل با موفقیت از آروان کلود حذف شد: $fileUrl');
        }
      } catch (e) {
        print('خطا در حذف فایل از آروان کلود: $e');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('ویرایش پست توسط ناظر'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بخش جملات آماده
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              const Text('جملات آماده:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: adminTemplates.map((template) {
                              return InkWell(
                                onTap: () {
                                  contentController.text = template;
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    template.length > 30
                                        ? '${template.substring(0, 30)}...'
                                        : template,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700]),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // بخش متن پست
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.text_fields,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              const Text('متن پست:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Directionality(
                            textDirection:
                                getTextDirection(contentController.text),
                            child: TextField(
                              controller: contentController,
                              maxLines: 4,
                              maxLength: 300,
                              textDirection:
                                  getTextDirection(contentController.text),
                              onChanged: (value) {
                                setState(() {
                                  // تغییر جهت متن بر اساس محتوا
                                });
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: 'متن پست را ویرایش کنید...',
                                counterText:
                                    '${contentController.text.length}/300',
                                filled: true,
                                fillColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[700]
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // بخش محتوای چندرسانه‌ای
                    if (imageUrl != null &&
                        imageUrl.isNotEmpty &&
                        !imageRemoved) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.image,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                const Text('تصویر فعلی:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 150,
                                      color: Colors.grey[300],
                                      child: const Center(
                                          child: CircularProgressIndicator()),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // حذف از آروان کلود
                                      await deleteFileFromArvan(imageUrl);
                                      setState(() {
                                        imageRemoved = true;
                                      });
                                    },
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: const Text('حذف تصویر'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // بخش ویدیو
                    if (videoUrl != null &&
                        videoUrl.isNotEmpty &&
                        !videoRemoved) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.video_library,
                                    size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                const Text('ویدیو فعلی:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Image.asset(
                                      'lib/view/util/images/component/reels.png',
                                      width: 50,
                                      height: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.video_library,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // حذف از آروان کلود
                                      await deleteFileFromArvan(videoUrl);
                                      setState(() {
                                        videoRemoved = true;
                                      });
                                    },
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: const Text('حذف ویدیو'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // اطلاعات پست
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              const Text('اطلاعات پست:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('نویسنده: ${post.username}'),
                          Text(
                              'تاریخ: ${post.createdAt.toString().substring(0, 16)}'),
                          Text('لایک‌ها: ${post.likeCount}'),
                          Text('کامنت‌ها: ${post.commentCount}'),
                          // نمایش اطلاعات ناظر قبلی (اگر وجود داشته باشد)
                          if (post.moderatorUsername != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings,
                                          size: 14, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      const Text('آخرین ویرایش توسط:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('ناظر: ${post.moderatorUsername}',
                                      style: const TextStyle(fontSize: 12)),
                                  if (post.moderatedAt != null)
                                    Text(
                                        'تاریخ: ${post.moderatedAt!.toString().substring(0, 16)}',
                                        style: const TextStyle(fontSize: 12)),
                                  if (post.moderationReason != null) ...[
                                    const SizedBox(height: 4),
                                    Text('دلیل: ${post.moderationReason}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.red)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('لغو'),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final content = contentController.text.trim();
                          if (content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('متن پست نمی‌تواند خالی باشد'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isLoading = true;
                          });

                          try {
                            // دریافت اطلاعات ناظر فعلی
                            final currentUser = supabase.auth.currentUser;
                            final moderatorProfile = await supabase
                                .from('profiles')
                                .select('username')
                                .eq('id', currentUser!.id)
                                .single();

                            final updateData = {
                              'content': content,
                              if (imageRemoved) 'image_url': null,
                              if (!imageRemoved && imageUrl != null)
                                'image_url': imageUrl,
                              if (videoRemoved) 'video_url': null,
                              if (!videoRemoved && videoUrl != null)
                                'video_url': videoUrl,
                              'updated_at': DateTime.now().toIso8601String(),
                              // ثبت اطلاعات ناظر
                              'moderator_id': currentUser.id,
                              'moderator_username':
                                  moderatorProfile['username'],
                              'moderated_at': DateTime.now().toIso8601String(),
                              'moderation_reason':
                                  content, // متن ویرایش شده به عنوان دلیل
                            };

                            await supabase
                                .from('posts')
                                .update(updateData)
                                .eq('id', post.id);
                            final _ =
                                ref.refresh(userProfileProvider(post.userId));

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text('پست با موفقیت ویرایش شد'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                isLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('خطا در ویرایش پست: $e'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isLoading ? 'در حال ذخیره...' : 'ذخیره تغییرات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  PopupMenuButton<String> _buildPostMenu(
      BuildContext context, PublicPostModel post) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        final currentUserId = supabase.auth.currentUser?.id;
        final isCurrentUserPost = post.userId == currentUserId;

        final isBlueTick = profile != null &&
            profile['is_verified'] == true &&
            profile['verification_type'] == 'blueTick';
        // فقط کاربران با تیک آبی مجاز به ویرایش هستند
        final canEditPost = isBlueTick;

        // Debug: چاپ اطلاعات پروفایل
        print('DEBUG: Profile data: $profile');
        print('DEBUG: isBlueTick: $isBlueTick');
        print('DEBUG: canEditPost (blueTick only): $canEditPost');

        return PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'delete':
                if (isCurrentUserPost || isBlueTick) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('حذف پست'),
                      content: const Text('آیا از حذف این پست اطمینان دارید؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('انصراف')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(supabaseServiceProvider)
                          .deletePost(ref, post.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('پست با موفقیت حذف شد')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('خطا در حذف پست')));
                    }
                  }
                }
                break;
              case 'report':
                if (!isCurrentUserPost) {
                  showDialog(
                      context: context,
                      builder: (context) => ReportDialog(post: post));
                }
                break;
              case 'copy':
                await Clipboard.setData(ClipboardData(text: post.content));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('متن کپی شد!')));
                }
                break;
              case 'edit':
                if (canEditPost) {
                  showEditPostDialog(context, ref, post);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('شما مجوز ویرایش این پست را ندارید'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[];

            // گزینه گزارش برای پست‌های دیگران
            if (!isCurrentUserPost) {
              items.add(
                  const PopupMenuItem(value: 'report', child: Text('گزارش')));
            }

            // گزینه کپی برای همه
            items.add(const PopupMenuItem(value: 'copy', child: Text('کپی')));

            // گزینه حذف برای صاحب پست یا مدیران (تیک آبی)
            if (isCurrentUserPost || isBlueTick) {
              items.add(
                  const PopupMenuItem(value: 'delete', child: Text('حذف')));
            }

            // گزینه ویرایش فقط برای کاربران با تیک آبی
            if (canEditPost) {
              items.add(
                  const PopupMenuItem(value: 'edit', child: Text('ویرایش')));
            }

            return items;
          },
        );
      },
      loading: () => PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'report':
              showDialog(
                  context: context,
                  builder: (context) => ReportDialog(post: post));
              break;
            case 'copy':
              await Clipboard.setData(ClipboardData(text: post.content));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('متن کپی شد!')));
              }
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'report', child: Text('گزارش')),
          const PopupMenuItem(value: 'copy', child: Text('کپی')),
        ],
      ),
      error: (_, __) => PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'report':
              showDialog(
                  context: context,
                  builder: (context) => ReportDialog(post: post));
              break;
            case 'copy':
              await Clipboard.setData(ClipboardData(text: post.content));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('متن کپی شد!')));
              }
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'report', child: Text('گزارش')),
          const PopupMenuItem(value: 'copy', child: Text('کپی')),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: imageUrl,
                child:
                    CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// بررسی اینکه آیا لینک مربوط به Vista یا پست اشتراکی است
bool _isVistaOrSharedPostLink(String url) {
  return url.contains('vista') ||
      url.contains('post/') ||
      url.contains('m مشاهده در Vista') ||
      url.contains('coffevista') ||
      url.contains('arvan');
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
