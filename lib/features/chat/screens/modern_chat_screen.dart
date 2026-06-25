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
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/modern_chat_app_bar.dart';
import '../../../DB/profile_cache_service.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/message_model.dart';
import '../../../utils/compat_extensions.dart';
import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/time_utils.dart';
import '../providers/chat_providers.dart';
import '../repositories/chat_repository.dart';
import '../services/e2e_encryption_service.dart';
import '../domain/message_payload.dart';

// ✅ Theme & Widgets
import '../theme/chat_theme.dart';
import '../models/group_member_item.dart';
import '../widgets/enhanced_chat_background.dart';
import '../widgets/modern_reaction_picker.dart'
    show kDefaultReactions, ModernReactionPicker;
import '../widgets/retry_indicator_widget.dart' show ModernConnectionBanner;
import '../widgets/improved_animated_message_bubble.dart';
import '../widgets/reaction_reactor_avatar_stack.dart';
import '../widgets/reactions_detail_sheet.dart';
import '../widgets/modern_context_menu.dart';
import '../widgets/animated_chat_input.dart';
import '../widgets/vista_emoji_panel.dart';
import '../widgets/voice_input_state.dart';
import '../widgets/social_style_post_card.dart';
import '../widgets/date_divider.dart' as date_divider;
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/modern_message_status.dart';

// ✅ Providers
import '../../../provider/typing_provider.dart';
import '../../../provider/presence_provider.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../../../provider/settings_providers.dart';
import '../../../services/modern_read_receipt_service.dart';
import '../../../services/current_user_service.dart';
import '../../../services/user_profile_service.dart';

// ✅ New Features
import '../widgets/chat_attachment_sheet.dart';
import '../widgets/message_search_bar.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/delete_message_dialog.dart';
import '../widgets/floating_date_header.dart';
import '../widgets/modern_online_status.dart';
import '../services/chat_attachment_service.dart';
import '../services/chat_transfer_manager.dart';
import '../services/attachment_type_resolver.dart';
import '../services/audio_metadata_service.dart';
import '../services/upload_policy_service.dart';
import '../services/message_tombstone_service.dart';
import '../services/group_service.dart';
import '../../../services/typing_service.dart'; // ✅ سرویس تایپینگ
import '../../../services/current_chat_tracker.dart';
import '../../../services/orphaned_media_cleanup_service.dart';
import '../../../services/PushNotificationService.dart';
import '../../../services/instant_message_deletion.dart';
import '../widgets/block_report_bottom_sheet.dart';
import '../services/user_moderation_service.dart';
import '../services/voice_duration_service.dart';
import '../services/message_reactions_service.dart';
import '../utils/chat_text_direction.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/modern_emoji_text.dart';
import '../../emoji/widgets/modern_emoji_text_editing_controller.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../security/logging_utility.dart';
import '../models/message_reaction.dart' as reaction_models;
import 'package:Vista/features/posts/navigation/content_routes.dart';
import '../../stories/presentation/providers/story_providers.dart';
import '../../stories/presentation/screens/story_player_screen.dart';
import '../../stories/domain/entities/entities.dart';
import 'package:uuid/uuid.dart';

// ✅ Phase 4: Final Integration
import 'modern_profile_screen.dart';
import 'modern_group_profile_screen.dart';
import 'document_preview_screen.dart';
import '../screens/message_info_screen.dart';
// TODO: Use CompleteDeletionService for delete with undo
// import '../services/complete_deletion_service.dart';
import '../services/message_actions_service.dart';
import '../performance/adaptive_effects_provider.dart';
import '../performance/chat_message_render_window.dart';
import '../performance/chat_performance_profile.dart';
import '../widgets/chat_input_dock.dart';
import '../widgets/keyboard_stable_media_query.dart';
import '../widgets/chat_group_presence_summary.dart';
import '../widgets/chat_message_bindings.dart';
import '../widgets/chat_message_list_scope.dart';
import '../widgets/chat_message_list_view.dart';
import '../widgets/chat_selection_controller.dart';
import '../services/secret_chat_privacy_service.dart';
import '../utils/conversation_name_utils.dart';

