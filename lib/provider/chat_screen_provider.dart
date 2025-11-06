import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';
import '../services/message_retry_service.dart';
import '../services/message_reaction_service.dart';
import '../DB/unified_message_cache_service.dart';
import '../services/optimized_message_deletion_service.dart';
import '../main.dart';
import 'chat_provider.dart';

// Class to hold parameters for the chat provider
class ChatProviderParams {
  final String conversationId;
  final String otherUserId;

  const ChatProviderParams(
      {required this.conversationId, required this.otherUserId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatProviderParams &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          otherUserId == other.otherUserId;

  @override
  int get hashCode => conversationId.hashCode ^ otherUserId.hashCode;
}

// A single, unified state for the chat screen
class ChatScreenState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const ChatScreenState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  ChatScreenState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return ChatScreenState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error, // Don't carry over old errors
    );
  }
}

// The single, efficient StateNotifier for the chat screen
class ChatScreenNotifier extends StateNotifier<ChatScreenState> {
  final ChatProviderParams params;
  final Ref? _ref;
  final ChatService _chatService = ChatService();
  final UnifiedMessageCacheService _cacheService = UnifiedMessageCacheService();
  final MessageRetryService _retryService = MessageRetryService();
  final OptimizedMessageDeletionService _deletionService =
      OptimizedMessageDeletionService();
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _reactionSubscription; // ✅ Subscription برای reactions
  bool _isFetching = false;
  bool _isKeyboardAnimating = false; // ✅ جلوگیری از عملیات سنگین در حین انیمیشن کیبورد
  DateTime? _lastInvalidateTime; // ✅ Debounce برای invalidation cache
  static const _pageSize = 30;
  int _retryCount = 0;
  static const int _maxRetries = 5; // برای قابلیت اطمینان بهتر

  // Tracking tempIds برای پیام‌های در حال ارسال تا از duplicate جلوگیری کنیم
  final Set<String> _pendingTempIds = {};

  // Mapping از localId به serverId برای بهتر deduplication
  final Map<String, String> _localToServerIdMap = {};

