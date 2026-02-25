import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../provider/chat_provider.dart' as legacy_chat;
import '../../../services/smart_share_service.dart';
import '../providers/chat_providers.dart';
import '../../../utils/user_friendly_error_utils.dart';

/// صفحه اطلاعات مخاطب گفتگو - طراحی مدرن و تمیز
class ChatPartnerInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatPartnerInfoScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<ChatPartnerInfoScreen> createState() =>
      _ChatPartnerInfoScreenState();
}

class _ChatPartnerInfoScreenState extends ConsumerState<ChatPartnerInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    final userProfileAsync =
        ref.watch(legacy_chat.userProfileProvider(widget.otherUserId));

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, isDark),
        ],
        body: Column(
          children: [
            _buildUserInfoSection(isDark, userProfileAsync),
            _buildActionButtons(isDark),
            const SizedBox(height: 8),
            _buildMediaTabs(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMediaGrid(isDark),
                  _buildEmptyTab(
                      'فایل', Icons.insert_drive_file_outlined, isDark),
                  _buildEmptyTab('صدا', Icons.mic_none_outlined, isDark),
                  _buildEmptyTab('لینک', Icons.link_outlined, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isDark ? Colors.black : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // تصویر پروفایل
            if (widget.otherUserAvatar != null)
              CachedNetworkImage(
                imageUrl: widget.otherUserAvatar!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                ),
                errorWidget: (context, url, error) =>
                    _buildAvatarPlaceholder(isDark),
              )
            else
              _buildAvatarPlaceholder(isDark),

            // گرادیان برای خوانایی متن
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // نام کاربر
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w300,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(bool isDark, AsyncValue userProfileAsync) {
    return userProfileAsync.when(
      data: (data) {
        final bio = data?['bio'] as String?;
        final username = data?['username'] as String?;

        if (bio == null && username == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (username != null) ...[
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (bio != null) ...[
                Text(
                  bio,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.share_outlined,
              label: 'اشتراک‌گذاری',
              isDark: isDark,
              onTap: () async {
                // Share profile link
                await SmartShareService().shareProfile(widget.otherUserName);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.notifications_off_outlined,
              label: 'بی‌صدا',
              isDark: isDark,
              onTap: _toggleMute,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.block_outlined,
              label: 'مسدود',
              isDark: isDark,
              isDestructive: true,
              onTap: _toggleBlock,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMute() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.toggleMuteConversation(widget.conversationId);
      if (!mounted) return;
      UserFriendlyErrorUtils.showSuccessSnackBar(
        context,
        'تنظیمات اعلان گفت\u200cوگو به\u200cروزرسانی شد',
      );
    } catch (e) {
      if (!mounted) return;
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  Future<void> _toggleBlock() async {
    try {
      final notifier = ref.read(legacy_chat.userBlockNotifierProvider.notifier);
      final isBlocked = await ref
          .read(legacy_chat.userBlockStatusProvider(widget.otherUserId).future);

      if (isBlocked) {
        await notifier.unblockUser(widget.otherUserId);
      } else {
        await notifier.blockUser(widget.otherUserId);
      }

      if (!mounted) return;
      UserFriendlyErrorUtils.showSuccessSnackBar(
        context,
        isBlocked ? 'کاربر از حالت مسدود خارج شد' : 'کاربر مسدود شد',
      );
    } catch (e) {
      if (!mounted) return;
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black);
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTabs(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[400],
        indicatorColor: isDark ? Colors.white : Colors.black,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'رسانه'),
          Tab(text: 'فایل'),
          Tab(text: 'صدا'),
          Tab(text: 'لینک'),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final media = messages
            .where((m) =>
                m.attachmentUrl != null &&
                (m.attachmentType == 'image' || m.attachmentType == 'video'))
            .toList();

        if (media.isEmpty) {
          return _buildEmptyTab('رسانه', Icons.photo_library_outlined, isDark);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: media.length,
          itemBuilder: (context, index) {
            final isVideo = media[index].attachmentType == 'video';
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: media[index].attachmentUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                  ),
                ),
                if (isVideo)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => _buildEmptyTab('رسانه', Icons.error_outline, isDark),
    );
  }

  Widget _buildEmptyTab(String title, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 56,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'بدون $title',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
