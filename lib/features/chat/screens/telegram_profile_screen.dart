// lib/features/chat/screens/vista_chat_profile_screen.dart
//
// صفحه پروفایل/جزئیات چت - Vista
// طراحی مدرن و زیبا
//
// ویژگی‌ها:
// ✅ هدر با تصویر پروفایل بزرگ
// ✅ نام کاربر و وضعیت آنلاین
// ✅ دکمه‌های سریع (پیام، بی‌صدا، پروفایل، جستجو)
// ✅ اطلاعات کاربر (نام کاربری، شماره موبایل)
// ✅ تب‌های رسانه (Media, Files, Links, Voice, GIFs)
// ✅ گرید رسانه‌ها
//

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart' as legacy_chat;
import '../../../provider/chat_screen_provider.dart';
import '../../../provider/presence_provider.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../services/voice_player_service.dart';
import '../../../widgets/CustomVideoPlayer.dart';
import 'ChatMessageSearchScreen.dart';
import '../widgets/block_report_bottom_sheet.dart';

import '../../../features/chat/providers/chat_providers.dart';
import '../../../provider/provider.dart';
import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../posts/screens/profileScreen.dart';
import '../../posts/screens/PostDetailPage.dart';

enum _SharedPostKind { text, image, video, music }

class _SharedPostGridItemData {
  const _SharedPostGridItemData({
    required this.postId,
    required this.author,
    required this.preview,
    required this.createdAt,
    required this.kind,
    this.imageUrl,
    this.videoUrl,
    this.musicUrl,
  });

  final String postId;
  final String author;
  final String preview;
  final DateTime createdAt;
  final _SharedPostKind kind;
  final String? imageUrl;
  final String? videoUrl;
  final String? musicUrl;
}

/// صفحه جزئیات چت - Vista
class VistaChatProfileScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const VistaChatProfileScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<VistaChatProfileScreen> createState() =>
      _VistaChatProfileScreenState();
}

