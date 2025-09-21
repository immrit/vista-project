import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';
import '../../../model/message_model.dart';
import '../../../provider/chat_provider.dart';
import '../../../provider/provider.dart';
import '../../../services/wallpaper_cache_service.dart';
import '../../../services/cache_manager.dart';
import 'optimized_message_widget.dart';
import 'ChatDetailsScreen.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// نسخه بهینه‌شده ChatScreen با performance بالا
class OptimizedChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;
  final bool isNewConversation;

  const OptimizedChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
    this.isNewConversation = false,
  });

  @override
  ConsumerState<OptimizedChatScreen> createState() =>
      _OptimizedChatScreenState();
}

class _OptimizedChatScreenState extends ConsumerState<OptimizedChatScreen>
    with TickerProviderStateMixin {
  // Controllers
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // State management
  final Set<String> _inlineImageGrants = <String>{};
  final Set<String> _inlineImageLoaded = <String>{};
  final Map<String, double> _inlineImageProgress = <String, double>{};
  final Map<String, bool> _messageReplyStates = {};

  // UI state
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _showScrollToBottom = false;

  // Performance optimizations
  late final String _cachedWallpaperUrl;
  late final Color _cachedOverlayColor;
  Timer? _debounceTimer;
  List<MessageModel>? _cachedFilteredMessages;

  @override
  void initState() {
    super.initState();

    // Pre-cache wallpaper URL and overlay color
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    _cachedWallpaperUrl = WallpaperCacheService.getWallpaperUrl(isDarkMode);
    _cachedOverlayColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.white.withOpacity(0.4);

    // Setup scroll listener with debouncing
    _itemPositionsListener.itemPositions.addListener(_handleScrollToBottomBtn);

    // Pre-warm wallpaper cache
    _preloadWallpaper();
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions
        .removeListener(_handleScrollToBottomBtn);
    _highlightTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// پیش‌بارگذاری والپیپر با کش بهینه
  Future<void> _preloadWallpaper() async {
    await WallpaperCacheService.preloadWallpapers();
  }

  /// مدیریت دکمه scroll to bottom با debouncing
  void _handleScrollToBottomBtn() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (_itemPositionsListener.itemPositions.value.isEmpty) return;

      final firstItemVisible = _itemPositionsListener.itemPositions.value
          .any((pos) => pos.index == 0 && pos.itemLeadingEdge >= 0);

      final shouldShow = !firstItemVisible;

      if (_showScrollToBottom != shouldShow) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    });
  }

  void _scrollToBottom() {
    _itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// فیلتر بهینه پیام‌ها با کش
  List<MessageModel> _getFilteredMessages(List<MessageModel> messages) {
    if (_cachedFilteredMessages != null &&
        _cachedFilteredMessages!.length == messages.length) {
      return _cachedFilteredMessages!;
    }

    final realLocalIds = messages
        .where((m) => !m.id.startsWith('temp_') && m.localId != null)
        .map((m) => m.localId)
        .toSet();

    _cachedFilteredMessages = messages.where((m) {
      if (m.id.startsWith('temp_') && realLocalIds.contains(m.id)) {
        return false;
      }
      return true;
    }).toList();

    return _cachedFilteredMessages!;
  }

  /// نمایش دیالوگ جزئیات چت
  void _navigateToChatDetails() async {
    final messageIdToJump = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailsScreen(
          conversationId: widget.conversationId,
          otherUserName: widget.otherUserName,
          otherUserAvatar: widget.otherUserAvatar,
          otherUserId: widget.otherUserId,
        ),
      ),
    );

    if (messageIdToJump != null && mounted) {
      _jumpToMessage(messageIdToJump);
    }
  }

  /// پرش به پیام مشخص
  void _jumpToMessage(String messageId) {
    final messages =
        ref.read(conversationMessagesProvider(widget.conversationId));
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && _itemScrollController.isAttached) {
      setState(() {
        _highlightedMessageId = messageId;
      });

      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  /// بناء app bar بهینه‌شده
  PreferredSizeWidget _buildOptimizedAppBar() {
    return AppBar(
      elevation: 1,
      titleSpacing: 0,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : Colors.white,
      iconTheme: IconThemeData(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
      ),
      title: InkWell(
        onTap: _navigateToChatDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              // Avatar با Hero animation
              Hero(
                tag: 'avatar_${widget.otherUserId}',
                child: Material(
                  type: MaterialType.transparency,
                  child: _buildUserAvatar(),
                ),
              ),
              const SizedBox(width: 12),
              // نام و وضعیت کاربر
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildUserStatusOptimized(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Show more options menu
          },
        ),
      ],
    );
  }

  /// Avatar کاربر
  Widget _buildUserAvatar() {
    return ClipOval(
      child: widget.otherUserAvatar != null &&
              widget.otherUserAvatar!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: widget.otherUserAvatar!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 40,
                height: 40,
                color: Colors.grey[300],
                child: const Icon(Icons.person, color: Colors.grey, size: 20),
              ),
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                color: Colors.grey[300],
                child: const Icon(Icons.person, color: Colors.grey, size: 20),
              ),
            )
          : Image.asset(
              'lib/view/util/images/default-avatar.jpg',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
    );
  }

  /// وضعیت آنلاین کاربر - بهینه‌شده
  Widget _buildUserStatusOptimized() {
    return Consumer(
      builder: (context, ref, child) {
        final isOnlineAsync =
            ref.watch(userOnlineStatusStreamProvider(widget.otherUserId));

        return isOnlineAsync.when(
          data: (isOnline) {
            if (isOnline) {
              return const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'آنلاین',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              );
            }
            return Text(
              'آفلاین',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            );
          },
          loading: () => const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1),
          ),
          error: (_, __) => const Text(
            'آفلاین',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }

  /// بناء background بهینه‌شده
  Widget _buildOptimizedBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Wallpaper - cached
          CachedNetworkImage(
            imageUrl: _cachedWallpaperUrl,
            fit: BoxFit.cover,
            cacheManager: CustomCacheManager.wallpaperInstance,
            placeholder: (context, url) => _buildWallpaperPlaceholder(),
            errorWidget: (context, url, error) => _buildWallpaperPlaceholder(),
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 200),
            memCacheWidth: 1080,
            memCacheHeight: 1920,
          ),
          // Overlay - cached color
          Container(
            decoration: BoxDecoration(color: _cachedOverlayColor),
          ),
        ],
      ),
    );
  }

  /// پلیس‌هولدر والپیپر
  Widget _buildWallpaperPlaceholder() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.grey[900]!, Colors.grey[800]!]
              : [Colors.grey[100]!, Colors.grey[200]!],
        ),
      ),
    );
  }

  /// تقسیم‌کننده تاریخ
  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final jDate = Jalali.fromDateTime(date);

    String label;
    if (_isSameDay(date, now)) {
      label = 'امروز';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'دیروز';
    } else {
      label = '${jDate.day} ${_getPersianMonth(jDate.month)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getPersianMonth(int month) {
    const months = [
      '',
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند'
    ];
    return months[month] ?? '';
  }

  /// لیست پیام‌های بهینه‌شده
  Widget _buildOptimizedMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final lazyState =
            ref.watch(lazyMessagesProvider(widget.conversationId));
        final fontSize = ref.watch(messageFontSizeProvider);

        if (lazyState.messages.isEmpty && !lazyState.isLoading) {
          return const Center(
            child: Text(
              'پیامی وجود ندارد. اولین پیام را ارسال کنید!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final filteredMessages = _getFilteredMessages(lazyState.messages);

        if (filteredMessages.isEmpty && !lazyState.isLoading) {
          return const Center(
            child: Text('پیامی وجود ندارد. اولین پیام را ارسال کنید!'),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              if (lazyState.hasMore && !lazyState.isLoading) {
                ref
                    .read(lazyMessagesProvider(widget.conversationId).notifier)
                    .loadMoreMessages();
              }
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            reverse: true,
            itemCount: filteredMessages.length + (lazyState.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              // Loading indicator
              if (index == filteredMessages.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final message = filteredMessages[index];
              final currentUser = ref.read(currentUserProvider);
              final isMe = currentUser.hasValue && currentUser.value != null
                  ? message.senderId == currentUser.value!['id']
                  : false;

              // Date divider check
              bool showDateDivider = false;
              if (index == filteredMessages.length - 1) {
                showDateDivider = true;
              } else {
                final prevMsg = filteredMessages[index + 1];
                if (!_isSameDay(message.createdAt, prevMsg.createdAt)) {
                  showDateDivider = true;
                }
              }

              return Column(
                children: [
                  if (showDateDivider) _buildDateDivider(message.createdAt),
                  OptimizedMessageWidget(
                    message: message,
                    isMe: isMe,
                    fontSize: fontSize,
                    highlightedMessageId: _highlightedMessageId,
                    messageReplyStates: _messageReplyStates,
                    inlineImageGrants: _inlineImageGrants,
                    inlineImageLoaded: _inlineImageLoaded,
                    inlineImageProgress: _inlineImageProgress,
                    onSetReply: (msg) {
                      // Handle reply
                    },
                    onShowOptions: (msg, isMyMessage) {
                      // Show message options
                    },
                    onShowFullScreenImage: (url) {
                      // Show full screen image
                    },
                    onTapMessage: (msg) {
                      // Handle message tap
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: _buildOptimizedAppBar(),
        body: Stack(
          children: [
            // Background - optimized
            _buildOptimizedBackground(),

            // Content
            Column(
              children: [
                // Messages list - optimized
                Expanded(child: _buildOptimizedMessagesList()),

                // Input area placeholder
                Container(
                  height: 60,
                  color: Theme.of(context)
                      .scaffoldBackgroundColor
                      .withOpacity(0.95),
                  child: const Center(
                    child: Text('Input area placeholder'),
                  ),
                ),
              ],
            ),

            // Scroll to bottom button
            if (_showScrollToBottom)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _scrollToBottom,
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
