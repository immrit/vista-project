import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'telegram_profile_screen.dart' show GalleryPhotoViewWrapper;
import 'package:shamsi_date/shamsi_date.dart' as shamsi;
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../model/conversation_model.dart';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart';
import '../../../provider/chat_screen_provider.dart';
// import '../../posts/screens/profileScreen.dart'; // Unused
// import '../../../features/chat/repositories/chat_repository.dart'; // Unused
import '../providers/chat_providers.dart';
import 'ChatMessageSearchScreen.dart';
import '../../../services/voice_player_service.dart'; // Added
import '../../../widgets/CustomVideoPlayer.dart'; // Added

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const ChatDetailsScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ✅ امنیت: flag برای جلوگیری از کلیک‌های مکرر و navigation همزمان
  bool _isNavigating = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(conversationProvider(widget.conversationId));
    // ✅ استفاده از اطلاعات کش شده از conversation
    final conversation = conversationAsync.value;
    final allowProfileZoom = conversation?.allowProfileZoom;
    final isBlocked = conversation?.isBlocked ?? false;

    // ✅ ساخت profileData از conversation کش شده
    final userProfileData = conversation == null
        ? null
        : <String, dynamic>{
            'bio': conversation.otherUserBio,
            'created_at': conversation.otherUserCreatedAt?.toIso8601String(),
            'is_verified': conversation.isVerified ?? false,
            'username': conversation.otherUserName,
            'avatar_url': conversation.otherUserAvatar,
          };

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(AsyncValue.data(userProfileData),
                conversationAsync, isBlocked, allowProfileZoom),
            _buildUserInfo(AsyncValue.data(userProfileData)),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMediaGrid(
                context, ref, 'image', 'تصویر', Icons.image_outlined),
            _buildMediaGrid(
                context, ref, 'video', 'ویدیو', Icons.videocam_outlined),
            _buildMediaGrid(
                context, ref, 'audio', 'موزیک', Icons.music_note_outlined),
            _buildFilesTab(context, ref),
            _buildLinksTab(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
      AsyncValue<Map<String, dynamic>?> userProfileAsync,
      AsyncValue<ConversationModel?> conversationAsync,
      bool isBlocked,
      bool? allowProfileZoom) {
    return SliverAppBar(
      expandedHeight: 320.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_outlined),
          onPressed: () async {
            final messageId = await Navigator.of(context).push<String?>(
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
              // Pass the result back to the previous screen (ChatScreen)
              Navigator.of(context).pop(messageId);
            }
          },
          tooltip: 'جستجو',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, isBlocked),
          itemBuilder: (BuildContext context) {
            return conversationAsync.when(
              data: (conversation) {
                final isMuted = conversation?.isMuted ?? false;
                final isPinned = conversation?.isPinned ?? false;
                final conversationIsBlocked = conversation?.isBlocked ?? false;

                return <PopupMenuEntry<String>>[
                  _buildPopupMenuItem(
                      context,
                      'mute',
                      isMuted ? 'فعال کردن صدا' : 'بی‌صدا کردن',
                      isMuted
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined),
                  _buildPopupMenuItem(
                      context,
                      'pin',
                      isPinned ? 'حذف پین' : 'پین کردن',
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined),
                  const PopupMenuDivider(),
                  _buildPopupMenuItem(
                      context,
                      'block',
                      conversationIsBlocked
                          ? 'رفع مسدودیت'
                          : 'مسدود کردن کاربر',
                      conversationIsBlocked
                          ? Icons.lock_open_outlined
                          : Icons.block_outlined,
                      isDestructive: true),
                  _buildPopupMenuItem(context, 'clear_history',
                      'پاکسازی تاریخچه', Icons.delete_sweep_outlined,
                      isDestructive: true),
                  _buildPopupMenuItem(context, 'delete', 'حذف گفتگو',
                      Icons.delete_forever_outlined,
                      isDestructive: true),
                ];
              },
              loading: () => [
                const PopupMenuItem(
                    enabled: false,
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ))))
              ],
              error: (e, s) =>
                  [const PopupMenuItem(enabled: false, child: Text("خطا"))],
            );
          },
          icon: const Icon(Icons.more_vert_outlined),
          tooltip: 'گزینه‌های بیشتر',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // تصویر پس‌زمینه
            Hero(
              tag: 'profile_background_${widget.otherUserId}',
              child: widget.otherUserAvatar != null &&
                      widget.otherUserAvatar!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.otherUserAvatar!,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.4),
                      colorBlendMode: BlendMode.darken,
                      placeholder: (context, url) => _buildImageShimmer(),
                      errorWidget: (context, url, error) =>
                          _buildDefaultBackground(),
                    )
                  : _buildDefaultBackground(),
            ),
            // گرادیان زیبا برای بهتر خواندن متن
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // آواتار و اطلاعات کاربر
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // آواتار بزرگ قابل کلیک
                  // ✅ امنیت: استفاده از allowProfileZoom از conversation که با مکالمه کش شده
                  conversationAsync.when(
                    loading: () => IgnorePointer(
                      ignoring: true,
                      child: AbsorbPointer(
                        child: Hero(
                          tag: 'profile_avatar_${widget.otherUserId}',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _buildAvatarShimmer(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (_, __) => IgnorePointer(
                      ignoring: true,
                      child: AbsorbPointer(
                        child: Hero(
                          tag: 'profile_avatar_${widget.otherUserId}',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _buildAvatarShimmer(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    data: (conversation) {
                      // ✅ امنیت: استفاده از allowProfileZoom از conversation
                      // اگر null است یعنی هنوز لود نشده - shimmer نشان بده
                      final allowZoom = conversation?.allowProfileZoom;

                      if (allowZoom == null) {
                        // ✅ امنیت: هنوز لود نشده - استفاده از IgnorePointer برای غیرفعال کردن کامل کلیک
                        return IgnorePointer(
                          ignoring: true,
                          child: AbsorbPointer(
                            child: Hero(
                              tag: 'profile_avatar_${widget.otherUserId}',
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildAvatarShimmer(),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // ✅ اطلاعات لود شده - بررسی allowZoom
                      // ✅ امنیت: استفاده از IgnorePointer برای جلوگیری از کلیک اگر allowZoom false است
                      return IgnorePointer(
                        ignoring: !allowZoom,
                        child: GestureDetector(
                          onTap: () => _handleAvatarTap(),
                          child: Hero(
                            tag: 'profile_avatar_${widget.otherUserId}',
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: allowZoom
                                    ? (widget.otherUserAvatar != null &&
                                            widget.otherUserAvatar!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: widget.otherUserAvatar!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                _buildAvatarShimmer(),
                                            errorWidget:
                                                (context, url, error) =>
                                                    _buildDefaultAvatar(),
                                          )
                                        : _buildDefaultAvatar())
                                    : _buildDefaultAvatar(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // نام کاربر
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 15,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildAvatarShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleAvatarTap() {
    // ✅ امنیت لایه 1: جلوگیری از کلیک‌های مکرر (debounce)
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 500)) {
      return; // جلوگیری از کلیک‌های سریع
    }
    _lastTapTime = now;

    // ✅ امنیت لایه 2: جلوگیری از navigation همزمان
    if (_isNavigating) {
      return;
    }

    // ✅ امنیت لایه 3: دریافت مستقیم از provider (نه از parameter) برای اطمینان از داده‌های به‌روز
    final conversationAsync =
        ref.read(conversationProvider(widget.conversationId));

    // ✅ امنیت لایه 4: بررسی دقیق state
    if (conversationAsync.isLoading) {
      _showSnackBar('در حال بارگذاری اطلاعات...');
      return;
    }

    if (conversationAsync.hasError || conversationAsync.value == null) {
      _showSnackBar('خطا در دریافت اطلاعات');
      return;
    }

    final conversation = conversationAsync.value!;

    // ✅ امنیت لایه 5: بررسی دقیق allowProfileZoom
    if (conversation.allowProfileZoom == null) {
      _showSnackBar('در حال بارگذاری اطلاعات...');
      return;
    }

    final allowZoom = conversation.allowProfileZoom!;

    // ✅ امنیت لایه 6: بررسی نهایی allowZoom
    if (!allowZoom) {
      _showSnackBar('این کاربر بزرگنمایی پروفایل را غیرفعال کرده است');
      return;
    }

    // ✅ امنیت لایه 7: بررسی وجود avatar
    if (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty) {
      return;
    }

    // ✅ امنیت لایه 8: set flag قبل از navigation
    _isNavigating = true;

    _showFullScreenAvatar(conversation).then((_) {
      // Reset flag after navigation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isNavigating = false;
        }
      });
    }).catchError((_) {
      // Reset flag on error
      if (mounted) {
        _isNavigating = false;
      }
    });
  }

  Future<void> _showFullScreenAvatar(ConversationModel conversation) async {
    // ✅ امنیت لایه 9: بررسی مجدد قبل از نمایش (از provider)
    final conversationAsync =
        ref.read(conversationProvider(widget.conversationId));

    if (conversationAsync.isLoading || conversationAsync.value == null) {
      _showSnackBar('در حال بارگذاری اطلاعات...');
      _isNavigating = false;
      return;
    }

    final currentConversation = conversationAsync.value!;

    // ✅ امنیت لایه 10: بررسی مجدد allowProfileZoom از provider
    if (currentConversation.allowProfileZoom == null) {
      _showSnackBar('در حال بارگذاری اطلاعات...');
      _isNavigating = false;
      return;
    }

    final allowZoom = currentConversation.allowProfileZoom!;

    // ✅ امنیت لایه 11: بررسی نهایی allowZoom
    if (!allowZoom) {
      _showSnackBar('این کاربر بزرگنمایی پروفایل را غیرفعال کرده است');
      _isNavigating = false;
      return;
    }

    // ✅ امنیت لایه 12: بررسی وجود avatar
    if (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty) {
      _isNavigating = false;
      return;
    }

    // ✅ امنیت لایه 13: بررسی mounted قبل از navigation
    if (!mounted) {
      _isNavigating = false;
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _downloadAvatar(),
              ),
            ],
          ),
          body: Center(
            child: Hero(
              tag: 'profile_avatar_${widget.otherUserId}',
              child: PhotoView(
                imageProvider:
                    CachedNetworkImageProvider(widget.otherUserAvatar!),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _downloadAvatar() {
    _showSnackBar('دانلود تصویر آغاز شد');
  }

  Widget _buildUserInfo(AsyncValue<Map<String, dynamic>?> userProfileAsync) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: userProfileAsync.when(
          loading: () => _buildUserInfoShimmer(),
          error: (err, stack) => _buildErrorCard('خطا در دریافت اطلاعات'),
          data: (profileData) => _buildUserInfoContent(profileData),
        ),
      ),
    );
  }

  Widget _buildUserInfoShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
                2,
                (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 120,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoContent(Map<String, dynamic>? profileData) {
    if (profileData == null) {
      return _buildErrorCard('پروفایل یافت نشد');
    }

    final createdAtString = profileData['created_at'] as String?;
    String joinDate = 'نامشخص';
    if (createdAtString != null) {
      try {
        final createdAt = DateTime.parse(createdAtString);
        joinDate = _formatJoinDate(createdAt);
      } catch (e) {
        // خطا در پارس کردن تاریخ
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'درباره کاربر',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            Icons.alternate_email,
            'نام کاربری',
            '@${widget.otherUserName.toLowerCase()}',
          ),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'تاریخ عضویت',
            joinDate,
          ),
          if (profileData['bio'] != null &&
              profileData['bio'].toString().isNotEmpty)
            _buildInfoRow(
              Icons.description_outlined,
              'بیوگرافی',
              profileData['bio'].toString(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          isScrollable: true,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'تصاویر'),
            Tab(text: 'ویدیوها'),
            Tab(text: 'موزیک‌ها'),
            Tab(text: 'فایل‌ها'),
            Tab(text: 'لینک‌ها'),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(BuildContext context, WidgetRef ref, String mediaType,
      String emptyLabel, IconData emptyIcon) {
    final mediaAsync = ref.watch(sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      loading: () => _buildMediaGridShimmer(),
      error: (err, stack) => _buildErrorWidget('خطا در بارگذاری رسانه: $err'),
      data: (messages) {
        final mediaMessages = messages
            .where(
                (m) => m.attachmentType == mediaType && m.attachmentUrl != null)
            .toList();

        if (mediaMessages.isEmpty) {
          return _buildEmptyWidget(
              'هیچ رسانه‌ای یافت نشد', Icons.image_not_supported_outlined);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: mediaMessages.length,
          itemBuilder: (context, index) {
            final message = mediaMessages[index];
            return _buildMediaItem(message, index, mediaMessages);
          },
        );
      },
    );
  }

  Widget _buildMediaGridShimmer() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (context, index) => _buildImageShimmer(),
          ),
        ),
      ],
    );
  }

  // removed unused _buildStatItem

  Widget _buildMediaItem(
      MessageModel message, int index, List<MessageModel> mediaMessages) {
    switch (message.attachmentType) {
      case 'audio':
        return _buildAudioItem(message);
      case 'video':
        return _buildVideoItem(message);
      case 'image':
      default:
        return _buildImageItem(message, index, mediaMessages);
    }
  }

  Widget _buildAudioItem(MessageModel message) {
    return StreamBuilder<VoicePlayerState>(
      stream: voicePlayerService.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying =
            state?.voiceId == message.id && (state?.isPlaying ?? false);
        final isLoading =
            state?.voiceId == message.id && (state?.isLoading ?? false);

        return GestureDetector(
          onTap: () {
            if (message.attachmentUrl != null) {
              voicePlayerService.playOrPause(
                message.id,
                message.attachmentUrl!,
                title:
                    message.content.trim().isNotEmpty ? message.content : null,
                artist: message.senderName,
                artUrl: message.senderAvatar,
                conversationId: message.conversationId,
                conversationTitle: widget.otherUserName,
                attachmentType: message.attachmentType,
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Text(
                    _formatMessageDate(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoItem(MessageModel message) {
    return GestureDetector(
      onTap: () {
        if (message.attachmentUrl != null) {
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
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 48,
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatMessageDate(message.createdAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(
      MessageModel message, int index, List<MessageModel> mediaMessages) {
    return GestureDetector(
      onTap: () {
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
      },
      child: Hero(
        tag: message.id,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: message.attachmentUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
                // تاریخ در گوشه با طراحی بهتر
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatMessageDate(message.createdAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilesTab(BuildContext context, WidgetRef ref) {
    return _buildEmptyWidget('هیچ فایلی یافت نشد', Icons.folder_off_outlined);
  }

  Widget _buildLinksTab(BuildContext context, WidgetRef ref) {
    return _buildEmptyWidget('هیچ لینکی یافت نشد', Icons.link_off_outlined);
  }

  Widget _buildEmptyWidget(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز';
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }

  String _formatJoinDate(DateTime date) {
    final jalaliDate = shamsi.Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.formatter.mN} ${jalaliDate.year}';
  }

  void _toggleMuteConversation() async {
    try {
      // ChatScreenNotifier might not expose toggleMute directly if it's in ChatRepository
      // But ChatRepository HAS it.
      // So calling repo directly is better for action-only.
      final repo = ref.read(chatRepositoryProvider);
      await repo.toggleMuteConversation(widget.conversationId);
      _showSnackBar('تنظیمات اعلان تغییر کرد');
    } catch (e) {
      _showSnackBar('خطا در تغییر تنظیمات اعلان');
    }
  }

  void _handleMenuAction(BuildContext context, String value, bool isBlocked) {
    switch (value) {
      case 'mute':
        _toggleMuteConversation();
        break;
      case 'pin':
        _togglePinConversation();
        break;
      case 'block':
        _toggleBlockUser(isBlocked);
        break;
      case 'clear_history':
        _showClearHistoryDialog();
        break;
      case 'delete':
        _showDeleteConversationDialog();
        break;
    }
  }

  void _toggleBlockUser(bool isCurrentlyBlocked) {
    final notifier = ref.read(userBlockNotifierProvider.notifier);
    final future = isCurrentlyBlocked
        ? notifier.unblockUser(widget.otherUserId)
        : notifier.blockUser(widget.otherUserId);

    future.then((_) {
      _showSnackBar(
          isCurrentlyBlocked ? 'کاربر از مسدودیت خارج شد' : 'کاربر مسدود شد');
    }).catchError((e) {
      _showSnackBar('خطا در تغییر وضعیت مسدودیت', isError: true);
    });
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      BuildContext context, String value, String text, IconData icon,
      {bool isDestructive = false}) {
    final color = isDestructive
        ? Colors.red
        : Theme.of(context).textTheme.bodyLarge?.color;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  void _togglePinConversation() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.togglePinConversation(widget.conversationId);
      _showSnackBar('وضعیت پین تغییر کرد');
    } catch (e) {
      _showSnackBar('خطا در تغییر وضعیت پین');
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاکسازی تاریخچه'),
        content: const Text(
            'آیا مطمئن هستید؟ این عمل پیام‌ها را فقط برای شما حذف می‌کند و قابل بازگشت نیست.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatScreenProvider(ChatScreenArgs(
                          conversationId: widget.conversationId,
                          otherUserId: widget.otherUserId))
                      .notifier)
                  .clearAllMessages()
                  .then((_) => _showSnackBar('تاریخچه گفتگو پاکسازی شد.'))
                  .catchError((e) =>
                      _showSnackBar('خطا در پاکسازی تاریخچه', isError: true));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('پاکسازی'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف گفتگو'),
        content: const Text(
            'آیا از حذف کامل این گفتگو اطمینان دارید؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog first
              final repo = ref.read(chatRepositoryProvider);
              repo.deleteConversation(widget.conversationId).then((_) {
                // After successful deletion, pop the details screen
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }).catchError((e) {
                _showSnackBar('خطا در حذف گفتگو', isError: true);
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isError ? Colors.red[700] : null,
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// باقی کلاس‌های کمکی (همان کدهای قبلی)
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

// class GalleryPhotoViewWrapper removed because it is now in telegram_profile_screen.dart