class _VistaChatProfileScreenState extends ConsumerState<VistaChatProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  double _headerOpacity = 0.0;
  bool _showCollapsedTitle = false;

  // رنگ‌های پایه (بر اساس تم)
  static const _darkBg = Color(0xFF17212B);
  static const _darkCard = Color(0xFF232E3C);
  static const _darkDivider = Color(0xFF303D4F);
  static const _lightBg = Color(0xFFFFFFFF);
  static const _lightDivider = Color(0xFFE4E6E9);

  /// دریافت رنگ اصلی از تم
  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final newOpacity = (offset / 200).clamp(0.0, 1.0);
    final showTitle = offset > 150;

    if (newOpacity != _headerOpacity || showTitle != _showCollapsedTitle) {
      setState(() {
        _headerOpacity = newOpacity;
        _showCollapsedTitle = showTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfileAsync =
        ref.watch(legacy_chat.userProfileProvider(widget.otherUserId));
    final conversationAsync =
        ref.watch(legacy_chat.conversationProvider(widget.conversationId));
    final isBlockedAsync =
        ref.watch(legacy_chat.userBlockStatusProvider(widget.otherUserId));
    final userOnlineAsync = ref
        .watch(userPresenceStreamProvider(widget.otherUserId))
        .whenData((presence) => presence.isOnline);

    final bgColor = isDark ? _darkBg : _lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // هدر با تصویر پروفایل
              _buildProfileHeader(isDark, userOnlineAsync),

              // محتوای صفحه
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // دکمه‌های عملیات سریع
                    _buildActionButtons(
                        isDark, conversationAsync, isBlockedAsync),

                    // اطلاعات کاربر
                    _buildUserInfoSection(isDark, userProfileAsync),

                    const SizedBox(height: 8),

                    // بخش رسانه‌ها
                    _buildMediaSection(isDark),
                  ],
                ),
              ),
            ],
          ),

          // نوار عنوان شناور
          _buildFloatingAppBar(isDark),
        ],
      ),
    );
  }

  /// هدر با تصویر پروفایل بزرگ
  Widget _buildProfileHeader(bool isDark, AsyncValue<bool> userOnlineAsync) {
    final avatarProvider =
        AvatarAssetUtils.imageProvider(widget.otherUserAvatar);

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // تصویر پس‌زمینه با افکت بلور
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? const Color(0xFF2A4157) : const Color(0xFF6C9BCF),
                  isDark ? _darkBg : _lightBg,
                ],
              ),
            ),
            child: avatarProvider != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // تصویر اصلی با بلور
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                      // گرادیان روی تصویر
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildDefaultAvatarBackground(isDark),
          ),

          // محتوای هدر
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // آواتار دایره‌ای
                GestureDetector(
                  onTap: () => _handleAvatarTap(),
                  child: Hero(
                    tag: 'profile_avatar_${widget.otherUserId}',
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? _darkBg : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarProvider != null
                            ? AvatarAssetUtils.image(
                                source: widget.otherUserAvatar,
                                fit: BoxFit.cover,
                                placeholder: _buildAvatarShimmer(),
                                fallback: _buildDefaultAvatar(isDark),
                              )
                            : _buildDefaultAvatar(isDark),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // نام کاربر
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // وضعیت آنلاین
                userOnlineAsync.when(
                  data: (isOnline) => _buildOnlineStatus(isOnline, isDark),
                  loading: () => Text(
                    'در حال بررسی...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  error: (_, __) => Text(
                    'آخرین بازدید اخیراً',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // دکمه بازگشت
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // دکمه منو
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => _showOptionsMenu(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// وضعیت آنلاین/آفلاین
  Widget _buildOnlineStatus(bool isOnline, bool isDark) {
    if (isOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'آنلاین',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4ADE80),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      'آخرین بازدید اخیراً',
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  /// دکمه‌های عملیات سریع
  Widget _buildActionButtons(
    bool isDark,
    AsyncValue conversationAsync,
    AsyncValue<bool> isBlockedAsync,
  ) {
    final cardColor = isDark ? _darkCard : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // دکمه پیام
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'پیام',
            color: _primaryColor,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 8),

          // دکمه بی‌صدا
          conversationAsync.when(
            data: (conversation) {
              final isMuted = conversation?.isMuted ?? false;
              return _buildActionButton(
                icon: isMuted
                    ? Icons.notifications_off
                    : Icons.notifications_outlined,
                label: isMuted ? 'صدادار' : 'بی‌صدا',
                color: isDark ? Colors.white70 : Colors.grey[700]!,
                isDark: isDark,
                onTap: () => _toggleMute(),
              );
            },
            loading: () => _buildActionButton(
              icon: Icons.notifications_outlined,
              label: 'بی‌صدا',
              color: isDark ? Colors.white70 : Colors.grey[700]!,
              isDark: isDark,
              onTap: () {},
            ),
            error: (_, __) => _buildActionButton(
              icon: Icons.notifications_outlined,
              label: 'بی‌صدا',
              color: isDark ? Colors.white70 : Colors.grey[700]!,
              isDark: isDark,
              onTap: () {},
            ),
          ),

          const SizedBox(width: 8),

          // دکمه مشاهده پروفایل
          _buildActionButton(
            icon: Icons.person_outline,
            label: 'پروفایل',
            color: isDark ? Colors.white70 : Colors.grey[700]!,
            isDark: isDark,
            onTap: () => _viewProfile(),
          ),

          const SizedBox(width: 8),

          // دکمه جستجو
          _buildActionButton(
            icon: Icons.search,
            label: 'جستجو',
            color: isDark ? Colors.white70 : Colors.grey[700]!,
            isDark: isDark,
            onTap: () => _openSearch(),
          ),
        ],
      ),
    );
  }

  /// دکمه عملیات تکی - طراحی چهارگوش مدرن
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بخش اطلاعات کاربر
  Widget _buildUserInfoSection(bool isDark, AsyncValue userProfileAsync) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];
    final dividerColor = isDark ? _darkDivider : _lightDivider;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: userProfileAsync.when(
        data: (profileData) {
          final username = profileData?['username'] ?? widget.otherUserName;
          final phone = profileData?['phone_number'] as String?;
          final bio = profileData?['bio'] as String?;

          return Column(
            children: [
              // نام کاربری
              _buildInfoTile(
                icon: Icons.alternate_email,
                title: '@$username',
                subtitle: 'نام کاربری',
                isDark: isDark,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '@$username'));
                  _showSnackBar('نام کاربری کپی شد');
                },
                trailing: IconButton(
                  icon: Icon(
                    Icons.qr_code_2,
                    color: subtitleColor,
                    size: 22,
                  ),
                  onPressed: () {
                    _showQrDialog(widget.otherUserId, username: username);
                  },
                ),
              ),

              // شماره موبایل (اگر موجود باشد)
              if (phone != null && phone.isNotEmpty) ...[
                Divider(height: 1, color: dividerColor, indent: 56),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  title: phone,
                  subtitle: 'موبایل',
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    _showSnackBar('شماره موبایل کپی شد');
                  },
                ),
              ],

              // بیوگرافی (اگر موجود باشد)
              if (bio != null && bio.isNotEmpty) ...[
                Divider(height: 1, color: dividerColor, indent: 56),
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: bio,
                  subtitle: 'بیوگرافی',
                  isDark: isDark,
                  maxLines: 3,
                ),
              ],
            ],
          );
        },
        loading: () => _buildInfoShimmer(isDark),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'خطا در دریافت اطلاعات',
            style: TextStyle(color: subtitleColor),
          ),
        ),
      ),
    );
  }

  /// تایل اطلاعات
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
    int maxLines = 1,
  }) {
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _primaryColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// بخش رسانه‌ها
  Widget _buildMediaSection(bool isDark) {
    final cardColor = isDark ? _darkCard : Colors.white;
    final tabColor = isDark ? Colors.white70 : Colors.grey[700];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // تب‌بار
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: _primaryColor,
            unselectedLabelColor: tabColor,
            indicatorColor: _primaryColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(text: 'پست‌ها'),
              Tab(text: 'رسانه'),
              Tab(text: 'فایل‌ها'),
              Tab(text: 'لینک‌ها'),
              Tab(text: 'صدا'),
              Tab(text: 'GIF'),
              Tab(text: 'گروه‌ها'),
            ],
          ),

          // محتوای تب‌ها
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(isDark),
                _buildMediaTab(isDark),
                _buildFilesTab(isDark),
                _buildLinksTab(isDark),
                _buildVoiceTab(isDark),
                _buildGifsTab(isDark),
                _buildGroupsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final sharedPosts =
            messages.where(_isSharedPostMessage).toList(growable: false);
        if (sharedPosts.isEmpty) {
          return _buildEmptyState(
            icon: Icons.article_outlined,
            text: 'هیچ پستی یافت نشد',
            isDark: isDark,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                _resolvePostsCrossAxisCount(constraints.maxWidth);

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: constraints.maxWidth >= 760 ? 0.9 : 0.82,
              ),
              itemCount: sharedPosts.length,
              itemBuilder: (context, index) => _buildSharedPostGridTile(
                _buildSharedPostGridItemData(sharedPosts[index]),
                isDark,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری پست‌ها',
        isDark: isDark,
      ),
    );
  }

  /// تب رسانه (تصاویر و ویدیوها)
  Widget _buildMediaTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final mediaMessages = messages
            .where((m) =>
                (m.attachmentType == 'image' || m.attachmentType == 'video') &&
                m.attachmentUrl != null)
            .toList();

        if (mediaMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.photo_library_outlined,
            text: 'هیچ رسانه‌ای یافت نشد',
            isDark: isDark,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: mediaMessages.length,
          itemBuilder: (context, index) {
            final message = mediaMessages[index];
            return _buildMediaGridItem(message, index, mediaMessages, isDark);
          },
        );
      },
      loading: () => _buildMediaGridShimmer(),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری رسانه‌ها',
        isDark: isDark,
      ),
    );
  }

  int _resolvePostsCrossAxisCount(double width) {
    if (width >= 980) return 4;
    if (width >= 700) return 3;
    return 2;
  }

  bool _isVisualSharedPost(_SharedPostKind kind) {
    return kind == _SharedPostKind.image || kind == _SharedPostKind.video;
  }

  Widget _buildSharedPostGridTile(_SharedPostGridItemData post, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF2A3646) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSharedPostById(post.postId),
        child: _isVisualSharedPost(post.kind)
            ? _buildSharedPostMediaThumbnailTile(post, isDark)
            : _buildSharedPostTextCardTile(post, isDark),
      ),
    );
  }

  Widget _buildSharedPostMediaThumbnailTile(
      _SharedPostGridItemData post, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildSharedPostGridPreview(post, isDark),
        Positioned(
          top: 8,
          left: 8,
          child: _buildSharedPostTypeChip(post.kind, true),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDate(post.createdAt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedPostTextCardTile(
      _SharedPostGridItemData post, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white70 : Colors.black54;
    final quoteBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.author.isNotEmpty ? post.author : 'پست اشتراک‌گذاری‌شده',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSharedPostTypeChip(post.kind, isDark),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: quoteBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                post.preview,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: subtleColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(post.createdAt),
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostGridPreview(
      _SharedPostGridItemData post, bool isDark) {
    final fallbackColor =
        isDark ? const Color(0xFF334155) : Colors.blueGrey[50]!;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF546E7A);

    if (post.kind == _SharedPostKind.image ||
        post.kind == _SharedPostKind.video) {
      final mediaUrl = post.kind == _SharedPostKind.video
          ? (post.imageUrl ?? post.videoUrl)
          : post.imageUrl;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => ColoredBox(color: fallbackColor),
              errorWidget: (_, __, ___) =>
                  Icon(Icons.image_not_supported_outlined, color: iconColor),
            ),
            if (post.kind == _SharedPostKind.video)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.58)
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
          ],
        );
      }
    }

    final bool isMusic = post.kind == _SharedPostKind.music;
    final colors = isMusic
        ? <Color>[
            const Color(0xFF0EA5E9),
            const Color(0xFF2563EB),
          ]
        : <Color>[
            const Color(0xFFFB7185),
            const Color(0xFFF59E0B),
          ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMusic ? Icons.music_note_rounded : Icons.subject_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const Spacer(),
          Text(
            isMusic ? 'پست موزیک' : 'پست متنی',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostTypeChip(_SharedPostKind kind, bool isDark) {
    final icon = _sharedPostTypeIcon(kind);
    final label = _sharedPostTypeLabel(kind);

    final bg = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : _primaryColor.withValues(alpha: 0.08);
    final fg = isDark ? Colors.white70 : _primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _sharedPostTypeIcon(_SharedPostKind kind) {
    switch (kind) {
      case _SharedPostKind.text:
        return Icons.subject_rounded;
      case _SharedPostKind.image:
        return Icons.image_outlined;
      case _SharedPostKind.video:
        return Icons.videocam_outlined;
      case _SharedPostKind.music:
        return Icons.music_note_outlined;
    }
  }

  String _sharedPostTypeLabel(_SharedPostKind kind) {
    switch (kind) {
      case _SharedPostKind.text:
        return 'متن';
      case _SharedPostKind.image:
        return 'عکس';
      case _SharedPostKind.video:
        return 'ویدیو';
      case _SharedPostKind.music:
        return 'موزیک';
    }
  }

  _SharedPostGridItemData _buildSharedPostGridItemData(MessageModel message) {
    final parsedMap = _decodeSharedPostMap(message);
    final model = message.sharedPostData;

    final postId = _firstNonEmpty([
          model?.postId,
          parsedMap?['postId'],
          parsedMap?['post_id'],
          parsedMap?['id'],
        ]) ??
        '';

    final author = _firstNonEmpty([
          model?.postAuthorName,
          parsedMap?['authorName'],
          parsedMap?['postAuthorName'],
          parsedMap?['post_author_name'],
          parsedMap?['full_name'],
          parsedMap?['username'],
        ]) ??
        '';

    final preview = _firstNonEmpty([
          model?.postContent,
          parsedMap?['content'],
          parsedMap?['post_content'],
          parsedMap?['caption'],
          parsedMap?['text'],
        ]) ??
        'برای مشاهده پست لمس کنید';

    final mediaUrls = _extractMediaUrls(parsedMap);
    final imageUrl = _firstNonEmpty([
      model?.postImageUrl,
      parsedMap?['image_url'],
      parsedMap?['post_image_url'],
      parsedMap?['imageUrl'],
      _firstMatching(mediaUrls, _looksLikeImageUrl),
    ]);
    final videoUrl = _firstNonEmpty([
      model?.postVideoUrl,
      parsedMap?['video_url'],
      parsedMap?['post_video_url'],
      parsedMap?['videoUrl'],
      _firstMatching(mediaUrls, _looksLikeVideoUrl),
    ]);
    final musicUrl = _firstNonEmpty([
      parsedMap?['music_url'],
      parsedMap?['post_music_url'],
      parsedMap?['musicUrl'],
      parsedMap?['audio_url'],
      parsedMap?['audioUrl'],
      parsedMap?['song_url'],
      parsedMap?['track_url'],
      _firstMatching(mediaUrls, _looksLikeAudioUrl),
    ]);

    final kind = videoUrl != null
        ? _SharedPostKind.video
        : imageUrl != null
            ? _SharedPostKind.image
            : musicUrl != null
                ? _SharedPostKind.music
                : _SharedPostKind.text;

    return _SharedPostGridItemData(
      postId: postId,
      author: author,
      preview: preview,
      createdAt: message.createdAt,
      kind: kind,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      musicUrl: musicUrl,
    );
  }

  Map<String, dynamic>? _decodeSharedPostMap(MessageModel message) {
    final content = message.content.trim();
    if (!content.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  List<String> _extractMediaUrls(Map<String, dynamic>? map) {
    if (map == null) return const [];
    final raw = map['mediaUrls'] ?? map['media_urls'];
    if (raw is! List) return const [];

    final urls = <String>[];
    for (final item in raw) {
      final normalized = _normalizeUrlValue(item);
      if (normalized != null) {
        urls.add(normalized);
      }
    }
    return urls;
  }

  String? _firstMatching(List<String> items, bool Function(String value) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  String? _firstNonEmpty(Iterable<dynamic> candidates) {
    for (final candidate in candidates) {
      final normalized = _normalizeUrlValue(candidate, allowAnyText: true);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _normalizeUrlValue(dynamic value, {bool allowAnyText = false}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    if (allowAnyText) return text;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    return null;
  }

  bool _looksLikeImageUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.gif') ||
        normalized.endsWith('.heic');
  }

  bool _looksLikeVideoUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp4') ||
        normalized.endsWith('.mov') ||
        normalized.endsWith('.mkv') ||
        normalized.endsWith('.webm') ||
        normalized.endsWith('.m4v');
  }

  bool _looksLikeAudioUrl(String url) {
    final normalized = url.toLowerCase();
    return normalized.endsWith('.mp3') ||
        normalized.endsWith('.wav') ||
        normalized.endsWith('.ogg') ||
        normalized.endsWith('.aac') ||
        normalized.endsWith('.m4a') ||
        normalized.endsWith('.flac');
  }

  bool _isSharedPostMessage(MessageModel message) {
    if (message.sharedPostData != null || message.isSharedPost) return true;

    final attachmentType = (message.attachmentType ?? '').toLowerCase();
    if (attachmentType == 'post' || attachmentType == 'shared_post') {
      return true;
    }

    final content = message.content.trim();
    if (!content.startsWith('{')) return false;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return map['postId'] != null || map['post_id'] != null;
      }
    } catch (_) {}
    return false;
  }

  void _openSharedPostById(String postId) {
    if (postId.isEmpty) {
      _showSnackBar('شناسه پست یافت نشد', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(postId: postId),
      ),
    );
  }

  /// آیتم گرید رسانه
  Widget _buildMediaGridItem(
    MessageModel message,
    int index,
    List<MessageModel> mediaMessages,
    bool isDark,
  ) {
    final isVideo = message.attachmentType == 'video';

    return GestureDetector(
      onTap: () => _showMediaViewer(message, index, mediaMessages),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: message.attachmentUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Icon(
                Icons.broken_image,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ),
          if (isVideo)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// تب فایل‌ها
  Widget _buildFilesTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final fileMessages = messages
            .where((m) => m.attachmentType == 'file' && m.attachmentUrl != null)
            .toList();

        if (fileMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_outlined,
            text: 'هیچ فایلی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: fileMessages.length,
          itemBuilder: (context, index) {
            final file = fileMessages[index];
            return _buildFileItem(file, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری فایل‌ها',
        isDark: isDark,
      ),
    );
  }

  /// آیتم فایل
  Widget _buildFileItem(MessageModel file, bool isDark) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.insert_drive_file, color: _primaryColor),
      ),
      title: Text(
        file.attachmentFileName ?? 'فایل',
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDate(file.createdAt),
        style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(Icons.download_outlined,
            color: isDark ? Colors.white60 : Colors.grey[600]),
        onPressed: () {
          _downloadFile(file);
        },
      ),
    );
  }

  /// تب لینک‌ها
  /// تب لینک‌ها
  Widget _buildLinksTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final linkEntries = <_MessageLinkEntry>[];
        for (final message in messages) {
          if (_isSharedPostMessage(message)) continue;
          final content = message.content.trim();
          if (content.isEmpty) continue;
          final urls = _extractUrlsFromText(content);
          for (final url in urls) {
            if (_isSharedPostLink(url)) continue;
            linkEntries.add(_MessageLinkEntry(message: message, url: url));
          }
        }

        if (linkEntries.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_off_outlined,
            text: 'هیچ لینکی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: linkEntries.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 72,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          itemBuilder: (context, index) {
            final entry = linkEntries[index];
            final msg = entry.message;
            final url = entry.url;
            final description = _removeUrlFromText(msg.content, url);

            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.public, color: _primaryColor),
              ),
              title: Text(
                url,
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                description.isEmpty ? 'بدون توضیحات' : description,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatDate(msg.createdAt),
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontSize: 10,
                ),
              ),
              onTap: () => _launchExternalUrl(url),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری لینک‌ها',
        isDark: isDark,
      ),
    );
  }

  List<String> _extractUrlsFromText(String text) {
    final urlRegex = RegExp(
      r'((https?:\/\/|www\.)[^\s<>()]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s<>()]*)?)',
      caseSensitive: false,
    );

    final unique = <String>{};
    final urls = <String>[];

    for (final match in urlRegex.allMatches(text)) {
      var url = match.group(0)?.trim() ?? '';
      if (url.isEmpty) continue;
      url = url.replaceAll(RegExp(r'[)\],.!?;:]+$'), '');
      if (url.isEmpty) continue;
      if (unique.add(url)) {
        urls.add(url);
      }
    }

    return urls;
  }

  String _removeUrlFromText(String text, String url) {
    final normalizedUrl = RegExp.escape(url);
    final withoutUrl = text.replaceAll(RegExp(normalizedUrl), '').trim();
    return withoutUrl;
  }

  bool _isSharedPostLink(String url) {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final fullPath = uri.path.toLowerCase();
    final firstSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first.toLowerCase() : '';
    final hasPostPath = firstSegment == 'post' ||
        firstSegment == 'posts' ||
        firstSegment == 'p' ||
        fullPath.contains('/post/') ||
        fullPath.contains('/posts/');
    final hasPostQuery = uri.queryParameters.containsKey('postId') ||
        uri.queryParameters.containsKey('post_id');
    final vistaPostScheme =
        uri.scheme.toLowerCase() == 'vista' && firstSegment == 'post';
    final isVistaHost = host.contains('vista');

    return vistaPostScheme || (isVistaHost && (hasPostPath || hasPostQuery));
  }

  Future<void> _launchExternalUrl(String url) async {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showSnackBar('لینک معتبر نیست', isError: true);
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showSnackBar('امکان باز کردن لینک وجود ندارد', isError: true);
      }
    } catch (_) {
      _showSnackBar('خطا در باز کردن لینک', isError: true);
    }
  }

  /// تب صدا
  Widget _buildVoiceTab(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final voiceMessages = messages
            .where(
                (m) => m.attachmentType == 'voice' && m.attachmentUrl != null)
            .toList();

        if (voiceMessages.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mic_none_outlined,
            text: 'هیچ پیام صوتی یافت نشد',
            isDark: isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: voiceMessages.length,
          itemBuilder: (context, index) {
            final voice = voiceMessages[index];
            return _buildVoiceItem(voice, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        text: 'خطا در بارگذاری',
        isDark: isDark,
      ),
    );
  }

  /// آیتم پیام صوتی
  Widget _buildVoiceItem(MessageModel voice, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];
    final url = voice.audioUrl ?? voice.attachmentUrl;

    if (url == null) return const SizedBox();

    return StreamBuilder<VoicePlayerState>(
      stream: VoicePlayerService().playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.isPlaying ?? false;
        final isCurrentVoice = state?.voiceId == voice.id;
        final isLoading = state?.isLoading ?? false;

        return ListTile(
          leading: GestureDetector(
            onTap: () {
              VoicePlayerService().playOrPause(voice.id, url);
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: isLoading && isCurrentVoice
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      (isCurrentVoice && isPlaying)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: _primaryColor,
                    ),
            ),
          ),
          title: Text(
            'پیام صوتی',
            style: TextStyle(color: textColor),
          ),
          subtitle: Text(
            _formatDate(voice.createdAt),
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
        );
      },
    );
  }

  /// تب GIF‌ها
  Widget _buildGifsTab(bool isDark) {
    return _buildEmptyState(
      icon: Icons.gif_box_outlined,
      text: 'هیچ GIF یافت نشد',
      isDark: isDark,
    );
  }

  /// تب گروه‌ها
  Widget _buildGroupsTab(bool isDark) {
    return _buildEmptyState(
      icon: Icons.group_outlined,
      text: 'گروه مشترکی یافت نشد',
      isDark: isDark,
    );
  }

  /// وضعیت خالی
  Widget _buildEmptyState({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// نوار عنوان شناور
  Widget _buildFloatingAppBar(bool isDark) {
    if (!_showCollapsedTitle) return const SizedBox.shrink();

    final avatarProvider =
        AvatarAssetUtils.imageProvider(widget.otherUserAvatar);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).padding.top + 56,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: BoxDecoration(
              color: (isDark ? _darkBg : _lightBg)
                  .withValues(alpha: _headerOpacity * 0.9),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? _darkDivider : _lightDivider)
                      .withValues(alpha: _headerOpacity),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(widget.otherUserName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _showOptionsMenu(context),
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛠️ متدهای کمکی
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAvatarShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildDefaultAvatarBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF3D5A80) : const Color(0xFF6C9BCF),
            isDark ? const Color(0xFF293241) : const Color(0xFF4A7C9B),
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor,
            _primaryColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
              2,
              (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 150,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 80,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
        ),
      ),
    );
  }

  Widget _buildMediaGridShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Container(color: Colors.grey[800]),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'امروز';
    if (diff.inDays == 1) return 'دیروز';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 عملیات‌ها
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی دسترسی بزرگنمایی و نمایش تصویر
  void _handleAvatarTap() async {
    if (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty) {
      return;
    }

    // بررسی تنظیمات حریم خصوصی کاربر
    final userSettingsAsync =
        ref.read(userSettingsByIdProvider(widget.otherUserId));

    userSettingsAsync.when(
      data: (settings) {
        // بررسی اجازه بزرگنمایی پروفایل
        final allowZoom = settings?['allow_profile_zoom'] as bool? ?? true;

        if (!allowZoom) {
          // نمایش پیغام عدم دسترسی
          _showPrivacyRestrictedDialog();
        } else {
          // نمایش تصویر تمام صفحه
          _showFullScreenAvatar();
        }
      },
      loading: () {
        // در حال بارگذاری - اجازه نمایش
        _showFullScreenAvatar();
      },
      error: (_, __) {
        // در صورت خطا، پیش‌فرض اجازه می‌دهیم
        _showFullScreenAvatar();
      },
    );
  }

  /// نمایش دیالوگ محدودیت حریم خصوصی
  void _showPrivacyRestrictedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.lock_outline,
          size: 48,
          color: _primaryColor,
        ),
        title: Text(
          'محدودیت دسترسی',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'این کاربر اجازه بزرگنمایی تصویر پروفایل خود را غیرفعال کرده است.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'متوجه شدم',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// نمایش تصویر پروفایل تمام صفحه
  void _showFullScreenAvatar() {
    final avatarProvider =
        AvatarAssetUtils.imageProvider(widget.otherUserAvatar);
    if (avatarProvider == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Hero(
            tag: 'profile_avatar_${widget.otherUserId}',
            child: PhotoView(
              imageProvider: avatarProvider,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaViewer(
      MessageModel message, int index, List<MessageModel> mediaMessages) {
    if (message.attachmentType == 'video' && message.attachmentUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: CustomVideoPlayer(
                      videoUrl: message.attachmentUrl!,
                      autoplay: true,
                      showControls: true,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryPhotoViewWrapper(
            galleryItems: mediaMessages,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            initialIndex: index,
            scrollDirection: Axis.horizontal,
          ),
        ),
      );
    }
  }

  void _showQrDialog(String vistaId, {String? username}) {
    final normalizedId = vistaId.trim();
    if (normalizedId.isEmpty) {
      _showSnackBar('Vista ID معتبر نیست', isError: true);
      return;
    }

    final qrData = 'vista://user/$normalizedId';
    final normalizedUsername = username?.trim() ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR کاربر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              size: 190,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text('Vista ID: $normalizedId', textDirection: TextDirection.ltr),
            if (normalizedUsername.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('@$normalizedUsername', textDirection: TextDirection.ltr),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: normalizedId));
              Navigator.pop(ctx);
              _showSnackBar('Vista ID کپی شد');
            },
            child: const Text('کپی Vista ID'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(MessageModel file) async {
    final url = file.attachmentUrl?.trim();
    if (url == null || url.isEmpty) {
      _showSnackBar('لینک فایل یافت نشد', isError: true);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showSnackBar('لینک فایل معتبر نیست', isError: true);
      return;
    }

    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        _showSnackBar('دانلود فایل ناموفق بود', isError: true);
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final fallbackName = 'file_${DateTime.now().millisecondsSinceEpoch}';
      final rawName = (file.attachmentFileName ?? fallbackName).trim();
      final sanitizedName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${directory.path}/$sanitizedName';
      final output = File(filePath);
      await output.writeAsBytes(bytes, flush: true);

      if (mounted) {
        _showSnackBar('فایل ذخیره شد');
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _showOptionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBlockedAsync =
        ref.read(legacy_chat.userBlockStatusProvider(widget.otherUserId));
    final isBlocked = isBlockedAsync.value ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? _darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دستگیره
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            _buildMenuOption(
              icon: Icons.block,
              label: isBlocked ? 'رفع مسدودیت' : 'مسدود کردن',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _toggleBlock(isBlocked);
              },
            ),

            _buildMenuOption(
              icon: Icons.report_outlined,
              label: 'گزارش',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),

            _buildMenuOption(
              icon: Icons.delete_outline,
              label: 'حذف گفتگو',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  void _toggleMute() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.toggleMuteConversation(widget.conversationId);
      _showSnackBar('تنظیمات اعلان تغییر کرد');
    } catch (e) {
      _showSnackBar('خطا در تغییر تنظیمات', isError: true);
    }
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: widget.otherUserId,
          username: widget.otherUserName,
        ),
      ),
    );
  }

  void _openSearch() async {
    final messageId = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(
        builder: (context) => ChatMessageSearchScreen(
          conversationId: widget.conversationId,
          otherUserName: widget.otherUserName,
          otherUserAvatar: widget.otherUserAvatar,
          otherUserId: widget.otherUserId,
        ),
      ),
    );

    if (messageId != null && mounted) {
      Navigator.of(context).pop(messageId);
    }
  }

  void _toggleBlock(bool isCurrentlyBlocked) {
    final notifier = ref.read(legacy_chat.userBlockNotifierProvider.notifier);
    final future = isCurrentlyBlocked
        ? notifier.unblockUser(widget.otherUserId)
        : notifier.blockUser(widget.otherUserId);

    future.then((_) {
      _showSnackBar(
        isCurrentlyBlocked ? 'کاربر از مسدودیت خارج شد' : 'کاربر مسدود شد',
      );
    }).catchError((e) {
      _showSnackBar('خطا در تغییر وضعیت', isError: true);
    });
  }

  void _showReportDialog() {
    BlockReportBottomSheet.show(
      context: context,
      userId: widget.otherUserId,
      userName: widget.otherUserName,
      isCurrentlyBlocked: false,
      type: ModerationType.report,
    ).then((submitted) {
      if (submitted == true && mounted) {
        _showSnackBar('گزارش شما ثبت شد');
      }
    });
  }

  void _showDeleteDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف گفتگو',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'آیا از حذف این گفتگو اطمینان دارید؟ این عمل قابل بازگشت نیست.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style:
                  TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation();
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteConversation() async {
    try {
      final notifier = ref.read(chatScreenProvider(ChatScreenArgs(
              conversationId: widget.conversationId,
              otherUserId: widget.otherUserId))
          .notifier);
      await notifier.deleteConversation();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showSnackBar('خطا در حذف گفتگو', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _MessageLinkEntry {
  final MessageModel message;
  final String url;

  const _MessageLinkEntry({
    required this.message,
    required this.url,
  });
}

class GalleryPhotoViewWrapper extends StatelessWidget {
  final List<MessageModel> galleryItems;
  final BoxDecoration backgroundDecoration;
  final int initialIndex;
  final PageController pageController;
  final Axis scrollDirection;

  GalleryPhotoViewWrapper({
    super.key,
    required this.galleryItems,
    required this.backgroundDecoration,
    required this.initialIndex,
    this.scrollDirection = Axis.horizontal,
  }) : pageController = PageController(initialPage: initialIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          final item = galleryItems[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(item.attachmentUrl!),
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: item.id),
          );
        },
        itemCount: galleryItems.length,
        loadingBuilder: (context, event) => const Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(),
          ),
        ),
        backgroundDecoration: backgroundDecoration,
        pageController: pageController,
        scrollDirection: scrollDirection,
      ),
    );
  }
}
