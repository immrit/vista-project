// lib/features/chat/screens/modern_chat_screen.dart
//
// صفحه چت مدرن با انیمیشن‌های حرفه‌ای
//
// ویژگی‌ها:
// ✅ انیمیشن‌های روان و حرفه‌ای
// ✅ هماهنگ با تم (دارک/لایت)
// ✅ بک‌گراند والپیپر
// ✅ Pagination با Infinite Scroll
// ✅ Message Reactions
// ✅ Network Status Banner
// ✅ Pending Messages Indicator
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/message_model.dart';
import '../../../utils/compat_extensions.dart';
import '../providers/chat_providers.dart';

// ✅ Theme & Widgets
import '../theme/chat_theme.dart';
import '../widgets/enhanced_chat_background.dart';
import '../widgets/telegram_reaction_picker.dart';
import '../widgets/retry_indicator_widget.dart' show TelegramConnectionBanner;
import '../widgets/improved_animated_message_bubble.dart';
import '../widgets/animated_chat_input.dart';
import '../widgets/instagram_style_post_card.dart';
import '../widgets/date_divider.dart' as date_divider;
import '../widgets/swipe_to_reply_wrapper.dart';

// ✅ Providers
import '../../../provider/typing_provider.dart' show typingUsersProvider;
import '../../../provider/presence_provider.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../../../services/telegram_read_receipt_service.dart';

// ✅ New Features
import '../widgets/chat_attachment_sheet.dart';
import '../widgets/message_search_bar.dart';
import '../widgets/edit_message_dialog.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/delete_message_dialog.dart';
import '../widgets/unread_messages_divider.dart';
import '../widgets/floating_date_header.dart';
import '../widgets/telegram_online_status.dart';
import '../services/chat_attachment_service.dart';
import '../widgets/block_report_bottom_sheet.dart';
import '../services/user_moderation_service.dart';
import '../services/voice_duration_service.dart';
import '../services/message_reactions_service.dart';
import '../models/message_reaction.dart' as reaction_models;
import '../../../view/screen/PublicPosts/profileScreen.dart';
import '../../../view/screen/PublicPosts/PostDetailPage.dart';

// ✅ Phase 4: Final Integration
import '../widgets/location_message_widgets.dart';
import '../widgets/contact_card_widgets.dart';
import '../screens/document_preview_screen.dart';
import '../screens/message_info_screen.dart';
import '../screens/telegram_profile_screen.dart';
// TODO: Use CompleteDeletionService for delete with undo
// import '../services/complete_deletion_service.dart';
import '../services/message_actions_service.dart';
import '../widgets/message_delete_animation.dart';

/// پارامترهای صفحه چت
class ChatScreenArgs {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const ChatScreenArgs({
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });
}

/// صفحه چت مدرن
class ModernChatScreen extends ConsumerStatefulWidget {
  final ChatScreenArgs args;

  const ModernChatScreen({super.key, required this.args});

  @override
  ConsumerState<ModernChatScreen> createState() => _ModernChatScreenState();
}

