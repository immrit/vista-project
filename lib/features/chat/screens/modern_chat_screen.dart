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
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/message_model.dart';
import '../../../utils/compat_extensions.dart';
import '../../../utils/time_utils.dart';
import '../providers/chat_providers.dart';
import '../repositories/chat_repository.dart';
import '../services/e2e_encryption_service.dart';
import '../domain/message_payload.dart';

// ✅ Theme & Widgets
import '../theme/chat_theme.dart';
import '../widgets/enhanced_chat_background.dart';
import '../widgets/telegram_reaction_picker.dart'
    show kDefaultReactions, TelegramReactionPicker;
import '../widgets/retry_indicator_widget.dart' show TelegramConnectionBanner;
import '../widgets/improved_animated_message_bubble.dart';
import '../widgets/telegram_context_menu.dart';
import '../widgets/animated_chat_input.dart';
import '../widgets/voice_input_state.dart';
import '../widgets/instagram_style_post_card.dart';
import '../widgets/date_divider.dart' as date_divider;
import '../widgets/swipe_to_reply_wrapper.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/telegram_message_status.dart';

// ✅ Providers
import '../../../provider/typing_provider.dart';
import '../../../provider/presence_provider.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../../../provider/settings_providers.dart';
import '../../../services/telegram_read_receipt_service.dart';
import '../../../services/current_user_service.dart';

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
import '../services/chat_transfer_manager.dart';
import '../services/attachment_type_resolver.dart';
import '../services/audio_metadata_service.dart';
import '../services/upload_policy_service.dart';
import '../services/message_tombstone_service.dart';
import '../../../services/typing_service.dart'; // ✅ سرویس تایپینگ
import '../../../services/current_chat_tracker.dart';
import '../../../services/PushNotificationService.dart';
import '../../../services/instant_message_deletion.dart';
import '../widgets/block_report_bottom_sheet.dart';
import '../services/user_moderation_service.dart';
import '../services/voice_duration_service.dart';
import '../services/message_reactions_service.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/telegram_emoji_text.dart';
import '../../emoji/widgets/telegram_emoji_text_editing_controller.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../security/logging_utility.dart';
import '../models/message_reaction.dart' as reaction_models;
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/posts/screens/PostDetailPage.dart';
import '../../stories/presentation/providers/story_providers.dart';
import '../../stories/presentation/screens/story_player_screen.dart';
import '../../stories/domain/entities/entities.dart';
import 'package:uuid/uuid.dart';

// ✅ Phase 4: Final Integration
import 'telegram_profile_screen.dart';
import 'group_details_screen.dart';
import 'document_preview_screen.dart';
import '../screens/message_info_screen.dart';
// TODO: Use CompleteDeletionService for delete with undo
// import '../services/complete_deletion_service.dart';
import '../services/message_actions_service.dart';
import '../widgets/molecular_delete_animation.dart';
import '../performance/adaptive_effects_provider.dart';
import '../performance/chat_performance_profile.dart';
import '../services/secret_chat_privacy_service.dart';
// So importing the file should expose it.

/// پارامترهای صفحه چت
class ChatScreenArgs {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;
  final bool isGroup;
  final bool isSecret;
  final String? initialReplyContent;
  final String? initialReplySenderName;
  final String? initialReplySenderId;
  final bool initialReplyFromNote;
  final String? initialDraftMessage;

  const ChatScreenArgs({
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
    this.isGroup = false,
    this.isSecret = false,
    this.initialReplyContent,
    this.initialReplySenderName,
    this.initialReplySenderId,
    this.initialReplyFromNote = false,
    this.initialDraftMessage,
  });
}

class _PendingReplyContext {
  const _PendingReplyContext({
    required this.content,
    required this.senderName,
    required this.senderId,
    this.fromNote = false,
  });

  final String content;
  final String senderName;
  final String senderId;
  final bool fromNote;
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

  final _messageController = TelegramEmojiTextEditingController(
    useTelegramEmoji: EmojiRenderPolicy.useTelegramEmojiRenderer(),
  );
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // انیمیشن‌ها
  late AnimationController _appBarAnimController;
  late Animation<double> _appBarAnimation;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════════════

  MessageModel? _replyToMessage;
  _PendingReplyContext? _pendingReplyContext;
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
  DateTime? _lastVisibleDateUpdateAt;
  DateTime? _lastScrollVelocitySampleAt;
  DateTime? _lastReactionWindowUpdateAt;
  double _lastScrollVelocitySampleOffset = 0;

  // Typing status
  bool _isOtherUserTyping = false;
  StreamSubscription<Set<String>>? _typingSubscription;

  // ✅ برای جلوگیری از اجرای منطق در build
  String? _lastFirstMessageId;
  List<MessageModel> _latestVisibleMessages = const [];

  // Unread messages
  String? _lastReadMessageId;
  int _unreadCount = 0;

  // Services
  final _moderationService = UserModerationService();
  final _voiceService = VoiceDurationService();
  final _audioMetadataService = const AudioMetadataService();
  final _chatTransferManager = ChatTransferManager();
  final UploadPolicyService _uploadPolicyService = const UploadPolicyService();
  final AttachmentTypeResolver _attachmentTypeResolver =
      const AttachmentTypeResolver();
  final MessageTombstoneService _tombstoneService = MessageTombstoneService();
  late final ChatRepository _chatRepository;
  late final TypingService _typingService;
  late final AdaptiveEffectsController _adaptiveEffectsController;
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

  // Reactions cache - isolated notifiers to avoid full-screen rebuilds.
  final Map<String, ValueNotifier<List<reaction_models.MessageReaction>>>
      _messageReactionNotifiers = {};
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
  bool _isPollingRefreshInFlight = false;
  Timer? _floatingDateHideTimer;
  Timer? _activeConversationHeartbeatTimer;
  Timer? _typingDebounceTimer;
  final List<Timer> _scheduledSendTimers = <Timer>[];
  final Map<String, Timer> _pendingDeleteTimers = <String, Timer>{};
  final Map<String, Timer> _secretAutoDeleteTimers = <String, Timer>{};
  final Set<String> _secretAutoDeletingIds = <String>{};
  final List<_SecretSystemNotice> _secretSystemNotices =
      <_SecretSystemNotice>[];
  int _secretAutoDeleteSeconds = 0;
  DateTime? _secretAutoDeleteEnabledAt;
  SecretKey? _secretSharedSecret;
  final Map<String, String> _secretDecryptedContentByMessageId =
      <String, String>{};
  final Set<String> _secretDecryptInFlight = <String>{};
  ProviderSubscription<AsyncValue<List<MessageModel>>>? _messagesListener;
  ProviderSubscription<AsyncValue<Map<String, dynamic>>>?
      _performanceSettingsListener;
  ProviderSubscription<AsyncValue<ConnectionStatus>>?
      _connectionStatusListener;
  ConnectionStatus _latestConnectionStatus = ConnectionStatus.connecting;
  bool _showConnectionBannerAfterDelay = false;
  Timer? _connectionBannerDelayTimer;

