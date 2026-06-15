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
import '../../../features/chat/providers/legacy_chat_providers.dart' as legacy_chat;
import '../../../provider/chat_screen_provider.dart';
import '../../../provider/presence_provider.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../services/voice_player_service.dart';
import '../../../widgets/CustomVideoPlayer.dart';
import 'ChatMessageSearchScreen.dart';
import '../widgets/block_report_bottom_sheet.dart';

import '../../../features/chat/providers/chat_providers.dart';
import '../../../features/auth/providers/auth_controller.dart';
import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/directional_navigation.dart';
import '../../../utils/profile_zoom_policy.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../posts/navigation/content_routes.dart';
import '../../posts/screens/PostDetailPage.dart';

part 'modern_profile_actions.dart';
part 'modern_profile_header.dart';
part 'modern_profile_tabs.dart';

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

// رنگ‌های پایه (بر اساس تم)
const _darkBg = Color(0xFF17212B);
const _darkCard = Color(0xFF232E3C);
const _darkDivider = Color(0xFF303D4F);
const _lightBg = Color(0xFFFFFFFF);
const _lightDivider = Color(0xFFE4E6E9);

class _VistaChatProfileScreenState extends ConsumerState<VistaChatProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  double _headerOpacity = 0.0;
  bool _showCollapsedTitle = false;



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
                    directionalBackIcon(context),
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
  Future<void> _handleAvatarTap() async {
    if (widget.otherUserAvatar == null || widget.otherUserAvatar!.isEmpty) {
      return;
    }

    await ProfileZoomPolicy.openEnlargedAvatar(
      context: context,
      ref: ref,
      targetUserId: widget.otherUserId,
      avatarUrl: widget.otherUserAvatar,
      viewerUserId: ref.read(activeUserProvider)?.id,
      heroTag: 'profile_avatar_${widget.otherUserId}',
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
    ContentNavigation.pushProfile(
      context,
      userId: widget.otherUserId,
      username: widget.otherUserName,
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