part 'modern_chat_screen_app_bar.dart';
part 'modern_chat_screen_list.dart';
part 'modern_chat_screen_input.dart';
part 'modern_chat_screen_bubbles.dart';
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

  /// فایل‌های share شده که باید در چت فرستاده شوند
  final List<String> initialSharedFilePaths;

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
    this.initialSharedFilePaths = const [],
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

  final _messageController = ModernEmojiTextEditingController(
    useModernEmoji: EmojiRenderPolicy.useModernEmojiRenderer(),
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
  MessageModel? _editToMessage;
  String? _preEditDraft;
  _PendingReplyContext? _pendingReplyContext;
  bool _isNearTop = false;
  final _showScrollToBottomNotifier = ValueNotifier<bool>(false);
  String? _currentUserId;
  bool _isTransitioning =
      true; // ✅ Deferred one frame so the list builds off-screen during push

  // Messages already present when the chat opens render static (no per-bubble
  // entry animation) so the push slide shows settled content — Telegram-style.
  // Lifted shortly after reveal so genuinely new incoming messages still animate.
  bool _suppressInitialEntryAnims = true;

  // Search
  bool _isSearchMode = false;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys =
      {}; // ✅ کلیدها برای اسکرول به پیام

  // Selection mode (granular Riverpod state per conversation)
  String get _conversationId => widget.args.conversationId;

  ConversationChatSelection get _selectionActions =>
      ref.read(conversationChatSelectionProvider(_conversationId).notifier);

  ChatSelectionState get _selection =>
      ref.read(conversationChatSelectionProvider(_conversationId));

  // Floating date
  final _isScrollingNotifier = ValueNotifier<bool>(false);
  final _visibleDateNotifier = ValueNotifier<DateTime?>(null);
  DateTime? _lastVisibleDateUpdateAt;
  DateTime? _lastScrollVelocitySampleAt;
  DateTime? _lastReactionWindowUpdateAt;
  double _lastScrollVelocitySampleOffset = 0;

  // Typing status
  final _otherUserTypingNotifier = ValueNotifier<bool>(false);
  StreamSubscription<Set<String>>? _typingSubscription;

  // ✅ برای جلوگیری از اجرای منطق در build
  String? _lastFirstMessageId;
  List<MessageModel> _latestVisibleMessages = const [];
  List<MessageModel> _allLatestUiMessages = const [];
  final _messageRenderCapNotifier =
      ValueNotifier<int>(ChatMessageRenderWindow.initialCap);
  final _listOverlayRevision = ValueNotifier<int>(0);
  ChatMessageBindings? _cachedMessageBindings;
  int _cachedBindingsOverlayRevision = -1;
  int _cachedBindingsGalleryStructureVersion = -1;
  int _cachedBindingsUnreadCount = -1;

  // Unread messages
  String? _lastReadMessageId;
  int _unreadCount = 0;
  bool _didCaptureUnreadBoundary = false;

  // Services
  final _moderationService = UserModerationService();
  final _voiceService = VoiceDurationService();
  final _audioMetadataService = const AudioMetadataService();
  final _chatTransferManager = ChatTransferManager();
  final UploadPolicyService _uploadPolicyService = const UploadPolicyService();
  final AttachmentTypeResolver _attachmentTypeResolver =
      const AttachmentTypeResolver();
  final MessageTombstoneService _tombstoneService = MessageTombstoneService();
  final GroupService _groupService = GroupService();
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
  List<GroupMemberItem> _groupMembers = const [];
  Map<String, GroupMemberItem> _groupMemberById = const {};
  bool _isLoadingGroupMembers = false;

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
  double _inputHeight = 70.0; // مقدار اولیه بدون emoji panel
  final _inputHeightNotifier = ValueNotifier<double>(70.0);

  // ─── keyboard / emoji panel (Modern-style) ────────────────────────────
  double _cachedKeyboardHeight = 300.0; // last observed keyboard height
  double _cachedSafeBottom = 34.0;
  double _lastViewInsetBottom = 0.0;
  bool _showEmojiPanel = false;
  bool _isKeyboardRequested = false; // spacer while keyboard is opening
  bool _reduceEffectsFromKeyboard = false;
  Timer? _keyboardRequestTimeoutTimer;
  final _listBottomGapNotifier = ValueNotifier<double>(34.0);
  final _inputDockLayoutNotifier =
      ValueNotifier<ChatInputDockLayout>(ChatInputDockLayout.initial);
  final _keyboardEffectsNotifier = ValueNotifier<bool>(false);
  // Lock A – emoji→keyboard dismiss animation (keyboard going away).
  // Prevents didChangeMetrics from closing the panel while h>80 temporarily.
  bool _lockEmojiPanel = false;
  Timer? _lockEmojiPanelTimer;
  // Lock B – keyboard→emoji appear animation (keyboard coming up).
  // Keeps reservedHeight pinned to _cachedKeyboardHeight so the input bar
  // doesn't jump while kbViewInset is still small mid-animation.
  bool _isKeyboardOpening = false;
  Timer? _keyboardOpeningTimer;
  static const double _keyboardVisibleThreshold = 80.0;

  double _keyboardInsetFromPlatform() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final view = views.first;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

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
  // TOFU: once a peer-key-change warning is shown, don't spam it every emit.
  bool _peerKeyChangeWarned = false;
  ProviderSubscription<AsyncValue<List<MessageModel>>>? _messagesListener;
  ProviderSubscription<AsyncValue<Map<String, dynamic>>>?
      _performanceSettingsListener;
  ProviderSubscription<AsyncValue<ConnectionStatus>>? _connectionStatusListener;
  ConnectionStatus _latestConnectionStatus = ConnectionStatus.connecting;
  bool _showConnectionBannerAfterDelay = false;
  Timer? _connectionBannerDelayTimer;
  bool _didInitialJumpToBottom = false;
  int _pinnedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // ✅ شروع با یک رندر کپ بسیار کوچک برای جلوگیری از لگ در حین انیمیشن باز شدن صفحه
    _messageRenderCapNotifier.value = 15;
    _chatRepository = ref.read(chatRepositoryProvider);
    _typingService = ref.read(typingServiceProvider);
    _adaptiveEffectsController = ref.read(adaptiveEffectsProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    _checkBlockStatus();
    _loadHiddenMessages();
    _loadPinnedMessageCount();
    _bootstrapInitialReplyContext();

    // ✅ کارهای سبک که باید در فریم اول باشند
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cachedSafeBottom = MediaQuery.paddingOf(context).bottom;
      _listBottomGapNotifier.value = _cachedSafeBottom;
      _publishKeyboardLayout(force: true);

      // Allow entry animations again once the open slide + initial paint settle,
      // so new incoming messages animate but the open itself stays static/smooth.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _suppressInitialEntryAnims = false;
      });
    });
  }

  bool _didRunTransitionSettledLogic = false;

  void _onTransitionSettle() {
    if (!mounted || _didRunTransitionSettledLogic) return;
    _didRunTransitionSettledLogic = true;

    // ✅ الان که انیمیشن روی غلتک افتاده، کارهای سنگین، کوئری‌ها و لیسنرها رو استارت می‌زنیم
    _initReadReceipts();
    _initTypingListeners();
    _setupMessageSideEffectsListener();
    _setupConnectionStatusBannerListener();
    _setupAdaptiveEffects();

    unawaited(_fetchUserProfileIfNeeded());
    unawaited(_initSecretChatPolicy());
    if (widget.args.isGroup) {
      unawaited(_loadGroupMembersForHeader());
    }

    _chatRepository.setActiveConversation(widget.args.conversationId);
    CurrentChatTracker.instance.setOpenConversation(widget.args.conversationId);
    ref
        .read(pushNotificationServiceProvider)
        .cancelConversationNotification(widget.args.conversationId);
    _startActiveConversationHeartbeat();

    _chatRepository.resetUnreadCount(widget.args.conversationId);
    _chatRepository.markMessagesAsSeen(widget.args.conversationId);

    _startPolling();
    unawaited(_triggerPollingRefresh());
  }

  bool _didSetupRouteListener = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSetupRouteListener) {
      _didSetupRouteListener = true;
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          _isTransitioning = false;
          _onTransitionSettle();
          _messageRenderCapNotifier.value = ChatMessageRenderWindow.initialCap;
        } else {
          route.animation!.addListener(_onRouteAnimationTick);
          route.animation!.addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              _onTransitionSettle();
              _messageRenderCapNotifier.value = ChatMessageRenderWindow.initialCap;
            }
          });
        }
      } else {
        _isTransitioning = false;
        _onTransitionSettle();
      }
    }
  }

  void _onRouteAnimationTick() {
    final route = ModalRoute.of(context);
    if (route != null && route.animation != null && _isTransitioning) {
      // 0.15 = 15% through the animation. Momentum is established.
      if (route.animation!.value > 0.15) {
        if (mounted) {
          setState(() => _isTransitioning = false);
          _onTransitionSettle();
        }
        route.animation!.removeListener(_onRouteAnimationTick);
      }
    }
  }


  /// Renders the message list immediately (on the first post-frame), so it is
  /// already populated as the screen slides in — Telegram-style — instead of
  /// sliding in blank and filling later. Cached messages are ready instantly,
  /// and the first (heavier) build happens while the page is still mostly
  /// off-screen, so its cost is hidden behind the push animation rather than
  /// shown to the user as a blank gap.
  /// (Removed in favor of _onRouteAnimationTick)
  void _revealListWhenTransitionSettles() {
    // Logic moved to _onRouteAnimationTick
  }

  void _bootstrapInitialReplyContext() {
    final initialContent = widget.args.initialReplyContent?.trim() ?? '';
    if (initialContent.isEmpty) return;

    _pendingReplyContext = _PendingReplyContext(
      content: initialContent,
      senderName:
          (widget.args.initialReplySenderName ?? widget.args.otherUserName)
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

    // اگر فایل‌های share شده وجود داشت، بعد از آماده‌شدن چت آن‌ها را ارسال کن
    final sharedPaths = widget.args.initialSharedFilePaths;
    if (sharedPaths.isNotEmpty) {
      _processInitialSharedFiles(sharedPaths);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  String? get _activeReplyContent => _resolveReplyContentForSend(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      );

  String? get _activeReplySenderName => _resolveReplySenderNameForSend(
        replyTo: _replyToMessage,
        pendingReply: _pendingReplyContext,
      );

  String? _resolveReplyContentForSend({
    MessageModel? replyTo,
    _PendingReplyContext? pendingReply,
  }) {
    if (replyTo != null) return _replyPreviewContent(replyTo);
    return pendingReply?.content;
  }

  String? _resolveReplySenderNameForSend({
    MessageModel? replyTo,
    _PendingReplyContext? pendingReply,
  }) {
    if (replyTo != null) return _replySenderDisplayName(replyTo);
    if (pendingReply == null) return null;
    if (pendingReply.fromNote) return 'یادداشت ${pendingReply.senderName}';
    return pendingReply.senderName;
  }

  String _replySenderDisplayName(MessageModel message) {
    if (message.senderId == _currentUserId) return 'شما';

    final resolved = _resolveMessageSenderName(message).trim();
    if (resolved.isNotEmpty && resolved != 'کاربر') return resolved;

    return widget.args.isGroup ? 'کاربر' : widget.args.otherUserName;
  }

  String _replyPreviewContent(MessageModel message) => message.content;

  ({String? content, String? senderName}) _resolveReplyPreviewForMessage(
    MessageModel message,
    Map<String, MessageModel> messagesById,
  ) {
    final replyToMessageId = message.replyToMessageId?.trim();
    if (replyToMessageId == null || replyToMessageId.isEmpty) {
      return (
        content: message.replyToContent,
        senderName: message.replyToSenderName
      );
    }
    if (_isSyntheticNoteReplyId(replyToMessageId) ||
        replyToMessageId.startsWith('story:')) {
      return (
        content: message.replyToContent,
        senderName: message.replyToSenderName
      );
    }

    final liveReplyTarget = messagesById[replyToMessageId];
    if (liveReplyTarget == null) {
      return (
        content: message.replyToContent,
        senderName: message.replyToSenderName
      );
    }

    return (
      content: _replyPreviewContent(liveReplyTarget),
      senderName: _replySenderDisplayName(liveReplyTarget),
    );
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

  void _clearEditContext({bool restoreDraft = true}) {
    final draft = _preEditDraft;
    setState(() {
      _editToMessage = null;
      _preEditDraft = null;
      if (restoreDraft && draft != null) {
        _messageController.text = draft;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }
    });
  }

  String? get _activeEditPreviewContent {
    final message = _editToMessage;
    if (message == null) return null;
    final text = message.displayContent.trim();
    return text.isNotEmpty ? text : 'پیام';
  }

  void _startEditMessage(MessageModel message) {
    _clearReplyContext();
    final currentDraft = _messageController.text;
    setState(() {
      _preEditDraft = currentDraft.trim().isNotEmpty ? currentDraft : null;
      _editToMessage = message;
      _messageController.text = message.displayContent;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  Future<void> _saveEditedMessage() async {
    if (!mounted || _editToMessage == null) return;

    var content = _messageController.text.trim();
    if (content.isEmpty) {
      _showErrorSnackBar('متن پیام نمی‌تواند خالی باشد');
      return;
    }

    final target = _editToMessage!;
    final original = target.displayContent.trim();
    if (content == original) {
      _messageController.clear();
      _clearEditContext(restoreDraft: true);
      return;
    }

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
      content = await e2e.encryptMessage(content, sharedSecret);
    }

    final messageId = target.id;
    _messageController.clear();
    _clearEditContext(restoreDraft: false);

    final result =
        await ref.read(chatRepositoryProvider).editMessage(messageId, content);
    if (!mounted) return;

    if (result.isSuccess) {
      _showSuccessSnackBar('پیام ویرایش شد');
    } else {
      _showErrorSnackBar(result.error ?? 'خطا در ویرایش پیام');
      setState(() {
        _editToMessage = target;
        _messageController.text = original;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      });
      _focusNode.requestFocus();
    }
  }

  void _setReplyToMessage(MessageModel message) {
    _clearEditContext(restoreDraft: false);
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

      if (_otherUserTypingNotifier.value != isTyping) {
        _otherUserTypingNotifier.value = isTyping;
      }
    });

    final currentUserId = _currentUserId;
    final initialTypingUsers =
        _typingService.getTypingUsers(widget.args.conversationId);
    final initialIsTyping =
        initialTypingUsers.any((id) => id != currentUserId && id.isNotEmpty);
    if (_otherUserTypingNotifier.value != initialIsTyping) {
      _otherUserTypingNotifier.value = initialIsTyping;
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
    _connectionStatusListener = ref.listenManual<AsyncValue<ConnectionStatus>>(
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
    _allLatestUiMessages = uiMessages;
    final renderCap = _messageRenderCapNotifier.value;
    final windowed = ChatMessageRenderWindow.clip(uiMessages, renderCap);
    _latestVisibleMessages = windowed;
    _rescheduleSecretAutoDelete(uiMessages);

    if (widget.args.isSecret) {
      _processSecretChatKeyExchange(allMessages);
    }

    if (widget.args.isGroup) {
      unawaited(_prefetchMissingGroupSenderAvatars(displayMessages));
    }

    if (!_didCaptureUnreadBoundary && displayMessages.isNotEmpty) {
      _didCaptureUnreadBoundary = true;
      _lastReadMessageId = _resolveLastReadMessageId(displayMessages);
    }

    if (visibleMessages.any((m) => !m.isMe && !m.isSeen)) {
      unawaited(_chatRepository.markMessagesAsSeen(widget.args.conversationId));
    }

    _calculateUnreadCount(displayMessages);

    if (uiMessages.isEmpty) {
      _latestVisibleMessages = const [];
      _allLatestUiMessages = const [];
      _lastFirstMessageId = null;
      if (_visibleDateNotifier.value != null || _isScrollingNotifier.value) {
        _visibleDateNotifier.value = null;
        _isScrollingNotifier.value = false;
      }
      return;
    }

    if (!_didInitialJumpToBottom) {
      _didInitialJumpToBottom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
      });
    }

    final firstId = uiMessages.first.id;
    if (_lastFirstMessageId != firstId) {
      _lastFirstMessageId = firstId;
      _loadReactionsForMessages(uiMessages);
    }
    _updateReactionWindow(DateTime.now(), force: true, messages: uiMessages);

    if (_scrollController.hasClients && _scrollController.offset < 100) {
      final newDate = uiMessages.first.createdAt;
      if (_visibleDateNotifier.value == null ||
          !_isSameDay(_visibleDateNotifier.value!, newDate)) {
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

    // اگر کلید طرف مقابل را قبلاً pin کرده‌ایم: کلیدِ جدیدِ متفاوت = تلاش برای
    // جایگزینی کلید (MITM). به‌جای پذیرش بی‌صدا، هشدار می‌دهیم و کلیدِ pin‌شده را
    // نگه می‌داریم (Trust-On-First-Use).
    if (peerPubB64 != null) {
      _detectPeerKeyChange(messages, peerPubB64);
      return;
    }

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

      await _announceSecureChannel(myPubBytes, peerKeyMessage.content);
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
      final myKeyPair = await e2e.getSavedKeyPair(_currentUserId!);
      final myPubBytes =
          myKeyPair == null ? null : await e2e.getPublicKeyBytes(myKeyPair);
      await _announceSecureChannel(myPubBytes, peerReplyMessage.content);
      unawaited(_prepareSecretSharedSecret());
    }
  }

  /// Post the "secure channel established" notice plus the safety number, so the
  /// user can verify it out-of-band against their contact (defends against MITM
  /// key substitution — the server can swap keys but cannot fake a matching
  /// safety number on both devices).
  Future<void> _announceSecureChannel(
      List<int>? myPubBytes, String peerPubB64) async {
    if (myPubBytes == null) {
      _addSecretSystemNotice(
          'ارتباط رمزنگاری‌شده (E2EE) برقرار شد.');
      return;
    }
    try {
      final peerPub = base64Decode(peerPubB64);
      final safety = await E2EEncryptionService()
          .computeSafetyNumber(myPubBytes, peerPub);
      _addSecretSystemNotice(
          'ارتباط رمزنگاری‌شده (E2EE) برقرار شد.\n'
          'کد امنیتی (با مخاطب مقایسه کنید):\n$safety');
    } catch (_) {
      _addSecretSystemNotice('ارتباط رمزنگاری‌شده (E2EE) برقرار شد.');
    }
  }

  /// Detect a pinned-peer-key mismatch (possible MITM / device change).
  void _detectPeerKeyChange(List<MessageModel> messages, String pinnedPubB64) {
    if (_peerKeyChangeWarned) return;
    for (final m in messages) {
      if (m.isMe) continue;
      final type = m.attachmentType ?? m.messageType;
      if (type != 'exchange_key' && type != 'exchange_key_reply') continue;
      if (m.content.isNotEmpty && m.content != pinnedPubB64) {
        _peerKeyChangeWarned = true;
        _addSecretSystemNotice(
            '⚠️ کلید امنیتی مخاطب تغییر کرده است! ممکن است دستگاه طرف مقابل عوض '
            'شده باشد یا کسی در حال شنود باشد. کد امنیتی را دوباره با مخاطب '
            'مقایسه کنید.');
        break;
      }
    }
  }

  bool _looksEncryptedSecretPayload(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return false;
    // v1 envelope is detected by exact prefix — authoritative, no guessing.
    if (E2EEncryptionService().isEncryptedEnvelope(text)) return true;
    // Legacy (pre-v1, unprefixed) messages: fall back to a base64-shape check.
    // decryptMessage uses the MAC as the oracle, so a false positive here just
    // round-trips back to plaintext rather than corrupting anything.
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
        // decryptMessage returns the input unchanged for plaintext/legacy
        // non-ciphertext; only store a genuine decryption result.
        if (clear.isNotEmpty && clear != message.content) {
          _secretDecryptedContentByMessageId[message.id] = clear;
          changed = true;
        }
      } on E2EDecryptException {
        // Authenticated v1 envelope failed MAC → tampering or wrong key.
        _secretDecryptedContentByMessageId[message.id] = '⚠️ پیام دستکاری‌شده';
        changed = true;
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
    _visibleDateNotifier.value = date;
    _isScrollingNotifier.value = true;

    _floatingDateHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _isScrollingNotifier.value = false;
    });
  }

  /// راه‌اندازی سرویس Read Receipt
  void _initReadReceipts() {
    final readReceiptService = ModernReadReceiptService();
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

      ModernReadReceiptService().setLastMessageId(
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
      ModernReadReceiptService().setLastMessageId(
        widget.args.conversationId,
        myLastMessage.id,
      );
    });
  }

  /// علامت‌گذاری همه پیام‌ها به عنوان خوانده شده
  Future<void> _markAllMessagesAsRead() async {
    try {
      final readReceiptService = ModernReadReceiptService();
      await readReceiptService.markAllAsRead(widget.args.conversationId);
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// اگر نام کاربر نامعتبر باشد، پروفایل را از کش/سرور دریافت می‌کند
  Future<void> _fetchUserProfileIfNeeded() async {
    if (isUnknownConversationName(widget.args.otherUserName) &&
        widget.args.otherUserId.trim().isNotEmpty) {
      try {
        final profile =
            await ProfileCacheService().getProfile(widget.args.otherUserId);
        if (mounted) {
          setState(() {
            _otherUserProfile = profile;
          });
        }
        final resolvedName = sanitizeConversationName(profile.username) ??
            sanitizeConversationName(profile.fullName);
        final resolvedAvatar = profile.avatarUrl?.trim();
        if ((resolvedName?.isNotEmpty ?? false) ||
            (resolvedAvatar?.isNotEmpty ?? false)) {
          await _chatRepository.cacheConversationProfile(
            conversationId: widget.args.conversationId,
            otherUserId: widget.args.otherUserId,
            otherUserName: resolvedName,
            otherUserAvatar:
                (resolvedAvatar?.isNotEmpty ?? false) ? resolvedAvatar : null,
          );
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

  Future<void> _loadGroupMembersForHeader() async {
    if (!widget.args.isGroup || _isLoadingGroupMembers) return;

    setState(() => _isLoadingGroupMembers = true);
    try {
      final members =
          await _groupService.fetchGroupMembers(widget.args.conversationId);
      if (!mounted) return;

      setState(() {
        _groupMembers = members;
        _groupMemberById = {
          for (final member in members) member.userId: member,
        };
        _isLoadingGroupMembers = false;
      });
    } catch (e) {
      debugPrint('Error loading group members for chat header: $e');
      if (mounted) {
        setState(() => _isLoadingGroupMembers = false);
      }
    }
  }

  /// ✅ چک کردن اینکه کاربر می‌تواند ویرایش کند (تیک طلایی یا آبی)
  bool get _canEditMessages {
    if (_currentUserProfile == null) return false;
    return _currentUserProfile!.hasPremiumPrivileges;
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
        _hiddenMessageIds = {...hiddenIds, ...tombstoneIds};
        _bumpListOverlay();
      }
    } catch (e) {
      debugPrint('Error loading hidden messages: $e');
    }
  }

  Future<void> _loadPinnedMessageCount() async {
    try {
      final actionsService = ref.read(messageActionsServiceProvider);
      final pinned = await actionsService.getPinnedMessages(
        widget.args.conversationId,
      );
      if (mounted) {
        setState(() => _pinnedMessageCount = pinned.length);
      }
    } catch (_) {}
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
      _deletingMessageIds.add(messageId);
      _hiddenMessageIds.add(messageId);
      _bumpListOverlay();
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
        _deletingMessageIds.remove(messageId);
        _bumpListOverlay();
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
      ModernReadReceiptService().stopListening(widget.args.conversationId);
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
    // FIX: نباید state یک provider را داخل dispose (فاز قفل unmount درخت) تغییر داد —
    // وگرنه StateNotifierListenerError. controller سینگلتون long-lived است، پس reset
    // velocity را به microtask موکول می‌کنیم تا بعد از پایان finalizeTree اجرا شود.
    final adaptiveEffectsController = _adaptiveEffectsController;
    scheduleMicrotask(() => adaptiveEffectsController.updateScrollVelocity(0));

    _keyboardRequestTimeoutTimer?.cancel();
    _lockEmojiPanelTimer?.cancel();
    _keyboardOpeningTimer?.cancel();
    _scrollEndTimer?.cancel();
    _appBarAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _isScrollingNotifier.dispose();
    _visibleDateNotifier.dispose();
    _showScrollToBottomNotifier.dispose();
    _otherUserTypingNotifier.dispose();
    _inputHeightNotifier.dispose();
    _listBottomGapNotifier.dispose();
    _inputDockLayoutNotifier.dispose();
    _keyboardEffectsNotifier.dispose();
    _messageRenderCapNotifier.dispose();
    _listOverlayRevision.dispose();

    _clearActiveConversationState();
    if (widget.args.isSecret) {
      unawaited(SecretChatPrivacyService.instance.disableSecureDisplay());
    }

    super.dispose();
  }

  /// کیبورد ظاهر/مخفی شد – فقط height را cache کن
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    _handleKeyboardMetrics(_keyboardInsetFromPlatform());
  }

  ChatInputDockLayout _inputDockLayoutSnapshot() {
    return ChatInputDockLayout(
      showEmojiPanel: _showEmojiPanel,
      lockEmojiPanel: _lockEmojiPanel,
      isKeyboardOpening: _isKeyboardOpening,
      isKeyboardRequested: _isKeyboardRequested,
      cachedKeyboardHeight: _cachedKeyboardHeight,
      safeBottom: _cachedSafeBottom,
    );
  }

  /// همان منطق reservedHeight نسخه قبل (01cfb92):
  /// - emoji/transition lock → cache
  /// - کیبورد باز → viewInset زنده (هماهنگ با IME)
  /// - idle → safeBottom
  double _reservedHeightForInset(double liveInset) {
    final keyboardVisible = liveInset > _keyboardVisibleThreshold;
    if (_showEmojiPanel || _lockEmojiPanel || _isKeyboardOpening) {
      return _cachedKeyboardHeight;
    }
    if (keyboardVisible) {
      return liveInset;
    }
    if (_isKeyboardRequested) {
      return _cachedKeyboardHeight;
    }
    return _cachedSafeBottom;
  }

  void _publishKeyboardLayout({bool force = false}) {
    final bottomGap = _reservedHeightForInset(_lastViewInsetBottom);
    final reduceEffectsFromKeyboard = _reduceEffectsFromKeyboard ||
        ref.read(adaptiveEffectsProvider).effectsLevel == ChatEffectsLevel.low;
    final dockLayout = _inputDockLayoutSnapshot();

    if (force || bottomGap != _listBottomGapNotifier.value) {
      _listBottomGapNotifier.value = bottomGap;
    }
    if (force || dockLayout != _inputDockLayoutNotifier.value) {
      _inputDockLayoutNotifier.value = dockLayout;
    }
    if (force || reduceEffectsFromKeyboard != _keyboardEffectsNotifier.value) {
      _keyboardEffectsNotifier.value = reduceEffectsFromKeyboard;
    }
  }

  void _handleKeyboardMetrics(double h) {
    _lastViewInsetBottom = h;
    var layoutChanged = false;
    final nextGap = _reservedHeightForInset(h);
    if (nextGap != _listBottomGapNotifier.value) {
      layoutChanged = true;
    }
    final nextLayout = _inputDockLayoutSnapshot();
    if (nextLayout != _inputDockLayoutNotifier.value) {
      layoutChanged = true;
    }

    if (h > _keyboardVisibleThreshold) {
      _keyboardRequestTimeoutTimer?.cancel();

      if (_isKeyboardRequested) {
        _isKeyboardRequested = false;
        layoutChanged = true;
      }

      if (!_lockEmojiPanel) {
        if (h > _cachedKeyboardHeight) {
          _cachedKeyboardHeight = h;
        }
        if (_showEmojiPanel) {
          _showEmojiPanel = false;
          layoutChanged = true;
        }
      }

      if (_isKeyboardOpening && h >= _cachedKeyboardHeight * 0.95) {
        _keyboardOpeningTimer?.cancel();
        _isKeyboardOpening = false;
        layoutChanged = true;
      }

      if (!_reduceEffectsFromKeyboard) {
        _reduceEffectsFromKeyboard = true;
        layoutChanged = true;
      }
    } else {
      if (_lockEmojiPanel) {
        _lockEmojiPanelTimer?.cancel();
        _lockEmojiPanel = false;
      }
      if (_isKeyboardRequested) {
        _isKeyboardRequested = false;
        layoutChanged = true;
      }
      if (_reduceEffectsFromKeyboard) {
        _reduceEffectsFromKeyboard = false;
        layoutChanged = true;
      }
    }

    _publishKeyboardLayout(force: layoutChanged);
  }

  Future<void> _processInitialSharedFiles(List<String> sharedPaths) async {
    // Wait until _currentUserId is loaded (max 3 seconds)
    for (int i = 0; i < 30; i++) {
      if (_currentUserId != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted || _currentUserId == null) {
      debugPrint(
          'Timeout or unmounted waiting for _currentUserId to send shared files');
      return;
    }

    final files =
        sharedPaths.map((p) => File(p)).where((f) => f.existsSync()).toList();
    if (files.isEmpty) return;

    final firstMime = _guessMimeTypeFromPath(files.first.path) ?? '';
    final isMedia =
        firstMime.startsWith('image/') || firstMime.startsWith('video/');

    final selection = AttachmentSelection(
      type: isMedia ? ChatAttachmentType.gallery : ChatAttachmentType.file,
      files: files
          .map((f) => SelectedAttachmentFile(
                file: f,
                displayFileName: f.path.split('/').last,
                mimeType: _guessMimeTypeFromPath(f.path),
              ))
          .toList(),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await _handleAttachmentSelected(selection);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CurrentChatTracker.instance
          .setOpenConversation(widget.args.conversationId);
      _chatRepository.setActiveConversation(widget.args.conversationId);
      _startActiveConversationHeartbeat();
      unawaited(_triggerPollingRefresh());
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
        // 2s was aggressive: each poll that changes anything triggers a full
        // message re-emit + reprocess. 6s keeps chat near-real-time during SSE
        // outage without hammering the pipeline mid-scroll.
        _pollingTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
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
      Duration(milliseconds: 80);
  static const Duration _reactionWindowUpdateInterval =
      Duration(milliseconds: 180);
  static const double _reactionEstimateItemExtent = 88.0;
  static const int _reactionWindowBuffer = 10;

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final now = DateTime.now();
    final currentScroll = _scrollController.position.pixels;
    _sampleScrollVelocity(now, currentScroll);

    // 1. Pagination Logic
    final maxScroll = _scrollController.position.maxScrollExtent;

    // وقتی به ۲۰۰ پیکسلی انتهای لیست (بالا) رسیدیم
    final isNearTop = currentScroll >= maxScroll - 200;

    if (isNearTop != _isNearTop) {
      _isNearTop = isNearTop;
      if (_isNearTop) _loadMoreMessages();
    }

    // 2. Scroll to Bottom Button Visibility
    final showScrollButton = currentScroll > 500;
    if (showScrollButton != _showScrollToBottomNotifier.value) {
      _showScrollToBottomNotifier.value = showScrollButton;
    }

    // 3. Floating Date Logic
    if (!_isScrollingNotifier.value) {
      _isScrollingNotifier.value = true;
    }

    // Debounce برای پایان اسکرول (جلوگیری از تایمرهای تودرتو)
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _isScrollingNotifier.value = false;
      _adaptiveEffectsController.updateScrollVelocity(0);
      _updateReactionWindow(DateTime.now(), force: true);
      // آپدیت تاریخ فقط وقتی اسکرول متوقف شد
      if (currentScroll < 100) {
        _updateDateForBottom();
      } else {
        _updateVisibleDate(force: true);
      }
    });
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
        if (_visibleDateNotifier.value != null) {
          _visibleDateNotifier.value = null;
        }
        return;
      }

      final scrollOffset = _scrollController.offset;
      const itemHeight = 70.0;
      var visibleIndex = (scrollOffset / itemHeight).floor();
      visibleIndex = visibleIndex.clamp(0, messages.length - 1);

      if (visibleIndex >= 0 && visibleIndex < messages.length) {
        final newDate = messages[visibleIndex].createdAt;
        if (_visibleDateNotifier.value == null ||
            !_isSameDay(_visibleDateNotifier.value!, newDate)) {
          _visibleDateNotifier.value = newDate;
        }
      } else if (_visibleDateNotifier.value != null) {
        _visibleDateNotifier.value = null;
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
    final previousUnread = _unreadCount;
    if (_lastReadMessageId == null) {
      var count = 0;
      for (final message in messages) {
        if (!message.isMe && !message.isSeen) {
          count++;
        } else {
          break;
        }
      }
      _unreadCount = count;
    } else {
      final lastReadIndex =
          messages.indexWhere((m) => m.id == _lastReadMessageId);
      if (lastReadIndex == -1) {
        _unreadCount = 0;
      } else {
        var count = 0;
        for (var i = 0; i < lastReadIndex; i++) {
          final message = messages[i];
          if (!message.isMe && !message.isSeen) {
            count++;
          }
        }
        _unreadCount = count;
      }
    }
    if (previousUnread != _unreadCount) {
      _cachedMessageBindings = null;
      _bumpListOverlay();
    }
  }

  /// Newest-first list: first already-read message marks the unread boundary.
  /// When every loaded message is unread, anchor on the oldest loaded message.
  String? _resolveLastReadMessageId(List<MessageModel> messages) {
    for (final message in messages) {
      if (message.isMe || message.isSeen) {
        return message.id;
      }
    }
    return messages.isNotEmpty ? messages.last.id : null;
  }

  void _loadMoreMessages() {
    if (!mounted) return;
    _messageRenderCapNotifier.value = ChatMessageRenderWindow.expandCap(
      _messageRenderCapNotifier.value,
    );
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
        if (_visibleDateNotifier.value != null || _isScrollingNotifier.value) {
          _visibleDateNotifier.value = null;
          _isScrollingNotifier.value = false;
        }
        return;
      }

      final newestMessage = messages.first;
      final newDate = newestMessage.createdAt;

      if (_visibleDateNotifier.value == null ||
          !_isSameDay(_visibleDateNotifier.value!, newDate)) {
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
    final blurConfig = ref.read(adaptiveEffectsProvider);
    final isConnected = _latestConnectionStatus == ConnectionStatus.connected;
    final showConnectionBanner =
        !isConnected && _showConnectionBannerAfterDelay;

    final isPendingRequest = ref.watch(
      optimizedConversationsProvider.select((state) {
        for (final c in state.conversations) {
          if (c.id == widget.args.conversationId) {
            return c.messageRequestStatus == 'pending';
          }
        }
        return false;
      }),
    );

    return Directionality(
      textDirection: kChatLayoutTextDirection,
      child: Stack(
        children: [
          // والپیپر + لیست — ایزوله از viewInsets کیبورد (Flutter #170592)
          KeyboardStableMediaQuery(
            child: Stack(
              children: [
                // Background is a static Container + image: BackdropFilter was
                // removed in App-Perf P4.9, so blurIntensity / allowHeavyEffects
                // are no-ops. It was wrapped in ChatAdaptiveBlurScope + two
                // ValueListenableBuilders, so every scroll start/stop and keyboard
                // toggle rebuilt the full-screen background subtree just to emit
                // identical pixels. Collapsed to a const, repaint-isolated tree.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: EnhancedChatBackground(
                      enablePattern: true,
                      isTransitioning: _isTransitioning,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  extendBody: true,
                  extendBodyBehindAppBar: true,
                  resizeToAvoidBottomInset: false,
                  appBar: _isSearchMode
                      ? null
                      : PreferredSize(
                          preferredSize: const Size.fromHeight(kToolbarHeight),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final selection = ref.watch(
                                conversationChatSelectionProvider(
                                    _conversationId),
                              );
                              return ModernChatAppBar(
                                theme: theme,
                                isSelectionMode: selection.isSelectionMode,
                                selectedMessagesCount:
                                    selection.selectedMessageIds.length,
                                args: widget.args,
                                isOtherUserTyping: _otherUserTypingNotifier,
                                appBarAnimation: _appBarAnimation,
                                isTransitioning: _isTransitioning,
                                secretAutoDeleteSeconds:
                                    _secretAutoDeleteSeconds,
                                secretAutoDeleteLabel: _secretAutoDeleteLabel(
                                    _secretAutoDeleteSeconds),
                                secretAutoDeleteStatusText:
                                    _secretAutoDeleteStatusText(),
                                onExitSelectionMode: _exitSelectionMode,
                                onForwardSelected:
                                    selection.selectedMessageIds.isEmpty
                                        ? null
                                        : _forwardSelectedMessages,
                                onCopySelected:
                                    selection.selectedMessageIds.isEmpty
                                        ? null
                                        : _copySelectedMessages,
                                onDeleteSelected:
                                    selection.selectedMessageIds.isEmpty
                                        ? null
                                        : _deleteSelectedMessages,
                                onMenuAction: _handleMenuAction,
                                onBack: () => Navigator.of(context).pop(),
                                otherUserProfile: _otherUserProfile,
                                isOtherUserBlocked: _isOtherUserBlocked,
                                isCurrentUserBlocked: _isCurrentUserBlocked,
                                isLoadingGroupMembers: _isLoadingGroupMembers,
                                groupMembers: _groupMembers,
                                onTitleTap: _navigateToChatDetails,
                                pinnedMessageCount: _pinnedMessageCount,
                                onPinnedMessageTap:
                                    _scrollToLatestPinnedMessage,
                              );
                            },
                          ),
                        ),
                  body: Stack(
                    children: [
                      // Message list — built ONCE, decoupled from the scroll-state
                      // and visible-date notifiers. Previously the list sat inside
                      // nested ValueListenableBuilders, so every drag start/stop
                      // (isScrolling toggle) and date change rebuilt the whole list
                      // subtree + descriptor cache mid-scroll → the "stiff under the
                      // finger" hitch. The input-height wrapper was also redundant
                      // (its value was unused; padding is handled inside the list).
                      Positioned.fill(
                        child: _isTransitioning
                            ? const SizedBox.shrink()
                            : ChatMessageListScope(
                                conversationId: _conversationId,
                                buildList: (context, paginationState) =>
                                    _buildMessageList(
                                  paginationState,
                                  theme,
                                  bottomPaddingListenable:
                                      _listBottomGapNotifier,
                                  inputHeightListenable: _inputHeightNotifier,
                                ),
                              ),
                      ),
                      // Floating date chip — independent overlay so it can react to
                      // scroll state without touching the list.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ValueListenableBuilder<DateTime?>(
                            valueListenable: _visibleDateNotifier,
                            builder: (context, currentDate, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _isScrollingNotifier,
                                builder: (context, isScrolling, _) {
                                  return FloatingDateHeader(
                                    currentDate: currentDate,
                                    isScrolling: isScrolling,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
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
                        child: ModernConnectionBanner(
                          isConnected: !showConnectionBanner,
                          onRetry: !showConnectionBanner
                              ? null
                              : () {
                                  unawaited(_triggerPollingRefresh());
                                },
                        ),
                      ),
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
              ],
            ),
          ),

          // اینپوت — خارج از KeyboardStableMediaQuery → viewInsets زنده = چسبیده به IME
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: _isTransitioning
                  ? Container(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: theme.backgroundColor,
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor ?? Colors.black12,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ChatInputDock(
                      inputHeightListenable: _inputHeightNotifier,
                      layoutListenable: _inputDockLayoutNotifier,
                      keyboardEffectsListenable: _keyboardEffectsNotifier,
                      isScrollingListenable: _isScrollingNotifier,
                      showScrollToBottomListenable: _showScrollToBottomNotifier,
                      showInput: !_isCurrentUserBlocked && !_isOtherUserBlocked,
                      onScrollToBottom: _scrollToBottom,
                      themeBackgroundColor: theme.backgroundColor,
                      themeIconColor: theme.iconColor,
                      inputHaloBuilder: (reduceEffects,
                              {required gapHeight, required keyboardVisible}) =>
                          _buildInputDockHalo(
                        gapHeight: gapHeight,
                        inputHeight: _inputHeight,
                        keyboardVisible: keyboardVisible,
                        reduceEffects: reduceEffects,
                      ),
                      inputAreaBuilder: (reduceEffects) => isPendingRequest
                          ? _buildMessageRequestOverlay(theme)
                          : _buildInputArea(
                              theme,
                              reduceEffects: reduceEffects,
                              allowHeavyEffects:
                                  blurConfig.allowHeavyBlur && !reduceEffects,
                              blurSigma: blurConfig.blurSigma,
                            ),
                      emojiPanel: _buildEmojiPanel(theme),
                    ),
            ),
          ),

          Consumer(
            builder: (context, ref, _) {
              final selection = ref.watch(
                conversationChatSelectionProvider(_conversationId),
              );
              if (_reactionPickerMessageId == null ||
                  _reactionPickerPosition == null ||
                  selection.isSelectionMode) {
                return const SizedBox.shrink();
              }
              return _buildReactionPickerOverlay();
            },
          ),
        ],
      ),
    );
  }

  /// اندازه‌گیری ارتفاع اینپوت بار به شکل امن
  void _onInputHeightChanged(double newHeight) {
    if (!mounted || newHeight <= 0) return;
    if ((newHeight - _inputHeight).abs() < 1.0) return;

    _inputHeight = newHeight;
    _inputHeightNotifier.value = newHeight;
  }

  /// Modern-style: keyboard ↔ emoji swap
  void _onEmojiPanelToggled(bool show) {
    _keyboardRequestTimeoutTimer?.cancel();
    if (show) {
      // ── keyboard → emoji ─────────────────────────────────────────────────
      _lockEmojiPanelTimer?.cancel();
      _lockEmojiPanel = true;
      _lockEmojiPanelTimer = Timer(const Duration(milliseconds: 600), () {
        _lockEmojiPanel = false;
        _publishKeyboardLayout(force: true);
      });

      final h = _lastViewInsetBottom > 0
          ? _lastViewInsetBottom
          : _keyboardInsetFromPlatform();
      if (h > _keyboardVisibleThreshold) {
        _cachedKeyboardHeight = h;
      }
      _showEmojiPanel = true;
      _isKeyboardRequested = false;
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      _publishKeyboardLayout(force: true);
    } else {
      // ── emoji → keyboard ─────────────────────────────────────────────────
      _lockEmojiPanelTimer?.cancel();
      _lockEmojiPanel = false;

      _keyboardOpeningTimer?.cancel();
      _isKeyboardOpening = true;
      _keyboardOpeningTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _isKeyboardOpening = false;
        _publishKeyboardLayout(force: true);
      });

      _showEmojiPanel = false;
      _isKeyboardRequested = true;
      _focusNode.requestFocus();
      _publishKeyboardLayout(force: true);
      _keyboardRequestTimeoutTimer =
          Timer(const Duration(milliseconds: 800), () {
        if (mounted && _isKeyboardRequested) {
          _isKeyboardRequested = false;
          _publishKeyboardLayout(force: true);
        }
      });
    }
  }

  /// پنل ایموجی – جایگزین کیبورد با همان ارتفاع
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
    final captionDirection = kChatLayoutTextDirection;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
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
              child: Directionality(
                textDirection: captionDirection,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ModernEmojiText(
                        caption!.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: captionDirection,
                        textAlign: TextAlign.start,
                        useModernEmoji:
                            EmojiRenderPolicy.useModernEmojiRenderer(),
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
    if (rows.length >= 2 &&
        rows.last.length == 1 &&
        rows[rows.length - 2].length == 3) {
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
            if (rowIndex != rowCount - 1) const SizedBox(height: _albumTileGap),
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
      topLeft: rowIndex == 0 && colIndex == 0
          ? const Radius.circular(12)
          : Radius.zero,
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
        tag: '${item.message.id}_${item.source.hashCode}_$index',
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
                return ModernMessageStatus(
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
