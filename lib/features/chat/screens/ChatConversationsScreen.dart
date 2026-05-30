// import '../../../security/logging_utility.dart'; // ⛔️ حذف شد - دیگر استفاده نمی‌شود
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../../../features/chat/screens/new_message_screen.dart';
import '../../../DB/database_file_utils.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../services/system_ui_bar_service.dart';
import '../../../features/chat/widgets/block_report_bottom_sheet.dart';
import '../../../features/chat/services/user_moderation_service.dart';
// ✅ ویجت Swipeable برای آیتم مکالمه
import 'package:Vista/widgets/swipeable_conversation_item.dart';
import 'package:Vista/core/theme/app_theme.dart';
// ✅ ویجت سینی یادداشت‌ها (شبیه اینستاگرام)
import '../../../features/chat/widgets/notes_tray.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';
import '../../../features/chat/utils/conversation_name_utils.dart';

class ChatConversationsScreen extends ConsumerStatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  ConsumerState<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState
    extends ConsumerState<ChatConversationsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final UserModerationService _moderationService = UserModerationService();
  final Set<String> _requestActionLoading = <String>{};
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSystemBars(Theme.of(context));
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
    super.build(context);
    final theme = Theme.of(context);
    _syncSystemBars(theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildComposeFab(theme),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchSection(theme),
          Expanded(child: _buildUnifiedList(theme)),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  // AppBar بهینه‌شده
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final appBarColor = _appBarColor(theme);
    final overlayStyle = _systemOverlayStyle(theme);
    return AppBar(
      backgroundColor: appBarColor,
      surfaceTintColor: appBarColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlayStyle,
      title: Text(
        AppLocalizations.of(context)?.messages ?? 'پیام‌ها',
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
        // ✅ نشانگر وضعیت اتصال (طبق درخواست کاربر)
        Consumer(
          builder: (context, ref, _) {
            final statusAsync = ref.watch(chatConnectionStatusProvider);
            return statusAsync.when(
              data: (status) {
                Color indicatorColor;
                switch (status) {
                  case ConnectionStatus.connected:
                    indicatorColor = Colors.green;
                    break;
                  case ConnectionStatus.connecting:
                    indicatorColor = Colors.orange;
                    break;
                  case ConnectionStatus.disconnected:
                    indicatorColor = Colors.red;
                    break;
                }
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(
                      left:
                          8), // Right side in LTR, Left in RTL (Persian)? Actions are usually at end.
                  // In RTL (Persian), actions are on the LEFT.
                  // EdgeInsets.only(left: 8) seems correct for spacing from the edge or next icon?
                  // Wait, actions are usually [Search, Menu, Gap].
                  // I should place it BEFORE Search or AFTER Menu?
                  // User "inside the AppBar actions".
                  // Let's put it as the first item in actions list so it is rightmost in RTL? No, leftmost in RTL?
                  // AppBar actions order: start to end. In RTL: Right to Left? No, AppBar actions are usually at the "End" of the bar.
                  // In RTL, "End" is Left.
                  // So items are [1, 2, 3] -> displayed [1] [2] [3] from Right to Left? Or Left to Right?
                  // Flutter AppBar actions: "A list of Widgets to display in a row after the [title] widget."
                  // Usually [Search, Menu].
                  // I'll add it to the list.
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: indicatorColor,
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle)),
            );
          },
        ),
        const SizedBox(width: 12),
        Consumer(
          builder: (context, ref, child) {
            final isLoading = ref.watch(conversationsLoadingProvider);
            if (isLoading) {
              return SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.primaryColor,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        _buildSearchToggle(theme),
        _buildMoreMenuButton(theme),
        const SizedBox(width: 8),
      ],
    );
  }

  Color _appBarColor(ThemeData theme) => theme.scaffoldBackgroundColor;

  SystemUiOverlayStyle _systemOverlayStyle(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    final appBarColor = _appBarColor(theme);
    return SystemUiOverlayStyle(
      statusBarColor: appBarColor,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
    );
  }

  void _syncSystemBars(ThemeData theme) {
    final overlayStyle = _systemOverlayStyle(theme);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    SystemUiBarService.sync(overlayStyle);
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
      tooltip: _isSearchVisible
          ? (AppLocalizations.of(context)?.closeSearch ?? 'بستن جستجو')
          : (AppLocalizations.of(context)?.search ?? 'جستجو'),
    );
  }

  Widget _buildComposeFab(ThemeData theme) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final minimumBottomPadding = bottomInset + 64;
    return SafeArea(
      minimum: EdgeInsets.only(bottom: minimumBottomPadding),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openNewMessageScreen,
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNewMessageScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewMessageScreen()),
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
          title:
              AppLocalizations.of(context)?.archivedChats ?? 'گفتگوهای بایگانی',
          theme: theme,
        ),
        _buildMenuItem(
          value: 'secret_chat',
          icon: Icons.lock_rounded,
          title: AppLocalizations.of(context)?.newSecretChat ??
              'گفتگوی محرمانه جدید',
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
              hintText:
                  AppLocalizations.of(context)?.searchInMessagesAndChannels ??
                      'جستجو در پیام‌ها و کانال‌ها...',
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

  // ✅ لیست مکالمات بر پایه Optimized Provider (منبع واحد برای badge + ترتیب)
  Widget _buildUnifiedList(ThemeData theme) {
    return Consumer(
      builder: (context, ref, child) {
        final conversationsState = ref.watch(optimizedConversationsProvider);
        final conversations = conversationsState.conversations;

        final isInitialLoading =
            (conversationsState.status == ConversationsStatus.loading ||
                    conversationsState.status == ConversationsStatus.initial) &&
                conversations.isEmpty;
        if (isInitialLoading) {
          return _buildLoadingState(theme);
        }

        if (conversationsState.status == ConversationsStatus.error &&
            conversations.isEmpty) {
          return _buildErrorState(
            theme,
            conversationsState.errorMessage ??
                (AppLocalizations.of(context)?.errorLoadingConversations ??
                    'خطا در بارگذاری گفتگوها'),
          );
        }

        if (conversations.isEmpty) {
          return _buildEmptyState(
            theme,
            AppLocalizations.of(context)?.noConversations ??
                'هیچ گفتگویی وجود ندارد',
            Icons.chat_bubble_outline_rounded,
          );
        }

        return _buildOptimizedConversationsList(theme, conversations, ref);
      },
    );
  }

  // ✅ لیست بهینه با Swipe Actions و گروه‌بندی Pinned
  Widget _buildOptimizedConversationsList(
      ThemeData theme, List<ConversationModel> conversations, WidgetRef ref) {
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
      return CustomScrollView(
        slivers: [
          if (_searchQuery.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: NotesTray(),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              theme,
              _searchQuery.isEmpty
                  ? (AppLocalizations.of(context)?.noConversations ??
                      'هیچ گفتگویی وجود ندارد')
                  : (AppLocalizations.of(context)?.noResultsFound ??
                      'نتیجه‌ای یافت نشد'),
              Icons.chat_bubble_outline_rounded,
            ),
          ),
        ],
      );
    }

    // ✅ جداسازی درخواست پیام، مکالمات پین شده و عادی
    final requestConversations = filteredConversations
        .where((c) => c.isMessageRequest && !c.isArchived)
        .toList();
    final nonRequestConversations =
        filteredConversations.where((c) => !c.isMessageRequest).toList();
    final pinnedConversations =
        nonRequestConversations.where((c) => c.isPinned).toList();
    final regularConversations =
        nonRequestConversations.where((c) => !c.isPinned).toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(optimizedConversationsProvider.notifier).refresh(),
      child: CustomScrollView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(500),
        slivers: [
          // ✅ بخش یادداشت‌ها (Notes) - فقط اگر در حالت جستجو نباشیم
          if (_searchQuery.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: NotesTray(),
              ),
            ),

          // ✅ بخش درخواست پیام (Instagram/X style)
          if (requestConversations.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                theme,
                AppLocalizations.of(context)?.messageRequests ?? 'درخواست پیام',
                Icons.mark_email_unread_outlined,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conversation = requestConversations[index];
                  return _buildSwipeableItem(
                    theme,
                    conversation,
                    index,
                    requestConversations.length,
                    isPinnedSection: false,
                  );
                },
                childCount: requestConversations.length,
              ),
            ),
          ],

          // ✅ بخش مکالمات پین شده
          if (pinnedConversations.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                theme,
                AppLocalizations.of(context)?.pinned ?? 'پین شده',
                Icons.push_pin_rounded,
              ),
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
                    theme,
                    AppLocalizations.of(context)?.allConversations ??
                        'همه گفتگوها',
                    Icons.chat_rounded),
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

          // ✅ فضای خالی در انتها (بالای باتم نویگیشن جزیره‌ای)
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).viewPadding.bottom + 110,
            ),
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
    final showRequestActions = conversation.isMessageRequest;
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
          onBlock: () => _handleConversationBlock(conversation),
        ),
        if (showRequestActions)
          _buildMessageRequestActions(theme, conversation),
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

  Widget _buildMessageRequestActions(
      ThemeData theme, ConversationModel conversation) {
    final isLoading = _requestActionLoading.contains(conversation.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading
                  ? null
                  : () => _respondToMessageRequest(conversation, false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('رد'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: isLoading
                  ? null
                  : () => _respondToMessageRequest(conversation, true),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('قبول'),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ دیالوگ تایید حذف
  void _showDeleteConfirmation(ConversationModel conversation) {
    final theme = Theme.of(context);
    final displayName = _conversationDisplayName(conversation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)?.deleteConversation ??
                'حذف گفتگو'),
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
              AppLocalizations.of(context)?.cancel ?? 'انصراف',
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
            child: Text(AppLocalizations.of(context)?.delete ?? 'حذف'),
          ),
        ],
      ),
    );
  }

  // ✅ Navigation به مکالمه
  Future<void> _navigateToConversation(ConversationModel conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: conversation.id,
            otherUserName: _conversationDisplayName(conversation),
            otherUserAvatar: conversation.otherUserAvatar,
            otherUserId: conversation.otherUserId ?? '',
            isGroup: conversation.isGroup,
            isSecret: conversation.isSecret,
          ),
        ),
      ),
    );
    // بازگشت از صفحه چت: استایل status bar رو با توجه به تم فعلی ریست می‌کنیم
    if (mounted) {
      _syncSystemBars(Theme.of(context));
    }
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
          UserFriendlyErrorUtils.showSuccessSnackBar(
            context,
            AppLocalizations.of(context)?.conversationDeleted ??
                'گفتگو با موفقیت حذف شد',
          );
        } else {
          UserFriendlyErrorUtils.showErrorSnackBar(
            context,
            result.error ??
                (AppLocalizations.of(context)?.conversationDeleteFailed ??
                    'حذف گفتگو انجام نشد'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _respondToMessageRequest(
      ConversationModel conversation, bool accept) async {
    final conversationId = conversation.id;
    if (_requestActionLoading.contains(conversationId)) return;

    setState(() {
      _requestActionLoading.add(conversationId);
    });

    try {
      final result =
          await ref.read(chatRepositoryProvider).respondToMessageRequest(
                conversationId,
                accept: accept,
              );
      if (!mounted) return;

      if (result.isSuccess) {
        await ref.read(optimizedConversationsProvider.notifier).refresh();
        if (!mounted) return;
        UserFriendlyErrorUtils.showSuccessSnackBar(
          context,
          accept ? 'درخواست پیام پذیرفته شد' : 'درخواست پیام رد شد',
        );
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          result.error ?? 'پاسخ به درخواست پیام انجام نشد',
        );
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestActionLoading.remove(conversationId);
        });
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
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
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
                  ? 'با دکمه مداد پیام جدید شروع کنید'
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

  void _handleMenuAction(String value) {
    switch (value) {
      case 'archived':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ArchivedConversationsScreen(),
          ),
        );
        break;
      case 'secret_chat':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NewMessageScreen(),
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
    final displayName = _conversationDisplayName(conversation);
    final canModerateUser = conversation.otherUserId?.isNotEmpty ?? false;

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
            if (canModerateUser)
              _buildOptionTile(
                theme,
                icon: Icons.block_rounded,
                title: 'مسدود/رفع مسدودیت',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _handleConversationBlock(conversation);
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

  Future<void> _handleConversationBlock(ConversationModel conversation) async {
    final userId = conversation.otherUserId;
    if (userId == null || userId.isEmpty) return;

    final displayName = _conversationDisplayName(conversation);
    try {
      final status =
          await _moderationService.getBlockStatus(userId, useCache: false);
      if (!mounted) return;

      final actionType =
          status.isBlocked ? ModerationType.unblock : ModerationType.block;
      final result = await BlockReportBottomSheet.show(
        context: context,
        userId: userId,
        userName: displayName,
        isCurrentlyBlocked: status.isBlocked,
        type: actionType,
      );

      if (result == true && mounted) {
        await ref.read(optimizedConversationsProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _createNewChannel() {}

  String _conversationDisplayName(ConversationModel conversation) {
    return resolveConversationDisplayName(conversation.otherUserName);
  }
}