  @override
  void initState() {
    super.initState();
    _chatRepository = ref.read(chatRepositoryProvider);
    _typingService = ref.read(typingServiceProvider);
    _adaptiveEffectsController = ref.read(adaptiveEffectsProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    _checkBlockStatus();
    _fetchUserProfileIfNeeded();
    _loadHiddenMessages();
    _initSecretChatPolicy();

    // ✅ شروع گوش دادن به Read Receipts
    _initReadReceipts();

    // ✅ لیسنرهای وضعیت تایپ کردن
    _initTypingListeners();
    _setupMessageSideEffectsListener();
    _setupConnectionStatusBannerListener();
    _setupAdaptiveEffects();
    _bootstrapInitialReplyContext();

    // ✅ تنظیم چت فعال برای جلوگیری از دریافت بج پیام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatRepository.setActiveConversation(widget.args.conversationId);
        CurrentChatTracker.instance.setOpenConversation(
          widget.args.conversationId,
        );
        ref
            .read(pushNotificationServiceProvider)
            .cancelConversationNotification(widget.args.conversationId);
        _startActiveConversationHeartbeat();
      }
    });

    // ✅ آپدیت فوری بج پیام (اگر پیام خوانده نشده داشتیم)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatRepository.resetUnreadCount(widget.args.conversationId);

        _chatRepository.markMessagesAsSeen(widget.args.conversationId);
      }
    });

    // ✅ Polling Fallback: هر 30 ثانیه برای اطمینان از دریافت پیام‌ها
    _startPolling();
  }

  void _bootstrapInitialReplyContext() {
    final initialContent = widget.args.initialReplyContent?.trim() ?? '';
    if (initialContent.isEmpty) return;

    _pendingReplyContext = _PendingReplyContext(
      content: initialContent,
      senderName: (widget.args.initialReplySenderName ?? widget.args.otherUserName)
          .trim(),
      senderId: widget.args.initialReplySenderId ?? widget.args.otherUserId,
      fromNote: widget.args.initialReplyFromNote,
    );

    final initialDraft = widget.args.initialDraftMessage?.trim() ?? '';
    if (initialDraft.isNotEmpty) {
      _messageController.text = initialDraft;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  String? get _activeReplyContent =>
      _replyToMessage?.content ?? _pendingReplyContext?.content;

  String? get _activeReplySenderName {
    if (_replyToMessage != null) {
      return _replyToMessage!.senderId == _currentUserId
          ? 'شما'
          : widget.args.otherUserName;
    }
    if (_pendingReplyContext == null) return null;
    if (_pendingReplyContext!.fromNote) {
      return 'یادداشت ${_pendingReplyContext!.senderName}';
    }
    return _pendingReplyContext!.senderName;
  }

  String? _resolveReplyToMessageId({
    MessageModel? replyTo,
    _PendingReplyContext? pendingReply,
  }) {
    if (replyTo != null) return replyTo.id;
    if (pendingReply?.fromNote == true) {
      final noteOwnerId = pendingReply!.senderId.trim();
      if (noteOwnerId.isNotEmpty) return 'note:$noteOwnerId';
    }
    return null;
  }

  String? _resolveReplyToKind({
    MessageModel? replyTo,
    _PendingReplyContext? pendingReply,
  }) {
    if (replyTo != null) return 'message';
    if (pendingReply?.fromNote == true) return 'note';
    return null;
  }

  bool _isSyntheticNoteReplyId(String? replyToMessageId) =>
      (replyToMessageId?.trim().startsWith('note:') ?? false);

  void _clearReplyContext() {
    setState(() {
      _replyToMessage = null;
      _pendingReplyContext = null;
    });
  }

  void _setReplyToMessage(MessageModel message) {
    setState(() {
      _pendingReplyContext = null;
      _replyToMessage = message;
    });
    _focusNode.requestFocus();
  }

  void _initTypingListeners() {
    _typingSubscription?.cancel();

    // Listen to typing updates
    _typingSubscription = _typingService
        .getTypingStream(widget.args.conversationId)
        .listen((typingUsers) {
      final currentUserId = _currentUserId;
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

    final currentUserId = _currentUserId;
    final initialTypingUsers =
        _typingService.getTypingUsers(widget.args.conversationId);
    final initialIsTyping =
        initialTypingUsers.any((id) => id != currentUserId && id.isNotEmpty);
    if (_isOtherUserTyping != initialIsTyping) {
      setState(() {
        _isOtherUserTyping = initialIsTyping;
      });
    }
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

  void _setupConnectionStatusBannerListener() {
    _connectionStatusListener =
        ref.listenManual<AsyncValue<ConnectionStatus>>(
      chatConnectionStatusProvider,
      (previous, next) {
        final status = next.valueOrNull;
        if (status == null) return;
        _latestConnectionStatus = status;

        if (status == ConnectionStatus.connected) {
          _connectionBannerDelayTimer?.cancel();
          _connectionBannerDelayTimer = null;
          if (_showConnectionBannerAfterDelay && mounted) {
            setState(() {
              _showConnectionBannerAfterDelay = false;
            });
          }
          return;
        }

        if (_showConnectionBannerAfterDelay ||
            _connectionBannerDelayTimer != null) {
          return;
        }

        _connectionBannerDelayTimer = Timer(const Duration(seconds: 5), () {
          _connectionBannerDelayTimer = null;
          if (!mounted) return;
          if (_latestConnectionStatus != ConnectionStatus.connected) {
            setState(() {
              _showConnectionBannerAfterDelay = true;
            });
          }
        });
      },
      fireImmediately: true,
    );
  }

  void _setupAdaptiveEffects() {
    // Ensure frame monitoring starts for this screen.
    ref.read(frameBudgetServiceProvider);

    _performanceSettingsListener =
        ref.listenManual<AsyncValue<Map<String, dynamic>>>(
      performanceSettingsProvider,
      (previous, next) {
        next.whenData((settings) {
          final animationsRaw = settings['animations'];
          final renderingRaw = settings['rendering'];
          final featureFlagsRaw = settings['feature_flags'];
          final animations = animationsRaw is Map
              ? Map<String, dynamic>.from(animationsRaw)
              : null;
          final rendering = renderingRaw is Map
              ? Map<String, dynamic>.from(renderingRaw)
              : null;
          final featureFlags = featureFlagsRaw is Map
              ? Map<String, dynamic>.from(featureFlagsRaw)
              : null;
          _adaptiveEffectsController.applySettings(
            animations: animations,
            rendering: rendering,
            featureFlags: featureFlags,
          );
        });
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

    // فیلتر کردن پیام‌های سیستمی سکرت چت از UI
    final displayMessages = visibleMessages
        .where((m) =>
            m.messageType != 'exchange_key' &&
            m.messageType != 'exchange_key_reply' &&
            m.attachmentType != 'exchange_key' &&
            m.attachmentType != 'exchange_key_reply')
        .toList();

    unawaited(_decryptVisibleSecretMessages(displayMessages));
    final uiMessages = _applySecretUiContent(displayMessages);
    _latestVisibleMessages = uiMessages;
    _rescheduleSecretAutoDelete(uiMessages);

    if (widget.args.isSecret) {
      _processSecretChatKeyExchange(allMessages);
    }

    if (visibleMessages.any((m) => !m.isMe && !m.isSeen)) {
      unawaited(_chatRepository.markMessagesAsSeen(widget.args.conversationId));
    }

    _calculateUnreadCount(visibleMessages);

    if (uiMessages.isEmpty) {
      _latestVisibleMessages = const [];
      _lastFirstMessageId = null;
      if (_currentVisibleDate != null || _isScrolling) {
        setState(() {
          _currentVisibleDate = null;
          _isScrolling = false;
        });
      }
      return;
    }

    final firstId = uiMessages.first.id;
    if (_lastFirstMessageId != firstId) {
      _lastFirstMessageId = firstId;
      _loadReactionsForMessages(uiMessages);
    }
    _updateReactionWindow(DateTime.now(), force: true, messages: uiMessages);

    if (_scrollController.hasClients && _scrollController.offset < 100) {
      final newDate = uiMessages.first.createdAt;
      if (_currentVisibleDate == null ||
          !_isSameDay(_currentVisibleDate!, newDate)) {
        _showFloatingDateTemporarily(newDate);
      }
    }
  }

  Future<void> _processSecretChatKeyExchange(
      List<MessageModel> messages) async {
    final e2e = E2EEncryptionService();
    final prefs = await SharedPreferences.getInstance();
    final conversationId = widget.args.conversationId;
    final peerPubB64 = prefs.getString('e2e_peer_pub_$conversationId');

    // اگر کلید طرف مقابل را داریم، دیگر نیازی به هندل کردن پیام‌های تبادل کلید نیست
    if (peerPubB64 != null) return;

    // ۱. بررسی پیام exchange_key از طرف مقابل
    final peerKeyMessage = messages.firstWhere(
      (m) =>
          (m.messageType == 'exchange_key' ||
              m.attachmentType == 'exchange_key') &&
          !m.isMe,
      orElse: () => MessageModel.empty(),
    );

    if (peerKeyMessage.id.isNotEmpty) {
      // کلید عمومی طرف مقابل را ذخیره می‌کنیم
      await prefs.setString(
          'e2e_peer_pub_$conversationId', peerKeyMessage.content);

      // حالا پاسخ (کلید خودمان) را می‌فرستیم
      final myKeyPair = await e2e.getSavedKeyPair(_currentUserId!) ??
          await e2e.generateAndSaveKeyPair(_currentUserId!);
      final myPubBytes = await e2e.getPublicKeyBytes(myKeyPair);

      await _chatRepository.sendMessage(MessagePayload(
        conversationId: conversationId,
        content: base64Encode(myPubBytes),
        attachmentType: 'exchange_key_reply',
      ));

      _addSecretSystemNotice(
          'کلید امنیتی با موفقیت تبادل شد. ارتباط رمزنگاری شده برقرار است.');
      unawaited(_prepareSecretSharedSecret());
      return;
    }

    // ۲. اگر پیام از طرف مقابل نیامده، آیا خودمان قبلاً exchange_key فرستاده‌ایم؟
    final myKeyMessage = messages.firstWhere(
      (m) =>
          (m.messageType == 'exchange_key' ||
              m.attachmentType == 'exchange_key') &&
          m.isMe,
      orElse: () => MessageModel.empty(),
    );

    if (myKeyMessage.id.isEmpty) {
      // خودمان شروع کننده تبادل کلید می‌شویم
      final myKeyPair = await e2e.getSavedKeyPair(_currentUserId!) ??
          await e2e.generateAndSaveKeyPair(_currentUserId!);
      final myPubBytes = await e2e.getPublicKeyBytes(myKeyPair);

      await _chatRepository.sendMessage(MessagePayload(
        conversationId: conversationId,
        content: base64Encode(myPubBytes),
        attachmentType: 'exchange_key',
      ));
      _addSecretSystemNotice('در حال تبادل کلید رمزنگاری با طرف مقابل...');
    }

    // ۳. آیا پاسخ (exchange_key_reply) از طرف مقابل آمده؟
    final peerReplyMessage = messages.firstWhere(
      (m) =>
          (m.messageType == 'exchange_key_reply' ||
              m.attachmentType == 'exchange_key_reply') &&
          !m.isMe,
      orElse: () => MessageModel.empty(),
    );

    if (peerReplyMessage.id.isNotEmpty) {
      await prefs.setString(
          'e2e_peer_pub_$conversationId', peerReplyMessage.content);
      _addSecretSystemNotice(
          'ارتباط کاملا امن و رمزنگاری شده (E2EE) برقرار شد.');
      unawaited(_prepareSecretSharedSecret());
    }
  }

  bool _looksEncryptedSecretPayload(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('e2ee:v1:')) return true;
    if (text.startsWith('{') || text.contains(' ') || text.contains('\n')) {
      return false;
    }
    final base64Like = RegExp(r'^[A-Za-z0-9+/=]+$');
    return text.length >= 32 && base64Like.hasMatch(text);
  }

  bool _canAttemptSecretDecrypt(MessageModel message) {
    if (!widget.args.isSecret) return false;
    final type = (message.attachmentType ?? message.messageType ?? 'text')
        .toLowerCase()
        .trim();
    if (type == 'exchange_key' || type == 'exchange_key_reply') return false;
    if (type != 'text') return false;
    return _looksEncryptedSecretPayload(message.content);
  }

  Future<void> _decryptVisibleSecretMessages(
      List<MessageModel> messages) async {
    if (!widget.args.isSecret || messages.isEmpty) return;
    if (_secretSharedSecret == null) {
      await _prepareSecretSharedSecret();
    }
    final secret = _secretSharedSecret;
    if (secret == null) return;

    final e2e = E2EEncryptionService();
    var changed = false;

    for (final message in messages) {
      if (!_canAttemptSecretDecrypt(message)) continue;
      if (_secretDecryptedContentByMessageId.containsKey(message.id)) continue;
      if (_secretDecryptInFlight.contains(message.id)) continue;

      _secretDecryptInFlight.add(message.id);
      try {
        final clear = await e2e.decryptMessage(message.content, secret);
        if (clear.isNotEmpty && clear != '[پیام غیرقابل رمزگشایی]') {
          _secretDecryptedContentByMessageId[message.id] = clear;
          changed = true;
        }
      } catch (_) {
        // keep secure placeholder
      } finally {
        _secretDecryptInFlight.remove(message.id);
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  List<MessageModel> _applySecretUiContent(List<MessageModel> messages) {
    if (!widget.args.isSecret || messages.isEmpty) return messages;
    return messages.map((message) {
      if (!_canAttemptSecretDecrypt(message)) return message;
      final clear = _secretDecryptedContentByMessageId[message.id];
      if (clear != null && clear.isNotEmpty) {
        return message.copyWith(content: clear);
      }
      return message.copyWith(content: 'پیام رمزنگاری‌شده');
    }).toList(growable: false);
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

    final messages =
        _latestVisibleMessages.isNotEmpty ? _latestVisibleMessages : null;
    if (messages != null && messages.isNotEmpty) {
      final myLastMessage = messages.firstWhere(
        (m) => m.senderId == _currentUserId,
        orElse: () => messages.first,
      );

      TelegramReadReceiptService().setLastMessageId(
        widget.args.conversationId,
        myLastMessage.id,
      );
      return;
    }

    final messagesAsync =
        ref.read(chatMessagesProvider(widget.args.conversationId));
    messagesAsync.whenData((messagesFromProvider) {
      if (messagesFromProvider.isEmpty) return;

      final myLastMessage = messagesFromProvider.firstWhere(
        (m) => m.senderId == _currentUserId,
        orElse: () => messagesFromProvider.first,
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

  Future<void> _loadCurrentUser() async {
    _currentUserId = await CurrentUserService.instance.resolveUserId();
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

  Future<void> _initSecretChatPolicy() async {
    if (!widget.args.isSecret) return;

    await SecretChatPrivacyService.instance.enableSecureDisplay();
    await _loadSecretAutoDeleteTimerSetting();
    await _initE2EEncryption();
    await _prepareSecretSharedSecret();
  }

  Future<void> _initE2EEncryption() async {
    final e2e = E2EEncryptionService();
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    // ۱. مطمئن می‌شویم که برای خودمان کلید داریم
    var myKeyPair = await e2e.getSavedKeyPair(userId);
    myKeyPair ??= await e2e.generateAndSaveKeyPair(userId);
  }

  Future<void> _prepareSecretSharedSecret() async {
    if (!widget.args.isSecret) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final peerPubB64 =
          prefs.getString('e2e_peer_pub_${widget.args.conversationId}');
      if (peerPubB64 == null || peerPubB64.isEmpty) {
        _secretSharedSecret = null;
        return;
      }

      final e2e = E2EEncryptionService();
      final myKeyPair = await e2e.getSavedKeyPair(currentUserId);
      if (myKeyPair == null) {
        _secretSharedSecret = null;
        return;
      }

      _secretSharedSecret = await e2e.computeSharedSecret(
        myKeyPair: myKeyPair,
        peerPublicKeyBytes: base64Decode(peerPubB64),
      );
    } catch (_) {
      _secretSharedSecret = null;
    }
  }

  String get _secretAutoDeletePrefKey =>
      'secret_auto_delete_seconds_${widget.args.conversationId}';
  String get _secretAutoDeleteEnabledAtPrefKey =>
      'secret_auto_delete_enabled_at_ms_${widget.args.conversationId}';

  Future<void> _loadSecretAutoDeleteTimerSetting() async {
    if (!widget.args.isSecret) return;
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_secretAutoDeletePrefKey) ?? 0;
    final enabledAtMs = prefs.getInt(_secretAutoDeleteEnabledAtPrefKey);
    DateTime? enabledAt;
    if (enabledAtMs != null && enabledAtMs > 0) {
      enabledAt = DateTime.fromMillisecondsSinceEpoch(enabledAtMs);
    } else if (seconds > 0) {
      enabledAt = DateTime.now();
      await prefs.setInt(
        _secretAutoDeleteEnabledAtPrefKey,
        enabledAt.millisecondsSinceEpoch,
      );
    }
    if (!mounted) return;
    setState(() {
      _secretAutoDeleteSeconds = seconds;
      _secretAutoDeleteEnabledAt = seconds > 0 ? enabledAt : null;
    });
  }

  Future<void> _setSecretAutoDeleteTimer(int seconds) async {
    if (!widget.args.isSecret) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final enabledAt = seconds > 0 ? now : null;
    await prefs.setInt(_secretAutoDeletePrefKey, seconds);
    if (enabledAt != null) {
      await prefs.setInt(
        _secretAutoDeleteEnabledAtPrefKey,
        enabledAt.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_secretAutoDeleteEnabledAtPrefKey);
    }
    if (!mounted) return;
    setState(() {
      _secretAutoDeleteSeconds = seconds;
      _secretAutoDeleteEnabledAt = enabledAt;
    });
    _rescheduleSecretAutoDelete(_latestVisibleMessages);
    final label = _secretAutoDeleteLabel(seconds);
    _addSecretSystemNotice('تایمر حذف خودکار روی $label تنظیم شد');
    _showSuccessSnackBar('حذف خودکار: $label');
  }

  Future<void> _pickSecretAutoDeleteTimer() async {
    if (!widget.args.isSecret) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final options = <int>[0, 10, 30, 60, 60 * 5, 60 * 60, 60 * 60 * 24];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'تایمر حذف خودکار',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final seconds in options)
                ListTile(
                  title: Text(_secretAutoDeleteLabel(seconds)),
                  trailing: Icon(
                    _secretAutoDeleteSeconds == seconds
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _secretAutoDeleteSeconds == seconds
                        ? Colors.green
                        : Theme.of(context).hintColor,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext, seconds);
                  },
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || selected == _secretAutoDeleteSeconds) return;
    await _setSecretAutoDeleteTimer(selected);
  }

  String _secretAutoDeleteLabel(int seconds) {
    if (seconds <= 0) return 'خاموش';
    if (seconds < 60) return '$seconds ثانیه';
    if (seconds < 3600) return '${seconds ~/ 60} دقیقه';
    if (seconds < 86400) return '${seconds ~/ 3600} ساعت';
    return '${seconds ~/ 86400} روز';
  }

  String _secretAutoDeleteStatusText() {
    if (_secretAutoDeleteSeconds <= 0) return 'حذف خودکار خاموش';
    return 'حذف خودکار: ${_secretAutoDeleteLabel(_secretAutoDeleteSeconds)}';
  }

  void _addSecretSystemNotice(String text) {
    if (!mounted || !widget.args.isSecret) return;
    setState(() {
      _secretSystemNotices.insert(
        0,
        _SecretSystemNotice(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      if (_secretSystemNotices.length > 10) {
        _secretSystemNotices.removeRange(10, _secretSystemNotices.length);
      }
    });
  }

  void _rescheduleSecretAutoDelete(List<MessageModel> messages) {
    if (!widget.args.isSecret ||
        _secretAutoDeleteSeconds <= 0 ||
        _secretAutoDeleteEnabledAt == null) {
      for (final timer in _secretAutoDeleteTimers.values) {
        timer.cancel();
      }
      _secretAutoDeleteTimers.clear();
      return;
    }

    final activeIds = messages.map((m) => m.id).toSet();
    final staleIds = _secretAutoDeleteTimers.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _secretAutoDeleteTimers.remove(id)?.cancel();
    }

    final now = DateTime.now();
    final activationTime = _secretAutoDeleteEnabledAt!;
    for (final message in messages) {
      if (_hiddenMessageIds.contains(message.id) ||
          _deletingMessageIds.contains(message.id) ||
          _secretAutoDeletingIds.contains(message.id) ||
          message.isPending ||
          message.isFailed == true) {
        continue;
      }
      if (message.createdAt.isBefore(activationTime)) {
        // پیام‌های قبل از فعال‌شدن تایمر نباید حذف شوند.
        continue;
      }
      if (_secretAutoDeleteTimers.containsKey(message.id)) continue;

      final expiresAt =
          message.createdAt.add(Duration(seconds: _secretAutoDeleteSeconds));
      final delay = expiresAt.difference(now);
      if (delay <= Duration.zero) {
        unawaited(_runSecretAutoDelete(message.id));
        continue;
      }
      _secretAutoDeleteTimers[message.id] = Timer(delay, () {
        _secretAutoDeleteTimers.remove(message.id);
        unawaited(_runSecretAutoDelete(message.id));
      });
    }
  }

  Future<void> _runSecretAutoDelete(String messageId) async {
    if (!widget.args.isSecret || _secretAutoDeletingIds.contains(messageId)) {
      return;
    }
    _secretAutoDeletingIds.add(messageId);
    if (mounted) {
      setState(() {
        _deletingMessageIds.add(messageId);
        _hiddenMessageIds.add(messageId);
      });
    }
    await Future.delayed(const Duration(milliseconds: 340));
    try {
      var result =
          await _chatRepository.deleteMessage(messageId, forEveryone: true);
      if (!result.isSuccess) {
        result =
            await _chatRepository.deleteMessage(messageId, forEveryone: false);
      }
      if (!result.isSuccess) {
        debugPrint('Secret auto-delete failed for $messageId: ${result.error}');
      }
    } catch (e) {
      debugPrint('Secret auto-delete error for $messageId: $e');
    } finally {
      _secretAutoDeletingIds.remove(messageId);
      if (mounted) {
        setState(() {
          _deletingMessageIds.remove(messageId);
        });
      }
    }
  }

  StreamSubscription<SseConnectionState>? _realtimeSubscription;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingDebounceTimer?.cancel();
    // توقف تایپ هنگام خروج - با try-catch برای جلوگیری از خطا
    try {
      if (_currentUserId != null) {
        _typingService.stopTyping(widget.args.conversationId, _currentUserId!);
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
    _connectionBannerDelayTimer?.cancel();
    _floatingDateHideTimer?.cancel();
    _activeConversationHeartbeatTimer?.cancel();
    _realtimeSubscription?.cancel();
    for (final timer in _scheduledSendTimers) {
      timer.cancel();
    }
    _scheduledSendTimers.clear();
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    _pendingDeleteTimers.clear();
    for (final timer in _secretAutoDeleteTimers.values) {
      timer.cancel();
    }
    _secretAutoDeleteTimers.clear();
    _secretAutoDeletingIds.clear();
    _messagesListener?.close();
    _performanceSettingsListener?.close();
    _connectionStatusListener?.close();

    for (final notifier in _messageReactionNotifiers.values) {
      notifier.dispose();
    }
    _messageReactionNotifiers.clear();
    _adaptiveEffectsController.updateScrollVelocity(0);

    _scrollEndTimer?.cancel();
    _appBarAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();

    _clearActiveConversationState();
    if (widget.args.isSecret) {
      unawaited(SecretChatPrivacyService.instance.disableSecureDisplay());
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CurrentChatTracker.instance
          .setOpenConversation(widget.args.conversationId);
      _chatRepository.setActiveConversation(widget.args.conversationId);
      _startActiveConversationHeartbeat();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _activeConversationHeartbeatTimer?.cancel();
      CurrentChatTracker.instance.clearOpenConversation();
      _chatRepository.setActiveConversation(null);
    }
  }

  void _startActiveConversationHeartbeat() {
    _activeConversationHeartbeatTimer?.cancel();
    _activeConversationHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
      CurrentChatTracker.instance.heartbeat(widget.args.conversationId);
      _chatRepository.setActiveConversation(widget.args.conversationId);
    });
  }

  void _clearActiveConversationState() {
    CurrentChatTracker.instance.clearOpenConversation();
    try {
      _chatRepository.setActiveConversation(null);
    } catch (_) {}
  }

  Future<void> _triggerPollingRefresh() async {
    if (!mounted || _isPollingRefreshInFlight) return;
    _isPollingRefreshInFlight = true;
    try {
      await ref
          .read(chatRepositoryProvider)
          .refreshMessages(widget.args.conversationId);
    } finally {
      _isPollingRefreshInFlight = false;
    }
  }

  void _startPolling() {
    // Keep chat near real-time even when SSE is temporarily disconnected.
    // Polling is only active while realtime is down.
    final repo = _chatRepository;

    _realtimeSubscription = repo.realtimeStatus.listen((status) {
      if (status == SseConnectionState.connected) {
        _pollingTimer?.cancel();
        _pollingTimer = null;
      } else {
        unawaited(_triggerPollingRefresh());
        _pollingTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
          unawaited(_triggerPollingRefresh());
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📜 SCROLL
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _scrollEndTimer;
  static const Duration _scrollVelocitySampleInterval =
      Duration(milliseconds: 120);
  static const Duration _reactionWindowUpdateInterval =
      Duration(milliseconds: 180);
  static const double _reactionEstimateItemExtent = 88.0;
  static const int _reactionWindowBuffer = 10;

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final now = DateTime.now();
    final currentScroll = _scrollController.position.pixels;
    _sampleScrollVelocity(now, currentScroll);
    _updateReactionWindow(now);

    bool needsSetState = false;

    // 1. Pagination Logic
    final maxScroll = _scrollController.position.maxScrollExtent;

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
            _updateVisibleDate(force: true);
          }
        });
      }
    });

    // ✅ فقط یک بار setState انجام میدهیم اگر واقعا چیزی تغییر کرده باشد
    if (needsSetState) {
      setState(() {});
    }
  }

  void _sampleScrollVelocity(DateTime now, double currentScroll) {
    final lastSampleAt = _lastScrollVelocitySampleAt;
    if (lastSampleAt == null) {
      _lastScrollVelocitySampleAt = now;
      _lastScrollVelocitySampleOffset = currentScroll;
      return;
    }

    final elapsed = now.difference(lastSampleAt);
    if (elapsed < _scrollVelocitySampleInterval) return;

    final delta = (currentScroll - _lastScrollVelocitySampleOffset).abs();
    final velocity = elapsed.inMilliseconds == 0
        ? 0.0
        : (delta * 1000.0 / elapsed.inMilliseconds);

    _lastScrollVelocitySampleAt = now;
    _lastScrollVelocitySampleOffset = currentScroll;
    _adaptiveEffectsController.updateScrollVelocity(velocity);
  }

  void _updateVisibleDate({bool force = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    final now = DateTime.now();
    if (!force &&
        _lastVisibleDateUpdateAt != null &&
        now.difference(_lastVisibleDateUpdateAt!).inMilliseconds < 120) {
      return;
    }
    _lastVisibleDateUpdateAt = now;

    try {
      final messages = _latestVisibleMessages;
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
    } catch (e) {
      debugPrint('Error in _updateVisibleDate: $e');
    }
  }

  void _updateReactionWindow(
    DateTime now, {
    bool force = false,
    List<MessageModel>? messages,
  }) {
    if (!mounted) return;
    if (!force &&
        _lastReactionWindowUpdateAt != null &&
        now.difference(_lastReactionWindowUpdateAt!) <
            _reactionWindowUpdateInterval) {
      return;
    }
    _lastReactionWindowUpdateAt = now;

    if (messages != null) {
      _setupReactionsStream(messages);
      return;
    }
    if (_latestVisibleMessages.isNotEmpty) {
      _setupReactionsStream(_latestVisibleMessages);
    }
  }

  List<MessageModel> _selectReactionWindow(List<MessageModel> messages) {
    if (messages.isEmpty) return const <MessageModel>[];
    if (!_scrollController.hasClients) {
      final end = math.min(messages.length, 24);
      return messages.sublist(0, end);
    }

    final position = _scrollController.position;
    final currentOffset = position.pixels.clamp(0.0, double.infinity);
    final viewport = position.viewportDimension;
    final visibleCount = math.max(
      8,
      (viewport / _reactionEstimateItemExtent).ceil(),
    );
    final startIndex = (((currentOffset / _reactionEstimateItemExtent).floor() -
                _reactionWindowBuffer)
            .clamp(0, math.max(0, messages.length - 1)))
        .toInt();
    final endExclusive =
        ((startIndex + visibleCount + (_reactionWindowBuffer * 2))
                .clamp(1, messages.length))
            .toInt();

    return messages.sublist(startIndex, endExclusive);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _shouldShowUnreadDividerForRenderItem(
    _ChatRenderItem renderItem,
    int index,
    List<_ChatRenderItem> renderItems,
  ) {
    if (_lastReadMessageId == null) return false;
    final hasBoundaryMessage =
        renderItem.messages.any((m) => m.id == _lastReadMessageId);
    return hasBoundaryMessage && index < renderItems.length - 1;
  }

  List<_ChatRenderItem> _buildRenderItems(List<MessageModel> messages) {
    if (messages.isEmpty) return const <_ChatRenderItem>[];

    final renderItems = <_ChatRenderItem>[];
    var index = 0;

    while (index < messages.length) {
      final current = messages[index];

      if (_isAlbumImageMessage(current)) {
        final grouped = <MessageModel>[current];
        var lookAhead = index + 1;
        final currentGroupId = current.mediaGroupId?.trim();
        final hasExplicitGroupId =
            currentGroupId != null && currentGroupId.isNotEmpty;

        while (lookAhead < messages.length && grouped.length < 10) {
          final candidate = messages[lookAhead];
          if (hasExplicitGroupId) {
            final candidateGroupId = candidate.mediaGroupId?.trim();
            if (!_isAlbumImageMessage(candidate) ||
                candidate.senderId != current.senderId ||
                candidateGroupId != currentGroupId) {
              break;
            }
          } else if (!_canAppendToAlbum(grouped.last, candidate, current)) {
            break;
          }
          grouped.add(candidate);
          lookAhead++;
        }

        if (grouped.length > 1) {
          renderItems.add(
            _ChatRenderItem(
              primaryIndex: index,
              messages: grouped,
            ),
          );
          index = lookAhead;
          continue;
        }
      }

      renderItems.add(
        _ChatRenderItem(
          primaryIndex: index,
          messages: [current],
        ),
      );
      index++;
    }

    return renderItems;
  }

  bool _isAlbumImageMessage(MessageModel message) {
    final hasMediaSource =
        (message.attachmentUrl?.trim().isNotEmpty ?? false) ||
            (message.localFilePath?.trim().isNotEmpty ?? false) ||
            (message.localImagePath?.trim().isNotEmpty ?? false);
    return hasMediaSource && message.isImage;
  }

  bool _canAppendToAlbum(
    MessageModel previousMessage,
    MessageModel candidate,
    MessageModel anchor,
  ) {
    if (!_isAlbumImageMessage(candidate)) return false;
    if (candidate.senderId != anchor.senderId) return false;

    final diffWithPrevious =
        previousMessage.createdAt.difference(candidate.createdAt).abs();
    if (diffWithPrevious > const Duration(seconds: 25)) return false;

    final diffWithAnchor =
        anchor.createdAt.difference(candidate.createdAt).abs();
    return diffWithAnchor <= const Duration(seconds: 60);
  }

  String _resolveAlbumMediaSource(MessageModel message) {
    final localFile = message.localFilePath?.trim() ?? '';
    if (localFile.isNotEmpty) {
      final local = File(localFile);
      if (local.existsSync()) return localFile;
    }

    final localImage = message.localImagePath?.trim() ?? '';
    if (localImage.isNotEmpty) {
      final image = File(localImage);
      if (image.existsSync()) return localImage;
    }

    final remote = message.attachmentUrl?.trim() ?? '';
    return remote;
  }

  List<_AlbumMediaItem> _extractAlbumMediaItems(List<MessageModel> messages) {
    final items = <_AlbumMediaItem>[];
    for (final message in messages) {
      final source = _resolveAlbumMediaSource(message);
      if (source.isEmpty) continue;
      items.add(_AlbumMediaItem(message: message, source: source));
    }
    return items;
  }

  bool _isNetworkMediaSource(String source) {
    final normalized = source.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  _ConversationImageGalleryBundle _buildConversationImageGallery(
    List<MessageModel> messages,
  ) {
    if (messages.isEmpty) return const _ConversationImageGalleryBundle.empty();

    final galleryItems = <GalleryItem>[];
    final indexByMessageId = <String, int>{};

    for (final message in messages.reversed) {
      final id = message.id.trim();
      if (id.isEmpty || indexByMessageId.containsKey(id)) continue;
      if (!_isAlbumImageMessage(message)) continue;

      final source = _resolveAlbumMediaSource(message);
      if (source.isEmpty) continue;

      final caption = message.content.trim();
      final isNetwork = _isNetworkMediaSource(source);
      galleryItems.add(
        GalleryItem(
          imageUrl: source,
          cachedFile: isNetwork ? null : File(source),
          caption: caption.isEmpty ? null : caption,
          heroTag: '${message.id}_${source.hashCode}',
        ),
      );
      indexByMessageId[id] = galleryItems.length - 1;
    }

    return _ConversationImageGalleryBundle(
      items: galleryItems,
      indexByMessageId: indexByMessageId,
    );
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
    if (!mounted) return;
    ref
        .read(chatMessagesProvider(widget.args.conversationId).notifier)
        .loadMore();
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
      final messages = _latestVisibleMessages;
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
    final adaptiveEffects = ref.watch(adaptiveEffectsProvider);
    final reduceEffects = keyboardVisible ||
        _isScrolling ||
        adaptiveEffects.effectsLevel == ChatEffectsLevel.low;
    final messagesAsync = ref.watch(
      chatMessagesProvider(widget.args.conversationId),
    );
    final paginationState = ref.watch(
      paginationStateProvider(widget.args.conversationId),
    );
    final connectionStatusAsync = ref.watch(chatConnectionStatusProvider);
    final connectionStatus = connectionStatusAsync.maybeWhen(
      data: (status) => status,
      orElse: () => ConnectionStatus.connecting,
    );
    final isConnected = connectionStatus == ConnectionStatus.connected;
    final showConnectionBanner = !isConnected && _showConnectionBannerAfterDelay;

    return Stack(
      children: [
        // 1. والپیپر (زیر همه چیز)
        Positioned.fill(
          // ✅ اضافه کردن RepaintBoundary
          // این باعث می‌شود هنگام باز شدن کیبورد، بک‌گراند دوباره Paint نشود (خیلی مهم برای GPU)
          child: RepaintBoundary(
            child: EnhancedChatBackground(
              enablePattern: true,
              forceEnableBlur:
                  reduceEffects ? false : adaptiveEffects.allowHeavyBlur,
              blurIntensity: adaptiveEffects.blurSigma,
              allowHeavyEffects: adaptiveEffects.allowHeavyBlur,
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
                    adaptiveEffects: adaptiveEffects,
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
                  isConnected: !showConnectionBanner,
                  onRetry: !showConnectionBanner
                      ? null
                      : () {
                          unawaited(_triggerPollingRefresh());
                        },
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
                  child: _buildInputArea(theme,
                      reduceEffects: reduceEffects,
                      allowHeavyEffects: adaptiveEffects.allowHeavyBlur,
                      blurSigma: adaptiveEffects.blurSigma),
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
        if (!widget.args.isSecret)
          IconButton(
            icon: const Icon(Icons.forward_rounded, color: Colors.white),
            onPressed:
                _selectedMessageIds.isEmpty ? null : _forwardSelectedMessages,
            tooltip: 'فوروارد',
          ),
        // کپی
        if (!widget.args.isSecret)
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
            onPressed:
                _selectedMessageIds.isEmpty ? null : _copySelectedMessages,
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

  void _enterSelectionModeForMessages(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.addAll(ids);
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

  bool _isRenderItemSelected(_ChatRenderItem renderItem) {
    if (renderItem.messages.isEmpty) return false;
    return renderItem.messages
        .every((message) => _selectedMessageIds.contains(message.id));
  }

  void _toggleRenderItemSelection(_ChatRenderItem renderItem) {
    final ids = renderItem.messages.map((m) => m.id).toSet();
    if (ids.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      final allSelected = ids.every(_selectedMessageIds.contains);
      if (allSelected) {
        _selectedMessageIds.removeAll(ids);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.addAll(ids);
      }
    });
  }

  /// ✅ توابع کمکی یکپارچه برای هندل کردن کلیک و لانگ پرس
  void _handleMessageTap(BuildContext itemContext, MessageModel message) {
    if (_isSelectionMode) {
      _toggleMessageSelection(message.id);
      return;
    }

    // Tap معمولی فقط برای باز کردن جزئیات/پیش‌نمایش مدیا استفاده می‌شود.
    final hasAttachment = (message.attachmentUrl?.isNotEmpty ?? false) ||
        _isSharedPostMessage(message);
    if (hasAttachment) {
      _showMessageDetails(message);
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
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
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
    if (widget.args.isSecret) {
      _showErrorSnackBar('کپی در گفتگوی محرمانه غیرفعال است');
      return;
    }
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
    final currentUserId = _currentUserId;
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

    await _confirmAndDeleteMessages(
      selectedMessagesList,
      allMyMessagesOverride: allMyMessages,
      exitSelectionModeOnSuccess: true,
    );
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
    try {
      await _tombstoneService.markDeletedLocallyBatch(
        messageIds: messageIds,
        conversationId: widget.args.conversationId,
        deleteForEveryone: deleteForEveryone,
      );
    } catch (e, s) {
      logError('Failed to persist message tombstones', error: e, stackTrace: s);
    }
    final wait = 260 + (messageIds.length * 36);
    await Future.delayed(Duration(milliseconds: wait));
    if (!mounted) return;
    setState(() {
      _deletingMessageIds.removeAll(messageIds);
    });
  }

  Future<void> _confirmAndDeleteMessages(
    List<MessageModel> messages, {
    bool? allMyMessagesOverride,
    bool exitSelectionModeOnSuccess = false,
  }) async {
    final messageMap = <String, MessageModel>{};
    for (final message in messages) {
      if (message.id.trim().isEmpty) continue;
      messageMap[message.id] = message;
    }
    final normalizedMessages = messageMap.values.toList(growable: false);
    if (normalizedMessages.isEmpty) return;

    final currentUserId = _currentUserId;
    final allMyMessages = allMyMessagesOverride ??
        normalizedMessages.every((m) => m.senderId == currentUserId);

    final result = await DeleteMessageDialog.show(
      context,
      isMyMessage: allMyMessages,
      messageCount: normalizedMessages.length,
    );

    if (!result.confirmed) return;

    final messageIds =
        normalizedMessages.map((message) => message.id).toList(growable: false);
    if (exitSelectionModeOnSuccess) {
      _exitSelectionMode();
    }

    _startDeleteAnimation(messageIds);
    logInfo('message_delete_requested: ${messageIds.join(",")}');
    final batchId = DateTime.now().microsecondsSinceEpoch.toString();
    final deleteTimer = Timer(const Duration(seconds: 4), () {
      _pendingDeleteTimers.remove(batchId);
      unawaited(_persistDeleteAfterAnimation(
        messageIds: messageIds,
        deleteForEveryone: result.deleteForEveryone,
      ));
      if (mounted) {
        final suffix = result.deleteForEveryone ? ' برای همه' : '';
        _showSuccessSnackBar(
          '${messageIds.length} پیام حذف شد$suffix'.toPersianDigit(),
        );
      }
    });
    _pendingDeleteTimers[batchId] = deleteTimer;

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${messageIds.length} پیام برای حذف آماده شد'.toPersianDigit()),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () {
              final timer = _pendingDeleteTimers.remove(batchId);
              timer?.cancel();
              if (!mounted) return;
              setState(() {
                _deletingMessageIds.removeAll(messageIds);
                _hiddenMessageIds.removeAll(messageIds);
              });
            },
          ),
        ),
      );
    }
  }

  PreferredSizeWidget _buildAppBar(ChatTheme theme) {
    // Selection mode AppBar
    if (_isSelectionMode) {
      return _buildSelectionAppBar(theme);
    }

    return AppBar(
      elevation: 0,
      backgroundColor:
          widget.args.isSecret ? const Color(0xFF1B3D2F) : theme.appBarColor,
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
            if (!widget.args.isSecret &&
                !widget.args.isGroup &&
                widget.args.otherUserId.isNotEmpty)
              const PopupMenuItem(
                value: 'start_secret_chat',
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'شروع گفتگوی محرمانه',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            if (widget.args.isSecret)
              PopupMenuItem(
                value: 'secret_timer',
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'تایمر حذف خودکار (${_secretAutoDeleteLabel(_secretAutoDeleteSeconds)})',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _otherUserProfile?.username ??
                              widget.args.otherUserName,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (widget.args.isSecret)
                        Icon(
                          Icons.lock_rounded, // 🔒 آیکون امنیتی E2EE
                          color:
                              theme.isDark ? Colors.greenAccent : Colors.green,
                          size: 14,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // ✅ وضعیت آنلاین به سبک ویستا - Real-time
                  if (widget.args.isSecret)
                    Row(
                      children: [
                        Icon(
                          _secretAutoDeleteSeconds > 0
                              ? Icons.timer_rounded
                              : Icons.timer_off_outlined,
                          size: 13,
                          color: _secretAutoDeleteSeconds > 0
                              ? Colors.greenAccent
                              : theme.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _secretAutoDeleteStatusText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _secretAutoDeleteSeconds > 0
                                  ? Colors.greenAccent
                                  : theme.secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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
            theme.sendButtonColor.withValues(alpha: 0.8),
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
    final initial = widget.args.otherUserName.trim().isNotEmpty
        ? widget.args.otherUserName.trim()[0].toUpperCase()
        : '?';
    return Center(
      child: Text(
        initial,
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
      case 'start_secret_chat':
        _startSecretChat();
        break;
      case 'secret_timer':
        _pickSecretAutoDeleteTimer();
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

  Future<void> _startSecretChat() async {
    if (widget.args.isSecret ||
        widget.args.isGroup ||
        widget.args.otherUserId.isEmpty) {
      return;
    }

    final result = await _chatRepository.createConversation(
      widget.args.otherUserId,
      isSecret: true,
    );

    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      _showErrorSnackBar(result.error ?? 'ایجاد گفتگوی محرمانه انجام نشد');
      return;
    }

    final secretConversation = result.data!;
    final displayName =
        (_otherUserProfile?.username ?? widget.args.otherUserName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: secretConversation.id,
            otherUserName: displayName,
            otherUserAvatar:
                _otherUserProfile?.avatarUrl ?? widget.args.otherUserAvatar,
            otherUserId: widget.args.otherUserId,
            isGroup: false,
            isSecret: true,
          ),
        ),
      ),
    );
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
              showDeleteConversationDialog(
                context: this.context,
                conversationId: widget.args.conversationId,
                conversationTitle: widget.args.otherUserName,
                isGroupChat: widget.args.isGroup,
                preferredOption: DeleteConversationOption.clearHistory,
                onDeleted: () {
                  ref.invalidate(
                      chatMessagesProvider(widget.args.conversationId));
                },
              );
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
    required AdaptiveEffectsState adaptiveEffects,
    required double bottomPadding, // پارامتر جدید
  }) {
    return messagesAsync.when(
      data: (allMessages) {
        // ✅ فیلتر پیام‌های مخفی شده (حذف شده برای من)
        // اما پیام‌های در حال حذف را نگه دار (برای انیمیشن پودر شدن)
        final filteredMessages = allMessages
            .where((m) =>
                (!_hiddenMessageIds.contains(m.id) ||
                    _deletingMessageIds.contains(m.id)) &&
                m.messageType != 'exchange_key' &&
                m.messageType != 'exchange_key_reply' &&
                m.attachmentType != 'exchange_key' &&
                m.attachmentType != 'exchange_key_reply')
            .toList();

        unawaited(_decryptVisibleSecretMessages(filteredMessages));
        final uiMessages = _applySecretUiContent(filteredMessages);

        // Isar query is already sorted (newest first).
        final messages = uiMessages;
        final renderItems = _buildRenderItems(messages);
        final conversationImageGallery =
            _buildConversationImageGallery(messages);

        if (renderItems.isEmpty) {
          return _buildEmptyState(theme);
        }

        return RepaintBoundary(
            child: CustomScrollView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(300),
          controller: _scrollController,
          reverse: true,
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
                      index == renderItems.length) {
                    return _buildLoadingIndicator(theme);
                  }

                  final renderItem = renderItems[index];
                  final message = renderItem.primaryMessage;
                  final isMe = message.senderId == _currentUserId;

                  // گروه‌بندی پیام‌ها
                  final (isFirstInGroup, isLastInGroup) =
                      _getMessageGroupPosition(
                    messages,
                    renderItem.primaryIndex,
                  );

                  // Date Divider - منطق صحیح برای لیست reverse:
                  // - مقایسه با پیام قدیمی‌تر (index + 1)
                  // - اگر تاریخ فرق داشت، divider نشون بده
                  // - divider باید بالای پیام فعلی باشه (قبل از پیام در Column)
                  // - برای قدیمی‌ترین پیام هم divider نشون بده (وقتی nextMessage null هست)
                  final nextMessage = index < renderItems.length - 1
                      ? renderItems[index + 1].primaryMessage
                      : null;
                  final showDateDivider = date_divider.shouldShowDateDivider(
                    renderItem.oldestMessage.createdAt,
                    nextMessage?.createdAt,
                  );

                  // ✅ درست: فقط اگر پیام در حال حذف شدن است انیمیشن را اعمال کن
                  final isDeleting = renderItem.messages
                      .any((m) => _deletingMessageIds.contains(m.id));

                  // ساخت ویجت پیام (DateDivider + Bubble + Unread)
                  Widget messageWidget = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Divider
                      if (showDateDivider)
                        date_divider.DateDivider(
                            date: renderItem.oldestMessage.createdAt),

                      // ✅ استفاده از Builder برای گرفتن کانتکست RenderBox
                      Builder(
                        builder: (itemContext) {
                          return GestureDetector(
                            behavior: HitTestBehavior
                                .translucent, // کلیک روی فضای خالی
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleRenderItemSelection(renderItem);
                              }
                            },
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              if (_isSelectionMode) {
                                _toggleRenderItemSelection(renderItem);
                              } else {
                                // ✅ حالا itemContext یک RenderBox است (چون دور Row پیچیده شده)
                                // و دیگر خطای RenderSliverList نمی‌دهد.
                                _showTelegramContextMenu(
                                  itemContext,
                                  message,
                                  groupedMessagesOverride: renderItem.isAlbum
                                      ? renderItem.messages
                                      : null,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 2),
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
                                                _toggleRenderItemSelection(
                                                    renderItem),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _isRenderItemSelected(
                                                        renderItem)
                                                    ? context.chatTheme
                                                        .sendButtonColor
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: _isRenderItemSelected(
                                                          renderItem)
                                                      ? context.chatTheme
                                                          .sendButtonColor
                                                      : context.chatTheme
                                                          .secondaryTextColor,
                                                  width: 2,
                                                ),
                                              ),
                                              child: _isRenderItemSelected(
                                                      renderItem)
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
                                        opacity: renderItem.messages.any((m) =>
                                                _temporarilyHiddenMessages
                                                    .contains(m.id))
                                            ? 0.0
                                            : 1.0,
                                        child: (!_isSelectionMode &&
                                                !renderItem.isAlbum)
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
                                                  renderItem.primaryIndex,
                                                  isFirstInGroup,
                                                  isLastInGroup,
                                                  adaptiveEffects,
                                                  conversationGalleryItems:
                                                      conversationImageGallery
                                                          .items,
                                                  conversationGalleryIndexByMessageId:
                                                      conversationImageGallery
                                                          .indexByMessageId,
                                                ),
                                              )
                                            : (renderItem.isAlbum
                                                ? _buildAlbumBubbleContent(
                                                    renderItem,
                                                    isMe,
                                                    adaptiveEffects,
                                                    conversationGalleryItems:
                                                        conversationImageGallery
                                                            .items,
                                                    conversationGalleryIndexByMessageId:
                                                        conversationImageGallery
                                                            .indexByMessageId,
                                                  )
                                                : _buildBubbleContent(
                                                    message,
                                                    isMe,
                                                    renderItem.primaryIndex,
                                                    isFirstInGroup,
                                                    isLastInGroup,
                                                    adaptiveEffects,
                                                    conversationGalleryItems:
                                                        conversationImageGallery
                                                            .items,
                                                    conversationGalleryIndexByMessageId:
                                                        conversationImageGallery
                                                            .indexByMessageId,
                                                  )),
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
                      if (_shouldShowUnreadDividerForRenderItem(
                          renderItem, index, renderItems))
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
                          for (final deletingMessage in renderItem.messages) {
                            _deletingMessageIds.remove(deletingMessage.id);
                          }
                        });
                      }
                    },
                    child: messageWidget,
                  );
                },
                childCount: renderItems.length +
                    (paginationState.isLoadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
            SliverToBoxAdapter(
              child: paginationState.isLoadingMore
                  ? _buildLoadingIndicator(theme)
                  : const SizedBox(height: 20),
            ),
            if (widget.args.isSecret && _secretSystemNotices.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: _secretSystemNotices
                        .map(
                          (notice) => KeyedSubtree(
                            key: ValueKey(notice.id),
                            child: _buildSecretSystemNoticeBubble(notice),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
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
    if (message.isSeen || message.isRead) return MessageStatus.read;
    if (message.isDelivered) return MessageStatus.delivered;
    if (message.isSent) return MessageStatus.sent;
    return MessageStatus.pending;
  }

  /// بارگذاری واکنش‌ها برای پیام‌های فعلی
  Future<void> _loadReactionsForMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    try {
      final windowMessages = _selectReactionWindow(messages);
      if (windowMessages.isEmpty) return;

      final messageIds =
          windowMessages.map((m) => m.id).toList(growable: false);
      final reactionsMap =
          await _reactionsService.getMultipleMessageReactions(messageIds);

      if (!mounted) return;
      for (final message in windowMessages) {
        _reactionNotifierFor(message.id).value =
            reactionsMap[message.id] ?? const [];
      }
    } catch (e) {
      debugPrint('❌ Error loading reactions: $e');
    }
  }

  /// راه‌اندازی real-time stream برای واکنش‌ها
  void _setupReactionsStream(List<MessageModel> messages) {
    if (messages.isEmpty) return;

    // فقط برای 20 پیام آخر stream ایجاد می‌کنیم (برای بهینه‌سازی)
    final windowMessages = _selectReactionWindow(messages);
    if (windowMessages.isEmpty) return;
    final messageIds = windowMessages.map((m) => m.id).toSet();

    // 1. لغو subscriptionهای قدیمی که دیگر نیاز نیستند
    final idsToRemove = _reactionsSubscriptions.keys
        .where((id) => !messageIds.contains(id))
        .toList();

    for (final id in idsToRemove) {
      _reactionsSubscriptions[id]?.cancel();
      _reactionsSubscriptions.remove(id);
      final notifier = _messageReactionNotifiers.remove(id);
      notifier?.dispose();
    }

    // 2. ایجاد subscription برای پیام‌های جدید
    final idsToPrime = <String>[];
    for (final messageId in messageIds) {
      if (!_reactionsSubscriptions.containsKey(messageId)) {
        idsToPrime.add(messageId);
        _reactionsSubscriptions[messageId] = _reactionsService
            .watchMessageReactions(messageId)
            .listen((reactions) {
          if (!mounted) return;
          _reactionNotifierFor(messageId).value = reactions;
        });
      }
    }
    if (idsToPrime.isNotEmpty) {
      _primeReactionWindow(idsToPrime);
    }
  }

  void _primeReactionWindow(List<String> messageIds) {
    unawaited(() async {
      try {
        final reactionsMap =
            await _reactionsService.getMultipleMessageReactions(messageIds);
        if (!mounted) return;
        for (final messageId in messageIds) {
          _reactionNotifierFor(messageId).value =
              reactionsMap[messageId] ?? const [];
        }
      } catch (e) {
        debugPrint('❌ Error priming reaction window: $e');
      }
    }());
  }

  ValueNotifier<List<reaction_models.MessageReaction>> _reactionNotifierFor(
      String messageId) {
    return _messageReactionNotifiers.putIfAbsent(
      messageId,
      () => ValueNotifier<List<reaction_models.MessageReaction>>(const []),
    );
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
            color: theme.secondaryTextColor.withValues(alpha: 0.5),
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
              color: theme.secondaryTextColor.withValues(alpha: 0.7),
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

  Widget _buildInputArea(
    ChatTheme theme, {
    required bool reduceEffects,
    required bool allowHeavyEffects,
    required double blurSigma,
  }) {
    return AnimatedChatInput(
      controller: _messageController,
      focusNode: _focusNode,
      onSend: _sendMessage,
      onAttachment: _handleAttachment,
      onVoice: _handleVoice,
      onScheduleMessage: _scheduleMessage,
      onChanged: _onTextChanged,
      onGifSelected: _handleGifSelected,
      replyToContent: _activeReplyContent,
      replyToSenderName: _activeReplySenderName,
      onCancelReply: _clearReplyContext,
      onVoiceRecorded: _handleVoiceRecorded,
      onAutocomplete: _handleAutocomplete,
      onHeightChanged: _onInputHeightChanged,
      reduceEffects: reduceEffects,
      allowHeavyEffects: allowHeavyEffects,
      blurSigma: blurSigma,
      voicePreset: reduceEffects
          ? VoiceInputPreset.soft
          : (allowHeavyEffects
              ? VoiceInputPreset.strict
              : VoiceInputPreset.balanced),
    );
  }

  /// Handle voice recording
  Future<void> _handleVoiceRecorded(File audioFile, int duration) async {
    if (!mounted) return;

    final attachmentService = ChatAttachmentService();
    final chatRepository = ref.read(chatRepositoryProvider);
    final localId = const Uuid().v4();
    final fileName = p.basename(audioFile.path);
    final fileSize = await audioFile.length();
    final mimeType = _guessMimeTypeFromPath(audioFile.path);

    // محاسبه دقیق مدت زمان
    final durationResult = await _voiceService.getAudioDuration(audioFile);
    final finalDuration =
        durationResult.success ? durationResult.durationInSeconds : duration;

    final pending = await chatRepository.createPendingMessage(
      conversationId: widget.args.conversationId,
      content: '',
      localId: localId,
      attachmentType: 'voice',
      attachmentFileName: fileName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: fileSize,
      localFilePath: audioFile.path,
      duration: finalDuration,
    );
    if (!pending.isSuccess) {
      if (mounted) {
        _showErrorSnackBar(pending.error ?? 'خطا در ایجاد پیام موقت');
      }
      return;
    }
    _scrollToBottom();

    final result = await attachmentService.uploadVoiceMessage(
      audioFile: audioFile,
      conversationId: widget.args.conversationId,
      duration: finalDuration ?? 0,
      onProgress: (progress) {
        unawaited(chatRepository.updateUploadProgress(localId, progress));
      },
    );

    if (!mounted) return;

    if (!result.success || result.url == null || result.url!.isEmpty) {
      final shortError =
          _shortUploadError(result.error, fallback: 'Voice upload failed');
      await chatRepository.markUploadFailed(
        localId,
        errorMessage: shortError,
      );
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
      return;
    }
    await chatRepository.updateUploadProgress(localId, 1.0);

    final params = SendMessageParams(
      conversationId: widget.args.conversationId,
      content: '',
      attachmentUrl: result.url,
      attachmentType: 'voice',
      attachmentFileName: result.fileName ?? fileName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: fileSize,
      duration: finalDuration,
      replyToMessageId: _resolveReplyToMessageId(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      ),
      replyToContent: _activeReplyContent,
      replyToSenderName: _activeReplySenderName,
      replyToKind: _resolveReplyToKind(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      ),
      recipientPublicKey:
          widget.args.isSecret ? _otherUserProfile?.publicKey : null,
    );

    try {
      final sendResult =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: localId,
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
                attachmentFileName: params.attachmentFileName,
                attachmentMimeType: params.attachmentMimeType,
                attachmentSizeBytes: params.attachmentSizeBytes,
                audioTitle: params.audioTitle,
                audioArtist: params.audioArtist,
                audioAlbum: params.audioAlbum,
                duration: params.duration,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
                replyToKind: params.replyToKind,
                recipientPublicKey:
                    widget.args.isSecret ? params.recipientPublicKey : null,
              );
      if (!sendResult.isSuccess) {
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: sendResult.error ?? 'ارسال پیام صوتی ناموفق بود',
        );
      }
      await _registerCompletedLocalUpload(
        messageId: localId,
        url: result.url!,
        localPath: audioFile.path,
        fileName: params.attachmentFileName ?? fileName,
      );
      if (mounted) {
        _scrollToBottom();
      }
    } catch (e) {
      final shortError = _shortUploadError(e.toString(),
          fallback: 'Voice message send failed');
      await chatRepository.markUploadFailed(
        localId,
        errorMessage: shortError,
      );
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
    }
  }

  /// Handle ارسال GIF
  Future<void> _handleGifSelected(String gifUrl) async {
    if (!mounted || gifUrl.isEmpty) return;

    debugPrint('🎞️ ModernChatScreen: Sending GIF: $gifUrl');

    try {
      final replyTo = _replyToMessage;
      final pendingReply = _pendingReplyContext;
      final params = SendMessageParams(
        conversationId: widget.args.conversationId,
        content: '', // محتوای خالی برای GIF
        attachmentUrl: gifUrl,
        attachmentType: 'gif', // نوع attachment
        replyToMessageId:
            _resolveReplyToMessageId(replyTo: replyTo, pendingReply: pendingReply),
        replyToContent: replyTo?.content ?? pendingReply?.content,
        replyToSenderName: replyTo != null
            ? (replyTo.senderId == _currentUserId ? 'شما' : widget.args.otherUserName)
            : pendingReply?.senderName,
        replyToKind:
            _resolveReplyToKind(replyTo: replyTo, pendingReply: pendingReply),
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
      );

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                attachmentUrl: params.attachmentUrl,
                attachmentType: params.attachmentType,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
                replyToKind: params.replyToKind,
                recipientPublicKey:
                    widget.args.isSecret ? params.recipientPublicKey : null,
              );

      if (!mounted) return;

      if (result.isSuccess) {
        // پاک کردن reply اگر وجود داشت
        if (_replyToMessage != null || _pendingReplyContext != null) {
          _clearReplyContext();
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
    final userId = _currentUserId;
    if (userId == null) return;

    final hasText = text.trim().isNotEmpty;
    _typingDebounceTimer?.cancel();

    if (!hasText) {
      try {
        _typingService.stopTyping(widget.args.conversationId, userId);
      } catch (e) {
        debugPrint('Error stopping typing: $e');
      }
      return;
    }

    // Start typing immediately for responsive indicator on the other side.
    try {
      _typingService.startTyping(widget.args.conversationId, userId);
    } catch (e) {
      debugPrint('Error starting typing: $e');
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

  Future<void> _scheduleMessage() async {
    if (!mounted) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'زمان‌بندی ارسال پیام',
      cancelText: 'لغو',
      confirmText: 'مرحله بعد',
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
      cancelText: 'لغو',
      confirmText: 'ثبت',
      helpText: 'انتخاب ساعت',
    );
    if (!mounted || time == null) return;

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!scheduledAt.isAfter(now)) {
      _showErrorSnackBar('زمان ارسال باید در آینده باشد');
      return;
    }

    final delay = scheduledAt.difference(now);
    final replyTo = _replyToMessage;
    final pendingReply = _pendingReplyContext;

    _messageController.clear();
    if (mounted) _clearReplyContext();

    final timer = Timer(delay, () async {
      if (!mounted) return;
      try {
        final result =
            await ref.read(chatActionControllerProvider.notifier).sendMessage(
                  conversationId: widget.args.conversationId,
                  content: content,
                  replyToMessageId: _resolveReplyToMessageId(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  replyToContent: replyTo?.content ?? pendingReply?.content,
                  replyToSenderName: replyTo != null
                      ? (replyTo.senderId == _currentUserId ? 'شما' : widget.args.otherUserName)
                      : pendingReply?.senderName,
                  replyToKind: _resolveReplyToKind(
                    replyTo: replyTo,
                    pendingReply: pendingReply,
                  ),
                  recipientPublicKey: widget.args.isSecret
                      ? _otherUserProfile?.publicKey
                      : null,
                );
        if (!mounted) return;
        if (result.isSuccess) {
          _scrollToBottom();
        } else {
          _showErrorSnackBar(result.error ?? 'ارسال زمان‌بندی‌شده ناموفق بود');
        }
      } catch (_) {
        if (mounted) {
          _showErrorSnackBar('خطا در ارسال زمان‌بندی‌شده');
        }
      }
    });
    _scheduledSendTimers.add(timer);
    _showSuccessSnackBar(
      'پیام برای ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')} زمان‌بندی شد',
    );
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;

    var content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    final replyTo = _replyToMessage;
    final pendingReply = _pendingReplyContext;
    if (mounted) _clearReplyContext();

    try {
      if (widget.args.isSecret) {
        final prefs = await SharedPreferences.getInstance();
        final peerPubB64 =
            prefs.getString('e2e_peer_pub_${widget.args.conversationId}');
        if (peerPubB64 == null) {
          _showErrorSnackBar(
              'درحال تبادل کلید امنیتی با مخاطب هستیم... لطفاً کمی صبر کنید');
          return;
        }

        final e2e = E2EEncryptionService();
        final myKeyPair = await e2e.getSavedKeyPair(_currentUserId!);
        if (myKeyPair == null) {
          _showErrorSnackBar('خطا: کلید امنیتی محلی یافت نشد.');
          return;
        }

        final sharedSecret = await e2e.computeSharedSecret(
          myKeyPair: myKeyPair,
          peerPublicKeyBytes: base64Decode(peerPubB64),
        );

        // جایگزین کردن محتوای واقعی با محتوای رمزنگاری شده
        content = await e2e.encryptMessage(content, sharedSecret);
      }

      String targetConvId = widget.args.conversationId;
      bool wasEmpty = targetConvId.isEmpty;

      if (wasEmpty) {
        final convResult = await _chatRepository.createConversation(
          widget.args.otherUserId,
          isSecret: widget.args.isSecret,
        );
        if (!convResult.isSuccess || convResult.data == null) {
          _showErrorSnackBar(convResult.error ?? 'خطا در ایجاد گفتگو');
          return;
        }
        targetConvId = convResult.data!.id;
      }

      final params = SendMessageParams(
        conversationId: targetConvId,
        content: content,
        replyToMessageId:
            _resolveReplyToMessageId(replyTo: replyTo, pendingReply: pendingReply),
        replyToContent: replyTo?.content ?? pendingReply?.content,
        replyToSenderName: replyTo != null
            ? (replyTo.senderId == _currentUserId ? 'شما' : widget.args.otherUserName)
            : pendingReply?.senderName,
        replyToKind:
            _resolveReplyToKind(replyTo: replyTo, pendingReply: pendingReply),
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
      );

      if (!mounted) return;

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: params.conversationId,
                content: params.content,
                replyToMessageId: params.replyToMessageId,
                replyToContent: params.replyToContent,
                replyToSenderName: params.replyToSenderName,
                replyToKind: params.replyToKind,
                recipientPublicKey:
                    widget.args.isSecret ? params.recipientPublicKey : null,
              );

      if (!mounted) return;

      if (result.isSuccess) {
        if (wasEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ModernChatScreen(
                args: ChatScreenArgs(
                  conversationId: targetConvId,
                  otherUserId: widget.args.otherUserId,
                  otherUserName: widget.args.otherUserName,
                  otherUserAvatar: widget.args.otherUserAvatar,
                  isGroup: widget.args.isGroup,
                  isSecret: widget.args.isSecret,
                ),
              ),
            ),
          );
          return;
        }
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
    final chatRepository = ref.read(chatRepositoryProvider);
    if (_currentUserId == null) {
      _showErrorSnackBar('User id not found');
      return;
    }

    final isAlbumSend =
        sendMode == ChatSendMode.gallery && selection.files.length > 1;
    final baseCaption = selection.caption ?? '';
    final mediaGroupId = isAlbumSend ? const Uuid().v4() : null;

    String targetConvId = widget.args.conversationId;
    bool wasEmpty = targetConvId.isEmpty;

    if (wasEmpty) {
      final convResult = await _chatRepository.createConversation(
        widget.args.otherUserId,
        isSecret: widget.args.isSecret,
      );
      if (!convResult.isSuccess || convResult.data == null) {
        _showErrorSnackBar(convResult.error ?? 'خطا در ایجاد گفتگو');
        return;
      }
      targetConvId = convResult.data!.id;
    }

    for (var index = 0; index < selection.files.length; index++) {
      final selected = selection.files[index];
      if (!mounted) break;
      final file = selected.file;
      final messageCaption = (isAlbumSend && index > 0) ? '' : baseCaption;

      final validation = _uploadPolicyService.validateFile(
        file: file,
        profile: _currentUserProfile,
        mode: sendMode,
      );
      if (!validation.isAllowed) {
        _showErrorSnackBar(validation.error ?? 'File is not allowed');
        continue;
      }

      final attachmentType = _resolveAttachmentType(
        sendMode: sendMode,
        file: file,
        policyType: validation.attachmentType,
      );
      final localId = const Uuid().v4();
      final fileName = selected.displayFileName.trim().isNotEmpty
          ? selected.displayFileName.trim()
          : p.basename(file.path);
      final fileSizeBytes = selected.sizeBytes ?? await file.length();
      String? attachmentMimeType =
          selected.mimeType ?? _guessMimeTypeFromPath(file.path);
      int? durationSeconds;
      String? audioTitle = selected.audioTitle;
      String? audioArtist = selected.audioArtist;
      String? audioAlbum = selected.audioAlbum;

      if (attachmentType == 'audio') {
        final metadata = await _audioMetadataService.extract(
          file: file,
          displayFileName: fileName,
          mimeTypeHint: attachmentMimeType,
          sizeBytesHint: fileSizeBytes,
        );
        attachmentMimeType = metadata.mimeType ?? attachmentMimeType;
        durationSeconds = metadata.durationSeconds;
        audioTitle = audioTitle ?? metadata.title;
        audioArtist = audioArtist ?? metadata.artist;
        audioAlbum = audioAlbum ?? metadata.album;

        if (durationSeconds == null) {
          final durationResult = await _voiceService.getAudioDuration(file);
          if (durationResult.success) {
            durationSeconds = durationResult.durationInSeconds;
          }
        }
      }

      final pending = await chatRepository.createPendingMessage(
        conversationId: targetConvId,
        content: messageCaption,
        localId: localId,
        attachmentType: attachmentType,
        attachmentFileName: fileName,
        attachmentMimeType: attachmentMimeType,
        attachmentSizeBytes: fileSizeBytes,
        audioTitle: audioTitle,
        audioArtist: audioArtist,
        audioAlbum: audioAlbum,
        localFilePath: file.path,
        duration: durationSeconds,
        mediaGroupId: mediaGroupId,
      );
      if (!pending.isSuccess) {
        _showErrorSnackBar(pending.error ?? 'Failed to create pending message');
        continue;
      }
      _scrollToBottom();

      final uploadResult = await _uploadWithProgress(
        file: file,
        type: attachmentType,
        service: attachmentService,
        localMessageId: localId,
      );

      if (!uploadResult.success ||
          uploadResult.url == null ||
          uploadResult.url!.isEmpty) {
        final shortError =
            _shortUploadError(uploadResult.error, fallback: 'Upload failed');
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: shortError,
        );
        if (mounted) {
          _showErrorSnackBar(shortError);
        }
        continue;
      }
      await chatRepository.updateUploadProgress(localId, 1.0);

      final result =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: localId,
                conversationId: targetConvId,
                content: messageCaption,
                attachmentUrl: uploadResult.url,
                attachmentType: attachmentType,
                attachmentFileName: fileName,
                attachmentMimeType: attachmentMimeType,
                attachmentSizeBytes: fileSizeBytes,
                audioTitle: audioTitle,
                audioArtist: audioArtist,
                audioAlbum: audioAlbum,
                duration: durationSeconds,
                mediaGroupId: mediaGroupId,
                recipientPublicKey:
                    widget.args.isSecret ? _otherUserProfile?.publicKey : null,
              );
      if (!result.isSuccess) {
        await chatRepository.markUploadFailed(
          localId,
          errorMessage: result.error ?? 'Message send failed after upload',
        );
      } else {
        await _registerCompletedLocalUpload(
          messageId: localId,
          url: uploadResult.url!,
          localPath: file.path,
          fileName: fileName,
        );
      }
    }

    if (wasEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ModernChatScreen(
            args: ChatScreenArgs(
              conversationId: targetConvId,
              otherUserId: widget.args.otherUserId,
              otherUserName: widget.args.otherUserName,
              otherUserAvatar: widget.args.otherUserAvatar,
              isGroup: widget.args.isGroup,
              isSecret: widget.args.isSecret,
            ),
          ),
        ),
      );
    }
  }

  String _resolveAttachmentType({
    required ChatSendMode sendMode,
    required File file,
    String? policyType,
    String? existingType,
  }) {
    return _attachmentTypeResolver.resolve(
      sendMode: sendMode,
      file: file,
      policyType: policyType,
      existingType: existingType,
    );
  }

  Future<AttachmentResult> _uploadWithProgress(
      {required File file,
      required String type,
      required ChatAttachmentService service,
      required String localMessageId}) async {
    try {
      AttachmentResult result;
      final chatRepository = ref.read(chatRepositoryProvider);
      void onProgress(double progress) {
        unawaited(
            chatRepository.updateUploadProgress(localMessageId, progress));
      }

      switch (type) {
        case 'image':
          result = await service.uploadImage(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        case 'audio':
          result = await service.uploadAudioFile(
            audioFile: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        case 'voice':
          result = await service.uploadAudioFile(
            audioFile: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
        default:
          result = await service.uploadFile(
            file: file,
            conversationId: widget.args.conversationId,
            onProgress: onProgress,
          );
          break;
      }

      return result;
    } catch (e) {
      debugPrint('Upload error: $e');
      final technical = '${e.runtimeType}: $e';
      final stage =
          RegExp(r'stage=([a-zA-Z0-9_]+)').firstMatch(technical)?.group(1);
      final code = RegExp(r'code=([A-Z0-9_]+)').firstMatch(technical)?.group(1);
      return AttachmentResult(
        success: false,
        type: _attachmentTypeFromWireType(type),
        error: _shortUploadError(e.toString(), fallback: 'Upload failed'),
        errorStage: stage,
        errorCode: code,
        technicalError: technical,
      );
    }
  }

  void _handleVoice() {
    HapticFeedback.mediumImpact();
    _showErrorSnackBar('برای ضبط صدا، دکمه میکروفون را نگه دارید');
  }

  Future<void> _retryFailedMessage(MessageModel message) async {
    if (message.isFailed != true) return;

    final hasAttachmentData =
        (message.attachmentType?.trim().isNotEmpty ?? false) ||
            (message.localFilePath?.isNotEmpty ?? false) ||
            (message.attachmentUrl?.isNotEmpty ?? false);

    if (hasAttachmentData) {
      await _retryFailedUpload(message);
      return;
    }

    final chatRepository = ref.read(chatRepositoryProvider);
    final resend =
        await ref.read(chatActionControllerProvider.notifier).sendMessage(
              id: message.id,
              conversationId: message.conversationId,
              content: message.content,
              replyToMessageId: message.replyToMessageId,
              replyToContent: message.replyToContent,
              replyToSenderName: message.replyToSenderName,
              replyToKind:
                  _isSyntheticNoteReplyId(message.replyToMessageId) ? 'note' : null,
            );

    if (!resend.isSuccess) {
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: resend.error ?? 'Message resend failed',
      );
      if (mounted) {
        _showErrorSnackBar('ارسال مجدد ناموفق بود');
      }
    }
  }

  Future<void> _retryFailedUpload(MessageModel message) async {
    final chatRepository = ref.read(chatRepositoryProvider);
    final hasCanonicalType =
        AttachmentTypeResolver.isCanonicalType(message.attachmentType);
    final existingAttachmentUrl = message.attachmentUrl?.trim();
    if (existingAttachmentUrl != null && existingAttachmentUrl.isNotEmpty) {
      await chatRepository.updateUploadProgress(message.id, 1.0);
      final preservedType = hasCanonicalType
          ? message.attachmentType
          : _attachmentTypeResolver.canonicalizeFromType(
              message.attachmentType,
            );
      final resendType = preservedType ?? 'document';
      final resend =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                id: message.id,
                conversationId: message.conversationId,
                content: message.content,
                attachmentUrl: existingAttachmentUrl,
                attachmentType: resendType,
                attachmentFileName: message.attachmentFileName,
                attachmentMimeType: message.attachmentMimeType,
                attachmentSizeBytes: message.attachmentSizeBytes,
                audioTitle: message.audioTitle,
                audioArtist: message.audioArtist,
                audioAlbum: message.audioAlbum,
                duration: message.duration,
                mediaGroupId: message.mediaGroupId,
                replyToMessageId: message.replyToMessageId,
                replyToContent: message.replyToContent,
                replyToSenderName: message.replyToSenderName,
                replyToKind:
                    _isSyntheticNoteReplyId(message.replyToMessageId) ? 'note' : null,
              );
      if (!resend.isSuccess) {
        await chatRepository.markUploadFailed(
          message.id,
          errorMessage: resend.error ?? 'Message resend failed',
        );
      } else if (message.localFilePath != null &&
          message.localFilePath!.isNotEmpty &&
          File(message.localFilePath!).existsSync()) {
        await _registerCompletedLocalUpload(
          messageId: message.id,
          url: existingAttachmentUrl,
          localPath: message.localFilePath!,
          fileName:
              message.attachmentFileName ?? p.basename(message.localFilePath!),
        );
      }
      return;
    }

    final localPath = message.localFilePath;
    if (localPath == null || localPath.isEmpty) {
      _showErrorSnackBar('Local file not found for retry');
      return;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      _showErrorSnackBar('Selected file is missing on device');
      return;
    }

    final attachmentService = ChatAttachmentService();
    await chatRepository.updateUploadProgress(message.id, 0.0);

    final normalizedType = hasCanonicalType
        ? message.attachmentType!
        : _resolveAttachmentType(
            sendMode: ChatSendMode.file,
            file: file,
            existingType: message.attachmentType,
          );
    final uploadResult = await _uploadWithProgress(
      file: file,
      type: normalizedType,
      service: attachmentService,
      localMessageId: message.id,
    );

    if (!uploadResult.success ||
        uploadResult.url == null ||
        uploadResult.url!.isEmpty) {
      final shortError =
          _shortUploadError(uploadResult.error, fallback: 'Retry failed');
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: shortError,
      );
      if (mounted) {
        _showErrorSnackBar(shortError);
      }
      return;
    }

    final result =
        await ref.read(chatActionControllerProvider.notifier).sendMessage(
              id: message.id,
              conversationId: message.conversationId,
              content: message.content,
              attachmentUrl: uploadResult.url,
              attachmentType: normalizedType,
              attachmentFileName:
                  message.attachmentFileName ?? p.basename(file.path),
              attachmentMimeType: message.attachmentMimeType ??
                  _guessMimeTypeFromPath(file.path),
              attachmentSizeBytes:
                  message.attachmentSizeBytes ?? await file.length(),
              audioTitle: message.audioTitle,
              audioArtist: message.audioArtist,
              audioAlbum: message.audioAlbum,
              duration: message.duration,
              mediaGroupId: message.mediaGroupId,
              replyToMessageId: message.replyToMessageId,
              replyToContent: message.replyToContent,
              replyToSenderName: message.replyToSenderName,
              replyToKind:
                  _isSyntheticNoteReplyId(message.replyToMessageId) ? 'note' : null,
            );

    if (!result.isSuccess) {
      await chatRepository.markUploadFailed(
        message.id,
        errorMessage: result.error ?? 'Message send failed after retry',
      );
    } else {
      await _registerCompletedLocalUpload(
        messageId: message.id,
        url: uploadResult.url!,
        localPath: file.path,
        fileName: message.attachmentFileName ?? p.basename(file.path),
      );
    }
  }

  AttachmentType _attachmentTypeFromWireType(String type) {
    switch (type) {
      case 'image':
        return AttachmentType.image;
      case 'audio':
        return AttachmentType.audio;
      case 'voice':
        return AttachmentType.voice;
      default:
        return AttachmentType.file;
    }
  }

  String? _guessMimeTypeFromPath(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return null;
    }
  }

  Future<void> _registerCompletedLocalUpload({
    required String messageId,
    required String url,
    required String localPath,
    required String fileName,
  }) async {
    try {
      await _chatTransferManager.registerCompletedLocalUpload(
        messageId: messageId,
        url: url,
        localPath: localPath,
        fileName: fileName,
      );
    } catch (e, s) {
      logWarning(
        'registerCompletedLocalUpload failed for $messageId',
        error: e,
        stackTrace: s,
      );
    }
  }

  String _shortUploadError(String? raw, {required String fallback}) {
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }

    var text = raw.trim();
    if (text.startsWith('Exception:')) {
      text = text.substring('Exception:'.length).trim();
    }

    const marker = '| technical:';
    final markerIndex = text.indexOf(marker);
    if (markerIndex >= 0) {
      text = text.substring(0, markerIndex).trim();
    }

    return text.isEmpty ? fallback : text;
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

  /// ✅ تابع جدید: نمایش Context Menu به سبک ویستا
  void _showTelegramContextMenu(
    BuildContext bubbleContext,
    MessageModel message, {
    List<MessageModel>? groupedMessagesOverride,
  }) async {
    // برای باز شدن منو، فقط فوکوس را آزاد می‌کنیم و از hide اجباری کیبورد اجتناب می‌کنیم.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 60));

    // چک کردن mounted بعد از delay
    if (!mounted || !bubbleContext.mounted) return;

    final groupedMessages = <MessageModel>[
      if (groupedMessagesOverride != null)
        ...groupedMessagesOverride
      else
        message,
    ];
    final groupedMap = <String, MessageModel>{};
    for (final groupedMessage in groupedMessages) {
      if (groupedMessage.id.trim().isEmpty) continue;
      groupedMap[groupedMessage.id] = groupedMessage;
    }
    final normalizedGroup =
        groupedMap.isNotEmpty ? groupedMap.values.toList() : [message];
    final groupedIds =
        normalizedGroup.map((groupedMessage) => groupedMessage.id).toList();
    final isAlbumContext = groupedIds.length > 1;

    // 2. گرفتن مختصات دقیق حباب پیام از روی Context
    final RenderBox? renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // fallback به BottomSheet قدیمی
      if (isAlbumContext) {
        _enterSelectionModeForMessages(groupedIds);
        return;
      }
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
    final isSharedPost = _isSharedPostMessage(message);
    final albumImageMessages = isAlbumContext
        ? normalizedGroup.where(_isAlbumImageMessage).toList(growable: false)
        : const <MessageModel>[];
    final albumHasOnlyImages =
        isAlbumContext && albumImageMessages.length == normalizedGroup.length;
    final isDocument = message.attachmentType != null &&
        ![
          'gif',
          'image',
          'video',
          'voice',
          'audio',
          'location',
          'contact',
          'post',
          'shared_post',
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
          _setReplyToMessage(message);
          _focusNode.requestFocus();
        },
      ),

      // Copy (فقط برای متن)
      if (!widget.args.isSecret &&
          !isGif &&
          !isImage &&
          !isVideo &&
          !isVoice &&
          !isSharedPost &&
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
      if (isGif && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.gif_box_outlined,
          label: 'ذخیره GIF',
          onTap: () => _saveGif(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص عکس/آلبوم
      if (albumHasOnlyImages && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.collections_rounded,
          label: 'ذخیره آلبوم',
          onTap: () => _saveImageAlbum(albumImageMessages),
        ),
        const TelegramContextMenuItem.divider(),
      ] else if (isImage && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره عکس',
          onTap: () => _saveImage(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص ویدیو
      if (isVideo && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره ویدیو',
          onTap: () => _saveVideo(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص صدا
      if (isVoice && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'ذخیره صدا',
          onTap: () => _saveVoice(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // گزینه‌های مخصوص فایل
      if (isDocument && !widget.args.isSecret) ...[
        TelegramContextMenuItem(
          icon: Icons.download_rounded,
          label: 'دانلود فایل',
          onTap: () => _downloadFile(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      if (isSharedPost) ...[
        TelegramContextMenuItem(
          icon: Icons.open_in_new_rounded,
          label: 'باز کردن پست',
          onTap: () => _showMessageDetails(message),
        ),
        const TelegramContextMenuItem.divider(),
      ],

      // Forward
      if (!widget.args.isSecret)
        TelegramContextMenuItem(
          icon: Icons.forward_rounded,
          label: 'فوروارد',
          onTap: () => _forwardMessagesByIds(groupedIds),
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
        onTap: () => _enterSelectionModeForMessages(groupedIds),
      ),

      // Delete
      TelegramContextMenuItem(
        icon: Icons.delete_outline_rounded,
        label: 'حذف',
        color: theme.errorColor,
        onTap: () => isAlbumContext
            ? _confirmAndDeleteMessages(
                normalizedGroup,
                allMyMessagesOverride:
                    normalizedGroup.every((m) => m.senderId == _currentUserId),
              )
            : _deleteMessage(message),
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
      quickReactions: (isGif || isVoice || isDocument || isAlbumContext)
          ? null
          : kDefaultReactions,
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
    if (_isSharedPostMessage(message)) {
      // استفاده از IgnorePointer برای اینکه دکمه‌های پست در حالت پیش‌نمایش کار نکنند
      return IgnorePointer(
        child: _buildPostMessageBubble(message, isMe),
      );
    }

    // 2. برای سایر پیام‌ها همان حباب معمولی
    return ImprovedAnimatedMessageBubble(
      recipientPublicKey:
          widget.args.isSecret ? _otherUserProfile?.publicKey : null,
      isSecretMode: widget.args.isSecret,
      onSwipeToReply: () {
        _setReplyToMessage(message);
      },
      key: ValueKey('preview_${message.id}'),
      messageId: message.id,
      content: message.content,
      isMe: isMe,
      time: message.createdAt,
      status: _getMessageStatus(message),
      attachmentUrl: message.attachmentUrl,
      attachmentType: message.attachmentType,
      attachmentFileName: message.attachmentFileName,
      duration: message.duration,
      replyToContent: message.replyToContent,
      replyToSenderName: message.replyToSenderName,
      replyToMessageId: message.replyToMessageId,
      onStoryReplyTap: (_) {},
      reactions:
          _convertToOldReactionFormat(_reactionNotifierFor(message.id).value),
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
    if (_isSharedPostMessage(message)) {
      final parsedPostData =
          message.sharedPostData ?? _extractLegacySharedPostData(message);
      final postId = parsedPostData?.postId.trim() ?? '';
      if (postId.isNotEmpty) {
        _navigateToPostScreen(postId);
      } else {
        _showErrorSnackBar('شناسه پست یافت نشد');
      }
      return;
    }

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
          _showErrorSnackBar('این استوری در دسترس نیست');
        }
        return;
      }

      final story = storyResult.data!;
      if (story.isExpired) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showErrorSnackBar('این استوری منقضی شده است');
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
      avatarUrl: profile?.avatarUrl ??
          data.storyOwnerAvatarUrl ??
          widget.args.otherUserAvatar,
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
              if (isGif && !widget.args.isSecret) ...[
                _buildOptionTile(
                  icon: Icons.gif_box_outlined,
                  label: 'ذخیره GIF',
                  onTap: () {
                    Navigator.pop(context);
                    _saveGif(message);
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
                  _setReplyToMessage(message);
                  _focusNode.requestFocus();
                },
              ),

              // ✅ کپی فقط برای پیام‌های متنی (نه GIF)
              if (!widget.args.isSecret && !isGif && message.content.isNotEmpty)
                _buildOptionTile(
                  icon: Icons.copy_rounded,
                  label: 'کپی',
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.content));
                    _showSuccessSnackBar('کپی شد');
                  },
                ),

              if (!widget.args.isSecret)
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
          color: context.chatTheme.dividerColor.withValues(alpha: 0.3),
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
    await _confirmAndDeleteMessages(
      [message],
      allMyMessagesOverride: message.senderId == _currentUserId,
    );
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
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
    await _forwardMessagesByIds([message.id]);
  }

  Future<void> _forwardMessagesByIds(List<String> messageIds) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('فوروارد در گفتگوی محرمانه غیرفعال است');
      return;
    }
    final ids = messageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;

    final result = await ForwardMessageSheet.show(
      context,
      messageIds: ids,
    );

    if (result == true) {
      _showSuccessSnackBar(
        ids.length > 1 ? 'پیام‌ها فوروارد شدند' : 'پیام فوروارد شد',
      );
    }
  }

  /// ذخیره GIF در گالری
  Future<void> _saveGif(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 💾 SAVE MEDIA (متدهای کمکی)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveImageAlbum(List<MessageModel> messages) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (messages.isEmpty) {
      _showErrorSnackBar('عکسی برای ذخیره یافت نشد');
      return;
    }

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
              Text('در حال آماده‌سازی آلبوم...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    var savedCount = 0;
    var failedCount = 0;

    for (final message in messages) {
      final source = _resolveAlbumMediaSource(message);
      if (source.isEmpty) {
        failedCount++;
        continue;
      }

      try {
        final file = await _resolveImageFileForGallerySave(source);
        if (file == null) {
          failedCount++;
          continue;
        }

        await Gal.putImage(file.path);
        savedCount++;
      } catch (_) {
        failedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (savedCount > 0) {
        _showSuccessSnackBar(
          failedCount > 0
              ? '$savedCount عکس ذخیره شد، $failedCount مورد ناموفق بود'
              : '$savedCount عکس در گالری ذخیره شد',
        );
      } else {
        _showErrorSnackBar('ذخیره آلبوم انجام نشد');
      }
    }
  }

  Future<File?> _resolveImageFileForGallerySave(String source) async {
    if (!_isNetworkMediaSource(source)) {
      final localFile = File(source);
      if (await localFile.exists()) return localFile;
      return null;
    }

    final response = await Dio().get(
      source,
      options: Options(responseType: ResponseType.bytes),
    );

    final tempDir = await getTemporaryDirectory();
    final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
    final normalizedExt = ext.isEmpty ? 'jpg' : ext;
    final fileName =
        'album_${DateTime.now().microsecondsSinceEpoch}.$normalizedExt';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(Uint8List.fromList(response.data));
    return tempFile;
  }

  /// ذخیره عکس
  Future<void> _saveImage(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک تصویر یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'image', 'عکس');
  }

  /// ذخیره ویدیو
  Future<void> _saveVideo(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک ویدیو یافت نشد');
      return;
    }
    await _saveMediaToGallery(message.attachmentUrl!, 'video', 'ویدیو');
  }

  /// ذخیره صدا
  Future<void> _saveVoice(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
      return;
    }
    if (message.attachmentUrl == null) {
      _showErrorSnackBar('لینک صدا یافت نشد');
      return;
    }
    // برای صدا از downloadFile استفاده می‌کنیم
    await _downloadFile(message);
  }

  /// دانلود فایل
  Future<void> _downloadFile(MessageModel message) async {
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج فایل در گفتگوی محرمانه غیرفعال است');
      return;
    }
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
    if (widget.args.isSecret) {
      _showErrorSnackBar('استخراج رسانه در گفتگوی محرمانه غیرفعال است');
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

  Widget _buildSecretSystemNoticeBubble(_SecretSystemNotice notice) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3D2F).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Colors.greenAccent, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${notice.text}  ${notice.createdAt.hour.toString().padLeft(2, '0')}:${notice.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      color: Colors.red.withValues(alpha: 0.8),
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
              color: Colors.black.withValues(alpha: 0.2),
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
      final postData =
          message.sharedPostData ?? _extractLegacySharedPostData(message);

      if (postData == null) {
        // Fallback به پیام متنی معمولی
        return ImprovedAnimatedMessageBubble(
          recipientPublicKey:
              widget.args.isSecret ? _otherUserProfile?.publicKey : null,
          isSecretMode: widget.args.isSecret,
          onSwipeToReply: () {
            _setReplyToMessage(message);
          },
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
      final mediaUrls = _extractSharedPostMediaUrls(message, postData);
      final likesCount = postData.likeCount;
      final commentsCount = postData.commentCount;
      final postCreatedAt = postData.postCreatedAt;
      final verificationType = postData.verificationType;
      final isVerified = postData.isVerified;
      final role = postData.role;
      final hashtags = null; // SharedPostData فعلاً hashtags ندارد
      void handlePostTap() {
        if (_isSelectionMode) {
          _toggleMessageSelection(message.id);
        } else {
          _navigateToPostScreen(postId);
        }
      }

      void handlePostLongPress() {
        HapticFeedback.mediumImpact();
        if (_isSelectionMode) {
          _toggleMessageSelection(message.id);
        } else {
          _showTelegramContextMenu(context, message);
        }
      }

      // ✅ ساختار جدید برای کنترل کامل کلیک‌ها
      return Stack(
        children: [
          // ویجت پست
          GestureDetector(
            // اولویت کلیک با ماست
            onTap: handlePostTap,
            onLongPress: handlePostLongPress,
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
                isVerified: isVerified,
                verificationType: verificationType,
                role: role,
                hashtags: hashtags,
                status: _getMessageStatus(message),
                // callbacks داخلی را هم به همان هندلرها وصل می‌کنیم تا tap حتماً کار کند
                onTap: handlePostTap,
                onLongPress: handlePostLongPress,
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
                  color: context.chatTheme.sendButtonColor.withValues(
                      alpha: 0.3), // کمی پررنگ تر برای دیده شدن روی عکس
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
        recipientPublicKey:
            widget.args.isSecret ? _otherUserProfile?.publicKey : null,
        isSecretMode: widget.args.isSecret,
        onSwipeToReply: () {
          _setReplyToMessage(message);
        },
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
  Widget _buildBubbleContent(
    MessageModel message,
    bool isMe,
    int index,
    bool isFirstInGroup,
    bool isLastInGroup,
    AdaptiveEffectsState adaptiveEffects, {
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    final isHighlighted = _highlightedMessageId == message.id;
    final isSelected = _selectedMessageIds.contains(message.id);
    final bubbleEffectsLevel = adaptiveEffects.motionTokensEnabled
        ? adaptiveEffects.effectsLevel
        : ChatEffectsLevel.high;

    final shouldAnimateEntry = switch (adaptiveEffects.chatEntryMode) {
      ChatEntryAnimationMode.off => false,
      ChatEntryAnimationMode.minimal => index < 2 && !_isNearTop,
      ChatEntryAnimationMode.full => index < 5 && !_isNearTop,
    };

    final bubbleContent = _isSharedPostMessage(message)
        ? Builder(
            builder: (postContext) => _buildPostMessageBubble(message, isMe),
          )
        : ValueListenableBuilder<List<reaction_models.MessageReaction>>(
            valueListenable: _reactionNotifierFor(message.id),
            builder: (context, messageReactions, _) {
              return ImprovedAnimatedMessageBubble(
                recipientPublicKey:
                    widget.args.isSecret ? _otherUserProfile?.publicKey : null,
                isSecretMode: widget.args.isSecret,
                onSwipeToReply: () {
                  _setReplyToMessage(message);
                },
                key: _messageKeys[message.id] ??= GlobalKey(),
                messageId: message.id,
                content: message.content,
                isMe: isMe,
                time: message.createdAt,
                status: _getMessageStatus(message),
                attachmentUrl: message.attachmentUrl,
                attachmentType: message.attachmentType,
                attachmentFileName: message.attachmentFileName,
                replyToContent: message.replyToContent,
                replyToSenderName: message.replyToSenderName,
                replyToMessageId: message.replyToMessageId,
                onReplyTap: _isSyntheticNoteReplyId(message.replyToMessageId)
                    ? null
                    : () => _scrollToMessage(message.replyToMessageId),
                onStoryReplyTap: _openStoryReply,
                duration: message.duration,
                reactions: _convertToOldReactionFormat(messageReactions),
                onTap: (ctx, msg) => _handleMessageTap(ctx, msg),
                onLongPress: (ctx, msg) => _handleMessageLongPress(ctx, msg),
                onDoubleTap: () => _onMessageDoubleTap(message),
                onAddReaction: (emoji) => _onAddReaction(message, emoji),
                animate: shouldAnimateEntry &&
                    adaptiveEffects.enableMessageEntryAnimation,
                effectsLevel: bubbleEffectsLevel,
                index: index,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
                isForwarded: message.isForwarded,
                forwardedFrom: message.forwardedFromSenderName,
                onRetryUpload: message.isFailed == true
                    ? () => _retryFailedMessage(message)
                    : null,
                conversationGalleryItems: conversationGalleryItems,
                initialGalleryIndex:
                    conversationGalleryIndexByMessageId?[message.id],
                message: message,
              );
            },
          );

    if (!isHighlighted && !isSelected) {
      return bubbleContent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isHighlighted
            ? context.chatTheme.sendButtonColor.withValues(alpha: 0.2)
            : context.chatTheme.sendButtonColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: bubbleContent,
    );
  }

  Widget _buildAlbumBubbleContent(
    _ChatRenderItem renderItem,
    bool isMe,
    AdaptiveEffectsState adaptiveEffects, {
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    final primaryMessage = renderItem.primaryMessage;
    final albumItems = _extractAlbumMediaItems(renderItem.messages);
    if (albumItems.length < 2) {
      return _buildBubbleContent(
        primaryMessage,
        isMe,
        renderItem.primaryIndex,
        true,
        true,
        adaptiveEffects,
        conversationGalleryItems: conversationGalleryItems,
        conversationGalleryIndexByMessageId:
            conversationGalleryIndexByMessageId,
      );
    }

    final captionMessage = renderItem.messages.firstWhere(
      (m) => m.content.trim().isNotEmpty,
      orElse: () => primaryMessage,
    );
    final hasHighlightedMessage = _highlightedMessageId != null &&
        renderItem.messages.any((m) => m.id == _highlightedMessageId);
    final isSelected = _isSelectionMode && _isRenderItemSelected(renderItem);
    final albumKey = _messageKeys[primaryMessage.id] ??= GlobalKey();
    for (final item in renderItem.messages) {
      _messageKeys[item.id] ??= albumKey;
    }

    final bubble = _ChatMediaAlbumBubble(
      key: albumKey,
      albumItems: albumItems,
      statusMessage: primaryMessage,
      isMe: isMe,
      caption: captionMessage.content.trim().isNotEmpty
          ? captionMessage.content.trim()
          : null,
      onImageTap: (index) {
        if (_isSelectionMode) {
          _toggleRenderItemSelection(renderItem);
          return;
        }
        _openAlbumViewer(
          albumItems,
          index,
          conversationGalleryItems: conversationGalleryItems,
          conversationGalleryIndexByMessageId:
              conversationGalleryIndexByMessageId,
        );
      },
    );

    if (!hasHighlightedMessage && !isSelected) {
      return bubble;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: hasHighlightedMessage
            ? context.chatTheme.sendButtonColor.withValues(alpha: 0.2)
            : context.chatTheme.sendButtonColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: bubble,
    );
  }

  void _openAlbumViewer(
    List<_AlbumMediaItem> albumItems,
    int initialIndex, {
    List<GalleryItem>? conversationGalleryItems,
    Map<String, int>? conversationGalleryIndexByMessageId,
  }) {
    if (!mounted || albumItems.isEmpty) return;

    final albumGalleryItems = albumItems
        .map(
          (item) => GalleryItem(
            imageUrl: item.source,
            caption: item.message.content.trim().isNotEmpty
                ? item.message.content
                : null,
            heroTag: '${item.message.id}_${item.source.hashCode}',
          ),
        )
        .toList(growable: false);
    if (albumGalleryItems.isEmpty) return;

    final safeAlbumIndex = initialIndex < 0
        ? 0
        : (initialIndex >= albumGalleryItems.length
            ? albumGalleryItems.length - 1
            : initialIndex);

    final selectedMessageId = albumItems[safeAlbumIndex].message.id;
    final canUseConversationGallery = conversationGalleryItems != null &&
        conversationGalleryItems.isNotEmpty &&
        conversationGalleryIndexByMessageId != null &&
        conversationGalleryIndexByMessageId.containsKey(selectedMessageId);

    final galleryItems = canUseConversationGallery
        ? conversationGalleryItems
        : albumGalleryItems;
    final safeInitialIndex = canUseConversationGallery
        ? conversationGalleryIndexByMessageId[selectedMessageId]!
        : safeAlbumIndex;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          galleryItems: galleryItems,
          initialIndex: safeInitialIndex,
          isSecretMode: widget.args.isSecret,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  bool _isSharedPostMessage(MessageModel message) {
    if (message.sharedPostData != null || message.isSharedPost) return true;

    final attachmentType = (message.attachmentType ?? '').toLowerCase().trim();
    if (attachmentType == 'post' || attachmentType == 'shared_post') {
      return true;
    }

    final messageType = (message.messageType ?? '').toLowerCase().trim();
    if (messageType == 'post' ||
        messageType == 'shared_post' ||
        messageType == 'sharedpost') {
      return true;
    }

    return _extractLegacySharedPostData(message) != null;
  }

  SharedPostData? _extractLegacySharedPostData(MessageModel message) {
    final raw = message.content.trim();
    if (raw.isEmpty || !raw.startsWith('{')) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      final postId =
          (map['postId'] ?? map['post_id'] ?? map['id'] ?? '').toString();
      if (postId.isEmpty) {
        return null;
      }

      int parseInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      bool parseBool(dynamic value) {
        if (value is bool) return value;
        final v = value?.toString().toLowerCase().trim();
        return v == 'true' || v == '1' || v == 'yes' || v == 'on';
      }

      DateTime parseDate(dynamic value) {
        if (value is DateTime) return value;
        final parsed = DateTime.tryParse(value?.toString() ?? '');
        return parsed ?? message.createdAt;
      }

      final mediaUrls = <String>[];
      final mediaRaw = map['mediaUrls'] ?? map['media_urls'];
      if (mediaRaw is List) {
        for (final item in mediaRaw) {
          final url = item?.toString().trim() ?? '';
          if (url.isNotEmpty) {
            mediaUrls.add(url);
          }
        }
      }

      final postImageUrl = (map['post_image_url'] ??
              map['postImageUrl'] ??
              (mediaUrls.isNotEmpty ? mediaUrls.first : null))
          ?.toString();

      final postVideoUrl =
          (map['post_video_url'] ?? map['postVideoUrl'])?.toString();

      return SharedPostData(
        postId: postId,
        postContent: (map['post_content'] ?? map['content'] ?? '').toString(),
        postImageUrl: (postImageUrl?.trim().isNotEmpty ?? false)
            ? postImageUrl!.trim()
            : null,
        postVideoUrl: (postVideoUrl?.trim().isNotEmpty ?? false)
            ? postVideoUrl!.trim()
            : null,
        postAuthorName:
            (map['post_author_name'] ?? map['authorName'] ?? '').toString(),
        postAuthorUsername:
            (map['post_author_username'] ?? map['authorUsername'] ?? '')
                .toString(),
        postAuthorAvatar:
            (map['post_author_avatar'] ?? map['authorAvatar'])?.toString(),
        postCreatedAt:
            parseDate(map['post_created_at'] ?? map['createdAt'] ?? ''),
        likeCount: parseInt(map['like_count'] ?? map['likesCount']),
        commentCount: parseInt(map['comment_count'] ?? map['commentsCount']),
        isVerified: parseBool(map['is_verified']),
        verificationType:
            (map['verification_type'] ?? map['verificationType'] ?? 'none')
                .toString(),
        role: map['role']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  List<String>? _extractSharedPostMediaUrls(
    MessageModel message,
    SharedPostData postData,
  ) {
    final urls = <String>{};

    final image = postData.postImageUrl?.trim() ?? '';
    if (image.isNotEmpty) {
      urls.add(image);
    }

    final video = postData.postVideoUrl?.trim() ?? '';
    if (video.isNotEmpty) {
      urls.add(video);
    }

    final raw = message.content.trim();
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final mediaRaw = map['mediaUrls'] ?? map['media_urls'];
          if (mediaRaw is List) {
            for (final item in mediaRaw) {
              final url = item?.toString().trim() ?? '';
              if (url.isNotEmpty) {
                urls.add(url);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (urls.isEmpty) return null;
    return urls.toList(growable: false);
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

class _ChatRenderItem {
  final int primaryIndex;
  final List<MessageModel> messages;

  const _ChatRenderItem({
    required this.primaryIndex,
    required this.messages,
  });

  bool get isAlbum => messages.length > 1;
  MessageModel get primaryMessage => messages.first;
  MessageModel get oldestMessage => messages.last;
}

class _SecretSystemNotice {
  final String id;
  final String text;
  final DateTime createdAt;

  const _SecretSystemNotice({
    required this.id,
    required this.text,
    required this.createdAt,
  });
}

class _AlbumMediaItem {
  final MessageModel message;
  final String source;

  const _AlbumMediaItem({
    required this.message,
    required this.source,
  });
}

class _ConversationImageGalleryBundle {
  final List<GalleryItem> items;
  final Map<String, int> indexByMessageId;

  const _ConversationImageGalleryBundle({
    required this.items,
    required this.indexByMessageId,
  });

  const _ConversationImageGalleryBundle.empty()
      : items = const [],
        indexByMessageId = const {};
}

class _ChatMediaAlbumBubble extends StatelessWidget {
  static const double _albumTileGap = 1.0;
  final List<_AlbumMediaItem> albumItems;
  final MessageModel statusMessage;
  final bool isMe;
  final String? caption;
  final ValueChanged<int> onImageTap;

  const _ChatMediaAlbumBubble({
    super.key,
    required this.albumItems,
    required this.statusMessage,
    required this.isMe,
    required this.onImageTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final hasCaption = caption != null && caption!.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
        minWidth: 140,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildGridLayout(context),
              ),
              if (!hasCaption)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _buildTimeAndStatus(
                    theme,
                    overlayMode: true,
                  ),
                ),
            ],
          ),
          if (hasCaption) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: isMe ? theme.myBubbleColor : theme.otherBubbleColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TelegramEmojiText(
                      caption!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      useTelegramEmoji:
                          EmojiRenderPolicy.useTelegramEmojiRenderer(),
                      style: TextStyle(
                        color: isMe
                            ? theme.myBubbleTextColor
                            : theme.otherBubbleTextColor,
                        fontSize: 14,
                        height: 1.35,
                        fontFamily: 'Vazir',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTimeAndStatus(theme),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    final visibleItems = albumItems.take(10).toList(growable: false);
    final count = visibleItems.length;

    if (count == 2) {
      return AspectRatio(
        aspectRatio: 1.75,
        child: Row(
          children: [
            Expanded(
              child: _buildTile(
                visibleItems[0],
                0,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: _albumTileGap),
            Expanded(
              child: _buildTile(
                visibleItems[1],
                1,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (count == 3) {
      return AspectRatio(
        aspectRatio: 1.5,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTile(
                visibleItems[0],
                0,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: _albumTileGap),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _buildTile(
                      visibleItems[1],
                      1,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: _albumTileGap),
                  Expanded(
                    child: _buildTile(
                      visibleItems[2],
                      2,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (count == 4) {
      return AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      visibleItems[0],
                      0,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: _albumTileGap),
                  Expanded(
                    child: _buildTile(
                      visibleItems[1],
                      1,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _albumTileGap),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      visibleItems[2],
                      2,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: _albumTileGap),
                  Expanded(
                    child: _buildTile(
                      visibleItems[3],
                      3,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Adaptive rows for 5-10 items so no trailing empty grid slot remains.
    // Examples:
    // 5 -> 3+2, 7 -> 3+2+2, 8 -> 3+3+2, 10 -> 3+3+2+2
    final rows = <List<int>>[];
    for (var i = 0; i < count; i += 3) {
      final end = (i + 3 > count) ? count : i + 3;
      rows.add(List<int>.generate(end - i, (offset) => i + offset));
    }
    if (rows.length >= 2 && rows.last.length == 1 && rows[rows.length - 2].length == 3) {
      final moved = rows[rows.length - 2].removeLast();
      rows.last.insert(0, moved);
    }

    final rowCount = rows.length;
    final gridAspectRatio = 3 / rowCount;

    return AspectRatio(
      aspectRatio: gridAspectRatio,
      child: Column(
        children: [
          for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) ...[
            Expanded(
              child: Row(
                children: [
                  for (var colIndex = 0;
                      colIndex < rows[rowIndex].length;
                      colIndex++) ...[
                    Expanded(
                      child: _buildTile(
                        visibleItems[rows[rowIndex][colIndex]],
                        rows[rowIndex][colIndex],
                        borderRadius: _adaptiveTileRadius(
                          rowIndex: rowIndex,
                          colIndex: colIndex,
                          rowCount: rowCount,
                          colCount: rows[rowIndex].length,
                        ),
                      ),
                    ),
                    if (colIndex != rows[rowIndex].length - 1)
                      const SizedBox(width: _albumTileGap),
                  ],
                ],
              ),
            ),
            if (rowIndex != rowCount - 1)
              const SizedBox(height: _albumTileGap),
          ],
        ],
      ),
    );
  }

  BorderRadius _adaptiveTileRadius({
    required int rowIndex,
    required int colIndex,
    required int rowCount,
    required int colCount,
  }) {
    final radius = BorderRadius.only(
      topLeft:
          rowIndex == 0 && colIndex == 0 ? const Radius.circular(12) : Radius.zero,
      topRight: rowIndex == 0 && colIndex == colCount - 1
          ? const Radius.circular(12)
          : Radius.zero,
      bottomLeft: rowIndex == rowCount - 1 && colIndex == 0
          ? const Radius.circular(12)
          : Radius.zero,
      bottomRight: rowIndex == rowCount - 1 && colIndex == colCount - 1
          ? const Radius.circular(12)
          : Radius.zero,
    );

    return radius;
  }

  Widget _buildTile(
    _AlbumMediaItem item,
    int index, {
    required BorderRadius borderRadius,
  }) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: Hero(
        tag: '${item.message.id}_${item.source.hashCode}',
        child: ClipRRect(
          borderRadius: borderRadius,
          child: _isNetworkUrl(item.source)
              ? CachedNetworkImage(
                  imageUrl: item.source,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildTilePlaceholder(),
                  errorWidget: (context, url, error) => _buildTilePlaceholder(),
                )
              : Image.file(
                  File(item.source),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildTilePlaceholder(),
                ),
        ),
      ),
    );
  }

  Widget _buildTilePlaceholder() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTimeAndStatus(
    ChatTheme theme, {
    bool overlayMode = false,
  }) {
    final textColor = overlayMode
        ? Colors.white
        : (isMe
            ? theme.myBubbleTextColor.withValues(alpha: 0.75)
            : theme.otherBubbleTextColor.withValues(alpha: 0.75));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: overlayMode ? 2 : 0,
      ),
      decoration: overlayMode
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe) ...[
            ValueListenableBuilder<MessageDeliveryStatus>(
              valueListenable: statusMessage.statusNotifier,
              builder: (context, status, _) {
                return TelegramMessageStatus(
                  status: status,
                  size: 14,
                  customColor: textColor,
                );
              },
            ),
            const SizedBox(width: 3),
          ],
          Text(
            _formatTime(statusMessage.createdAt),
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isNetworkUrl(String value) {
    final url = value.trim().toLowerCase();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
