// import '../../../security/logging_utility.dart'; // ⛔️ حذف شد - دیگر استفاده نمی‌شود
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../model/conversation_model.dart';

// ✅ Provider بهینه‌شده جدید
import '../../../provider/optimized_conversations_provider.dart';
import '../../../features/chat/providers/chat_providers.dart';
import 'ArchivedConversationsScreen.dart';
// ✅ استفاده از صفحه چت جدید
import '../../../features/chat/screens/modern_chat_screen.dart';
import '../../../DB/database_file_utils.dart';
// ✅ ویجت Swipeable برای آیتم مکالمه
import 'package:Vista/widgets/swipeable_conversation_item.dart';
// ✅ نشانگر وضعیت شبکه
import '../../../widgets/animated_network_indicator.dart';

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
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // ⛔️ غیرفعال شده - چون از PushNotificationService جدید استفاده می‌کنیم
    // _initializeOptimizedMessaging();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimController.dispose();
    super.dispose();
  }

  /// Initialize optimized messaging system
  /// ⛔️ غیرفعال شده - چون از PushNotificationService جدید استفاده می‌کنیم
  // Future<void> _initializeOptimizedMessaging() async {
  //   try {
  //     final chatService = ref.read(chatServiceProvider);
  //     await chatService.initializeOptimizedMessaging();
  //     logInfo('✅ Optimized messaging initialized for conversations screen');
  //   } catch (e) {
  //     logInfo('⚠️ Error initializing optimized messaging: $e');
  //   }
  // }

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
    // ✅ استفاده از provider بهینه‌شده
    final isLoading = ref.watch(conversationsLoadingProvider);

    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      title: Row(
        children: [
          // ✅ عنوان با نمایش وضعیت شبکه (مثل تلگرام)
          NetworkAwareTitle(
            title: 'پیام‌ها',
            titleStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ) ??
                TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.titleLarge?.color,
                ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.primaryColor,
                ),
              ),
            ),
          ],
        ],
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
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
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
            onChanged: (query) {
              setState(() => _searchQuery = query);
            },
          ),
        ),
      ),
    );
  }

  // ✅ لیست بهینه‌شده مکالمات با provider جدید
  Widget _buildUnifiedList(ThemeData theme) {
    // استفاده از provider بهینه‌شده
    final state = ref.watch(optimizedConversationsProvider);

    // بر اساس وضعیت، UI مناسب نمایش بده
    switch (state.status) {
      case ConversationsStatus.initial:
      case ConversationsStatus.loading:
        if (state.conversations.isEmpty) {
          return _buildLoadingState(theme);
        }
        // اگر در حال لود هستیم ولی داده داریم، داده رو نمایش بده
        return _buildOptimizedConversationsList(theme, state.conversations);

      case ConversationsStatus.error:
        if (state.conversations.isNotEmpty) {
          // اگر خطا داریم ولی داده قبلی موجوده، همون رو نمایش بده
          return _buildOptimizedConversationsList(theme, state.conversations);
        }
        return _buildErrorState(theme, state.errorMessage ?? 'خطای نامشخص');

      case ConversationsStatus.loaded:
        if (state.conversations.isEmpty) {
          return _buildEmptyState(
            theme,
            'هیچ گفتگویی وجود ندارد',
            Icons.chat_bubble_outline_rounded,
          );
        }
        return _buildOptimizedConversationsList(theme, state.conversations);
    }
  }

  // ✅ لیست بهینه با Swipe Actions و گروه‌بندی Pinned
  Widget _buildOptimizedConversationsList(
      ThemeData theme, List<ConversationModel> conversations) {
    // فیلتر جستجو
    final filteredConversations = _searchQuery.isEmpty
        ? conversations
        : conversations.where((c) {
            final name = c.otherUserName?.toLowerCase() ?? '';
            final message = c.lastMessage?.toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || message.contains(query);
          }).toList();

    if (filteredConversations.isEmpty) {
      return _buildEmptyState(
        theme,
        _searchQuery.isEmpty ? 'هیچ گفتگویی وجود ندارد' : 'نتیجه‌ای یافت نشد',
        Icons.chat_bubble_outline_rounded,
      );
    }

    // ✅ جداسازی مکالمات پین شده و عادی
    final pinnedConversations =
        filteredConversations.where((c) => c.isPinned).toList();
    final regularConversations =
        filteredConversations.where((c) => !c.isPinned).toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(optimizedConversationsProvider.notifier).refresh(),
      child: CustomScrollView(
        cacheExtent: 500,
        slivers: [
          // ✅ بخش مکالمات پین شده
          if (pinnedConversations.isNotEmpty) ...[
            SliverToBoxAdapter(
              child:
                  _buildSectionHeader(theme, 'پین شده', Icons.push_pin_rounded),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conversation = pinnedConversations[index];
                  return _buildSwipeableItem(
                      theme, conversation, index, pinnedConversations.length,
                      isPinnedSection: true);
                },
                childCount: pinnedConversations.length,
              ),
            ),
          ],

          // ✅ بخش مکالمات عادی
          if (regularConversations.isNotEmpty) ...[
            if (pinnedConversations.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                    theme, 'همه گفتگوها', Icons.chat_rounded),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conversation = regularConversations[index];
                  return _buildSwipeableItem(
                      theme, conversation, index, regularConversations.length,
                      isPinnedSection: false);
                },
                childCount: regularConversations.length,
              ),
            ),
          ],

          // ✅ فضای خالی در انتها
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  // ✅ هدر بخش‌ها
  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ آیتم Swipeable
  Widget _buildSwipeableItem(
    ThemeData theme,
    ConversationModel conversation,
    int index,
    int totalCount, {
    required bool isPinnedSection,
  }) {
    return Column(
      children: [
        SwipeableConversationItem(
          key: ValueKey(conversation.id),
          conversation: conversation,
          onTap: () => _navigateToConversation(conversation),
          onLongPress: () => _showConversationOptions(conversation),
          onPin: () => _togglePinConversation(conversation),
          onArchive: () => _archiveConversation(conversation),
          onDelete: () => _showDeleteConfirmation(conversation),
          onMute: () => _toggleMuteConversation(conversation),
        ),
        // Divider
        if (index < totalCount - 1)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 82,
            endIndent: 16,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  // ✅ دیالوگ تایید حذف
  void _showDeleteConfirmation(ConversationModel conversation) {
    final theme = Theme.of(context);
    final displayName = conversation.otherUserName ?? 'VISTA USER';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('حذف گفتگو'),
          ],
        ),
        content: Text(
          'آیا از حذف گفتگو با "$displayName" مطمئن هستید؟\nاین عمل قابل بازگشت نیست.',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(color: theme.hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation(conversation);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // ✅ Navigation به مکالمه
  void _navigateToConversation(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: conversation.id,
            otherUserName: conversation.otherUserName ?? 'VISTA USER',
            otherUserAvatar: conversation.otherUserAvatar,
            otherUserId: conversation.otherUserId ?? '',
          ),
        ),
      ),
    );
  }

  // ✅ نمایش گزینه‌های مکالمه
  void _showConversationOptions(ConversationModel conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildConversationOptionsSheet(conversation),
    );
  }

  // ✅ حذف مکالمه
  Future<void> _deleteConversation(ConversationModel conversation) async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final result = await repo.deleteConversation(conversation.id);
      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("گفتگو با موفقیت حذف شد!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("خطا در حذف گفتگو: ${result.error}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطا در حذف گفتگو: $e")),
        );
      }
    }
  }

  // Divider
  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 82,
      endIndent: 16,
      color: theme.dividerColor.withValues(alpha: 0.3),
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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar shimmer
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username shimmer
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Last message shimmer
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            // Time shimmer
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
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
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.primaryColor.withValues(alpha: 0.7),
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
                color: theme.hintColor.withValues(alpha: 0.7),
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
    // شناسایی خطاهای دیتابیس و نمایش پیام راهنما
    final isDbMigrationError = message.contains('NOT NULL') ||
        message.contains('SqliteException') ||
        message.contains('migration') ||
        message.contains('ALTER TABLE');

    String customMessage = message;
    if (isDbMigrationError) {
      customMessage = 'مشکلی در بروزرسانی داده‌های برنامه پیش آمده است.\n'
          'برای رفع مشکل یکی از راه‌های زیر را امتحان کنید:\n\n'
          '۱. برنامه را یکبار کامل ببندید و دوباره باز کنید.\n'
          '۲. اگر مشکل حل نشد، از تنظیمات گوشی وارد بخش برنامه‌ها شوید و داده‌های برنامه (Clear Data) را پاک کنید.\n'
          '۳. یا برنامه را حذف و مجدداً نصب کنید.\n\n'
          'در صورت نیاز به راهنمایی بیشتر با پشتیبانی تماس بگیرید.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.8),
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
              customMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isDbMigrationError
                  ? _resetCacheAndRefresh
                  : () {
                      // Real-time system handles updates automatically
                      Navigator.pop(context);
                    },
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

  Future<void> _resetCacheAndRefresh() async {
    // پاک‌سازی کش مکالمات و پیام‌ها
    await deleteConversationCacheDbFile();
    await deleteMessageCacheDbFile();
    // رفرش provider بهینه‌شده
    ref.invalidate(optimizedConversationsProvider);
    // نمایش پیام موفقیت
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('کش برنامه پاک‌سازی شد. لطفاً دوباره تلاش کنید.')),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'archived':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ArchivedConversationsScreen(),
          ),
        );
        break;
      case 'new_channel':
        _createNewChannel();
        break;
    }
  }

  // ✅ Bottom sheet گزینه‌های مکالمه (ConversationModel-based)
  Widget _buildConversationOptionsSheet(ConversationModel conversation) {
    final theme = Theme.of(context);
    final displayName = conversation.otherUserName ?? 'VISTA USER';

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
              displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              theme,
              icon: conversation.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded,
              title:
                  conversation.isPinned ? 'حذف از سنجاق شده‌ها' : 'سنجاق کردن',
              onTap: () {
                Navigator.pop(context);
                _togglePinConversation(conversation);
              },
            ),
            _buildOptionTile(
              theme,
              icon: conversation.isMuted
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              title: conversation.isMuted
                  ? 'فعال کردن اعلان‌ها'
                  : 'خاموش کردن اعلان‌ها',
              onTap: () {
                Navigator.pop(context);
                _toggleMuteConversation(conversation);
              },
            ),
            _buildOptionTile(
              theme,
              icon: Icons.archive_outlined,
              title: 'بایگانی کردن',
              onTap: () {
                Navigator.pop(context);
                _archiveConversation(conversation);
              },
            ),
            _buildOptionTile(
              theme,
              icon: Icons.delete_outline_rounded,
              title: 'حذف گفتگو',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _deleteConversation(conversation);
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
          color: theme.dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? theme.colorScheme.error.withValues(alpha: 0.1)
                : theme.primaryColor.withValues(alpha: 0.1),
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

  // ✅ Action Methods (ConversationModel-based)
  void _togglePinConversation(ConversationModel conversation) async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.togglePinConversation(conversation.id);

    if (mounted && result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'مکالمه ${conversation.isPinned ? 'از سنجاق حذف' : 'سنجاق'} شد'),
        ),
      );
    }
  }

  void _toggleMuteConversation(ConversationModel conversation) async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.toggleMuteConversation(conversation.id);

    if (mounted && result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'اعلان‌ها برای این گفتگو ${conversation.isMuted ? 'فعال' : 'خاموش'} شد'),
        ),
      );
    }
  }

  void _archiveConversation(ConversationModel conversation) async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.toggleArchiveConversation(conversation.id);

    if (mounted) {
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('درخواست بایگانی/خروج از بایگانی انجام شد.')),
        );
      }
    }
  }

  void _createNewChannel() {}
}