class _ModernChatScreenState extends ConsumerState<ModernChatScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // انیمیشن‌ها
  late AnimationController _appBarAnimController;
  late Animation<double> _appBarAnimation;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════════════

  MessageModel? _replyToMessage;
  bool _isNearTop = false;
  bool _showScrollToBottom = false;
  String? _currentUserId;

  // Search
  bool _isSearchMode = false;
  String? _highlightedMessageId;

  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // Floating date
  bool _isScrolling = false;
  DateTime? _currentVisibleDate;

  // Unread messages
  String? _lastReadMessageId;
  int _unreadCount = 0;

  // Services
  final _moderationService = UserModerationService();
  final _voiceService = VoiceDurationService();
  // TODO: Use CompleteDeletionService for delete with undo
  // final _completeDeletionService = CompleteDeletionService();

  // Block status
  bool _isOtherUserBlocked = false;
  bool _isCurrentUserBlocked = false;

  // Profile
  ProfileModel? _otherUserProfile;

  // Reaction picker
  String? _reactionPickerMessageId;
  Offset? _reactionPickerPosition;

  // Reactions cache - Map<messageId, List<reaction_models.MessageReaction>>
  final Map<String, List<reaction_models.MessageReaction>> _messageReactions =
      {};
  final MessageReactionsService _reactionsService = MessageReactionsService();
  final Map<String, StreamSubscription> _reactionsSubscriptions = {};

  // Hidden messages (حذف شده برای من)
  Set<String> _hiddenMessageIds = {};

  // انیمیشن حذف پیام
  final Set<String> _deletingMessageIds = {};
  final Map<String, MessageDeleteAnimationController>
      _deleteAnimationControllers = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    _checkBlockStatus();
    _fetchUserProfileIfNeeded();
    _loadHiddenMessages();

    // ✅ شروع گوش دادن به Read Receipts
    _initReadReceipts();
  }

  /// راه‌اندازی سرویس Read Receipt
  void _initReadReceipts() {
    final readReceiptService = TelegramReadReceiptService();
    readReceiptService.startListening(widget.args.conversationId);

    // ✅ تنظیم callback برای آپدیت لیست مکالمات
    readReceiptService.onLastMessageStatusChanged = (conversationId, status) {
      if (mounted) {
        ref
            .read(optimizedConversationsProvider.notifier)
            .updateLastMessageDeliveryStatus(
              conversationId: conversationId,
              status: status,
            );
      }
    };

    // ✅ ثبت آخرین پیام مکالمه برای sync تیک‌ها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerLastMessage();
    });

    // علامت‌گذاری همه پیام‌ها به عنوان خوانده شده وقتی وارد چت می‌شویم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllMessagesAsRead();
    });
  }

  /// ثبت آخرین پیام برای sync وضعیت تیک در لیست مکالمات
  void _registerLastMessage() {
    if (!mounted) return;

    final messagesAsync =
        ref.read(messagesStreamProvider(widget.args.conversationId));
    messagesAsync.whenData((messages) {
      if (messages.isEmpty) return;

      // پیدا کردن آخرین پیام من (برای نمایش تیک)
      final myLastMessage = messages.firstWhere(
        (m) => m.senderId == _currentUserId,
        orElse: () => messages.first,
      );

      TelegramReadReceiptService().setLastMessageId(
        widget.args.conversationId,
        myLastMessage.id,
      );
    });
  }

  /// علامت‌گذاری همه پیام‌ها به عنوان خوانده شده
  Future<void> _markAllMessagesAsRead() async {
    try {
      final readReceiptService = TelegramReadReceiptService();
      await readReceiptService.markAllAsRead(widget.args.conversationId);
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// اگر نام کاربر نامعتبر باشد، پروفایل را از کش/سرور دریافت می‌کند
  Future<void> _fetchUserProfileIfNeeded() async {
    final name = widget.args.otherUserName.toLowerCase();
    if (name == 'vista user' ||
        name == 'unknown' ||
        name == 'کاربر ناشناس' ||
        name.isEmpty) {
      try {
        final profile =
            await ProfileCacheService().getProfile(widget.args.otherUserId);
        if (mounted) {
          setState(() {
            _otherUserProfile = profile;
          });
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
      }
    }
  }

  void _setupAnimations() {
    _appBarAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _appBarAnimation = CurvedAnimation(
      parent: _appBarAnimController,
      curve: Curves.easeOutCubic,
    );

    _appBarAnimController.forward();
  }

  void _loadCurrentUser() {
    // ✅ گرفتن userId از Supabase
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_currentUserId == null) {
      debugPrint('⚠️ Warning: currentUserId is null!');
    } else {
      debugPrint('✅ Current user ID loaded: $_currentUserId');
    }
  }

  Future<void> _checkBlockStatus() async {
    final status =
        await _moderationService.getBlockStatus(widget.args.otherUserId);
    if (mounted) {
      setState(() {
        _isOtherUserBlocked = status.isBlocked;
        _isCurrentUserBlocked = status.isBlockedBy;
      });
    }
  }

  /// بارگذاری پیام‌های مخفی شده (حذف شده برای من)
  Future<void> _loadHiddenMessages() async {
    try {
      final actionsService = ref.read(messageActionsServiceProvider);
      final hiddenIds = await actionsService.getHiddenMessageIds(
        widget.args.conversationId,
      );
      if (mounted) {
        setState(() {
          _hiddenMessageIds = hiddenIds;
        });
      }
    } catch (e) {
      debugPrint('Error loading hidden messages: $e');
    }
  }

  @override
  void dispose() {
    // توقف تایپ هنگام خروج - با try-catch برای جلوگیری از خطا
    try {
      if (mounted) {
        ref.read(typingActionsProvider).stopTyping(widget.args.conversationId);
      }
    } catch (e) {
      // Ignore errors after dispose
      debugPrint('Error stopping typing in dispose: $e');
    }

    // ✅ توقف گوش دادن به Read Receipts
    try {
      TelegramReadReceiptService().stopListening(widget.args.conversationId);
    } catch (e) {
      debugPrint('Error stopping read receipt listener: $e');
    }

    for (final sub in _reactionsSubscriptions.values) {
      sub.cancel();
    }
    _reactionsSubscriptions.clear();
    _scrollEndTimer?.cancel();
    _appBarAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📜 SCROLL
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _scrollEndTimer;

  void _onScroll() {
    // ✅ FIX: بررسی mounted قبل از هر کاری
    if (!mounted) return;

    // Pagination - چون لیست reverse است
    final isNearTop = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200;

    if (isNearTop != _isNearTop) {
      if (mounted) {
        setState(() => _isNearTop = isNearTop);
        if (_isNearTop) _loadMoreMessages();
      }
    }

    // دکمه Scroll to Bottom
    final showScrollButton = _scrollController.position.pixels > 300;
    if (showScrollButton != _showScrollToBottom) {
      if (mounted) {
        setState(() => _showScrollToBottom = showScrollButton);
      }
    }

    // Floating date - شروع اسکرول
    if (!_isScrolling && mounted) {
      setState(() => _isScrolling = true);
    }

    // ریست تایمر پایان اسکرول
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _isScrolling = false);

        // ✅ FIX: بعد از توقف اسکرول، اگر در پایین لیست هستیم، تاریخ را به‌روز کن
        if (mounted && _scrollController.hasClients) {
          final offset = _scrollController.offset;
          if (offset < 100) {
            // در پایین لیست هستیم - تاریخ را به اولین پیام (جدیدترین) تنظیم کن
            _updateDateForBottom();
          }
        }
      }
    });

    // آپدیت تاریخ قابل مشاهده
    if (mounted) {
      _updateVisibleDate();
    }
  }

  void _updateVisibleDate() {
    if (!mounted || !_scrollController.hasClients) return;

    // ✅ FIX: بررسی mounted قبل از استفاده از ref
    if (!mounted) return;

    try {
      final messagesAsync =
          ref.read(messagesStreamProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        // ✅ FIX: اگر پیامی وجود ندارد، floating date را پاک کن
        if (messages.isEmpty) {
          if (_currentVisibleDate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentVisibleDate = null;
                });
              }
            });
          }
          return;
        }

        // تخمین ایندکس پیام قابل مشاهده
        final scrollOffset = _scrollController.offset;
        final itemHeight = 70.0; // تقریبی
        var visibleIndex = (scrollOffset / itemHeight).floor();
        visibleIndex = visibleIndex.clamp(0, messages.length - 1);

        // ✅ FIX: بررسی معتبر بودن index
        if (visibleIndex >= 0 && visibleIndex < messages.length) {
          final newDate = messages[visibleIndex].createdAt;

          // ✅ فقط اگر تاریخ متفاوت بود update کن
          if (_currentVisibleDate == null ||
              !_isSameDay(_currentVisibleDate!, newDate)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentVisibleDate = newDate;
                });
              }
            });
          }
        } else {
          // ✅ FIX: index نامعتبر است - floating date را پاک کن
          if (_currentVisibleDate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentVisibleDate = null;
                });
              }
            });
          }
        }
      });
    } catch (e) {
      // Ignore errors if widget is disposed
      debugPrint('Error in _updateVisibleDate: $e');
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// بررسی نمایش unread divider
  bool _shouldShowUnreadDivider(
      MessageModel message, int index, List<MessageModel> messages) {
    // اگه آخرین پیام خونده شده تنظیم نشده، نشون نده
    if (_lastReadMessageId == null) return false;

    // اگه این پیام همون آخرین پیام خونده شده هست
    if (message.id == _lastReadMessageId) {
      // و پیام بعدی (قدیمی‌تر) وجود داره
      if (index < messages.length - 1) {
        return true;
      }
    }
    return false;
  }

  /// محاسبه تعداد پیام‌های خوانده نشده
  void _calculateUnreadCount(List<MessageModel> messages) {
    if (_lastReadMessageId == null) {
      _unreadCount = 0;
      return;
    }

    final lastReadIndex =
        messages.indexWhere((m) => m.id == _lastReadMessageId);
    if (lastReadIndex == -1) {
      _unreadCount = 0;
    } else {
      // چون لیست reverse هست، پیام‌های جدیدتر index کمتر دارن
      _unreadCount = lastReadIndex;
    }
  }

  void _loadMoreMessages() {
    // ✅ FIX: بررسی mounted قبل از استفاده از ref
    if (!mounted) return;

    try {
      final messagesAsync = ref.read(
        messagesStreamProvider(widget.args.conversationId),
      );

      messagesAsync.whenData((messages) {
        if (!mounted) return;
        if (messages.isEmpty) return;

        final oldestMessage = messages.last;
        if (mounted) {
          ref
              .read(
                  paginationStateProvider(widget.args.conversationId).notifier)
              .loadMore(oldestMessage.createdAt);
        }
      });
    } catch (e) {
      // Ignore errors if widget is disposed
      debugPrint('Error in _loadMoreMessages: $e');
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;

    _scrollController
        .animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    )
        .then((_) {
      // بعد از اسکرول به پایین، تاریخ اولین پیام (جدیدترین) را بگیر
      if (mounted) {
        _updateDateForBottom();
      }
    });
  }

  /// آپدیت تاریخ وقتی در پایین لیست هستیم
  void _updateDateForBottom() {
    if (!mounted) return;

    // ✅ FIX: بررسی mounted قبل از استفاده از ref
    try {
      final messagesAsync =
          ref.read(messagesStreamProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        // ✅ FIX: اگر پیامی وجود ندارد، floating date را پاک کن
        if (messages.isEmpty) {
          if (_currentVisibleDate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentVisibleDate = null;
                  _isScrolling = false;
                });
              }
            });
          }
          return;
        }

        // اولین پیام (جدیدترین) چون لیست reverse است
        final newestMessage = messages.first;
        final newDate = newestMessage.createdAt;

        // ✅ فقط اگر تاریخ متفاوت بود update کن
        if (_currentVisibleDate == null ||
            !_isSameDay(_currentVisibleDate!, newDate)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentVisibleDate = newDate;
                _isScrolling = true; // نمایش تاریخ
              });
              // بعد از 2 ثانیه مخفی کن
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() => _isScrolling = false);
                }
              });
            }
          });
        }
      });
    } catch (e) {
      // Ignore errors if widget is disposed
      debugPrint('Error in _updateDateForBottom: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.args.conversationId),
    );
    final paginationState = ref.watch(
      paginationStateProvider(widget.args.conversationId),
    );

    return Stack(
      children: [
        // Main Screen
        EnhancedChatBackground(
          enablePattern: true,
          enableBlur: theme.isDark,
          blurIntensity: 3.0,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // ✅ فعال کردن اسکرول پیام‌ها از پشت app bar
            extendBodyBehindAppBar: true,
            appBar: _isSearchMode ? null : _buildAppBar(theme),
            body: Column(
              children: [
                // Search bar
                if (_isSearchMode)
                  MessageSearchBar(
                    conversationId: widget.args.conversationId,
                    onClose: () => setState(() {
                      _isSearchMode = false;
                      _highlightedMessageId = null;
                    }),
                    onResultSelected: (messageId) {
                      setState(() => _highlightedMessageId = messageId);
                      _scrollToMessage(messageId);
                    },
                  ),

                // بنر مسدودیت
                if (_isCurrentUserBlocked || _isOtherUserBlocked)
                  _buildBlockedBanner(theme),

                // بنر اتصال
                TelegramConnectionBanner(
                  isConnected: true, // TODO: اتصال به network state
                  onRetry: () {
                    // TODO: retry connection
                  },
                ),

                // لیست پیام‌ها
                Expanded(
                  child: Stack(
                    children: [
                      // پیام‌ها با تاریخ شناور
                      FloatingDateHeader(
                        currentDate: _currentVisibleDate,
                        isScrolling: _isScrolling,
                        child: _buildMessageList(
                            messagesAsync, paginationState, theme),
                      ),

                      // دکمه Scroll to Bottom
                      if (_showScrollToBottom)
                        _buildScrollToBottomButton(theme),
                    ],
                  ),
                ),

                // Input area
                if (!_isCurrentUserBlocked && !_isOtherUserBlocked)
                  AnimatedPadding(
                    duration: Duration.zero,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: _buildInputArea(theme),
                  ),
              ],
            ),
          ),
        ),

        // Reaction Picker Overlay
        if (_reactionPickerMessageId != null &&
            _reactionPickerPosition != null &&
            !_isSelectionMode)
          _buildReactionPickerOverlay(),
      ],
    );
  }

  /// Scroll به پیام خاص
  void _scrollToMessage(String messageId) {
    setState(() => _highlightedMessageId = messageId);

    // پاک کردن highlight بعد از چند ثانیه
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  /// Scroll به پیام با استفاده از ID
  void _scrollToMessageById(String messageId, List<MessageModel> messages) {
    // پیدا کردن ایندکس پیام
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index == -1) {
      _showErrorSnackBar('پیام یافت نشد');
      return;
    }

    // Scroll به پیام
    // چون لیست reverse هست، باید از scrollController استفاده کنیم
    final itemExtent = 80.0; // تقریبی ارتفاع هر پیام
    final scrollPosition = index * itemExtent;

    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );

    // Highlight پیام
    setState(() => _highlightedMessageId = messageId);

    // پاک کردن highlight بعد از چند ثانیه
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildSelectionAppBar(ChatTheme theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: theme.sendButtonColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedMessageIds.length} انتخاب شده'.toPersianDigit(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // فوروارد
        IconButton(
          icon: const Icon(Icons.forward_rounded, color: Colors.white),
          onPressed:
              _selectedMessageIds.isEmpty ? null : _forwardSelectedMessages,
          tooltip: 'فوروارد',
        ),
        // کپی
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: Colors.white),
          onPressed: _selectedMessageIds.isEmpty ? null : _copySelectedMessages,
          tooltip: 'کپی',
        ),
        // حذف
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed:
              _selectedMessageIds.isEmpty ? null : _deleteSelectedMessages,
          tooltip: 'حذف',
        ),
      ],
    );
  }

  void _enterSelectionMode(String messageId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _forwardSelectedMessages() async {
    final result = await ForwardMessageSheet.show(
      context,
      messageIds: _selectedMessageIds.toList(),
    );

    if (result == true) {
      _showSuccessSnackBar('پیام‌ها فوروارد شدند');
      _exitSelectionMode();
    }
  }

  Future<void> _copySelectedMessages() async {
    if (!mounted) return;

    try {
      // گرفتن متن پیام‌های انتخاب شده
      final messagesAsync =
          ref.read(messagesStreamProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        final selectedMessages = messages
            .where((m) => _selectedMessageIds.contains(m.id))
            .map((m) => m.content)
            .join('\n\n');

        Clipboard.setData(ClipboardData(text: selectedMessages));
        if (mounted) {
          _showSuccessSnackBar(
              '${_selectedMessageIds.length} پیام کپی شد'.toPersianDigit());
          _exitSelectionMode();
        }
      });
    } catch (e) {
      debugPrint('Error in _copySelectedMessages: $e');
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    // بررسی آیا همه پیام‌های انتخاب شده متعلق به کاربر فعلی هستند
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    bool allMyMessages = true;

    // دریافت پیام‌ها برای بررسی مالکیت
    final messagesAsync =
        ref.read(messagesStreamProvider(widget.args.conversationId));
    final messages = messagesAsync.valueOrNull ?? [];
    final selectedMessages =
        messages.where((m) => _selectedMessageIds.contains(m.id)).toList();

    for (final msg in selectedMessages) {
      if (msg.senderId != currentUserId) {
        allMyMessages = false;
        break;
      }
    }

    // نمایش دیالوگ حذف
    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: allMyMessages,
      messageCount: _selectedMessageIds.length,
    );

    if (!result.confirmed) return;

    // حذف پیام‌ها
    int successCount = 0;
    final actionsService = ref.read(messageActionsServiceProvider);

    for (final messageId in _selectedMessageIds) {
      if (!mounted) break;

      try {
        final deleteResult = await actionsService.deleteMessage(
          messageId: messageId,
          conversationId: widget.args.conversationId,
          forEveryone: result.deleteForEveryone,
        );
        if (deleteResult.isSuccess) {
          successCount++;
        }
      } catch (e) {
        debugPrint('Error deleting message: $e');
      }
    }

    if (successCount > 0) {
      final suffix = result.deleteForEveryone ? ' برای همه' : '';
      _showSuccessSnackBar('$successCount پیام حذف شد$suffix'.toPersianDigit());

      // بروزرسانی لیست پیام‌های مخفی برای حذف یک‌طرفه
      if (!result.deleteForEveryone) {
        setState(() {
          _hiddenMessageIds = {..._hiddenMessageIds, ..._selectedMessageIds};
        });
      }
    }

    _exitSelectionMode();
  }

  PreferredSizeWidget _buildAppBar(ChatTheme theme) {
    // Selection mode AppBar
    if (_isSelectionMode) {
      return _buildSelectionAppBar(theme);
    }

    return AppBar(
      elevation: 0,
      backgroundColor: theme.appBarColor,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle:
          theme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: theme.textColor,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: FadeTransition(
        opacity: _appBarAnimation,
        child: _buildAppBarTitle(theme),
      ),
      actions: [
        // منوی بیشتر
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: theme.iconColor),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.iconColor, size: 20),
                  const SizedBox(width: 12),
                  const Text('جستجو'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.iconColor, size: 20),
                  const SizedBox(width: 12),
                  const Text('جزئیات چت'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Text('مسدود کردن', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Text('گزارش', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: theme.errorColor, size: 20),
                  const SizedBox(width: 12),
                  Text('پاک کردن چت',
                      style: TextStyle(color: theme.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppBarTitle(ChatTheme theme) {
    // دریافت وضعیت تایپ
    final typingUsersAsync = ref.watch(
      typingUsersProvider(widget.args.conversationId),
    );

    // تعیین وضعیت تایپ
    final isTyping = typingUsersAsync.maybeWhen(
      data: (users) => users.isNotEmpty,
      orElse: () => false,
    );

    return InkWell(
      onTap: () {
        _navigateToChatDetails();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // آواتار با نقطه آنلاین
            Hero(
              tag: 'avatar_${widget.args.otherUserId}',
              child: _buildAvatarWithOnlineIndicator(theme),
            ),

            const SizedBox(width: 12),

            // نام و وضعیت
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _otherUserProfile?.username ?? widget.args.otherUserName,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // ✅ وضعیت آنلاین به سبک تلگرام - Real-time
                  TelegramOnlineStatus(
                    userId: widget.args.otherUserId,
                    isTyping: isTyping,
                    textStyle: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
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

  /// آواتار با نشانگر آنلاین
  Widget _buildAvatarWithOnlineIndicator(ChatTheme theme) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          // آواتار اصلی
          _buildAvatar(theme),
          // نقطه آنلاین
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildOnlineDot(),
          ),
        ],
      ),
    );
  }

  /// نقطه آنلاین برای آواتار - ✅ بهینه با Consumer
  Widget _buildOnlineDot() {
    return Consumer(
      builder: (context, ref, _) {
        final presenceAsync = ref.watch(
          userPresenceStreamProvider(widget.args.otherUserId),
        );

        return presenceAsync.maybeWhen(
          data: (state) {
            if (!state.isOnline) return const SizedBox.shrink();

            return OnlineStatusDot(
              status: state.status,
              size: 14,
              borderColor: Theme.of(context).scaffoldBackgroundColor,
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildAvatar(ChatTheme theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.sendButtonColor.withOpacity(0.8),
            theme.sendButtonColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.sendButtonColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.args.otherUserAvatar != null
          ? ClipOval(
              child: Image.network(
                widget.args.otherUserAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarText(theme),
              ),
            )
          : _buildAvatarText(theme),
    );
  }

  Widget _buildAvatarText(ChatTheme theme) {
    return Center(
      child: Text(
        widget.args.otherUserName[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'search':
        setState(() => _isSearchMode = true);
        break;
      case 'details':
        _navigateToChatDetails();
        break;
      case 'profile':
        _navigateToProfile();
        break;
      case 'block':
        _showBlockDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
      case 'clear':
        _showClearChatDialog();
        break;
    }
  }

  void _showClearChatDialog() {
    final theme = context.chatTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'پاک کردن چت',
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          'آیا مطمئن هستید؟ این عمل قابل بازگشت نیست.',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: پاک کردن چت
            },
            child: Text(
              'پاک کردن',
              style: TextStyle(color: theme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📢 STATUS BANNERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // 💬 MESSAGE LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMessageList(
    AsyncValue<List<MessageModel>> messagesAsync,
    PaginationState paginationState,
    ChatTheme theme,
  ) {
    return messagesAsync.when(
      data: (allMessages) {
        // فیلتر پیام‌های مخفی شده (حذف شده برای من)
        final messages = allMessages
            .where((m) => !_hiddenMessageIds.contains(m.id))
            .toList();

        if (messages.isEmpty) {
          // ✅ فیکس: اگر لیست خالی است، تاریخ شناور را فوراً حذف کن
          if (_currentVisibleDate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _currentVisibleDate = null);
              }
            });
          }

          return _buildEmptyState(theme);
        }

        // بارگذاری واکنش‌ها از دیتابیس
        _loadReactionsForMessages(messages);
        _setupReactionsStream(messages);

        // محاسبه تعداد پیام‌های خوانده نشده
        _calculateUnreadCount(messages);

        // ✅ FIX: اگر در پایین لیست هستیم (offset = 0 یا نزدیک به 0)، تاریخ را آپدیت کن
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;

          final offset = _scrollController.offset;

          // اگر در پایین لیست هستیم (offset < 100) و پیامی وجود دارد
          if (offset < 100 && messages.isNotEmpty) {
            final newestMessage = messages.first;
            final newDate = newestMessage.createdAt;

            // ✅ فقط اگر تاریخ متفاوت بود update کن
            if (_currentVisibleDate == null ||
                !_isSameDay(_currentVisibleDate!, newDate)) {
              setState(() {
                _currentVisibleDate = newDate;
                // اگر اسکرول نمی‌کنیم، تاریخ را نمایش نده (بعد از 2 ثانیه محو می‌شود)
                if (!_isScrolling) {
                  _isScrolling = true;
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() => _isScrolling = false);
                    }
                  });
                }
              });
            }
          } else if (offset >= 100) {
            // ✅ اگر در بالا هستیم و اسکرول نمی‌کنیم، تاریخ را به‌روز کن
            // (این کار در _updateVisibleDate انجام می‌شود)
            if (!_isScrolling) {
              _updateVisibleDate();
            }
          }
        });

        return CustomScrollView(
          controller: _scrollController,
          reverse: true,
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverPadding(padding: EdgeInsets.only(bottom: 10)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Loading indicator در بالا
                  if (paginationState.isLoadingMore &&
                      index == messages.length) {
                    return _buildLoadingIndicator(theme);
                  }

                  final message = messages[index];
                  final isMe = message.senderId == _currentUserId;

                  // گروه‌بندی پیام‌ها
                  final (isFirstInGroup, isLastInGroup) =
                      _getMessageGroupPosition(
                    messages,
                    index,
                  );

                  // Date Divider - منطق صحیح برای لیست reverse:
                  // - مقایسه با پیام قدیمی‌تر (index + 1)
                  // - اگر تاریخ فرق داشت، divider نشون بده
                  // - divider باید بالای پیام فعلی باشه (قبل از پیام در Column)
                  // - برای قدیمی‌ترین پیام هم divider نشون بده (وقتی nextMessage null هست)
                  final nextMessage =
                      index < messages.length - 1 ? messages[index + 1] : null;
                  final showDateDivider = date_divider.shouldShowDateDivider(
                    message.createdAt,
                    nextMessage?.createdAt,
                  );

                  // ایجاد کنترلر انیمیشن برای این پیام
                  _deleteAnimationControllers.putIfAbsent(
                    message.id,
                    () => MessageDeleteAnimationController(),
                  );

                  return MessageDeleteAnimation(
                    controller: _deleteAnimationControllers[message.id],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Date Divider (بالای پیام - قبل از محتوای پیام در Column)
                        if (showDateDivider)
                          date_divider.DateDivider(date: message.createdAt),

                        // حباب پیام
                        Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            // Selection checkbox
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AnimatedScale(
                                  scale: _isSelectionMode ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: GestureDetector(
                                    onTap: () =>
                                        _toggleMessageSelection(message.id),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _selectedMessageIds
                                                .contains(message.id)
                                            ? context.chatTheme.sendButtonColor
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _selectedMessageIds
                                                  .contains(message.id)
                                              ? context
                                                  .chatTheme.sendButtonColor
                                              : context
                                                  .chatTheme.secondaryTextColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: _selectedMessageIds
                                              .contains(message.id)
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),

                            // پیام
                            Flexible(
                              child: (!_isSelectionMode)
                                  ? SwipeToReplyWrapper(
                                      isMe: isMe,
                                      onReply: () {
                                        setState(() {
                                          _replyToMessage = message;
                                        });
                                        _focusNode.requestFocus();
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        decoration: BoxDecoration(
                                          color: _highlightedMessageId ==
                                                  message.id
                                              ? context
                                                  .chatTheme.sendButtonColor
                                                  .withOpacity(0.2)
                                              : _selectedMessageIds
                                                      .contains(message.id)
                                                  ? context
                                                      .chatTheme.sendButtonColor
                                                      .withOpacity(0.1)
                                                  : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: message.attachmentType == 'post'
                                            ? _buildPostMessageBubble(
                                                message, isMe)
                                            : ImprovedAnimatedMessageBubble(
                                                key: ValueKey(message.id),
                                                messageId: message.id,
                                                content: message.content,
                                                isMe: isMe,
                                                time: message.createdAt,
                                                status:
                                                    _getMessageStatus(message),
                                                attachmentUrl:
                                                    message.attachmentUrl,
                                                attachmentType:
                                                    message.attachmentType,
                                                duration: message.duration,
                                                replyToContent:
                                                    message.replyToContent,
                                                replyToSenderName:
                                                    message.replyToSenderName,
                                                replyToMessageId:
                                                    message.replyToMessageId,
                                                onReplyTap: message
                                                            .replyToMessageId !=
                                                        null
                                                    ? () => _scrollToMessageById(
                                                        message
                                                            .replyToMessageId!,
                                                        messages)
                                                    : null,
                                                reactions:
                                                    _convertToOldReactionFormat(
                                                        _messageReactions[
                                                                message.id] ??
                                                            []),
                                                onTap: () =>
                                                    _onMessageTap(message),
                                                onLongPress: () =>
                                                    _onMessageLongPress(
                                                        message),
                                                onDoubleTap: () =>
                                                    _onMessageDoubleTap(
                                                        message),
                                                onAddReaction: (emoji) =>
                                                    _onAddReaction(
                                                        message, emoji),
                                                animate:
                                                    index < 5 && !_isNearTop,
                                                index: index,
                                                isFirstInGroup: isFirstInGroup,
                                                isLastInGroup: isLastInGroup,
                                                isForwarded:
                                                    message.isForwarded,
                                                forwardedFrom: message
                                                    .forwardedFromSenderName,
                                              ),
                                      ),
                                    )
                                  : AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      decoration: BoxDecoration(
                                        color: _highlightedMessageId ==
                                                message.id
                                            ? context.chatTheme.sendButtonColor
                                                .withOpacity(0.2)
                                            : _selectedMessageIds
                                                    .contains(message.id)
                                                ? context
                                                    .chatTheme.sendButtonColor
                                                    .withOpacity(0.1)
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: message.attachmentType == 'post'
                                          ? _buildPostMessageBubble(
                                              message, isMe)
                                          : ImprovedAnimatedMessageBubble(
                                              key: ValueKey(message.id),
                                              messageId: message.id,
                                              content: message.content,
                                              isMe: isMe,
                                              time: message.createdAt,
                                              status:
                                                  _getMessageStatus(message),
                                              attachmentUrl:
                                                  message.attachmentUrl,
                                              attachmentType:
                                                  message.attachmentType,
                                              duration: message.duration,
                                              replyToContent:
                                                  message.replyToContent,
                                              replyToSenderName:
                                                  message.replyToSenderName,
                                              replyToMessageId:
                                                  message.replyToMessageId,
                                              onReplyTap: message
                                                          .replyToMessageId !=
                                                      null
                                                  ? () => _scrollToMessageById(
                                                      message.replyToMessageId!,
                                                      messages)
                                                  : null,
                                              reactions:
                                                  _convertToOldReactionFormat(
                                                      _messageReactions[
                                                              message.id] ??
                                                          []),
                                              onTap: () =>
                                                  _onMessageTap(message),
                                              onLongPress: () =>
                                                  _onMessageLongPress(message),
                                              onDoubleTap: () =>
                                                  _onMessageDoubleTap(message),
                                              onAddReaction: (emoji) =>
                                                  _onAddReaction(
                                                      message, emoji),
                                              animate: index < 5 && !_isNearTop,
                                              index: index,
                                              isFirstInGroup: isFirstInGroup,
                                              isLastInGroup: isLastInGroup,
                                            ),
                                    ),
                            )
                          ],
                        ),

                        // Unread Divider
                        if (_shouldShowUnreadDivider(message, index, messages))
                          UnreadMessagesDivider(
                            unreadCount: _unreadCount,
                            onTap: _scrollToBottom,
                          ),
                      ],
                    ),
                  );
                },
                childCount:
                    messages.length + (paginationState.isLoadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
            SliverToBoxAdapter(
              child: paginationState.isLoadingMore
                  ? _buildLoadingIndicator(theme)
                  : const SizedBox(height: 20),
            ),
          ],
        );
      },
      loading: () => _buildLoadingState(theme),
      error: (error, stack) => _buildErrorState(error.toString(), theme),
    );
  }

  /// تشخیص موقعیت پیام در گروه
  ///
  /// پیام‌های متوالی از یک فرستنده گروه‌بندی میشن
  /// Returns: (isFirstInGroup, isLastInGroup)
  (bool, bool) _getMessageGroupPosition(
      List<MessageModel> messages, int index) {
    final currentMessage = messages[index];

    // چون لیست reverse است:
    // - index کمتر = پیام جدیدتر (پایین صفحه)
    // - index بیشتر = پیام قدیمی‌تر (بالای صفحه)

    // بررسی پیام قبلی (جدیدتر - پایین‌تر)
    final hasPrevious = index > 0;
    final previousMessage = hasPrevious ? messages[index - 1] : null;
    final isFirstInGroup = !hasPrevious ||
        previousMessage!.senderId != currentMessage.senderId ||
        _isTimeDifferenceSignificant(
            currentMessage.createdAt, previousMessage.createdAt);

    // بررسی پیام بعدی (قدیمی‌تر - بالاتر)
    final hasNext = index < messages.length - 1;
    final nextMessage = hasNext ? messages[index + 1] : null;
    final isLastInGroup = !hasNext ||
        nextMessage!.senderId != currentMessage.senderId ||
        _isTimeDifferenceSignificant(
            nextMessage.createdAt, currentMessage.createdAt);

    return (isFirstInGroup, isLastInGroup);
  }

  /// آیا فاصله زمانی بین دو پیام بیش از 5 دقیقه است؟
  bool _isTimeDifferenceSignificant(DateTime time1, DateTime time2) {
    return time1.difference(time2).abs() > const Duration(minutes: 5);
  }

  MessageStatus _getMessageStatus(MessageModel message) {
    if (message.isPending) return MessageStatus.pending;
    if (message.isFailed == true) return MessageStatus.failed;
    if (message.isSeen) return MessageStatus.read;
    if (message.isDelivered) return MessageStatus.delivered;
    if (message.isSent) return MessageStatus.sent;
    return MessageStatus.pending;
  }

  /// بارگذاری واکنش‌ها برای پیام‌های فعلی
  Future<void> _loadReactionsForMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    try {
      final messageIds = messages.map((m) => m.id).toList();
      final reactionsMap =
          await _reactionsService.getMultipleMessageReactions(messageIds);

      if (mounted) {
        setState(() {
          _messageReactions.clear();
          _messageReactions.addAll(reactionsMap);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading reactions: $e');
    }
  }

  /// راه‌اندازی real-time stream برای واکنش‌ها
  void _setupReactionsStream(List<MessageModel> messages) {
    if (messages.isEmpty) return;

    // فقط برای 20 پیام آخر stream ایجاد می‌کنیم (برای بهینه‌سازی)
    final recentMessages = messages.take(20).toList();
    final messageIds = recentMessages.map((m) => m.id).toSet();

    // 1. لغو subscriptionهای قدیمی که دیگر نیاز نیستند
    final idsToRemove = _reactionsSubscriptions.keys
        .where((id) => !messageIds.contains(id))
        .toList();

    for (final id in idsToRemove) {
      _reactionsSubscriptions[id]?.cancel();
      _reactionsSubscriptions.remove(id);
    }

    // 2. ایجاد subscription برای پیام‌های جدید
    for (final messageId in messageIds) {
      if (!_reactionsSubscriptions.containsKey(messageId)) {
        _reactionsSubscriptions[messageId] = _reactionsService
            .watchMessageReactions(messageId)
            .listen((reactions) {
          if (mounted) {
            setState(() {
              _messageReactions[messageId] = reactions;
            });
          }
        });
      }
    }
  }

  /// تبدیل reaction_models.MessageReaction به فرمت قدیمی برای AnimatedMessageBubble
  List<MessageReaction> _convertToOldReactionFormat(
      List<reaction_models.MessageReaction> reactions) {
    if (reactions.isEmpty) return [];

    // گروه‌بندی بر اساس emoji
    final Map<String, List<reaction_models.MessageReaction>> grouped = {};
    for (final reaction in reactions) {
      grouped.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    return grouped.entries.map((entry) {
      final userIds = entry.value.map((r) => r.userId).toList();
      return MessageReaction(
        emoji: entry.key,
        count: entry.value.length,
        userIds: userIds,
        isMyReaction: userIds.contains(_currentUserId),
      );
    }).toList();
  }

  Widget _buildLoadingIndicator(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.sendButtonColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ChatTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: theme.secondaryTextColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'شروع گفتگو با ${widget.args.otherUserName}',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اولین پیام رو ارسال کنید!',
            style: TextStyle(
              color: theme.secondaryTextColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ChatTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.sendButtonColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'در حال بارگذاری...',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ChatTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'خطا در بارگذاری پیام‌ها',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(
                    messagesStreamProvider(widget.args.conversationId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.sendButtonColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton(ChatTheme theme) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: FloatingActionButton.small(
          onPressed: _scrollToBottom,
          backgroundColor: theme.backgroundColor,
          foregroundColor: theme.iconColor,
          elevation: 4,
          child: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🖊️ INPUT AREA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputArea(ChatTheme theme) {
    return AnimatedChatInput(
      controller: _messageController,
      focusNode: _focusNode,
      onSend: _sendMessage,
      onAttachment: _handleAttachment,
      onVoice: _handleVoice,
      onChanged: _onTextChanged,
      replyToContent: _replyToMessage?.content,
      replyToSenderName: _replyToMessage?.senderId == _currentUserId
          ? 'شما'
          : widget.args.otherUserName,
      onCancelReply: () => setState(() => _replyToMessage = null),
      onVoiceRecorded: _handleVoiceRecorded,
    );
  }

  /// Handle ضبط صدا
  Future<void> _handleVoiceRecorded(File audioFile, int duration) async {
    if (!mounted) return;

    final attachmentService = ChatAttachmentService();

    // محاسبه دقیق مدت زمان
    final durationResult = await _voiceService.getAudioDuration(audioFile);
    final finalDuration =
        durationResult.success ? durationResult.durationInSeconds : duration;

    final result = await attachmentService.uploadVoiceMessage(
      audioFile: audioFile,
      conversationId: widget.args.conversationId,
      duration: finalDuration ?? 0,
    );

    if (!mounted) return;

    if (result.success && result.url != null) {
      final params = SendMessageParams(
        conversationId: widget.args.conversationId,
        content: '',
        attachmentUrl: result.url,
        attachmentType: 'voice',
        attachmentFileName: result.fileName,
        duration: finalDuration,
      );

      try {
        await ref.read(chatActionsProvider.notifier).sendMessage(params);
        if (mounted) {
          _scrollToBottom();
        }
      } catch (e) {
        debugPrint('Error sending voice message: $e');
        if (mounted) {
          _showErrorSnackBar('خطا در ارسال پیام صوتی');
        }
      }
    } else {
      if (mounted) {
        _showErrorSnackBar(result.error ?? 'خطا در ارسال پیام صوتی');
      }
    }
  }

  void _onTextChanged(String text) {
    if (!mounted) return;
    if (text.isNotEmpty) {
      try {
        ref.read(typingActionsProvider).startTyping(widget.args.conversationId);
      } catch (e) {
        debugPrint('Error starting typing: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    final replyTo = _replyToMessage;
    if (mounted) {
      setState(() => _replyToMessage = null);
    }

    try {
      final params = SendMessageParams(
        conversationId: widget.args.conversationId,
        content: content,
        replyToMessageId: replyTo?.id,
        replyToContent: replyTo?.content,
        replyToSenderName: replyTo?.senderId == _currentUserId
            ? 'شما'
            : widget.args.otherUserName,
      );

      if (!mounted) return;

      final result =
          await ref.read(chatActionsProvider.notifier).sendMessage(params);

      if (!mounted) return;

      if (result.isSuccess) {
        // Scroll to bottom after sending
        _scrollToBottom();

        // ✅ آپدیت آخرین پیام برای sync تیک در لیست مکالمات
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _registerLastMessage();
        });
      } else {
        _showErrorSnackBar(result.error ?? 'خطا در ارسال پیام');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در ارسال پیام');
      }
    }
  }

  void _handleAttachment() {
    HapticFeedback.lightImpact();
    ChatAttachmentSheet.show(
      context,
      onSelected: _handleAttachmentSelected,
    );
  }

  Future<void> _handleAttachmentSelected(AttachmentSelection selection) async {
    if (!mounted) return;

    // Handle Location
    if (selection.type == ChatAttachmentType.location) {
      final locationData = await LocationPickerSheet.show(context);
      if (locationData != null && mounted) {
        // Store location data as JSON in content
        final locationJson = locationData.toJson();
        final params = SendMessageParams(
          conversationId: widget.args.conversationId,
          content: locationJson.toString(), // Store as JSON string
          attachmentType: 'location',
        );

        try {
          await ref.read(chatActionsProvider.notifier).sendMessage(params);
          if (mounted) {
            _scrollToBottom();
          }
        } catch (e) {
          debugPrint('Error sending location: $e');
        }
      }
      return;
    }

    // Handle Contact
    if (selection.type == ChatAttachmentType.contact) {
      final contactData = await ContactPickerSheet.show(context);
      if (contactData != null && mounted) {
        // Store contact data as JSON in content
        final contactJson = contactData.toJson();
        final params = SendMessageParams(
          conversationId: widget.args.conversationId,
          content: contactJson.toString(), // Store as JSON string
          attachmentType: 'contact',
        );

        try {
          await ref.read(chatActionsProvider.notifier).sendMessage(params);
          if (mounted) {
            _scrollToBottom();
          }
        } catch (e) {
          debugPrint('Error sending contact: $e');
        }
      }
      return;
    }

    // Handle Files
    if (selection.files.isEmpty) return;

    final attachmentService = ChatAttachmentService();

    for (final file in selection.files) {
      if (!mounted) break;

      String? url;
      String attachmentType = 'file';

      // تعیین نوع و آپلود فایل
      final extension = file.path.split('.').last.toLowerCase();

      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        url = await _uploadWithProgress(file, 'image', attachmentService);
        attachmentType = 'image';
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
        url = await _uploadWithProgress(file, 'video', attachmentService);
        attachmentType = 'video';
      } else {
        url = await _uploadWithProgress(file, 'file', attachmentService);
        attachmentType = extension;
      }

      if (url != null && url.isNotEmpty && mounted) {
        // ارسال پیام با attachment
        final params = SendMessageParams(
          conversationId: widget.args.conversationId,
          content: selection.caption ?? '',
          attachmentUrl: url,
          attachmentType: attachmentType,
          attachmentFileName: file.path.split('/').last,
        );

        try {
          await ref.read(chatActionsProvider.notifier).sendMessage(params);
          if (mounted) {
            _scrollToBottom();
          }
        } catch (e) {
          debugPrint('Error sending attachment: $e');
        }
      }
    }
  }

  /// آپلود فایل با progress
  Future<String?> _uploadWithProgress(
    File file,
    String type,
    ChatAttachmentService service,
  ) async {
    try {
      switch (type) {
        case 'image':
          final result = await service.pickImageFromGallery(
            conversationId: widget.args.conversationId,
          );
          return result.url;
        case 'video':
          final result = await service.pickVideoFromGallery(
            conversationId: widget.args.conversationId,
          );
          return result.url;
        default:
          final result = await service.pickFile(
            conversationId: widget.args.conversationId,
          );
          return result.url;
      }
    } catch (e) {
      _showErrorSnackBar('خطا در آپلود فایل');
      return null;
    }
  }

  void _handleVoice() {
    HapticFeedback.mediumImpact();
    // TODO: ضبط صدا
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👆 MESSAGE INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMessageTap(MessageModel message) {
    if (_isSelectionMode) {
      _toggleMessageSelection(message.id);
    } else {
      // نمایش جزئیات پیام یا Document Preview
      if (message.attachmentType == 'document' &&
          message.attachmentUrl != null) {
        _showDocumentPreview(message);
      } else if (message.attachmentType == 'location') {
        // Location already opens in maps via LocationMessageBubble
      } else {
        _showMessageInfo(message);
      }
    }
  }

  /// Navigate to Chat Details Screen
  void _navigateToChatDetails() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => TelegramProfileScreen(
          conversationId: widget.args.conversationId,
          otherUserId: widget.args.otherUserId,
          otherUserName: widget.args.otherUserName,
          otherUserAvatar: widget.args.otherUserAvatar,
        ),
      ),
    );

    // اگر از جستجو برگشت و messageId داشت، به آن پیام اسکرول کن
    if (result != null && mounted) {
      _scrollToMessage(result);
    }
  }

  /// Show Document Preview
  void _showDocumentPreview(MessageModel message) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentPreviewScreen(
          documentUrl: message.attachmentUrl!,
          documentName: message.attachmentFileName ?? 'document',
          documentType: message.attachmentType ?? 'file',
        ),
      ),
    );
  }

  /// Show Message Info
  void _showMessageInfo(MessageModel message) {
    if (_currentUserId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageInfoScreen(
          message: message,
          currentUserId: _currentUserId!,
        ),
      ),
    );
  }

  void _onMessageLongPress(MessageModel message) {
    HapticFeedback.mediumImpact();
    if (_isSelectionMode) {
      _toggleMessageSelection(message.id);
    } else {
      // نمایش منوی گزینه‌ها
      _showMessageOptions(message);
    }
  }

  void _onMessageDoubleTap(MessageModel message) {
    // لایک سریع
    _onAddReaction(message, '❤️');
  }

  void _onAddReaction(MessageModel message, String emoji) {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    try {
      ref.read(chatActionsProvider.notifier).toggleReaction(
            messageId: message.id,
            conversationId: widget.args.conversationId,
            emoji: emoji,
          );
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  void _showMessageOptions(MessageModel message) {
    final theme = context.chatTheme;
    final isMe = message.senderId == _currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Quick Reactions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏']
                      .map((emoji) => _buildQuickReaction(emoji, message))
                      .toList(),
                ),
              ),

              const Divider(),

              // Options
              _buildOptionTile(
                icon: Icons.reply_rounded,
                label: 'پاسخ',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyToMessage = message);
                  _focusNode.requestFocus();
                },
              ),
              _buildOptionTile(
                icon: Icons.copy_rounded,
                label: 'کپی',
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  _showSuccessSnackBar('کپی شد');
                },
              ),
              _buildOptionTile(
                icon: Icons.forward_rounded,
                label: 'فوروارد',
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessage(message);
                },
              ),
              _buildOptionTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'انتخاب',
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(message.id);
                },
              ),
              if (isMe)
                _buildOptionTile(
                  icon: Icons.edit_rounded,
                  label: 'ویرایش',
                  onTap: () {
                    Navigator.pop(context);
                    _editMessage(message);
                  },
                ),
              // حذف برای همه پیام‌ها (یک‌طرفه یا دوطرفه)
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'حذف',
                color: theme.errorColor,
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReaction(String emoji, MessageModel message) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _onAddReaction(message, emoji);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.chatTheme.dividerColor.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = context.chatTheme;
    final tileColor = color ?? theme.textColor;

    return ListTile(
      leading: Icon(icon, color: tileColor),
      title: Text(
        label,
        style: TextStyle(color: tileColor),
      ),
      onTap: onTap,
    );
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final isMe = message.senderId == _currentUserId;

    // نمایش دیالوگ حذف با گزینه "حذف برای همه"
    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: isMe,
      messageCount: 1,
    );

    if (!result.confirmed) return;

    // شروع انیمیشن حذف
    setState(() {
      _deletingMessageIds.add(message.id);
    });

    // اجرای انیمیشن
    final controller = _deleteAnimationControllers[message.id];
    if (controller != null) {
      await controller.startDeleteAnimation();
      // صبر کوتاه برای اتمام انیمیشن
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final actionsService = ref.read(messageActionsServiceProvider);
      final deleteResult = await actionsService.deleteMessage(
        messageId: message.id,
        conversationId: widget.args.conversationId,
        forEveryone: result.deleteForEveryone,
      );

      if (deleteResult.isSuccess) {
        // بروزرسانی UI برای حذف یک‌طرفه
        setState(() {
          _deletingMessageIds.remove(message.id);
          _deleteAnimationControllers.remove(message.id);
          if (!result.deleteForEveryone) {
            _hiddenMessageIds = {..._hiddenMessageIds, message.id};
          }
        });
        final suffix = result.deleteForEveryone ? ' برای همه' : '';
        _showSuccessSnackBar('پیام حذف شد$suffix');
      } else {
        setState(() {
          _deletingMessageIds.remove(message.id);
        });
        _showErrorSnackBar(deleteResult.error ?? 'خطا در حذف پیام');
      }
    } catch (e) {
      setState(() {
        _deletingMessageIds.remove(message.id);
      });
      _showErrorSnackBar('خطا در حذف پیام');
    }
  }

  /// ویرایش پیام
  Future<void> _editMessage(MessageModel message) async {
    final result = await EditMessageDialog.show(
      context,
      messageId: message.id,
      currentContent: message.content,
    );

    if (result == true) {
      _showSuccessSnackBar('پیام ویرایش شد');
      // Refresh messages
      ref.invalidate(messagesStreamProvider(widget.args.conversationId));
    }
  }

  /// فوروارد پیام
  Future<void> _forwardMessage(MessageModel message) async {
    final result = await ForwardMessageSheet.show(
      context,
      messageIds: [message.id],
    );

    if (result == true) {
      _showSuccessSnackBar('پیام فوروارد شد');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📢 SNACKBARS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSuccessSnackBar(String message) {
    final theme = context.chatTheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.sentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final theme = context.chatTheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚫 BLOCK & REPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBlockedBanner(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            _isCurrentUserBlocked
                ? 'شما توسط ${widget.args.otherUserName} مسدود شده‌اید'
                : 'شما ${widget.args.otherUserName} را مسدود کرده‌اید',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockDialog() async {
    final result = await BlockReportBottomSheet.show(
      context: context,
      userId: widget.args.otherUserId,
      userName: widget.args.otherUserName,
      isCurrentlyBlocked: _isOtherUserBlocked,
      type: _isOtherUserBlocked ? ModerationType.unblock : ModerationType.block,
    );

    if (result == true) {
      await _checkBlockStatus();
    }
  }

  Future<void> _showReportDialog() async {
    final result = await BlockReportBottomSheet.show(
      context: context,
      userId: widget.args.otherUserId,
      userName: widget.args.otherUserName,
      type: ModerationType.report,
    );

    if (result == true) {
      // گزارش ارسال شد
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 REACTION PICKER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReactionPickerOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _reactionPickerMessageId = null;
            _reactionPickerPosition = null;
          });
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Backdrop
            Container(
              color: Colors.black.withOpacity(0.2),
            ),
            // Reaction Picker
            TelegramReactionPicker(
              position: _reactionPickerPosition!,
              showAbove: _reactionPickerPosition!.dy > 200,
              onReactionSelected: (emoji) async {
                if (_reactionPickerMessageId != null) {
                  await ref.read(chatActionsProvider.notifier).toggleReaction(
                        messageId: _reactionPickerMessageId!,
                        conversationId: widget.args.conversationId,
                        emoji: emoji,
                      );
                }
                setState(() {
                  _reactionPickerMessageId = null;
                  _reactionPickerPosition = null;
                });
              },
              onClose: () {
                setState(() {
                  _reactionPickerMessageId = null;
                  _reactionPickerPosition = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 👤 PROFILE NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _navigateToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: widget.args.otherUserId,
          username: widget.args.otherUserName,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 POST MESSAGE BUBBLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// ساخت ویجت پست برای پیام‌های پست
  Widget _buildPostMessageBubble(MessageModel message, bool isMe) {
    try {
      // Parse اطلاعات پست از content (JSON)
      final postData = message.content.isNotEmpty
          ? (message.content.startsWith('{')
              ? jsonDecode(message.content) as Map<String, dynamic>
              : null)
          : null;

      if (postData == null) {
        // اگر parse نشد، از ImprovedAnimatedMessageBubble استفاده کن
        return ImprovedAnimatedMessageBubble(
          key: ValueKey(message.id),
          messageId: message.id,
          content: message.content,
          isMe: isMe,
          time: message.createdAt,
          status: _getMessageStatus(message),
          animate: false,
          index: 0,
          isFirstInGroup: true,
          isLastInGroup: true,
          isForwarded: message.isForwarded,
          forwardedFrom: message.forwardedFromSenderName,
        );
      }

      // Extract اطلاعات پست
      final postId = postData['postId'] as String? ?? message.id;
      final authorName = postData['authorName'] as String? ??
          (isMe ? 'شما' : widget.args.otherUserName);
      final authorAvatar = postData['authorAvatar'] as String?;
      final authorUsername = postData['authorUsername'] as String?;
      final postContent = postData['content'] as String? ?? '';
      final mediaUrls = postData['mediaUrls'] != null
          ? List<String>.from(postData['mediaUrls'] as List)
          : null;
      final likesCount = postData['likesCount'] as int? ?? 0;
      final commentsCount = postData['commentsCount'] as int? ?? 0;
      final postCreatedAt = postData['createdAt'] != null
          ? DateTime.parse(postData['createdAt'] as String)
          : message.createdAt;
      final verificationType = postData['verificationType'] as String?;
      final hashtags = postData['hashtags'] != null
          ? List<String>.from(postData['hashtags'] as List)
          : null;

      // استفاده از کارت پست به سبک اینستاگرام
      return InstagramStylePostCard(
        postId: postId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorUsername: authorUsername,
        content: postContent,
        mediaUrls: mediaUrls,
        likesCount: likesCount,
        commentsCount: commentsCount,
        createdAt: postCreatedAt,
        sentAt: message.createdAt,
        isMine: isMe,
        verificationType: verificationType,
        hashtags: hashtags,
        onTap: () => _navigateToPostScreen(postId),
        onShare: () async {
          final result = await ForwardMessageSheet.show(
            context,
            messageIds: [message.id],
          );
          if (result == true) {
            _showSuccessSnackBar('پست ارسال شد');
          }
        },
        onLongPress: () => _onMessageLongPress(message),
      );
    } catch (e) {
      debugPrint('Error parsing post message: $e');
      // در صورت خطا، از ImprovedAnimatedMessageBubble استفاده کن
      return ImprovedAnimatedMessageBubble(
        key: ValueKey(message.id),
        messageId: message.id,
        content: message.content,
        isMe: isMe,
        time: message.createdAt,
        status: _getMessageStatus(message),
        animate: false,
        index: 0,
        isFirstInGroup: true,
        isLastInGroup: true,
        isForwarded: message.isForwarded,
        forwardedFrom: message.forwardedFromSenderName,
      );
    }
  }

  /// Navigate to post screen
  void _navigateToPostScreen(String postId) {
    if (postId.isEmpty) {
      _showErrorSnackBar('شناسه پست یافت نشد');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsPage(postId: postId),
      ),
    );
  }
}
