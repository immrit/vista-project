import '../../../security/logging_utility.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';
import 'dart:async';

import '../../../model/channel_model.dart';
import '../../../model/conversation_model.dart';
import '../../../provider/channel_provider.dart';
import '../../../provider/chat_provider.dart';
import '../../util/const.dart';
import 'ArchivedConversationsScreen.dart';
// import 'ChatSettingsScreen.dart'; // اضافه کردن ایمپورت صفحه جدید
import '../../../services/ChatService.dart';
// ✅ استفاده از صفحه چت جدید
import '../../../features/chat/screens/modern_chat_screen.dart';
import '../../../DB/database_file_utils.dart';
import '../../../DB/unified_conversation_cache_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../services/conversation_prewarmer.dart';
// ✅ نشانگر وضعیت شبکه
import '../../../widgets/animated_network_indicator.dart';
import '/main.dart'; // برای دسترسی به supabase

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
  final bool isArchived; // اضافه کردن فیلد isArchived
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
    this.isArchived = false, // مقدار پیش‌فرض
    this.source,
    this.memberCount,
  });

  factory UnifiedChatItem.fromConversation(ConversationModel conversation) {
    // Keep original username - let the UI decide what to show
    String displayName = conversation.otherUserName ?? '';

    // نمایش آخرین پیام - اولویت با formattedLastMessage
    String? subtitle =
        conversation.formattedLastMessage ?? conversation.lastMessage;
    if (subtitle == null || subtitle.isEmpty) {
      subtitle = 'پیام جدیدی ارسال کنید';
    }

    // لاگ برای بررسی آخرین پیام و unreadCount (فقط در debug mode)
    // print('📱 Conversation ${conversation.id}: lastMessage="${conversation.lastMessage}", formattedLastMessage="${conversation.formattedLastMessage}", subtitle="$subtitle", unreadCount=${conversation.unreadCount}');

    return UnifiedChatItem(
      id: conversation.id,
      title: displayName,
      subtitle: subtitle,
      avatarUrl: conversation.otherUserAvatar,
      lastActivity: conversation.lastMessageTime,
      unreadCount: conversation.unreadCount, // فعال کردن قابلیت خوانده نشده
      isChannel: false,
      isPinned: conversation.isPinned,
      isMuted: conversation.isMuted,
      isArchived: conversation.isArchived, // خواندن isArchived
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
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    _initializeOptimizedMessaging();

    // شروع prefetch سریع برای بهبود سرعت بارگیری اولیه
    _startInitialPrefetch();

    // به تعویق انداختن بارگذاری پروفایل ها برای جلوگیری از فریز UI
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _preloadUserProfiles();
      }
    });
  }

  /// Load missing profiles in background for better UX
  Future<void> _loadMissingProfilesInBackground(
      List<ConversationModel> conversations) async {
    try {
      // جمع‌آوری تمام otherUserId ها که نیاز به لود دارند
      final userIdsToLoad = <String>[];
      for (final conversation in conversations) {
        if (conversation.otherUserId != null &&
            (conversation.otherUserName == null ||
                conversation.otherUserName!.isEmpty ||
                conversation.otherUserName == 'کاربر' ||
                conversation.otherUserName == 'کاربر ناشناس')) {
          userIdsToLoad.add(conversation.otherUserId!);
        }
      }

      if (userIdsToLoad.isNotEmpty) {
        print(
            '🔄 Background loading profiles for ${userIdsToLoad.length} users');

        // محدود کردن تعداد کاربران همزمان برای جلوگیری از فریز
        final maxConcurrentUsers = 5; // کمتر برای background loading
        final limitedUserIds = userIdsToLoad.length > maxConcurrentUsers
            ? userIdsToLoad.take(maxConcurrentUsers).toList()
            : userIdsToLoad;

        // استفاده از UserProfileService برای preload کردن
        final userProfileService = UserProfileService();
        await userProfileService.preloadProfiles(limitedUserIds);

        print(
            '✅ Background loaded profiles for ${limitedUserIds.length} users');

        // بروزرسانی UI
        if (mounted) {
          ref.read(cachedConversationsProvider.notifier).refresh();
          ref.invalidate(conversationsWithProfilesProvider);
          ref.invalidate(enrichedConversationsStreamProvider);
        }
      }
    } catch (e) {
      logInfo('⚠️ Error in background profile loading: $e');
    }
  }

  /// Preload user profiles to ensure usernames are available
  Future<void> _preloadUserProfiles() async {
    try {
      // ابتدا کش را بررسی کنیم
      final conversationCache = UnifiedConversationCacheService();
      final cachedConversations =
          await conversationCache.getCachedConversations(
        supabase.auth.currentUser?.id ?? '',
      );

      if (cachedConversations.isNotEmpty) {
        print(
            '🔄 Preloading profiles for ${cachedConversations.length} cached conversations');

        // جمع‌آوری تمام otherUserId ها که نیاز به لود دارند
        final userIdsToLoad = <String>[];
        for (final conversation in cachedConversations) {
          if (conversation.otherUserId != null &&
              (conversation.otherUserName == null ||
                  conversation.otherUserName!.isEmpty ||
                  conversation.otherUserName == 'کاربر' ||
                  conversation.otherUserName == 'کاربر ناشناس')) {
            userIdsToLoad.add(conversation.otherUserId!);
          }
        }

        if (userIdsToLoad.isNotEmpty) {
          print(
              '📱 Loading profiles for ${userIdsToLoad.length} users: $userIdsToLoad');

          // محدود کردن تعداد کاربران همزمان برای جلوگیری از فریز
          final maxConcurrentUsers = 10; // حداکثر ۱۰ کاربر همزمان
          final limitedUserIds = userIdsToLoad.length > maxConcurrentUsers
              ? userIdsToLoad.take(maxConcurrentUsers).toList()
              : userIdsToLoad;

          print(
              '📱 Limited to ${limitedUserIds.length} concurrent users for performance');

          // استفاده از UserProfileService برای preload کردن
          final userProfileService = UserProfileService();
          await userProfileService.preloadProfiles(limitedUserIds);

          logInfo('✅ Preloaded profiles for ${userIdsToLoad.length} users');

          // بروزرسانی UI
          if (mounted) {
            ref.read(cachedConversationsProvider.notifier).refresh();
            ref.invalidate(conversationsWithProfilesProvider);
            ref.invalidate(enrichedConversationsStreamProvider);
          }
        } else {
          logInfo('✅ All conversations already have usernames');
        }
      } else {
        // اگر کش موجود نیست، از provider استفاده کنیم
        final conversations = await ref.read(conversationsProvider.future);

        for (final conversation in conversations) {
          if (conversation.otherUserId != null &&
              (conversation.otherUserName == null ||
                  conversation.otherUserName!.isEmpty ||
                  conversation.otherUserName == 'کاربر' ||
                  conversation.otherUserName == 'کاربر ناشناس')) {
            // Load profile for this user
            try {
              final profileService = ref.read(profileServiceProvider);
              final profile =
                  await profileService.getProfile(conversation.otherUserId!);
              print(
                  '✅ Preloaded profile for ${conversation.otherUserId}: ${profile?.displayName ?? 'null'}');

              // اگر پروفایل لود شد، UI رو refresh کن
              if (profile != null && mounted) {
                // بروزرسانی cached conversations provider
                ref.read(cachedConversationsProvider.notifier).refresh();

                // بروزرسانی providerهای دیگر
                ref.invalidate(conversationsWithProfilesProvider);
                ref.invalidate(enrichedConversationsStreamProvider);
              }
            } catch (e) {
              print(
                  '⚠️ Error preloading profile for ${conversation.otherUserId}: $e');
            }
          }
        }
      }
    } catch (e) {
      logInfo('⚠️ Error preloading user profiles: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimController.dispose();
    super.dispose();
  }

  /// Initialize optimized messaging system
  Future<void> _initializeOptimizedMessaging() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.initializeOptimizedMessaging();
      logInfo('✅ Optimized messaging initialized for conversations screen');
    } catch (e) {
      logInfo('⚠️ Error initializing optimized messaging: $e');
    }
  }

  /// Start initial prefetch for faster loading
  Future<void> _startInitialPrefetch() async {
    try {
      // شروع prefetch در پس‌زمینه برای بهبود سرعت بارگیری اولیه
      Future.microtask(() async {
        try {
          final chatService = ref.read(chatServiceProvider);

          // prefetch مکالمات در پس‌زمینه
          final conversationsFuture = chatService.getConversations();

          // منتظر نتایج prefetch بمانیم اما UI را مسدود نکنیم
          final conversations = await conversationsFuture;

          if (conversations.isNotEmpty && mounted) {
            print(
                '✅ Initial prefetch completed: ${conversations.length} conversations');

            // اگر مکالمات prefetch شده‌اند، کش را بروزرسانی کنیم
            final conversationCache = UnifiedConversationCacheService();
            for (final conversation in conversations) {
              await conversationCache.cacheConversation(
                  conversation, supabase.auth.currentUser?.id ?? '');
            }

            // رفرش providerها
            ref.invalidate(cachedConversationsProvider);
            ref.invalidate(enrichedConversationsStreamProvider);
          }
        } catch (e) {
          logInfo('⚠️ Error in initial prefetch: $e');
        }
      });
    } catch (e) {
      logInfo('⚠️ Error starting initial prefetch: $e');
    }
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
    final conversationsAsync = ref.watch(enrichedConversationsStreamProvider);
    final isLoading = conversationsAsync.isLoading;

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

  // چک کردن آیا مکالمات نیاز به لود پروفایل دارند
  bool _needsProfileLoading(List<ConversationModel> conversations) {
    final userProfileService = UserProfileService();

    for (final conversation in conversations) {
      final username = conversation.otherUserName ?? '';
      final otherUserId = conversation.otherUserId;

      // اگر نام کاربری خالی است و otherUserId موجود است
      if ((username.isEmpty ||
              username == 'کاربر' ||
              username == 'کاربر ناشناس') &&
          otherUserId != null &&
          otherUserId.isNotEmpty) {
        // چک کن آیا پروفایل در کش موجود است یا نه
        final cachedProfile = userProfileService.getCachedProfile(otherUserId);
        if (cachedProfile == null) {
          // اگر پروفایل در کش نیست، نیاز به لود دارد
          return true;
        }
      }
    }
    return false;
  }

  // نمایش لیست مکالمات کش شده
  Widget _buildConversationsList(
      ThemeData theme, List<ConversationModel> conversations) {
    // استفاده از یک instance واحد برای بهینه‌سازی عملکرد
    final userProfileService = UserProfileService();

    // Enrich conversations with user profiles if needed
    final enrichedConversations = conversations.map((conversation) {
      // اگر نام کاربری خالی است، از کش پروفایل استفاده کن
      if ((conversation.otherUserName == null ||
              conversation.otherUserName!.isEmpty ||
              conversation.otherUserName == 'کاربر' ||
              conversation.otherUserName == 'کاربر ناشناس') &&
          conversation.otherUserId != null) {
        // سعی کن از کش پروفایل استفاده کن
        final cachedProfile =
            userProfileService.getCachedProfile(conversation.otherUserId!);

        if (cachedProfile != null) {
          return conversation.copyWith(
            otherUserName: cachedProfile['username'] ??
                cachedProfile['full_name'] ??
                'VISTA USER',
            otherUserAvatar: cachedProfile['avatar_url'],
          );
        }
      }
      return conversation;
    }).toList();

    final unifiedItems = enrichedConversations
        .map((conversation) => UnifiedChatItem.fromConversation(conversation))
        .toList();

    if (unifiedItems.isEmpty) {
      return _buildEmptyState(
        theme,
        'هیچ گفتگویی وجود ندارد',
        Icons.chat_bubble_outline_rounded,
      );
    }

    // محدود کردن تعداد آیتم‌ها برای جلوگیری از فریز در لیست‌های بزرگ
    final maxDisplayItems = 50;
    final displayItems = unifiedItems.length > maxDisplayItems
        ? unifiedItems.take(maxDisplayItems).toList()
        : unifiedItems;

    final hasMoreItems = unifiedItems.length > maxDisplayItems;

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null && enrichedConversations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ConversationPrewarmer().prewarmRecentConversations(
          enrichedConversations,
          currentUserId,
        );
      });
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: displayItems.length + (hasMoreItems ? 1 : 0),
      separatorBuilder: (context, index) => _buildDivider(theme),
      itemBuilder: (context, index) {
        if (hasMoreItems && index == displayItems.length) {
          // نمایش indicator برای موارد بیشتر
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '${unifiedItems.length - maxDisplayItems} گفتگوی دیگر...',
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        final item = displayItems[index];
        return _buildUnifiedItem(theme, item);
      },
    );
  }

  // لیست یکپارچه چت‌ها و کانال‌ها
  Widget _buildUnifiedList(ThemeData theme) {
    // همواره به استریم کش گوش بده تا تغییرات real-time اعمال شود
    final cachedStreamAsync = ref.watch(cachedConversationsStreamProvider);
    final cachedConversations = ref.watch(cachedConversationsProvider);

    // اگر استریم داده دارد، همان را نمایش بده (اولویت با استریم برای realtime)
    final streamData = cachedStreamAsync.maybeWhen(
        data: (value) => value, orElse: () => <ConversationModel>[]);

    if (streamData.isNotEmpty) {
      return _buildConversationsList(theme, streamData);
    }

    // در غیر اینصورت اگر کش موجود است، آن را بررسی کنیم
    if (cachedConversations.isNotEmpty) {
      print(
          '📱 UI: Displaying cached conversations: ${cachedConversations.length} items');

      // چک کنیم آیا نام کاربری‌ها نیاز به لود شدن دارند یا نه
      final needsProfileLoading = _needsProfileLoading(cachedConversations);

      if (needsProfileLoading) {
        print(
            '🔄 UI: Profiles need loading, but showing list immediately for better UX');

        // نمایش لیست با اطلاعات موجود و بارگذاری پروفایل ها در background
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadMissingProfilesInBackground(cachedConversations);
        });

        return _buildConversationsList(theme, cachedConversations);
      } else {
        // اگر پروفایل‌ها آماده هستند، لیست رو نمایش بده
        return _buildConversationsList(theme, cachedConversations);
      }
    }

    // اگر کش خالی است، از stream provider استفاده کنیم
    logInfo('🌐 No cached conversations, using stream provider');
    final conversationsAsync = ref.watch(enrichedConversationsStreamProvider);
    final channelsAsync = ref.watch(channelsProvider);

    return conversationsAsync.when(
      loading: () {
        // اگر در حالت loading هستیم، loading state نشان بده
        logInfo('⏳ UI: Provider is loading, showing loading state');
        return _buildLoadingState(theme);
      },
      error: (error, stack) {
        logInfo('❌ UI: Provider error: $error');
        return _buildErrorState(theme, error.toString());
      },
      data: (enrichedConversations) {
        print(
            '📱 UI: Provider data received: ${enrichedConversations.length} conversations');

        // اگر هیچ مکالمه‌ای وجود ندارد، empty state نشان بده
        if (enrichedConversations.isEmpty) {
          logInfo('📱 UI: No conversations found, showing empty state');
          return _buildEmptyState(
            theme,
            'هیچ گفتگویی وجود ندارد',
            Icons.chat_bubble_outline_rounded,
          );
        }

        // محدود کردن تعداد مکالمات برای جلوگیری از فریز
        final limitedConversations = enrichedConversations.length > 50
            ? enrichedConversations.take(50).toList()
            : enrichedConversations;

        return channelsAsync.when(
          loading: () => _buildLoadingState(theme),
          error: (error, stack) => _buildErrorState(theme, error.toString()),
          data: (channels) {
            return _buildConversationsList(theme, limitedConversations);
          },
        );
      },
    );
  }

  Future<void> _deleteItem(ConversationModel item) async {
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    try {
      // به جای فراخوانی مستقیم سرویس، از MessageNotifier استفاده می‌کنیم
      await messageNotifier.deleteConversation(item.id);
      // Invalidation ها در MessageNotifier.deleteConversation انجام می‌شود
      // providerهای جدید به طور خودکار با تغییرات کش به‌روز می‌شوند
      ref.invalidate(conversationsWithProfilesProvider);
      ref.invalidate(enrichedConversationsStreamProvider);
      // حتی میتونی بفرستی به صفحه اصلی یا SnackBar نشون بدی
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("گفتگو با موفقیت حذف شد!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطا در حذف گفتگو: $e")),
      );
    }
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
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
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
        placeholder: (context, url) => _buildAvatarShimmer(theme),
        errorWidget: (context, url, error) => _buildDefaultAvatar(theme, item),
      );
    }
    return _buildDefaultAvatar(theme, item);
  }

  /// Build shimmer for loading avatar
  Widget _buildAvatarShimmer(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1000),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme, UnifiedChatItem item) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: item.isChannel
              ? theme.primaryColor.withValues(alpha: 0.1)
              : theme.colorScheme.secondary.withValues(alpha: 0.1),
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
    // اگر نام کاربری خالی یا پیش‌فرضه، VISTA USER نمایش بده
    final displayName = (item.title.isEmpty ||
            item.title == 'کاربر' ||
            item.title == 'کاربر ناشناس')
        ? 'VISTA USER'
        : item.title;

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
            displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
    // Check for the placeholder for cleared history
    if (item.subtitle == ChatService.clearedHistoryPlaceholder) {
      return Text(
        'تاریخچه گفتگو حذف شده است',
        style: TextStyle(
          fontSize: 14,
          color: theme.hintColor,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (item.isChannel) {
      // For channels, show description/title
      final text = (item.subtitle == null || item.subtitle!.isEmpty)
          ? 'کانال'
          : item.subtitle!;
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: theme.hintColor,
          fontWeight: FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (item.subtitle?.isEmpty ?? true) {
      if (item.isChannel) {
        return Text(
          'کانال',
          style: TextStyle(
            fontSize: 14,
            color: theme.primaryColor.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Show last message subtitle
    final subtitleText = item.subtitle!;
    return Text(
      subtitleText,
      style: TextStyle(
        fontSize: 14,
        color: theme.hintColor,
        fontWeight: FontWeight.normal,
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
              color: theme.hintColor,
              fontWeight: FontWeight.normal,
            ),
          ),
        const SizedBox(height: 4),
        if (item.isChannel && item.memberCount != null)
          Text(
            '${_formatNumber(item.memberCount!)} عضو',
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        // Badge برای نمایش تعداد پیام‌های خوانده‌نشده (فقط برای مکالمات)
        if (!item.isChannel && item.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.unreadCount > 9 ? Colors.red : Colors.blue,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (item.unreadCount > 9 ? Colors.red : Colors.blue)
                      .withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
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

  // Helper Methods

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

  Future<void> _resetCacheAndRefresh() async {
    // پاک‌سازی کش مکالمات و پیام‌ها
    await deleteConversationCacheDbFile();
    await deleteMessageCacheDbFile();
    // رفرش providerها
    ref.invalidate(conversationsProvider);
    ref.invalidate(cachedConversationsStreamProvider);
    ref.invalidate(channelsProvider);
    // نمایش پیام موفقیت
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  void _navigateToItem(UnifiedChatItem item) {
    if (item.isChannel) {
      // Navigate to Channel Screen
    } else {
      // ✅ Navigate to NEW Modern Chat Screen
      if (item.source is ConversationModel) {
        final conversation = item.source as ConversationModel;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernChatScreen(
              args: ChatScreenArgs(
                conversationId: item.id,
                otherUserName: conversation.otherUserName ?? 'VISTA USER',
                otherUserAvatar: conversation.otherUserAvatar,
                otherUserId: conversation.otherUserId ?? '',
              ),
            ),
          ),
        );
      }
    }
  }

  // Option Sheets
  void _showItemOptions(UnifiedChatItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildItemOptionsSheet(item),
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
                  if (!item.isChannel && item.source is ConversationModel) {
                    _deleteItem(item.source as ConversationModel);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "این عملیات برای این نوع آیتم پشتیبانی نمی‌شود")),
                    );
                  }
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

  // Placeholder Action Methods
  void _togglePin(UnifiedChatItem item) {
    ref.read(messageNotifierProvider.notifier).togglePinConversation(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('مکالمه ${item.isPinned ? 'از سنجاق حذف' : 'سنجاق'} شد')),
    );
  }

  void _toggleMute(UnifiedChatItem item) {
    ref.read(messageNotifierProvider.notifier).toggleMuteConversation(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'اعلان‌ها برای این گفتگو ${item.isMuted ? 'فعال' : 'خاموش'} شد')),
    );
  }

  void _archiveItem(UnifiedChatItem item) {
    if (!item.isChannel && item.source is ConversationModel) {
      ref
          .read(messageNotifierProvider.notifier) // خواندن وضعیت قبل از تغییر
          .toggleArchiveConversation(item.id)
          .then((_) {
        // این بخش پس از اتمام عملیات اجرا می‌شود
        // برای نمایش پیام صحیح، باید وضعیت جدید را از provider یا آیتم به‌روز شده بگیریم
        // فعلا یک پیام عمومی‌تر نمایش می‌دهیم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('درخواست بایگانی/خروج از بایگانی ارسال شد.')),
        );
      });
    }
  }

  void _showChannelInfo(UnifiedChatItem item) {}

  void _muteChannel(UnifiedChatItem item) {}

  void _leaveChannel(UnifiedChatItem item) {}

  void _createNewChannel() {}
}
