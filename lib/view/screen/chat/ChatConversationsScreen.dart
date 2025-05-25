import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

import '../../../model/channel_model.dart';
import '../../../model/conversation_model.dart';
import '../../../provider/channel_provider.dart';
import '../../../provider/chat_provider.dart';
import '../../util/const.dart';
import '../channel/ChannelScreen.dart';
import 'ChatScreen.dart';

// مدل یکپارچه برای نمایش چت‌ها و کانال‌ها در یک لیست
@immutable
class UnifiedChatItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final DateTime? lastActivity;
  final int unreadCount;
  final bool isChannel;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final dynamic source;
  final int? memberCount;

  const UnifiedChatItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.lastActivity,
    this.unreadCount = 0,
    required this.isChannel,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
    this.source,
    this.memberCount,
  });

  factory UnifiedChatItem.fromConversation(ConversationModel conversation) {
    return UnifiedChatItem(
      id: conversation.id,
      title: conversation.otherUserName ?? 'کاربر ناشناس',
      subtitle: conversation.lastMessage,
      avatarUrl: conversation.otherUserAvatar,
      lastActivity: conversation.lastMessageTime,
      unreadCount: conversation.unreadCount ?? 0,
      isChannel: false,

      // isOnline: conversation.isOnline ?? false,
      // isPinned: conversation.isPinned ?? false,
      // isMuted: conversation.isMuted ?? false,
      source: conversation,
    );
  }

  factory UnifiedChatItem.fromChannel(ChannelModel channel) {
    return UnifiedChatItem(
      id: channel.id,
      title: channel.name,
      subtitle: channel.description,
      avatarUrl: channel.avatarUrl,
      lastActivity: channel.updatedAt,
      unreadCount: 0,
      isChannel: true,
      source: channel,
      memberCount: channel.memberCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedChatItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isChannel == other.isChannel;

  @override
  int get hashCode => Object.hash(id, isChannel);
}

class ChatConversationsScreen extends ConsumerStatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  ConsumerState<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState
    extends ConsumerState<ChatConversationsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _searchAnimController;
  late final Animation<double> _searchAnimation;
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeInOut,
    );
    timeago.setLocaleMessages('fa', timeago.FaMessages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchSection(theme),
          Expanded(child: _buildUnifiedList(theme)),
        ],
      ),
    );
  }

  // AppBar بهینه‌شده
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      title: Text(
        'پیام‌ها',
        style: theme.appBarTheme.titleTextStyle?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.titleLarge?.color,
            ),
      ),
      centerTitle: false,
      actions: [
        _buildSearchToggle(theme),
        _buildMoreMenuButton(theme),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchToggle(ThemeData theme) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
          key: ValueKey(_isSearchVisible),
          color: theme.appBarTheme.iconTheme?.color,
        ),
      ),
      onPressed: _toggleSearch,
      tooltip: _isSearchVisible ? 'بستن جستجو' : 'جستجو',
    );
  }

  Widget _buildMoreMenuButton(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: theme.appBarTheme.iconTheme?.color,
      ),
      onSelected: _handleMenuAction,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      itemBuilder: (context) => [
        _buildMenuItem(
          value: 'archived',
          icon: Icons.archive_outlined,
          title: 'گفتگوهای بایگانی',
          theme: theme,
        ),
        _buildMenuItem(
          value: 'settings',
          icon: Icons.settings_outlined,
          title: 'تنظیمات چت',
          theme: theme,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required ThemeData theme,
  }) {
    return PopupMenuItem(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.iconTheme.color),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  // Search Section
  Widget _buildSearchSection(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isSearchVisible ? 80 : 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              hintText: 'جستجو در پیام‌ها و کانال‌ها...',
              hintStyle: TextStyle(
                color: theme.hintColor,
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.hintColor,
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: theme.hintColor,
                      ),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // لیست یکپارچه چت‌ها و کانال‌ها
  Widget _buildUnifiedList(ThemeData theme) {
    // ترکیب داده‌ها از هر دو provider
    final conversationsAsync = ref.watch(conversationsProvider);
    final channelsAsync = ref.watch(channelsProvider);

    return conversationsAsync.when(
      loading: () => _buildLoadingState(theme),
      error: (error, stack) => _buildErrorState(theme, error.toString()),
      data: (conversations) {
        return channelsAsync.when(
          loading: () => _buildLoadingState(theme),
          error: (error, stack) => _buildErrorState(theme, error.toString()),
          data: (channels) {
            final unifiedItems =
                _combineAndFilterItems(conversations, channels);

            if (unifiedItems.isEmpty) {
              return _buildEmptyState(
                theme,
                _searchQuery.isEmpty
                    ? 'هیچ گفتگو یا کانالی وجود ندارد'
                    : 'نتیجه‌ای یافت نشد',
                _searchQuery.isEmpty
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.search_off_rounded,
              );
            }

            return RefreshIndicator(
              onRefresh: () => _refreshData(),
              color: theme.primaryColor,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: unifiedItems.length,
                separatorBuilder: (context, index) => _buildDivider(theme),
                itemBuilder: (context, index) => _buildUnifiedItem(
                  theme,
                  unifiedItems[index],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ترکیب و فیلتر کردن آیتم‌ها
  List<UnifiedChatItem> _combineAndFilterItems(
    List<ConversationModel> conversations,
    List<ChannelModel> channels,
  ) {
    final List<UnifiedChatItem> allItems = [];

    // اضافه کردن conversations
    allItems.addAll(
      conversations.map(UnifiedChatItem.fromConversation),
    );

    // اضافه کردن channels
    allItems.addAll(
      channels.map(UnifiedChatItem.fromChannel),
    );

    // فیلتر کردن بر اساس جستجو
    final filteredItems = _searchQuery.isEmpty
        ? allItems
        : allItems.where(_matchesSearchQuery).toList();

    // مرتب‌سازی: pinned ها اول، سپس بر اساس آخرین فعالیت
    filteredItems.sort((a, b) {
      // اول pinned ها
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // سپس بر اساس آخرین فعالیت
      final aTime = a.lastActivity ?? DateTime(1970);
      final bTime = b.lastActivity ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return filteredItems;
  }

  // نمایش آیتم یکپارچه
  Widget _buildUnifiedItem(ThemeData theme, UnifiedChatItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToItem(item),
        onLongPress: () => _showItemOptions(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(theme, item),
              const SizedBox(width: 12),
              Expanded(child: _buildContent(theme, item)),
              _buildTrailing(theme, item),
            ],
          ),
        ),
      ),
    );
  }

  // آواتار یکپارچه
  Widget _buildAvatar(ThemeData theme, UnifiedChatItem item) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: _buildAvatarImage(theme, item),
          ),
        ),
        // Online indicator for conversations
        if (!item.isChannel && item.isOnline) _buildOnlineIndicator(theme),
        // Channel indicator
        if (item.isChannel) _buildChannelIndicator(theme),
        // Pinned indicator
        if (item.isPinned) _buildPinnedIndicator(theme),
      ],
    );
  }

  Widget _buildAvatarImage(ThemeData theme, UnifiedChatItem item) {
    if (item.avatarUrl?.isNotEmpty == true) {
      return CachedNetworkImage(
        imageUrl: item.avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(theme, item),
        errorWidget: (context, url, error) => _buildDefaultAvatar(theme, item),
      );
    }
    return _buildDefaultAvatar(theme, item);
  }

  Widget _buildDefaultAvatar(ThemeData theme, UnifiedChatItem item) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: item.isChannel
              ? theme.primaryColor.withOpacity(0.1)
              : theme.colorScheme.secondary.withOpacity(0.1),
          child: Icon(
            item.isChannel ? Icons.campaign_rounded : Icons.person_rounded,
            color: item.isChannel
                ? theme.primaryColor
                : theme.colorScheme.secondary,
            size: 28,
          ),
        );
      },
    );
  }

  Widget _buildOnlineIndicator(ThemeData theme) {
    return Positioned(
      right: 2,
      bottom: 2,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.scaffoldBackgroundColor,
            width: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildChannelIndicator(ThemeData theme) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.scaffoldBackgroundColor,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.campaign_rounded,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPinnedIndicator(ThemeData theme) {
    return Positioned(
      left: 2,
      top: 2,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.scaffoldBackgroundColor,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.push_pin_rounded,
          size: 10,
          color: Colors.white,
        ),
      ),
    );
  }

  // محتوای یکپارچه
  Widget _buildContent(ThemeData theme, UnifiedChatItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(theme, item),
        const SizedBox(height: 4),
        _buildSubtitle(theme, item),
      ],
    );
  }

  Widget _buildTitle(ThemeData theme, UnifiedChatItem item) {
    return Row(
      children: [
        if (item.isMuted) ...[
          Icon(
            Icons.volume_off_rounded,
            size: 16,
            color: theme.hintColor,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            item.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  item.unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
              color: theme.textTheme.titleMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(ThemeData theme, UnifiedChatItem item) {
    if (item.subtitle?.isEmpty ?? true) {
      if (item.isChannel) {
        return Text(
          'کانال',
          style: TextStyle(
            fontSize: 14,
            color: theme.primaryColor.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Text(
      item.subtitle!,
      style: TextStyle(
        fontSize: 14,
        color: item.unreadCount > 0
            ? theme.textTheme.bodyMedium?.color
            : theme.hintColor,
        fontWeight: item.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing(ThemeData theme, UnifiedChatItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.lastActivity != null)
          Text(
            _formatTime(item.lastActivity!),
            style: TextStyle(
              fontSize: 12,
              color:
                  item.unreadCount > 0 ? theme.primaryColor : theme.hintColor,
              fontWeight:
                  item.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        const SizedBox(height: 4),
        if (item.unreadCount > 0)
          _buildUnreadBadge(theme, item.unreadCount)
        else if (item.isChannel && item.memberCount != null)
          Text(
            '${_formatNumber(item.memberCount!)} عضو',
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildUnreadBadge(ThemeData theme, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Divider
  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 82,
      endIndent: 16,
      color: theme.dividerColor.withOpacity(0.3),
    );
  }

  // Loading State
  Widget _buildLoadingState(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (context, index) => _buildDivider(theme),
      itemBuilder: (context, index) => _buildShimmerItem(theme),
    );
  }

  Widget _buildShimmerItem(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.hintColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: theme.hintColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.primaryColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'با دکمه + پیام جدید شروع کنید'
                  : 'عبارت دیگری را امتحان کنید',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Error State
  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'خطا در بارگذاری',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  bool _matchesSearchQuery(UnifiedChatItem item) {
    final query = _searchQuery.toLowerCase();
    final title = item.title.toLowerCase();
    final subtitle = item.subtitle?.toLowerCase() ?? '';

    return title.contains(query) || subtitle.contains(query);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 6) {
      return '${time.day}/${time.month}';
    }

    if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'دیروز' : '${difference.inDays} روز پیش';
    }

    if (difference.inHours > 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    }

    return 'اکنون';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // Action Methods
  void _toggleSearch() {
    if (_isSearchVisible) {
      _searchAnimController.reverse();
    } else {
      _searchAnimController.forward();
    }
    setState(() => _isSearchVisible = !_isSearchVisible);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _refreshData() async {
    await Future.wait([
      ref.refresh(conversationsProvider.future),
      ref.refresh(channelsProvider.future),
    ]);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'archived':
        _openArchivedChats();
        break;
      case 'new_channel':
        _createNewChannel();
        break;
      case 'settings':
        _openChatSettings();
        break;
    }
  }

  // Navigation Methods
  void _navigateToItem(UnifiedChatItem item) {
    if (item.isChannel) {
      _navigateToChannel(item.source as ChannelModel);
    } else {
      _navigateToChat(item.source as ConversationModel);
    }
  }

  void _navigateToChat(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserName: conversation.otherUserName ?? '',
          otherUserAvatar: conversation.otherUserAvatar ?? defaultAvatarUrl,
          conversationId: conversation.id,
          otherUserId: conversation.otherUserId ?? '',
        ),
      ),
    );
  }

  void _navigateToChannel(ChannelModel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChannelScreen(channel: channel),
      ),
    );
  }

  // Option Sheets
  void _showItemOptions(UnifiedChatItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildItemOptionsSheet(item),
    );
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNewChatOptionsSheet(),
    );
  }

  Widget _buildItemOptionsSheet(UnifiedChatItem item) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(theme),
            const SizedBox(height: 20),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            if (!item.isChannel) ...[
              _buildOptionTile(
                theme,
                icon: item.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                title: item.isPinned ? 'حذف از سنجاق شده‌ها' : 'سنجاق کردن',
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(item);
                },
              ),
              _buildOptionTile(
                theme,
                icon: item.isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                title:
                    item.isMuted ? 'فعال کردن اعلان‌ها' : 'خاموش کردن اعلان‌ها',
                onTap: () {
                  Navigator.pop(context);
                  _toggleMute(item);
                },
              ),
              _buildOptionTile(
                theme,
                icon: Icons.archive_outlined,
                title: 'بایگانی کردن',
                onTap: () {
                  Navigator.pop(context);
                  _archiveItem(item);
                },
              ),
              _buildOptionTile(
                theme,
                icon: Icons.delete_outline_rounded,
                title: 'حذف گفتگو',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item);
                },
              ),
            ] else ...[
              _buildOptionTile(
                theme,
                icon: Icons.info_outline_rounded,
                title: 'اطلاعات کانال',
                onTap: () {
                  Navigator.pop(context);
                  _showChannelInfo(item);
                },
              ),
              _buildOptionTile(
                theme,
                icon: Icons.volume_off_rounded,
                title: 'خاموش کردن اعلان‌ها',
                onTap: () {
                  Navigator.pop(context);
                  _muteChannel(item);
                },
              ),
              _buildOptionTile(
                theme,
                icon: Icons.exit_to_app_rounded,
                title: 'ترک کانال',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _leaveChannel(item);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNewChatOptionsSheet() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHandle(theme),
            const SizedBox(height: 20),
            Text(
              'شروع جدید',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              theme,
              icon: Icons.person_add_rounded,
              title: 'چت خصوصی',
              subtitle: 'شروع گفتگو با کاربر',
              onTap: () {
                Navigator.pop(context);
                _startNewPrivateChat();
              },
            ),
            _buildOptionTile(
              theme,
              icon: Icons.group_add_rounded,
              title: 'گروه جدید',
              subtitle: 'ایجاد گروه چند نفره',
              onTap: () {
                Navigator.pop(context);
                _createNewGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHandle(ThemeData theme) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.hintColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildOptionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? theme.colorScheme.error.withOpacity(0.1)
                : theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? theme.colorScheme.error : theme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? theme.colorScheme.error
                : theme.textTheme.titleMedium?.color,
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
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Placeholder Action Methods
  void _togglePin(UnifiedChatItem item) {
    // TODO: Implement pin/unpin logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.isPinned ? 'حذف سنجاق' : 'سنجاق'} شد')),
    );
  }

  void _toggleMute(UnifiedChatItem item) {
    // TODO: Implement mute/unmute logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('اعلان‌ها ${item.isMuted ? 'فعال' : 'خاموش'} شد')),
    );
  }

  void _archiveItem(UnifiedChatItem item) {
    // TODO: Implement archive logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بایگانی شد')),
    );
  }

  void _deleteItem(UnifiedChatItem item) {
    // TODO: Implement delete logic with confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('حذف شد')),
    );
  }

  void _showChannelInfo(UnifiedChatItem item) {
    // TODO: Implement channel info screen
  }

  void _muteChannel(UnifiedChatItem item) {
    // TODO: Implement channel mute logic
  }

  void _leaveChannel(UnifiedChatItem item) {
    // TODO: Implement leave channel logic with confirmation
  }

  void _startNewPrivateChat() {
    // TODO: Implement new private chat logic
  }

  void _createNewGroup() {
    // TODO: Implement new group creation logic
  }

  void _createNewChannel() {
    // TODO: Implement new channel creation logic
  }

  void _openArchivedChats() {
    // TODO: Implement archived chats screen
  }

  void _openChatSettings() {
    // TODO: Implement chat settings screen
  }
}
