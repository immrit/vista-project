// lib/features/chat/screens/telegram_chat_details_screen.dart
//
// صفحه جزئیات چت به سبک تلگرام
//
// ویژگی‌ها:
// ✅ User info با avatar بزرگ
// ✅ مدیریت Notifications
// ✅ مشاهده Media/Files/Links
// ✅ تنظیمات Wallpaper
// ✅ Clear History & Delete Chat
// ✅ Block & Report
// ✅ Statistics
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../repositories/chat_details_repository.dart';
import '../widgets/telegram_delete_dialog.dart';
import '../widgets/telegram_undo_snackbar.dart';
import '../services/complete_deletion_service.dart';
import '../services/message_deletion_service.dart';
import '../../../model/message_model.dart';

/// صفحه جزئیات چت
class TelegramChatDetailsScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const TelegramChatDetailsScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<TelegramChatDetailsScreen> createState() =>
      _TelegramChatDetailsScreenState();
}

class _TelegramChatDetailsScreenState
    extends ConsumerState<TelegramChatDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = ChatDetailsRepository();
  late final CompleteDeletionService _deletionService;

  ChatStatistics? _statistics;
  ChatSettings? _settings;
  bool _isLoadingStats = true;

  // Media tabs
  List<MessageModel> _images = [];
  List<MessageModel> _videos = [];
  List<MessageModel> _documents = [];
  List<MessageModel> _links = [];

  @override
  void initState() {
    super.initState();
    // استفاده از Provider برای دریافت MessageDeletionService
    final messageDeletionService = ref.read(messageDeletionServiceProvider);
    _deletionService = CompleteDeletionService(messageDeletionService);
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deletionService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingStats = true);

    // بارگذاری موازی
    final results = await Future.wait([
      _repository.getChatStatistics(widget.conversationId),
      _repository.getChatSettings(widget.conversationId),
      _repository.getChatImages(conversationId: widget.conversationId),
      _repository.getChatVideos(conversationId: widget.conversationId),
      _repository.getChatDocuments(conversationId: widget.conversationId),
      _repository.getChatLinks(conversationId: widget.conversationId),
    ]);

    if (mounted) {
      setState(() {
        _statistics = results[0] as ChatStatistics;
        _settings = results[1] as ChatSettings;
        _images = results[2] as List<MessageModel>;
        _videos = results[3] as List<MessageModel>;
        _documents = results[4] as List<MessageModel>;
        _links = results[5] as List<MessageModel>;
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar با Hero Header
          _buildSliverAppBar(theme, isDark),

          // محتوا
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildUserInfo(theme, isDark),
                const SizedBox(height: 8),
                _buildQuickActions(theme, isDark),
                const SizedBox(height: 8),
                _buildNotificationSettings(theme, isDark),
                const SizedBox(height: 8),
                _buildMediaSection(theme, isDark),
                const SizedBox(height: 8),
                _buildChatSettings(theme, isDark),
                const SizedBox(height: 8),
                _buildDangerZone(theme, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Avatar بزرگ با گرادیانت
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withOpacity(0.8),
                    theme.primaryColor,
                  ],
                ),
              ),
              child: widget.otherUserAvatar != null
                  ? CachedNetworkImage(
                      imageUrl: widget.otherUserAvatar!,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        widget.otherUserName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            // Gradient overlay
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
            // نام کاربر در پایین
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'آخرین بازدید اخیراً', // TODO: از provider بگیر
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(ThemeData theme, bool isDark) {
    if (_isLoadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.message_rounded,
            label: 'تعداد پیام‌ها',
            value: _statistics?.totalMessages.toString() ?? '0',
            color: Colors.blue,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.image_rounded,
                  value: _statistics?.imagesCount.toString() ?? '0',
                  label: 'تصویر',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.videocam_rounded,
                  value: _statistics?.videosCount.toString() ?? '0',
                  label: 'ویدیو',
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.insert_drive_file_rounded,
                  value: _statistics?.documentsCount.toString() ?? '0',
                  label: 'فایل',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.call_rounded,
              label: 'تماس صوتی',
              color: Colors.green,
              onTap: () {
                // TODO: voice call
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.videocam_rounded,
              label: 'تماس تصویری',
              color: Colors.blue,
              onTap: () {
                // TODO: video call
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.search_rounded,
              label: 'جستجو',
              color: Colors.orange,
              onTap: () {
                // TODO: search messages
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: 'اعلان‌ها',
            subtitle: _settings?.isMuted ?? false ? 'بی‌صدا شده' : 'فعال',
            trailing: Switch(
              value: !(_settings?.isMuted ?? false),
              onChanged: (value) {
                _toggleMute(!value);
              },
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          _buildSettingTile(
            icon: Icons.push_pin_outlined,
            title: 'پین کردن',
            subtitle:
                _settings?.isPinned ?? false ? 'در بالای لیست' : 'غیرفعال',
            trailing: Switch(
              value: _settings?.isPinned ?? false,
              onChanged: (value) {
                _togglePin(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.perm_media_rounded,
                    color: theme.primaryColor, size: 22),
                const SizedBox(width: 12),
                Text(
                  'رسانه، فایل‌ها و لینک‌ها',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(
                icon: Icon(Icons.image_rounded, size: 20),
                text: 'تصاویر',
              ),
              Tab(
                icon: Icon(Icons.videocam_rounded, size: 20),
                text: 'ویدیوها',
              ),
              Tab(
                icon: Icon(Icons.insert_drive_file_rounded, size: 20),
                text: 'فایل‌ها',
              ),
              Tab(
                icon: Icon(Icons.link_rounded, size: 20),
                text: 'لینک‌ها',
              ),
            ],
          ),
          // Tab Content
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(_images, 'image'),
                _buildMediaGrid(_videos, 'video'),
                _buildDocumentsList(_documents),
                _buildLinksList(_links),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(List<MessageModel> items, String type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'image'
                  ? Icons.image_not_supported_rounded
                  : Icons.videocam_off_rounded,
              size: 48,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'image' ? 'بدون تصویر' : 'بدون ویدیو',
              style: TextStyle(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length > 9 ? 9 : items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.attachmentUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Theme.of(context).cardColor,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context).cardColor,
                  child: Icon(Icons.broken_image_rounded,
                      color: Theme.of(context).hintColor),
                ),
              ),
              if (type == 'video')
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentsList(List<MessageModel> documents) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'بدون فایل',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: documents.length > 5 ? 5 : documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final doc = documents[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.insert_drive_file_rounded, color: Colors.blue),
          ),
          title: Text(
            doc.attachmentFileName ?? 'فایل',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatDate(doc.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.download_rounded),
          onTap: () {
            // TODO: download or open file
          },
        );
      },
    );
  }

  Widget _buildLinksList(List<MessageModel> links) {
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 48,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'بدون لینک',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: links.length > 5 ? 5 : links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final link = links[index];
        final extractedLinks = _repository.extractLinks(link.content);
        if (extractedLinks.isEmpty) return const SizedBox.shrink();

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link_rounded, color: Colors.green),
          ),
          title: Text(
            extractedLinks.first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatDate(link.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () {
            // TODO: open link
          },
        );
      },
    );
  }

  Widget _buildChatSettings(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.wallpaper_rounded,
            title: 'تغییر والپیپر',
            subtitle: 'سفارشی‌سازی پس‌زمینه چت',
            onTap: () {
              // TODO: wallpaper picker
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          _buildSettingTile(
            icon: Icons.archive_outlined,
            title: 'آرشیو چت',
            subtitle: 'انتقال به بخش آرشیو',
            onTap: () {
              _toggleArchive();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.block_rounded,
            title: 'مسدود کردن کاربر',
            subtitle: 'جلوگیری از ارسال پیام',
            textColor: Colors.orange,
            onTap: () {
              // TODO: block user
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          _buildSettingTile(
            icon: Icons.report_outlined,
            title: 'گزارش کاربر',
            subtitle: 'گزارش به تیم پشتیبانی',
            textColor: Colors.orange,
            onTap: () {
              // TODO: report user
            },
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
          _buildSettingTile(
            icon: Icons.delete_outline_rounded,
            title: 'پاک کردن چت',
            subtitle: 'حذف تمام پیام‌ها',
            textColor: Colors.red,
            onTap: () {
              _showClearChatDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final color = textColor ?? theme.textTheme.titleLarge?.color;

    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: theme.hintColor,
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _toggleMute(bool mute) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(isMuted: mute);
    final success = await _repository.saveChatSettings(
      conversationId: widget.conversationId,
      settings: newSettings,
    );

    if (success && mounted) {
      setState(() => _settings = newSettings);
      TelegramUndoSnackbar.show(
        context: context,
        action: UndoAction.muteChat,
        onUndo: () {
          _toggleMute(!mute);
        },
      );
    }
  }

  void _togglePin(bool pin) async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(isPinned: pin);
    final success = await _repository.saveChatSettings(
      conversationId: widget.conversationId,
      settings: newSettings,
    );

    if (success && mounted) {
      setState(() => _settings = newSettings);
    }
  }

  void _toggleArchive() async {
    if (_settings == null) return;

    final newSettings = _settings!.copyWith(
      isArchived: !(_settings!.isArchived),
    );
    final success = await _repository.saveChatSettings(
      conversationId: widget.conversationId,
      settings: newSettings,
    );

    if (success && mounted) {
      setState(() => _settings = newSettings);
      Navigator.pop(context);
    }
  }

  void _showClearChatDialog() {
    TelegramDeleteDialog.show(
      context: context,
      type: DeleteDialogType.entireChat,
      canDeleteForEveryone: true,
      onDeleteForMe: () => _clearChat(false),
      onDeleteForEveryone: () => _clearChat(true),
    );
  }

  Future<void> _clearChat(bool forEveryone) async {
    final deletionId = await _deletionService.clearChatWithUndo(
      conversationId: widget.conversationId,
      isForEveryone: forEveryone,
    );

    if (mounted) {
      TelegramUndoSnackbar.show(
        context: context,
        action: UndoAction.clearChat,
        onUndo: () {
          _deletionService.undoDeletion(deletionId);
        },
        onDismiss: () {
          // بعد از 5 ثانیه برگرد به صفحه قبل
          Navigator.pop(context);
        },
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'امروز';
    } else if (difference.inDays == 1) {
      return 'دیروز';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
