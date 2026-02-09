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
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/message_model.dart';
import '../../../utils/compat_extensions.dart';
import '../../../utils/time_utils.dart';
import '../providers/chat_providers.dart';

// ✅ Theme & Widgets
import '../theme/chat_theme.dart';
import '../widgets/enhanced_chat_background.dart';
import '../widgets/telegram_reaction_picker.dart'
    show kDefaultReactions, TelegramReactionPicker;
import '../widgets/retry_indicator_widget.dart' show TelegramConnectionBanner;
import '../widgets/improved_animated_message_bubble.dart';
import '../widgets/telegram_context_menu.dart';
import '../widgets/animated_chat_input.dart';
import '../widgets/instagram_style_post_card.dart';
import '../widgets/date_divider.dart' as date_divider;
import '../widgets/swipe_to_reply_wrapper.dart';

// ✅ Providers
import '../../../provider/typing_provider.dart';
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
import '../services/upload_policy_service.dart';
import '../services/message_tombstone_service.dart';
import '../../../services/typing_service.dart'; // ✅ سرویس تایپینگ
import '../../../services/current_chat_tracker.dart';
import '../../../services/PushNotificationService.dart';
import '../widgets/block_report_bottom_sheet.dart';
import '../services/user_moderation_service.dart';
import '../services/voice_duration_service.dart';
import '../services/message_reactions_service.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../security/logging_utility.dart';
import '../models/message_reaction.dart' as reaction_models;
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import '../../stories/presentation/providers/story_providers.dart';
import '../../stories/presentation/screens/story_player_screen.dart';
import '../../stories/domain/entities/entities.dart';

// ✅ Phase 4: Final Integration
import '../widgets/location_message_widgets.dart';
import '../widgets/contact_card_widgets.dart';
import 'telegram_profile_screen.dart';
import 'group_details_screen.dart';
import 'document_preview_screen.dart';
import '../screens/message_info_screen.dart';
// TODO: Use CompleteDeletionService for delete with undo
// import '../services/complete_deletion_service.dart';
import '../services/message_actions_service.dart';
import '../widgets/molecular_delete_animation.dart';
// So importing the file should expose it.

/// پارامترهای صفحه چت
class ChatScreenArgs {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;
  final bool isGroup;