  ChatScreenNotifier(this.params, this._ref) : super(const ChatScreenState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    print(
        '🚀 Starting ChatProvider initialization for conversation: ${params.conversationId}');

    state = state.copyWith(isLoading: true);

    // بررسی وجود کاربر
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      print('❌ User not authenticated');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'کاربر وارد نشده است',
        );
      }
      return;
    }

    final userId = currentUser.id;

    // بررسی conversationId
    if (params.conversationId.isEmpty) {
      print('❌ ConversationId is empty');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'شناسه مکالمه نامعتبر است',
        );
      }
      return;
    }

    print('✅ User authenticated and conversationId valid');

    try {
      // 1. Load from cache first for instant UI
      print('📦 Loading from cache...');
      final cachedMessages = await _cacheService.getConversationMessages(
          params.conversationId, userId);
      print('✅ Loaded ${cachedMessages.length} messages from cache');
      if (mounted) {
        state = state.copyWith(messages: cachedMessages, isLoading: false);
      }

      // 2. Fetch from server to get latest messages
      print('🌐 Fetching from server...');
      await fetchLatestMessages();

      // 3. Listen for real-time updates
      print('📡 Starting real-time updates...');
      _listenForRealtimeUpdates();
      
      // 4. Listen for real-time reaction updates
      print('📡 Starting real-time reaction updates...');
      _listenForReactionUpdates();
    } catch (e) {
      print('❌ Error during initialization: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'خطا در بارگذاری پیام‌ها: $e',
        );
      }
    }
  }

  Future<void> fetchLatestMessages({bool fromKeyboard = false}) async {
    if (_isFetching || _isKeyboardAnimating) return;

    // ✅ جلوگیری از عملیات سنگین در حین انیمیشن کیبورد
    if (fromKeyboard) {
      _isKeyboardAnimating = true;
      await Future.delayed(const Duration(milliseconds: 300)); // صبر برای پایان انیمیشن
      _isKeyboardAnimating = false;
    }

    _isFetching = true;

    try {
      print(
          '🔄 Fetching latest messages for conversation: ${params.conversationId}');
      final serverMessages = await _chatService
          .getMessages(params.conversationId, limit: _pageSize);
      print('✅ Received ${serverMessages.length} messages from server');
      if (mounted) {
        _updateMessages(serverMessages);
      }
    } catch (e) {
      print('❌ Error fetching latest messages: $e');
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> fetchMoreMessages({bool fromKeyboard = false}) async {
    if (state.isLoading || !state.hasMore || _isFetching || _isKeyboardAnimating) return;

    // ✅ جلوگیری از عملیات سنگین در حین انیمیشن کیبورد
    if (fromKeyboard) {
      _isKeyboardAnimating = true;
      await Future.delayed(const Duration(milliseconds: 300)); // صبر برای پایان انیمیشن
      _isKeyboardAnimating = false;
    }

    state = state.copyWith(isLoading: true);
    _isFetching = true;

    try {
      final moreMessages = await _chatService.getMessages(
        params.conversationId,
        limit: _pageSize,
        offset: state.messages.length,
      );

      if (mounted) {
        if (moreMessages.isEmpty) {
          state = state.copyWith(hasMore: false, isLoading: false);
        } else {
          final updatedList = [...moreMessages, ...state.messages];
          _updateMessages(updatedList, fromPagination: true);
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    } finally {
      _isFetching = false;
    }
  }

  // ✅ Debouncing برای real-time updates
  Timer? _realtimeDebounceTimer;

  void _listenForRealtimeUpdates() {
    if (_realtimeSubscription != null) {
      print('⚠️ Real-time subscription already exists, skipping');
      return;
    }

    print(
        '📡 Setting up real-time subscription for conversation: ${params.conversationId}');

    try {
      _realtimeSubscription?.cancel();
      _realtimeSubscription =
          _chatService.subscribeToMessages(params.conversationId).listen(
        (messages) {
          // ✅ Debounce: فقط بعد از 150ms عدم تغییر، پردازش کن
          _realtimeDebounceTimer?.cancel();
          _realtimeDebounceTimer = Timer(const Duration(milliseconds: 150), () {
            print('📨 Received ${messages.length} real-time messages');
            if (mounted) {
              _updateMessages(messages);
            }
          });
        },
        onError: (error) {
          print('❌ Real-time subscription error: $error');
          if (mounted) {
            state = state.copyWith(error: 'خطا در دریافت پیام‌های جدید');
          }
          // تلاش مجدد با محدودیت
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 8), () {
              // از 10 به 8 ثانیه برای پاسخ سریع‌تر
              if (mounted) {
                _listenForRealtimeUpdates();
              }
            });
          } else {
            print('❌ Max retries reached for real-time subscription');
          }
        },
        onDone: () {
          print('⚠️ Real-time subscription closed, reconnecting...');
          _realtimeSubscription = null;
          // تلاش مجدد با محدودیت
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(seconds: 8), () {
              // از 10 به 8 ثانیه برای پاسخ سریع‌تر
              if (mounted) {
                _listenForRealtimeUpdates();
              }
            });
          } else {
            print('❌ Max retries reached for real-time subscription');
          }
        },
      );
    } catch (e) {
      print('❌ Error setting up real-time subscription: $e');
      if (mounted) {
        state = state.copyWith(error: 'خطا در راه‌اندازی دریافت پیام‌های جدید');
      }
      // تلاش مجدد با محدودیت
      if (_retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 8), () {
          // از 15 به 8 ثانیه برای پاسخ سریع‌تر
          if (mounted) {
            _listenForRealtimeUpdates();
          }
        });
      } else {
        print('❌ Max retries reached for real-time subscription setup');
      }
    }
  }

  // ✅ Listener برای real-time reaction updates
  void _listenForReactionUpdates() {
    if (_reactionSubscription != null) {
      print('⚠️ Reaction subscription already exists, skipping');
      return;
    }

    print('📡 Setting up reaction subscription for conversation: ${params.conversationId}');

    try {
      final reactionService = MessageReactionService();
      _reactionSubscription?.cancel();
      _reactionSubscription = reactionService
          .watchConversationReactions(params.conversationId)
          .listen(
        (reactions) {
          if (!mounted) return;

          // گروه‌بندی reactions بر اساس messageId
          final Map<String, Map<String, List<String>>> messageReactions = {};
          for (final reaction in reactions) {
            messageReactions[reaction.messageId] ??= {};
            messageReactions[reaction.messageId]![reaction.emoji] ??= [];
            // ✅ جلوگیری از duplicate user IDs
            if (!messageReactions[reaction.messageId]![reaction.emoji]!
                .contains(reaction.userId)) {
              messageReactions[reaction.messageId]![reaction.emoji]!
                  .add(reaction.userId);
            }
          }

          // آپدیت پیام‌هایی که reactions آنها تغییر کرده
          final currentMessages =
              Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
          bool hasChanges = false;

          for (final message in state.messages) {
            final newReactions = messageReactions[message.id] ?? {};

            // ✅ مقایسه دقیق‌تر reactions
            if (!_areReactionsEqual(newReactions, message.reactions)) {
              hasChanges = true;
              currentMessages[message.id] = message.copyWith(reactions: newReactions);
              print('📝 Updated reactions for message: ${message.id}');
            }
          }

          if (hasChanges && mounted) {
            final sortedMessages = currentMessages.values.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            state = state.copyWith(messages: sortedMessages);
            print('✅ Updated messages with new reactions');
          }
        },
        onError: (error) {
          print('❌ Real-time reaction subscription error: $error');
        },
      );
    } catch (e) {
      print('❌ Error setting up reaction subscription: $e');
    }
  }

  // ✅ Helper function برای مقایسه دقیق reactions
  bool _areReactionsEqual(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;

      final listA = List<String>.from(a[key]!)..sort();
      final listB = List<String>.from(b[key]!)..sort();

      if (listA.length != listB.length) return false;
      for (int i = 0; i < listA.length; i++) {
        if (listA[i] != listB[i]) return false;
      }
    }

    return true;
  }

  void _updateMessages(List<MessageModel> newMessages,
      {bool fromPagination = false}) {
    if (newMessages.isEmpty && !fromPagination) {
      print('⚠️ No new messages to update');
      return;
    }

    print('🔄 Updating messages: ${newMessages.length} new messages');

    final currentMessages =
        Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

    // Only add messages that don't already exist or are newer
    // AND skip messages that we're currently sending (pending tempIds)
    for (var msg in newMessages) {
      final existingMessage = currentMessages[msg.id];

      // اگر پیام‌ای از سرور می‌آید و ما همینطور قبلاً آن را موقتاً ارسال کرده‌ایم
      // آن را ignore کن تا duplicate نشود
      if (_pendingTempIds.contains(msg.id)) {
        print('⏭️ Skipped pending message from real-time: ${msg.id}');
        continue;
      }

      // اگر localId این پیام در mapping ما موجود است (یعنی ما ارسال کردیم)
      // پیام موقتی را پیدا کن و جایگزین کن
      if (msg.localId != null && _localToServerIdMap.containsKey(msg.localId)) {
        final oldTempId = msg.localId!;
        currentMessages.remove(oldTempId);
        print(
            '✨ Replacing temp message with server message: $oldTempId → ${msg.id}');
      }

      if (existingMessage == null ||
          msg.createdAt.isAfter(existingMessage.createdAt)) {
        // ✅ حفظ reaction‌های موجود اگر پیام جدید reaction ندارد
        if (msg.reactions.isEmpty && existingMessage != null && existingMessage.reactions.isNotEmpty) {
          currentMessages[msg.id] = msg.copyWith(reactions: existingMessage.reactions);
          print('📝 Added/Updated message: ${msg.id} (preserved reactions)');
        } else {
          currentMessages[msg.id] = msg;
          print('📝 Added/Updated message: ${msg.id}');
        }
      } else {
        // ✅ اگر پیام موجود است و جدیدتر نیست، reaction‌های جدید را اعمال کن
        if (msg.reactions.isNotEmpty && existingMessage.reactions != msg.reactions) {
          currentMessages[msg.id] = existingMessage.copyWith(reactions: msg.reactions);
          print('📝 Updated reactions for message: ${msg.id}');
        } else {
          print('⏭️ Skipped duplicate message: ${msg.id}');
        }
      }
    }

    final sortedMessages = currentMessages.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('✅ Updated message list: ${sortedMessages.length} total messages');

    if (mounted) {
      state = state.copyWith(messages: sortedMessages);
    }

    // ✅ بهینه‌سازی: Update cache در background با scheduleMicrotask
    scheduleMicrotask(() async {
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          await _cacheService.cacheMessages(newMessages, currentUser.id);

          // ✅ بروزرسانی conversation با debounce (فقط اگر پیام جدید از طرف مقابل باشه)
          if (newMessages.isNotEmpty &&
              newMessages.any((msg) => msg.senderId != currentUser.id) &&
              _ref != null) {
            // ✅ Debounce: جلوگیری از invalidate مکرر در کمتر از 1 ثانیه
            final now = DateTime.now();
            if (_lastInvalidateTime == null ||
                now.difference(_lastInvalidateTime!).inSeconds >= 1) {
              scheduleMicrotask(() {
                _ref.invalidate(conversationsProvider);
                _ref.invalidate(conversationsStreamProvider);
                _ref.invalidate(cachedConversationsStreamProvider);
                _ref.read(cachedConversationsProvider.notifier).refresh();
                _lastInvalidateTime = DateTime.now();
              });
            }
          }
        }
      } catch (e) {
        print('⚠️ Error caching messages: $e');
      }
    });
  }

  Future<void> sendMessage(String content,
      {String? attachmentUrl,
      String? attachmentType,
      String? attachmentFileName,
      int? duration,
      MessageModel? replyToMessage}) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = MessageModel.temporary(
      tempId: tempId,
      conversationId: params.conversationId,
      senderId: currentUser.id,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      duration: duration,
      replyToMessageId: replyToMessage?.id,
      replyToContent: replyToMessage?.content,
      replyToSenderName: replyToMessage?.senderName,
    );

    // 📌 اضافه کردن tempId به set تا real-time updates آن را ignore کند
    _pendingTempIds.add(tempId);
    print('📌 Added tempId to pending set: $tempId');

    // فوری نمایش پیام (Optimistic Update) - آنی و بدون تاخیر
    _showMessageOptimistically(tempMessage);

    // سپس ارسال به سرور در پس‌زمینه
    _performSendMessage(
      tempId,
      tempMessage,
      currentUser.id,
      content,
      attachmentUrl,
      attachmentType,
      attachmentFileName,
      duration,
      replyToMessage,
    );
  }

  /// نمایش فوری پیام قبل از تایید سرور (Optimistic Update)
  void _showMessageOptimistically(MessageModel tempMessage) {
    if (!mounted) return;

    print('⚡ Optimistic update: نمایش فوری پیام - ${tempMessage.id}');

    final currentMessages =
        Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
    currentMessages[tempMessage.id] = tempMessage;

    final sortedMessages = currentMessages.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    state = state.copyWith(messages: sortedMessages);
    print('✅ پیام فوری نمایش داده شد - ${tempMessage.id}');
  }

  Future<void> _performSendMessage(
    String tempId,
    MessageModel tempMessage,
    String userId,
    String content,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    int? duration,
    MessageModel? replyToMessage,
  ) async {
    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId: params.conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        attachmentFileName: attachmentFileName,
        localId: tempId,
        replyToMessageId: replyToMessage?.id,
        replyToContent: replyToMessage?.content,
        replyToSenderName: replyToMessage?.senderName,
      );

      // Success - بروزرسانی پیام موقتی با پیام واقعی (بدون duplicate)
      if (mounted) {
        final currentMessages =
            Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

        // حذف پیام موقتی
        currentMessages.remove(tempId);

        // اگر پیام واقعی قبلاً موجود است (از real-time)، حذف کن تا دوپلیکت نشود
        if (currentMessages.containsKey(sentMessage.id)) {
          print('⚠️ Message already exists from real-time, updating it');
          currentMessages.remove(sentMessage.id);
        }

        // اضافه کردن پیام واقعی
        currentMessages[sentMessage.id] = sentMessage;

        final sortedMessages = currentMessages.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = state.copyWith(messages: sortedMessages);
        print('✅ Message successfully sent and updated: ${sentMessage.id}');

        _cacheService.cacheMessage(sentMessage, userId);
        _cacheService.clearMessage(params.conversationId, tempId, userId);

        // Update conversation list
        if (_ref != null) {
          _ref.invalidate(conversationsProvider);
          _ref.invalidate(conversationsStreamProvider);
          _ref.invalidate(cachedConversationsStreamProvider);
          _ref.read(cachedConversationsProvider.notifier).refresh();
        }
      }

      // 📌 حذف tempId از pending set
      _pendingTempIds.remove(tempId);

      // 📌 اضافه کردن mapping از localId به serverId
      _localToServerIdMap[tempId] = sentMessage.id;
      print(
          '✅ Removed tempId from pending set: $tempId → ${sentMessage.id} (total pending: ${_pendingTempIds.length})');

      // Cancel any pending retries
      _retryService.cancelRetry(tempId);
    } catch (e) {
      // Failure - نمایش پیام با خطا
      print('❌ Failed to send message: $e');

      final errorMessage = e.toString();
      final failedMessage = tempMessage.copyWith(
        isSent: false,
        isPending: false,
        errorMessage: errorMessage,
        retryCount: 1,
        lastRetryTime: DateTime.now(),
      );

      // بروزرسانی پیام در UI با وضعیت خطا
      if (mounted) {
        final currentMessages =
            Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
        currentMessages[tempId] = failedMessage;

        final sortedMessages = currentMessages.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = state.copyWith(messages: sortedMessages);
      }

      // 📌 حذف tempId از pending set (حتی اگر ناموفق باشد)
      _pendingTempIds.remove(tempId);
      print('⚠️ Removed tempId from pending set due to error: $tempId');

      // Schedule automatic retry
      await _retryService.scheduleRetry(
        tempId,
        onRetry: () => _performSendMessage(
          tempId,
          failedMessage,
          userId,
          content,
          attachmentUrl,
          attachmentType,
          attachmentFileName,
          duration,
          replyToMessage,
        ),
        retryCount: 0,
      );
    }
  }

  /// Manually retry sending a failed message
  Future<void> resendMessage(String messageId) async {
    final message = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => MessageModel.empty(),
    );

    if (message.id.isEmpty) {
      print('❌ Message not found: $messageId');
      return;
    }

    print('👤 Manual resend for message: $messageId');

    // Remove error and retry the send
    await _retryService.manualRetry(
      messageId,
      onRetry: () => _performSendMessage(
        messageId,
        message,
        supabase.auth.currentUser?.id ?? '',
        message.content,
        message.attachmentUrl,
        message.attachmentType,
        message.attachmentFileName,
        message.duration,
        null,
      ),
    );
  }

  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    try {
      print('🗑️ Deleting message: $messageId (forEveryone: $forEveryone)');

      // استفاده از سرویس حذف بهینه‌شده (Optimistic + Batching)
      await _deletionService.deleteMessage(
        messageId: messageId,
        conversationId: params.conversationId,
        mode: forEveryone ? DeletionMode.everyone : DeletionMode.me,
        optimisticDelete: true,
      );

      // حذف فوری از UI (Optimistic Update)
      final currentMessages =
          Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
      currentMessages.remove(messageId);

      final sortedMessages = currentMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        state = state.copyWith(messages: sortedMessages);
      }

      print('✅ Message marked for deletion (will be synced): $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
      if (mounted) {
        state = state.copyWith(error: 'خطا در حذف پیام: $e');
      }
      rethrow;
    }
  }

  /// حذف دسته‌ای پیام‌ها (بهینه برای Clear All)
  Future<void> deleteMultipleMessages(List<String> messageIds,
      {bool forEveryone = false}) async {
    try {
      if (messageIds.isEmpty) return;

      print(
          '🗑️ Batch deleting ${messageIds.length} messages (forEveryone: $forEveryone)');

      // استفاده از حذف دسته‌ای بهینه‌شده
      await _deletionService.deleteMultipleMessages(
        conversationId: params.conversationId,
        messageIds: messageIds,
        mode: forEveryone ? DeletionMode.everyone : DeletionMode.me,
      );

      // حذف فوری از UI
      final currentMessages =
          Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
      for (final msgId in messageIds) {
        currentMessages.remove(msgId);
      }

      final sortedMessages = currentMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        state = state.copyWith(messages: sortedMessages);
      }

      print('✅ ${messageIds.length} messages marked for deletion');
    } catch (e) {
      print('❌ Error batch deleting messages: $e');
      if (mounted) {
        state = state.copyWith(error: 'خطا در حذف پیام‌ها: $e');
      }
      rethrow;
    }
  }

  void clearAllMessages() {
    print('🗑️ Clearing all messages from UI');
    if (mounted) {
      state = state.copyWith(messages: []);
    }

    // شروع حذف دسته‌ای در background
    // (بدون انتظار برای UI responsiveness)
    _deletionService
        .clearConversationMessages(
          conversationId: params.conversationId,
          mode: DeletionMode.me,
        )
        .then(
          (_) => print('✅ Conversation clear all initiated'),
          onError: (e) => print('⚠️ Error clearing conversation: $e'),
        );
  }

  /// ✅ به‌روزرسانی یک پیام خاص (برای reactions و ...)
  void updateMessage(MessageModel updatedMessage) {
    if (!mounted) return;

    final currentMessages =
        Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
    
    if (currentMessages.containsKey(updatedMessage.id)) {
      currentMessages[updatedMessage.id] = updatedMessage;
      
      final sortedMessages = currentMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      state = state.copyWith(messages: sortedMessages);
      
      // به‌روزرسانی کش
      scheduleMicrotask(() async {
        try {
          final currentUser = supabase.auth.currentUser;
          if (currentUser != null) {
            await _cacheService.cacheMessage(updatedMessage, currentUser.id);
          }
        } catch (e) {
          print('⚠️ Error caching updated message: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    // ✅ لغو تمام timer ها و subscription ها
    _realtimeDebounceTimer?.cancel();
    _realtimeSubscription?.cancel();
    _reactionSubscription?.cancel(); // ✅ لغو reaction subscription
    _retryService.dispose();
    _deletionService.dispose();
    super.dispose();
  }
}

// The provider for chat screen state management
final chatScreenProvider = StateNotifierProvider.family
    .autoDispose<ChatScreenNotifier, ChatScreenState, ChatProviderParams>(
        (ref, params) {
  return ChatScreenNotifier(params, ref);
});