  const ChatScreenArgs({
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
    this.isGroup = false,
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  final Map<String, GlobalKey> _messageKeys =
      {}; // ✅ کلیدها برای اسکرول به پیام

  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // Floating date
  bool _isScrolling = false;
  DateTime? _currentVisibleDate;

  // Typing status
  bool _isOtherUserTyping = false;
  StreamSubscription<Set<String>>? _typingSubscription;

  // ✅ برای جلوگیری از اجرای منطق در build
  String? _lastFirstMessageId;

  // Unread messages
  String? _lastReadMessageId;
  int _unreadCount = 0;

  // Services
  final _moderationService = UserModerationService();
  final _voiceService = VoiceDurationService();
  final UploadPolicyService _uploadPolicyService = const UploadPolicyService();
  final MessageTombstoneService _tombstoneService = MessageTombstoneService();
  // TODO: Use CompleteDeletionService for delete with undo
  // final _completeDeletionService = CompleteDeletionService();

  // Block status
  bool _isOtherUserBlocked = false;
  bool _isCurrentUserBlocked = false;

  // Profile
  ProfileModel? _otherUserProfile;
  ProfileModel? _currentUserProfile; // ✅ پروفایل کاربر فعلی برای چک کردن badge

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

  // ✅ لیست پیام‌هایی که الان منوی آن‌ها باز است (برای مخفی کردن از لیست اصلی)
  final Set<String> _temporarilyHiddenMessages = {};

  // ✅ اندازه‌گیری ارتفاع اینپوت بار برای پدینگ دقیق لیست
  double _inputHeight = 110.0; // مقدار اولیه تقریبی

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _pollingTimer;
  Timer? _floatingDateHideTimer;
  Timer? _activeConversationHeartbeatTimer;
  ProviderSubscription<AsyncValue<List<MessageModel>>>? _messagesListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    _checkBlockStatus();
    _fetchUserProfileIfNeeded();
    _loadHiddenMessages();

    // ✅ شروع گوش دادن به Read Receipts
    _initReadReceipts();

    // ✅ لیسنرهای وضعیت تایپ کردن
    _initTypingListeners();
    _setupMessageSideEffectsListener();

    // ✅ تنظیم چت فعال برای جلوگیری از دریافت بج پیام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(chatRepositoryProvider)
            .setActiveConversation(widget.args.conversationId);
        CurrentChatTracker.instance.setOpenConversation(
          widget.args.conversationId,
        );
        ref
            .read(pushNotificationServiceProvider)
            .cancelConversationNotification(widget.args.conversationId);
        unawaited(_setServerActiveConversation(isActive: true));
        _startActiveConversationHeartbeat();
      }
    });

    // ✅ آپدیت فوری بج پیام (اگر پیام خوانده نشده داشتیم)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(chatRepositoryProvider)
            .resetUnreadCount(widget.args.conversationId);

        ref
            .read(chatRepositoryProvider)
            .markMessagesAsSeen(widget.args.conversationId);
      }
    });

    // ✅ Polling Fallback: هر 30 ثانیه برای اطمینان از دریافت پیام‌ها
    _startPolling();
  }

  void _initTypingListeners() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Listen to typing updates
    _typingSubscription = TypingService()
        .getTypingStream(widget.args.conversationId)
        .listen((typingUsers) {
      if (currentUserId == null) return;

      // ✅ فقط اگر "کسی غیر از من" در حال تایپ بود
      // این لاجیک مطمئن‌ترین راه است که خودم را نبینم
      final isTyping = typingUsers.any((id) => id != currentUserId);

      if (_isOtherUserTyping != isTyping) {
        setState(() {
          _isOtherUserTyping = isTyping;
        });
      }
    });
  }

  void _setupMessageSideEffectsListener() {
    _messagesListener = ref.listenManual<AsyncValue<List<MessageModel>>>(
      chatMessagesProvider(widget.args.conversationId),
      (previous, next) {
        next.whenData(_handleMessagesChanged);
      },
      fireImmediately: true,
    );
  }

  void _handleMessagesChanged(List<MessageModel> allMessages) {
    if (!mounted) return;

    final visibleMessages = allMessages
        .where((m) =>
            !_hiddenMessageIds.contains(m.id) ||
            _deletingMessageIds.contains(m.id))
        .toList();

    _calculateUnreadCount(visibleMessages);

    if (visibleMessages.isEmpty) {
      _lastFirstMessageId = null;
      if (_currentVisibleDate != null || _isScrolling) {
        setState(() {
          _currentVisibleDate = null;
          _isScrolling = false;
        });
      }
      return;
    }

    final firstId = visibleMessages.first.id;
    if (_lastFirstMessageId != firstId) {
      _lastFirstMessageId = firstId;
      _loadReactionsForMessages(visibleMessages);
      _setupReactionsStream(visibleMessages);
    }

    if (_scrollController.hasClients && _scrollController.offset < 100) {
      final newDate = visibleMessages.first.createdAt;
      if (_currentVisibleDate == null ||
          !_isSameDay(_currentVisibleDate!, newDate)) {
        _showFloatingDateTemporarily(newDate);
      }
    }
  }

  void _showFloatingDateTemporarily(DateTime date) {
    _floatingDateHideTimer?.cancel();
    setState(() {
      _currentVisibleDate = date;
      _isScrolling = true;
    });

    _floatingDateHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isScrolling = false);
    });
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
              status: status.name,
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
        ref.read(chatMessagesProvider(widget.args.conversationId));
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
      // ✅ بارگذاری پروفایل کاربر فعلی برای چک کردن badge
      _loadCurrentUserProfile();
    }
  }

  /// ✅ بارگذاری پروفایل کاربر فعلی
  Future<void> _loadCurrentUserProfile() async {
    if (_currentUserId == null) return;
    try {
      final profile = await ProfileCacheService().getProfile(_currentUserId!);
      if (mounted) {
        setState(() => _currentUserProfile = profile);
      }
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  /// ✅ چک کردن اینکه کاربر می‌تواند ویرایش کند (تیک طلایی یا آبی)
  bool get _canEditMessages {
    if (_currentUserProfile == null) return false;
    return _currentUserProfile!.hasGoldBadge ||
        _currentUserProfile!.hasBlueBadge;
  }

  /// ✅ نمایش دیالوگ ارتقا به پریمیوم
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text('قابلیت ویژه'),
          ],
        ),
        content: const Text(
          'ویرایش پیام مخصوص کاربران تایید شده (تیک آبی) یا کاربران پریمیوم (تیک طلایی) است.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/pricing');
            },
            icon: const Icon(Icons.star, size: 18),
            label: const Text('دریافت تیک طلایی'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
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
      final tombstoneIds = await _tombstoneService
          .getDeletedMessageIds(widget.args.conversationId);
      if (mounted) {
        setState(() {
          _hiddenMessageIds = {...hiddenIds, ...tombstoneIds};
        });
      }
    } catch (e) {
      debugPrint('Error loading hidden messages: $e');
    }
  }

  StreamSubscription<RealtimeSubscribeStatus>? _realtimeSubscription;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // توقف تایپ هنگام خروج - با try-catch برای جلوگیری از خطا
    try {
      if (mounted) {
        if (_currentUserId != null) {
          ref
              .read(typingServiceProvider)
              .stopTyping(widget.args.conversationId, _currentUserId!);
        }
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

    _typingSubscription?.cancel(); // ✅ لغو اشتراک تایپ

    for (final sub in _reactionsSubscriptions.values) {
      sub.cancel();
    }

    // ✅ پاک‌سازی پیام‌های مخفی
    _temporarilyHiddenMessages.clear();
    _reactionsSubscriptions.clear();

    _pollingTimer?.cancel();
    _floatingDateHideTimer?.cancel();
    _activeConversationHeartbeatTimer?.cancel();
    _realtimeSubscription?.cancel();
    _messagesListener?.close();

    _scrollEndTimer?.cancel();
    _appBarAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();

    _clearActiveConversationState();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CurrentChatTracker.instance
          .setOpenConversation(widget.args.conversationId);
      unawaited(_setServerActiveConversation(isActive: true));
      _startActiveConversationHeartbeat();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _activeConversationHeartbeatTimer?.cancel();
      CurrentChatTracker.instance.clearOpenConversation();
      unawaited(_setServerActiveConversation(isActive: false));
    }
  }

  void _startActiveConversationHeartbeat() {
    _activeConversationHeartbeatTimer?.cancel();
    _activeConversationHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
      CurrentChatTracker.instance.heartbeat(widget.args.conversationId);
      unawaited(_heartbeatActiveConversation());
    });
  }

  Future<void> _setServerActiveConversation({required bool isActive}) async {
    try {
      await Supabase.instance.client.rpc('set_active_conversation', params: {
        'p_conversation_id': widget.args.conversationId,
        'p_is_active': isActive,
      });
    } catch (e) {
      logInfo('⚠️ set_active_conversation failed: $e');
    }
  }

  Future<void> _heartbeatActiveConversation() async {
    try {
      await Supabase.instance.client
          .rpc('heartbeat_active_conversation', params: {
        'p_conversation_id': widget.args.conversationId,
      });
    } catch (e) {
      logInfo('⚠️ heartbeat_active_conversation failed: $e');
    }
  }

  void _clearActiveConversationState() {
    CurrentChatTracker.instance.clearOpenConversation();
    try {
      ref.read(chatRepositoryProvider).setActiveConversation(null);
    } catch (_) {}
    unawaited(_setServerActiveConversation(isActive: false));
  }

  void _startPolling() {
    // ✅ Smart Polling: گوش دادن به وضعیت اتصال ریل‌تایم
    final repo = ref.read(chatRepositoryProvider);

    _realtimeSubscription = repo.realtimeStatus.listen((status) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('🔌 Realtime Connected: Stopping Polling 🛑');
        _pollingTimer?.cancel();
        _pollingTimer = null;
      } else {
        debugPrint('🔌 Realtime Disconnected ($status): Starting Polling 🔄');
        // اگر قبلاً تایمر نداشتم، بسازم
        if (_pollingTimer == null || !_pollingTimer!.isActive) {
          _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            debugPrint('🔄 Smart Polling Check...');
            ref
                .read(chatRepositoryProvider)
                .refreshMessages(widget.args.conversationId);
          });
        }
      }
    });

    // حالت اولیه: اگر وضعیت هنوز نیامده، فرض کنیم قطع است و پولیگ را شروع کنیم (بعداً با اولین استاتوس اصلاح میشه)
    // اما چون استریم broadcast است، ممکن است آخرین مقدار را نداشته باشد
    // برای همین بهتر است یک تایمر اولیه با تاخیر بگذاریم که اگر وصل نشد شروع شود
    Future.delayed(const Duration(seconds: 5), () {
      if (_pollingTimer == null && mounted) {
        // اگر بعد از 5 ثانیه هنوز وصل نشده (تایمر کنسل نشده)، یه چک بکنیم
        // البته لیسنر بالا اگر ایونت بیاد کار میکنه.
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📜 SCROLL
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _scrollEndTimer;

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    bool needsSetState = false;

    // 1. Pagination Logic
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // وقتی به ۲۰۰ پیکسلی انتهای لیست (بالا) رسیدیم
    final isNearTop = currentScroll >= maxScroll - 200;

    if (isNearTop != _isNearTop) {
      _isNearTop = isNearTop;
      needsSetState = true;
      if (_isNearTop) _loadMoreMessages();
    }

    // 2. Scroll to Bottom Button Visibility
    // دکمه فقط وقتی نمایش داده شود که بیش از ۵۰۰ پیکسل اسکرول کرده‌ایم
    final showScrollButton = currentScroll > 500;
    if (showScrollButton != _showScrollToBottom) {
      _showScrollToBottom = showScrollButton;
      needsSetState = true;
    }

    // 3. Floating Date Logic
    if (!_isScrolling) {
      _isScrolling = true;
      needsSetState = true;
    }

    // Debounce برای پایان اسکرول (جلوگیری از تایمرهای تودرتو)
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
          // آپدیت تاریخ فقط وقتی اسکرول متوقف شد
          if (currentScroll < 100) {
            _updateDateForBottom();
          } else {
            _updateVisibleDate();
          }
        });
      }
    });

    // ✅ فقط یک بار setState انجام میدهیم اگر واقعا چیزی تغییر کرده باشد
    if (needsSetState) {
      setState(() {});
    }
  }

  void _updateVisibleDate() {
    if (!mounted || !_scrollController.hasClients) return;

    try {
      final messagesAsync =
          ref.read(chatMessagesProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        if (messages.isEmpty) {
          if (_currentVisibleDate != null) {
            setState(() {
              _currentVisibleDate = null;
            });
          }
          return;
        }

        final scrollOffset = _scrollController.offset;
        const itemHeight = 70.0;
        var visibleIndex = (scrollOffset / itemHeight).floor();
        visibleIndex = visibleIndex.clamp(0, messages.length - 1);

        if (visibleIndex >= 0 && visibleIndex < messages.length) {
          final newDate = messages[visibleIndex].createdAt;
          if (_currentVisibleDate == null ||
              !_isSameDay(_currentVisibleDate!, newDate)) {
            setState(() {
              _currentVisibleDate = newDate;
            });
          }
        } else if (_currentVisibleDate != null) {
          setState(() {
            _currentVisibleDate = null;
          });
        }
      });
    } catch (e) {
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
        chatMessagesProvider(widget.args.conversationId),
      );

      messagesAsync.whenData((messages) {
        if (!mounted) return;
        if (messages.isEmpty) return;

        if (mounted) {
          ref
              .read(chatMessagesProvider(widget.args.conversationId).notifier)
              .loadMore();
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

    try {
      final messagesAsync =
          ref.read(chatMessagesProvider(widget.args.conversationId));
      messagesAsync.whenData((messages) {
        if (!mounted) return;

        if (messages.isEmpty) {
          if (_currentVisibleDate != null || _isScrolling) {
            setState(() {
              _currentVisibleDate = null;
              _isScrolling = false;
            });
          }
          return;
        }

        final newestMessage = messages.first;
        final newDate = newestMessage.createdAt;

        if (_currentVisibleDate == null ||
            !_isSameDay(_currentVisibleDate!, newDate)) {
          _showFloatingDateTemporarily(newDate);
        }
      });
    } catch (e) {
      debugPrint('Error in _updateDateForBottom: $e');
    }
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final reduceEffects = keyboardVisible || _isScrolling;
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.args.conversationId),
    );
    final paginationState = ref.watch(
      paginationStateProvider(widget.args.conversationId),
    );

    return Stack(
      children: [
        // 1. والپیپر (زیر همه چیز)
        Positioned.fill(
          // ✅ اضافه کردن RepaintBoundary
          // این باعث می‌شود هنگام باز شدن کیبورد، بک‌گراند دوباره Paint نشود (خیلی مهم برای GPU)
          child: RepaintBoundary(
            child: EnhancedChatBackground(
              enablePattern: true,
              forceEnableBlur: reduceEffects ? false : null,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),

        // 2. اسکفولد اصلی
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset:
              true, // ✅ بازگشت به حالت استاندارد برای جلوگیری از مشکل مخفی شدن اینپوت

          appBar: _isSearchMode ? null : _buildAppBar(theme),

          body: Stack(
            children: [
              // لایه 1: لیست پیام‌ها (تمام صفحه)
              // با استفاده از Stack، لیست زیر اینپوت می‌رود و افکت شیشه‌ای دیده می‌شود
              Positioned.fill(
                child: FloatingDateHeader(
                  currentDate: _currentVisibleDate,
                  isScrolling: _isScrolling,
                  child: _buildMessageList(
                    messagesAsync,
                    paginationState,
                    theme,
                    // ✅ پدینگ پایین داینامیک بر اساس ارتفاع واقعی اینپوت بار
                    bottomPadding: _inputHeight,
                  ),
                ),
              ),

              // لایه 2: بنرها
              if (_isCurrentUserBlocked || _isOtherUserBlocked)
                Positioned(
                  top: kToolbarHeight + 30,
                  left: 0,
                  right: 0,
                  child: _buildBlockedBanner(theme),
                ),

              Positioned(
                top: kToolbarHeight + 30,
                left: 0,
                right: 0,
                child: TelegramConnectionBanner(
                  isConnected: true,
                  onRetry: () {},
                ),
              ),

              // لایه 3: دکمه اسکرول به پایین
              if (_showScrollToBottom)
                Positioned(
                  right: 16,
                  bottom: 90, // بالاتر از اینپوت بار
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
                ),

              // لایه 4: اینپوت بار (چسبیده به پایین)
              if (!_isCurrentUserBlocked && !_isOtherUserBlocked)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildInputArea(theme, reduceEffects),
                ),

              // لایه 5: Search Bar
              if (_isSearchMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: MessageSearchBar(
                      conversationId: widget.args.conversationId,
                      onClose: () => setState(() {
                        _isSearchMode = false;
                        _highlightedMessageId = null;
                      }),
                      onResultSelected: (id) {
                        setState(() => _highlightedMessageId = id);
                        _scrollToMessage(id);
                      },
                    ),
                  ),
                ),
            ],
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

  /// اندازه‌گیری ارتفاع اینپوت بار به شکل امن
  void _onInputHeightChanged(double newHeight) {
    if (!mounted || newHeight <= 0) return;
    if ((newHeight - _inputHeight).abs() < 1.0) return;

    setState(() {
      _inputHeight = newHeight;
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

  /// ✅ توابع کمکی یکپارچه برای هندل کردن کلیک و لانگ پرس
  void _handleMessageTap(BuildContext itemContext, MessageModel message) {
    if (_isSelectionMode) {
      _toggleMessageSelection(message.id);
    } else {
      // تک کلیک روی پیام معمولی -> باز شدن کانتکست منو (مثل تلگرام iOS)
      _showTelegramContextMenu(itemContext, message);
    }
  }

  void _handleMessageLongPress(BuildContext itemContext, MessageModel message) {
    HapticFeedback.mediumImpact();
    if (_isSelectionMode) {
      _toggleMessageSelection(message.id);
    } else {
      // لانگ پرس -> باز شدن کانتکست منو
      _showTelegramContextMenu(itemContext, message);
    }
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
          ref.read(chatMessagesProvider(widget.args.conversationId));
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

    // دسترسی به لیست کامل پیام‌ها برای استخراج MessageModel
    final messagesAsync =
        ref.read(chatMessagesProvider(widget.args.conversationId));
    final allMessages = messagesAsync.valueOrNull ?? [];

    // تبدیل ID های انتخاب شده به مدل‌های کامل پیام
    // (این برای سرویس لازم است تا بتواند URL فایل‌ها را برای حذف پیدا کند)
    final List<MessageModel> selectedMessagesList = [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    bool allMyMessages = true;

    for (final id in _selectedMessageIds) {
      final msg = allMessages.firstWhere(
        (m) => m.id == id,
        orElse: () => MessageModel.empty(),
      );

      if (msg.id.isNotEmpty) {
        selectedMessagesList.add(msg);
        // بررسی مالکیت
        if (msg.senderId != currentUserId) {
          allMyMessages = false;
        }
      }
    }

    if (selectedMessagesList.isEmpty) return;

    // نمایش دیالوگ
    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: allMyMessages,
      messageCount: selectedMessagesList.length,
    );

    if (!result.confirmed) return;

    final messagesToDelete = List<String>.from(_selectedMessageIds);
    _exitSelectionMode();
    _startDeleteAnimation(messagesToDelete);
    logInfo('message_delete_requested: ${messagesToDelete.join(",")}');
    unawaited(_persistDeleteAfterAnimation(
      messageIds: messagesToDelete,
      deleteForEveryone: result.deleteForEveryone,
    ));

    final suffix = result.deleteForEveryone ? ' برای همه' : '';
    _showSuccessSnackBar(
        '${messagesToDelete.length} پیام حذف شد$suffix'.toPersianDigit());
  }

  void _startDeleteAnimation(List<String> messageIds) {
    for (var i = 0; i < messageIds.length; i++) {
      final id = messageIds[i];
      Future.delayed(Duration(milliseconds: i * 36), () {
        if (!mounted) return;
        setState(() {
          _deletingMessageIds.add(id);
          _hiddenMessageIds.add(id);
        });
      });
    }
  }

  Future<void> _persistDeleteAfterAnimation({
    required List<String> messageIds,
    required bool deleteForEveryone,
  }) async {
    final wait = 260 + (messageIds.length * 36);
    await Future.delayed(Duration(milliseconds: wait));
    try {
      await _tombstoneService.markDeletedLocallyBatch(
        messageIds: messageIds,
        conversationId: widget.args.conversationId,
        deleteForEveryone: deleteForEveryone,
      );
    } catch (e, s) {
      logError('Failed to persist message tombstones', error: e, stackTrace: s);
    }
    if (!mounted) return;
    setState(() {
      _deletingMessageIds.removeAll(messageIds);
    });
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
                    isTyping: _isOtherUserTyping, // استفاده از متغیر صحیح
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
      ),
      child: widget.args.otherUserAvatar != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.args.otherUserAvatar!,
                fit: BoxFit.cover,
                // ✅ بسیار مهم: آواتار ۴۰ پیکسلی نباید عکس ۲۰۰۰ پیکسلی در رم نگه دارد
                memCacheWidth: 100,
                memCacheHeight: 100,
                placeholder: (context, url) => _buildAvatarText(theme),
                errorWidget: (_, __, ___) => _buildAvatarText(theme),
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
    ChatTheme theme, {
    required double bottomPadding, // پارامتر جدید
  }) {
    return messagesAsync.when(
      data: (allMessages) {
        // ✅ فیلتر پیام‌های مخفی شده (حذف شده برای من)
        // اما پیام‌های در حال حذف را نگه دار (برای انیمیشن پودر شدن)
        final filteredMessages = allMessages
            .where((m) =>
                !_hiddenMessageIds.contains(m.id) ||
                _deletingMessageIds.contains(m.id))
            .toList();

        // Isar query is already sorted (newest first).
        final messages = filteredMessages;

        if (messages.isEmpty) {
          return _buildEmptyState(theme);
        }

        return RepaintBoundary(
            child: CustomScrollView(
          controller: _scrollController,
          reverse: true,
          // ✅ اضافه کردن cacheExtent
          // مقدار 300 یعنی حدود ۳-۴ پیام قبل از دیده شدن در حافظه رندر شوند
          // این کار پرش‌های ریز هنگام اسکرول سریع را حذف می‌کند
          cacheExtent: 300,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ✅ مهم: پدینگ پایین لیست برای اینکه زیر اینپوت نرود
            // چون لیست reverse است، اولین آیتم slivers پایین‌ترین نقطه بصری است
            if (bottomPadding > 0)
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
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

                  // ✅ درست: فقط اگر پیام در حال حذف شدن است انیمیشن را اعمال کن
                  final isDeleting = _deletingMessageIds.contains(message.id);

                  // ساخت ویجت پیام (DateDivider + Bubble + Unread)
                  Widget messageWidget = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Divider
                      if (showDateDivider)
                        date_divider.DateDivider(date: message.createdAt),

                      // ✅ استفاده از Builder برای گرفتن کانتکست RenderBox
                      Builder(
                        builder: (itemContext) {
                          return GestureDetector(
                            behavior: HitTestBehavior
                                .translucent, // کلیک روی فضای خالی
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleMessageSelection(message.id);
                              } else {
                                FocusScope.of(context).unfocus();
                              }
                            },
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              if (_isSelectionMode) {
                                _toggleMessageSelection(message.id);
                              } else {
                                // ✅ حالا itemContext یک RenderBox است (چون دور Row پیچیده شده)
                                // و دیگر خطای RenderSliverList نمی‌دهد.
                                _showTelegramContextMenu(itemContext, message);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              child: RepaintBoundary(
                                child: Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    // Selection checkbox
                                    if (_isSelectionMode)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: AnimatedScale(
                                          scale: _isSelectionMode ? 1.0 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: GestureDetector(
                                            onTap: () =>
                                                _toggleMessageSelection(
                                                    message.id),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _selectedMessageIds
                                                        .contains(message.id)
                                                    ? context.chatTheme
                                                        .sendButtonColor
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: _selectedMessageIds
                                                          .contains(message.id)
                                                      ? context.chatTheme
                                                          .sendButtonColor
                                                      : context.chatTheme
                                                          .secondaryTextColor,
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
                                      child: Opacity(
                                        opacity: _temporarilyHiddenMessages
                                                .contains(message.id)
                                            ? 0.0
                                            : 1.0,
                                        child: (!_isSelectionMode)
                                            ? SwipeToReplyWrapper(
                                                isMe: isMe,
                                                onReply: () {
                                                  setState(() =>
                                                      _replyToMessage =
                                                          message);
                                                  _focusNode.requestFocus();
                                                },
                                                child: _buildBubbleContent(
                                                    message,
                                                    isMe,
                                                    index,
                                                    isFirstInGroup,
                                                    isLastInGroup,
                                                    messages),
                                              )
                                            : _buildBubbleContent(
                                                message,
                                                isMe,
                                                index,
                                                isFirstInGroup,
                                                isLastInGroup,
                                                messages),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Unread Divider
                      if (_shouldShowUnreadDivider(message, index, messages))
                        UnreadMessagesDivider(
                          unreadCount: _unreadCount,
                          onTap: _scrollToBottom,
                        ),
                    ],
                  );

                  // ✅ استفاده از MolecularDeleteAnimation برای افکت پودر شدن
                  return MolecularDeleteAnimation(
                    isDeleting: isDeleting,
                    onAnimationComplete: () {
                      if (mounted) {
                        setState(() {
                          _deletingMessageIds.remove(message.id);
                        });
                      }
                    },
                    child: messageWidget,
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
        ));
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
    final hasBelow = index > 0;
    final belowMessage = hasBelow ? messages[index - 1] : null;
    final hasAbove = index < messages.length - 1;
    final aboveMessage = hasAbove ? messages[index + 1] : null;

    final bool sameAsAbove = hasAbove &&
        TimeUtils.isInSameGroup(
          currentMessage.createdAt,
          aboveMessage!.createdAt,
          currentMessage.senderId,
          aboveMessage.senderId,
        );

    final bool sameAsBelow = hasBelow &&
        TimeUtils.isInSameGroup(
          belowMessage!.createdAt,
          currentMessage.createdAt,
          belowMessage.senderId,
          currentMessage.senderId,
        );

    final isFirstInGroup = !sameAsAbove;
    final isLastInGroup = !sameAsBelow;

    return (isFirstInGroup, isLastInGroup);
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
                    chatMessagesProvider(widget.args.conversationId));
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 🖊️ INPUT AREA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInputArea(ChatTheme theme, bool reduceEffects) {
    return AnimatedChatInput(
      controller: _messageController,
      focusNode: _focusNode,
      onSend: _sendMessage,
      onAttachment: _handleAttachment,
      onVoice: _handleVoice,
      onChanged: _onTextChanged,
      onGifSelected: _handleGifSelected,
      replyToContent: _replyToMessage?.content,
      replyToSenderName: _replyToMessage?.senderId == _currentUserId
          ? '\u0634\u0645\u0627'
          : widget.args.otherUserName,
      onCancelReply: () => setState(() => _replyToMessage = null),
      onVoiceRecorded: _handleVoiceRecorded,
      onAutocomplete: _handleAutocomplete,
      onHeightChanged: _onInputHeightChanged,
      reduceEffects: reduceEffects,
    );
  }

  /// Handle voice recording
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
        await ref.read(chatActionControllerProvider.notifier).sendMessage(
              conversationId: params.conversationId,
              content: params.content,
              attachmentUrl: params.attachmentUrl,
              attachmentType: params.attachmentType,
              replyToMessageId: params.replyToMessageId,
            );
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

  /// Handle ارسال GIF
  Future<void> _handleGifSelected(String gifUrl) async {
    if (!mounted || gifUrl.isEmpty) return;

    debugPrint('🎞️ ModernChatScreen: Sending GIF: $gifUrl');

    try {
      final params = SendMessageParams(
        conversationId: widget.args.conversationId,
        content: '', // محتوای خالی برای GIF
        attachmentUrl: gifUrl,
        attachmentType: 'gif', // نوع attachment
        replyToMessageId: _replyToMessage?.id,
        replyToContent: _replyToMessage?.content,
        replyToSenderName: _replyToMessage?.senderId == _currentUserId
            ? 'شما'
            : widget.args.otherUserName,
      );

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
                replyToMessageId: params.replyToMessageId,
              );

      if (!mounted) return;

      if (result.isSuccess) {
        // پاک کردن reply اگر وجود داشت
        if (_replyToMessage != null) {
          setState(() => _replyToMessage = null);
        }

        // Scroll به پایین
        _scrollToBottom();

        // ✅ آپدیت آخرین پیام برای sync تیک در لیست مکالمات
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _registerLastMessage();
        });

        _showSuccessSnackBar('گیف ارسال شد');
      } else {
        _showErrorSnackBar(result.error ?? 'خطا در ارسال گیف');
      }
    } catch (e) {
      debugPrint('❌ Error sending GIF: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در ارسال گیف');
      }
    }
  }

  void _onTextChanged(String text) {
    if (!mounted) return;
    if (text.isNotEmpty) {
      try {
        if (_currentUserId != null) {
          ref
              .read(typingServiceProvider)
              .startTyping(widget.args.conversationId, _currentUserId!);
        }
      } catch (e) {
        debugPrint('Error starting typing: $e');
      }
    }
  }

  /// Handle autocomplete triggers (@mention or #hashtag)
  void _handleAutocomplete(String? query, String type) {
    if (!mounted) return;

    if (query == null || query.isEmpty) {
      return;
    }

    // For now, we'll just store the query - in a full implementation
    // you would fetch user suggestions here
    debugPrint('Autocomplete: type=$type, query=$query');
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
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
              );

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
      currentUserProfile: _currentUserProfile,
    );
  }

  Future<void> _handleAttachmentSelected(AttachmentSelection selection) async {
    if (!mounted) return;
    if (selection.files.isEmpty) return;

    final sendMode = switch (selection.type) {
      ChatAttachmentType.gallery => ChatSendMode.gallery,
      ChatAttachmentType.camera => ChatSendMode.camera,
      ChatAttachmentType.file => ChatSendMode.file,
    };

    final attachmentService = ChatAttachmentService();

    for (final file in selection.files) {
      if (!mounted) break;

      final validation = _uploadPolicyService.validateFile(
        file: file,
        profile: _currentUserProfile,
        mode: sendMode,
      );
      if (!validation.isAllowed) {
        _showErrorSnackBar(validation.error ?? 'فایل مجاز نیست');
        continue;
      }

      String? url;
      String attachmentType = validation.attachmentType ?? 'file';

      if (attachmentType == 'image') {
        url = await _uploadWithProgress(file, 'image', attachmentService);
      } else {
        url = await _uploadWithProgress(file, 'file', attachmentService);
      }

      if (url != null && url.isNotEmpty && mounted) {
        final params = SendMessageParams(
          conversationId: widget.args.conversationId,
          content: selection.caption ?? '',
          attachmentUrl: url,
          attachmentType: attachmentType,
          attachmentFileName: file.path.split('/').last,
        );

        try {
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
              );
          if (mounted) _scrollToBottom();
        } catch (e) {
          debugPrint('Error sending attachment: $e');
        }
      }
    }
  }

  /// آپلود فایل با progress - اصلاح شده
  /// این متد فایل ورودی را مستقیماً آپلود می‌کند بدون باز کردن picker
  Future<String?> _uploadWithProgress(
    File file,
    String type,
    ChatAttachmentService service,
  ) async {
    try {
      AttachmentResult result;

      switch (type) {
        case 'image':
          // ✅ اصلاح: به جای pickImageFromGallery از متد جدید uploadImage استفاده کن
          result = await service.uploadImage(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress:
                null, // اگر می‌خواهی progress نشان بدی باید callback اضافه کنی
          );
          break;

        case 'video':
          // ✅ برای ویدیو از متد جدید uploadVideo استفاده می‌کنیم
          result = await service.uploadVideo(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: null,
          );
          break;

        default:
          // ✅ برای فایل‌های عمومی از متد جدید uploadFile استفاده می‌کنیم
          result = await service.uploadFile(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: null,
          );
          break;
      }

      return result.success ? result.url : null;
    } catch (e) {
      debugPrint('❌ خطا در آپلود فایل: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در آپلود فایل');
      }
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

  /// Navigate to Chat Details Screen
  void _navigateToChatDetails() async {
    // اگر گروه است به صفحه جزئیات گروه برو
    if (widget.args.isGroup || widget.args.otherUserId.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GroupDetailsScreen(
            conversationId: widget.args.conversationId,
          ),
        ),
      );
      return;
    }

    // چت خصوصی
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => VistaChatProfileScreen(
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

  /// ✅ تغییر: Long Press → ورود به حالت Selection
  /// این متد دیگر استفاده نمی‌شود - onLongPress مستقیماً از ImprovedAnimatedMessageBubble صدا زده می‌شود

  /// ✅ Double Tap → Like سریع (بدون تغییر)
  void _onMessageDoubleTap(MessageModel message) {
    _onAddReaction(message, '❤️');
  }

  /// ✅ تابع جدید: نمایش Context Menu به سبک تلگرام
  void _showTelegramContextMenu(
      BuildContext bubbleContext, MessageModel message) async {
    // 1. Force close keyboard aggressively
    // استفاده از هر دو روش برای اطمینان از بسته شدن و ماندن در حالت بسته
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // کمی صبر بیشتر برای اطمینان از آپدیت شدن State فلاتر
    await Future.delayed(const Duration(milliseconds: 150));

    // چک کردن mounted بعد از delay
    if (!mounted) return;

    // 2. گرفتن مختصات دقیق حباب پیام از روی Context
    final RenderBox? renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // fallback به BottomSheet قدیمی
      _showMessageOptions(message);
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final Rect messageRect =
        Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    final theme = context.chatTheme;
    final isMe = message.senderId == _currentUserId;
    final isGif = message.attachmentType == 'gif';
    final isImage = message.attachmentType == 'image';
    final isVideo = message.attachmentType == 'video';
    final isVoice =
        message.attachmentType == 'voice' || message.attachmentType == 'audio';
    final isDocument = message.attachmentType != null &&
        ![
          'gif',
          'image',
          'video',
          'voice',
          'audio',
          'location',
          'contact',
          'post'
        ].contains(message.attachmentType);

    // 2. ساخت ویجت برای نمایش در Overlay
    final previewWidget = _buildMessagePreviewWidget(message, isMe);

    // 3. مخفی کردن پیام اصلی در لیست
    setState(() {
      _temporarilyHiddenMessages.add(message.id);
    });

    // 4. ساخت آیتم‌های منو
    final items = <TelegramContextMenuItem>[
      // Reply
      TelegramContextMenuItem(
        icon: Icons.reply_rounded,
        label: 'پاسخ',
        onTap: () {
          setState(() => _replyToMessage = message);
          _focusNode.requestFocus();
        },
      ),

      // Copy (فقط برای متن)
      if (!isGif &&
          !isImage &&
          !isVideo &&
          !isVoice &&
          message.content.isNotEmpty)
        TelegramContextMenuItem(
          icon: Icons.copy_rounded,
          label: 'کپی متن',
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.content));
            _showSuccessSnackBar('متن کپی شد');
          },
        ),

      // گزینه‌های مخصوص GIF
      if (isGif) ...[
        TelegramContextMenuItem(
          icon: Icons.gif_box_outlined,
          label: 'ذخیره GIF',
          onTap: () => _saveGif(message),
        ),
        TelegramContextMenuItem(
          icon: Icons.open_in_browser_rounded,
          label: 'باز کردن در مرورگر',
          onTap: () => _openGifInBrowser(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص عکس
      if (isImage) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره عکس',
          onTap: () => _saveImage(message),
        ),
        TelegramContextMenuItem(
          icon: Icons.open_in_new_rounded,
          label: 'باز کردن در مرورگر',
          onTap: () => _openInBrowser(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص ویدیو
      if (isVideo) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره ویدیو',
          onTap: () => _saveVideo(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص صدا
      if (isVoice) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره صدا',
          onTap: () => _saveVoice(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص فایل
      if (isDocument) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'دانلود فایل',
          onTap: () => _downloadFile(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // Forward
      TelegramContextMenuItem(
        icon: Icons.forward_rounded,
        label: 'فوروارد',
        onTap: () => _forwardMessage(message),
      ),

      // ✅ جزئیات پیام (گزینه جدید)
      TelegramContextMenuItem(
        icon: Icons.info_outline_rounded,
        label: 'جزئیات پیام',
        onTap: () => _showMessageDetails(message),
      ),

      // Edit (فقط برای پیام‌های متنی خودم)
      if (isMe &&
          !isGif &&
          !isImage &&
          !isVideo &&
          !isVoice &&
          message.attachmentUrl == null)
        TelegramContextMenuItem(
          icon: _canEditMessages ? Icons.edit_rounded : Icons.lock_outline,
          label: 'ویرایش',
          color: _canEditMessages ? null : Colors.amber,
          onTap: () {
            if (_canEditMessages) {
              _editMessage(message);
            } else {
              _showUpgradeDialog();
            }
          },
        ),

      const TelegramContextMenuItem.divider(),

      // Select
      TelegramContextMenuItem(
        icon: Icons.check_circle_outline_rounded,
        label: 'انتخاب چندتایی',
        onTap: () => _enterSelectionMode(message.id),
      ),

      // Delete
      TelegramContextMenuItem(
        icon: Icons.delete_outline_rounded,
        label: 'حذف',
        color: theme.errorColor,
        onTap: () => _deleteMessage(message),
      ),
    ];

    // 5. نمایش منو
    TelegramContextMenu.show(
      context: context,
      messageWidget: previewWidget,
      messageRect: messageRect, // پاس دادن مختصات
      isMyMessage: isMe,
      items: items,
      // ✅ استفاده از لیست کامل ایموجی‌ها (از kDefaultReactions)
      // برای GIF، صدا و فایل ری‌اکشن نمایش داده نمی‌شود
      quickReactions:
          (isGif || isVoice || isDocument) ? null : kDefaultReactions,
      onReactionSelected: (emoji) => _onAddReaction(message, emoji),
      onDismiss: () {
        // 6. وقتی منو بسته شد، پیام اصلی را برگردان
        if (mounted) {
          setState(() {
            _temporarilyHiddenMessages.remove(message.id);
          });
        }
      },
    );
  }

  /// ✅ اصلاح شده: ساخت Widget پیام برای Preview
  /// اگر پیام پست است، کارت گرافیکی پست را نمایش می‌دهد (نه کد JSON)
  Widget _buildMessagePreviewWidget(MessageModel message, bool isMe) {
    // 1. اگر پیام پست است، ویجت پست را برگردان تا کارت گرافیکی دیده شود نه کد JSON
    if (message.isSharedPost ||
        message.sharedPostData != null ||
        message.messageType == 'post' ||
        message.messageType == 'shared_post' ||
        message.attachmentType == 'post') {
      // استفاده از IgnorePointer برای اینکه دکمه‌های پست در حالت پیش‌نمایش کار نکنند
      return IgnorePointer(
        child: _buildPostMessageBubble(message, isMe),
      );
    }

    // 2. برای سایر پیام‌ها همان حباب معمولی
    return ImprovedAnimatedMessageBubble(
      key: ValueKey('preview_${message.id}'),
      messageId: message.id,
      content: message.content,
      isMe: isMe,
      time: message.createdAt,
      status: _getMessageStatus(message),
      attachmentUrl: message.attachmentUrl,
      attachmentType: message.attachmentType,
      duration: message.duration,
      replyToContent: message.replyToContent,
      replyToSenderName: message.replyToSenderName,
      replyToMessageId: message.replyToMessageId,
      onStoryReplyTap: (_) {},
      reactions:
          _convertToOldReactionFormat(_messageReactions[message.id] ?? []),
      // ✅ غیرفعال کردن تعاملات در Preview
      onTap: (context, message) {},
      onLongPress: (context, message) {},
      onDoubleTap: () {},
      onAddReaction: (emoji) {},
      animate: false,
      index: 0,
      isFirstInGroup: true,
      isLastInGroup: true,
      isForwarded: message.isForwarded,
      forwardedFrom: message.forwardedFromSenderName,
      message: message,
    );
  }

  /// ✅ تابع جدید: نمایش جزئیات پیام
  void _showMessageDetails(MessageModel message) {
    // تشخیص نوع پیام
    final isDocument = message.attachmentType == 'document' ||
        (message.attachmentType != null &&
            ![
              'gif',
              'image',
              'video',
              'voice',
              'audio',
              'location',
              'contact',
              'post'
            ].contains(message.attachmentType));

    if (isDocument && message.attachmentUrl != null) {
      // نمایش Document Preview
      _showDocumentPreview(message);
    } else if (message.attachmentType == 'location') {
      // Location: از LocationMessageBubble باز می‌شود
      _showSuccessSnackBar('روی مکان کلیک کنید تا در نقشه باز شود');
    } else {
      // نمایش Message Info Screen
      _showMessageInfo(message);
    }
  }

  Future<void> _openStoryReply(StoryReplyData data) async {
    if (!mounted) return;

    // نمایش لودینگ کوتاه برای جلوگیری از دوبار کلیک
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(storyRepositoryProvider);

      final storyResult = await repository.getStoryById(data.storyId);
      if (!storyResult.isSuccess || storyResult.data == null) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('استوری پیدا نشد');
        }
        return;
      }

      final story = storyResult.data!;
      if (story.isExpired) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('استوری منقضی شده');
        }
        return;
      }

      List<Story> stories = [];
      final userStoriesResult =
          await repository.getUserStories(data.storyOwnerId);
      if (userStoriesResult.isSuccess && userStoriesResult.data != null) {
        stories = userStoriesResult.data!;
      }

      if (stories.isEmpty) {
        stories = [story];
      }

      var index = stories.indexWhere((s) => s.id == story.id);
      if (index == -1) {
        stories = [story, ...stories];
        index = 0;
      }

      final storyUser = _buildStoryUserForReply(data, stories);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryPlayerScreen(
              users: [storyUser],
              initialUserIndex: 0,
              initialStoryIndex: index,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('خطا در باز کردن استوری');
      }
    }
  }

  StoryUser _buildStoryUserForReply(StoryReplyData data, List<Story> stories) {
    ProfileModel? profile;
    if (data.storyOwnerId == _currentUserId) {
      profile = _currentUserProfile;
    } else if (data.storyOwnerId == widget.args.otherUserId) {
      profile = _otherUserProfile;
    }

    StoryVerificationType verificationType = StoryVerificationType.none;
    if (profile != null) {
      switch (profile.verificationType) {
        case VerificationType.blueTick:
          verificationType = StoryVerificationType.blue;
          break;
        case VerificationType.goldTick:
          verificationType = StoryVerificationType.gold;
          break;
        case VerificationType.blackTick:
          verificationType = StoryVerificationType.black;
          break;
        case VerificationType.none:
          verificationType = StoryVerificationType.none;
          break;
      }
    }

    final username = data.storyOwnerUsername.isNotEmpty
        ? data.storyOwnerUsername
        : (profile?.username ?? widget.args.otherUserName);

    return StoryUser(
      id: data.storyOwnerId,
      username: username,
      avatarUrl: profile?.avatarUrl ?? widget.args.otherUserAvatar,
      isVerified: profile?.isVerified ?? false,
      isPremium: profile?.role == 'premium',
      verificationType: verificationType,
      stories: stories,
      lastStoryAt:
          stories.isNotEmpty ? stories.last.createdAt : data.storyCreatedAt,
    );
  }

  void _onAddReaction(MessageModel message, String emoji) {
    if (!mounted) return;

    HapticFeedback.lightImpact();
    try {
      ref.read(chatActionControllerProvider.notifier).toggleReaction(
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
    final isGif = message.attachmentType == 'gif'; // ✅ تشخیص GIF

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

              // ✅ Quick Reactions (برای همه پیام‌ها به جز GIF)
              if (!isGif)
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

              if (!isGif) const Divider(),

              // ✅ گزینه‌های مخصوص GIF
              if (isGif) ...[
                _buildOptionTile(
                  icon: Icons.gif_box_outlined,
                  label: 'ذخیره GIF',
                  onTap: () {
                    Navigator.pop(context);
                    _saveGif(message);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.open_in_browser_rounded,
                  label: 'باز کردن در مرورگر',
                  onTap: () {
                    Navigator.pop(context);
                    _openGifInBrowser(message);
                  },
                ),
                const Divider(),
              ],

              // گزینه‌های عمومی
              _buildOptionTile(
                icon: Icons.reply_rounded,
                label: 'پاسخ',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyToMessage = message);
                  _focusNode.requestFocus();
                },
              ),

              // ✅ کپی فقط برای پیام‌های متنی (نه GIF)
              if (!isGif && message.content.isNotEmpty)
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

              // ویرایش فقط برای پیام‌های متنی خودم (نه GIF)
              if (isMe && !isGif && message.attachmentUrl == null)
                _buildOptionTile(
                  icon: _canEditMessages
                      ? Icons.edit_rounded
                      : Icons.lock_outline,
                  label: 'ویرایش',
                  color: _canEditMessages ? null : Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    if (_canEditMessages) {
                      _editMessage(message);
                    } else {
                      _showUpgradeDialog();
                    }
                  },
                ),

              // حذف
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

    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: isMe,
      messageCount: 1,
    );

    if (!result.confirmed) return;

    _startDeleteAnimation([message.id]);
    logInfo('message_delete_requested: ${message.id}');
    unawaited(_persistDeleteAfterAnimation(
      messageIds: [message.id],
      deleteForEveryone: result.deleteForEveryone,
    ));

    final suffix = result.deleteForEveryone ? ' برای همه' : '';
    _showSuccessSnackBar('پیام حذف شد$suffix');
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
      ref.invalidate(chatMessagesProvider(widget.args.conversationId));
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

  /// ذخیره GIF در گالری
  Future<void> _saveGif(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک گیف یافت نشد');
      return;
    }

    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('در حال دانلود...'),
              ],
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }

      // دانلود GIF
      final dio = Dio();
      final response = await dio.get(
        message.attachmentUrl!,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره بایت‌ها در فایل موقت
      final tempDir = await getTemporaryDirectory();
      final fileName = 'gif_${DateTime.now().millisecondsSinceEpoch}.gif';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(response.data));

      // ذخیره در گالری
      await Gal.putImage(tempFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccessSnackBar('گیف در گالری ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error saving GIF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showErrorSnackBar('خطا در ذخیره گیف');
      }
    }
  }

  /// باز کردن GIF در مرورگر
  Future<void> _openGifInBrowser(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک گیف یافت نشد');
      return;
    }

    try {
      final uri = Uri.parse(message.attachmentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showErrorSnackBar('خطا در باز کردن لینک');
        }
      }
    } catch (e) {
      debugPrint('Error opening GIF in browser: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در باز کردن لینک');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💾 SAVE MEDIA (متدهای کمکی)
  // ═══════════════════════════════════════════════════════════════════════════

  /// ذخیره عکس
  Future<void> _saveImage(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک تصویر یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'image', 'عکس');
  }

  /// ذخیره ویدیو
  Future<void> _saveVideo(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک ویدیو یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'video', 'ویدیو');
  }

  /// ذخیره صدا
  Future<void> _saveVoice(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک صدا یافت نشد');
      return;
    }
    // برای صدا از downloadFile استفاده می‌کنیم
    await _downloadFile(message);
  }

  /// باز کردن در مرورگر
  Future<void> _openInBrowser(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک یافت نشد');
      return;
    }

    try {
      final uri = Uri.parse(message.attachmentUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showErrorSnackBar('خطا در باز کردن لینک');
        }
      }
    } catch (e) {
      debugPrint('Error opening in browser: $e');
      if (mounted) {
        _showErrorSnackBar('خطا در باز کردن لینک');
      }
    }
  }

  /// دانلود فایل
  Future<void> _downloadFile(MessageModel message) async {
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک فایل یافت نشد');
      return;
    }

    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('در حال دانلود...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // دانلود فایل
      final response = await Dio().get(
        message.attachmentUrl!,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره در Downloads
      final fileName = message.attachmentFileName ??
          'file_${DateTime.now().millisecondsSinceEpoch}';

      // استفاده از path_provider
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      if (mounted) {
        _showSuccessSnackBar('فایل در $filePath ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      if (mounted) {
        _showErrorSnackBar(e);
      }
    }
  }

  /// متد کمکی برای ذخیره رسانه در گالری
  Future<void> _saveMediaToGallery(
      String url, String type, String typeName) async {
    try {
      // نمایش loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('در حال دانلود...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // دانلود
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // ذخیره بایت‌ها در فایل موقت
      final tempDir = await getTemporaryDirectory();
      final extension = type == 'image' ? 'jpg' : 'png';
      final fileName =
          '${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(Uint8List.fromList(response.data));

      // ذخیره در گالری
      await Gal.putImage(tempFile.path);

      if (mounted) {
        _showSuccessSnackBar('$typeName در گالری ذخیره شد');
      }
    } catch (e) {
      debugPrint('Error saving media: $e');
      if (mounted) {
        _showErrorSnackBar(e);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📢 SNACKBARS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSuccessSnackBar(String message) {
    UserFriendlyErrorUtils.showSuccessSnackBar(context, message);
  }

  void _showErrorSnackBar(dynamic error) {
    UserFriendlyErrorUtils.showErrorSnackBar(context, error);
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
                  await ref
                      .read(chatActionControllerProvider.notifier)
                      .toggleReaction(
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
      // ✅ کد جدید: استفاده مستقیم از دیتای مدل (پارس شده در fromJson)
      final postData = message.sharedPostData;

      if (postData == null) {
        // Fallback به پیام متنی معمولی
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
          onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
          onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
        );
      }

      // ✅ Extract اطلاعات پست از SharedPostData
      final postId = postData.postId.isNotEmpty ? postData.postId : message.id;
      final authorName = postData.postAuthorName.isNotEmpty
          ? postData.postAuthorName
          : (isMe ? 'شما' : widget.args.otherUserName);
      final authorAvatar = postData.postAuthorAvatar;
      final authorUsername = postData.postAuthorUsername;
      final postContent = postData.postContent;
      final mediaUrls = postData.postImageUrl != null
          ? [postData.postImageUrl!]
          : (postData.postVideoUrl != null ? [postData.postVideoUrl!] : null);
      final likesCount = postData.likeCount;
      final commentsCount = postData.commentCount;
      final postCreatedAt = postData.postCreatedAt;
      final verificationType = postData.verificationType;
      final hashtags = null; // SharedPostData فعلاً hashtags ندارد

      // ✅ ساختار جدید برای کنترل کامل کلیک‌ها
      return Stack(
        children: [
          // ویجت پست
          GestureDetector(
            // اولویت کلیک با ماست
            onTap: () {
              if (_isSelectionMode) {
                _toggleMessageSelection(message.id);
              } else {
                _navigateToPostScreen(postId);
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              if (_isSelectionMode) {
                _toggleMessageSelection(message.id);
              } else {
                // پاس دادن context درست برای باز شدن منو روی پست
                _showTelegramContextMenu(context, message);
              }
            },
            child: AbsorbPointer(
              // اگر در حالت انتخاب هستیم، اجازه نده دکمه‌های داخلی پست (لایک و...) کار کنند
              absorbing: _isSelectionMode,
              child: InstagramStylePostCard(
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
                status: _getMessageStatus(message),
                // callbacks داخلی ویجت را خالی می‌گذاریم چون GestureDetector والد هندل می‌کند
                onTap: () {},
                onLongPress: () {},
                onShare: () async {
                  if (!_isSelectionMode) {
                    final result = await ForwardMessageSheet.show(
                      context,
                      messageIds: [message.id],
                    );
                    if (result == true) {
                      _showSuccessSnackBar('پست ارسال شد');
                    }
                  }
                },
              ),
            ),
          ),

          // ✅ لایه آبی رنگ (Selection Overlay) روی پست
          if (_selectedMessageIds.contains(message.id))
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: context.chatTheme.sendButtonColor
                      .withOpacity(0.3), // کمی پررنگ تر برای دیده شدن روی عکس
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.chatTheme.sendButtonColor,
                    width: 3,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 48,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
                  ),
                ),
              ),
            ),
        ],
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
        onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
        onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// اسکرول به پیام خاص
  void _scrollToMessage(String? messageId) {
    if (messageId == null) return;

    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      // اسکرول به پیام
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // پیام را در وسط صفحه قرار می‌دهد
      );

      // هایلایت کردن پیام برای چند لحظه
      setState(() {
        _highlightedMessageId = messageId;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      // پیام در لیست فعلی موجود نیست (شاید باید لود شود یا دور است)
      _showErrorSnackBar('پیام در دسترس نیست');
    }
  }

  /// متد کمکی برای تمیز شدن کد بالا
  Widget _buildBubbleContent(MessageModel message, bool isMe, int index,
      bool isFirstInGroup, bool isLastInGroup, List<MessageModel> messages) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: _highlightedMessageId == message.id
            ? context.chatTheme.sendButtonColor.withOpacity(0.2)
            : _selectedMessageIds.contains(message.id)
                ? context.chatTheme.sendButtonColor.withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: message.attachmentType == 'post'
          ? Builder(
              builder: (postContext) => _buildPostMessageBubble(message, isMe),
            )
          : ImprovedAnimatedMessageBubble(
              key: _messageKeys[message.id] ??=
                  GlobalKey(), // ✅ استفاده از GlobalKey ذخیره شده
              messageId: message.id,
              content: message.content,
              isMe: isMe,
              time: message.createdAt,
              status: _getMessageStatus(message),
              attachmentUrl: message.attachmentUrl,
              attachmentType: message.attachmentType,

              // ✅ اضافه کردن هندلر تپ روی ریپلی
              replyToContent: message.replyToContent,
              replyToSenderName: message.replyToSenderName,
              replyToMessageId: message.replyToMessageId,
              onReplyTap: () => _scrollToMessage(message.replyToMessageId),
              onStoryReplyTap: _openStoryReply,

              duration: message.duration,
              reactions: _convertToOldReactionFormat(
                  _messageReactions[message.id] ?? []),
              onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
              onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
              onDoubleTap: () => _onMessageDoubleTap(message),
              onAddReaction: (emoji) => _onAddReaction(message, emoji),
              animate: index < 5 && !_isNearTop,
              index: index,
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
              isForwarded: message.isForwarded,
              forwardedFrom: message.forwardedFromSenderName,
              message: message,
            ),
    );
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
