import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../DB/conversation_cache_service_wrapper.dart';
import '../DB/message_cache_service_wrapper.dart';
import '../DB/database_file_utils.dart';
import '../main.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';
import '../services/profile_service.dart';
import '../services/user_profile_service.dart';

// لیست مکالمات
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final conversations = await ref.watch(chatServiceProvider).getConversations();
  // conversations فقط مکالمات کاربر جاری را واکشی می‌کند
  return conversations;
});

// استریم مکالمات برای بروزرسانی خودکار
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  final userId = supabase.auth.currentUser!.id;
  final conversationCache = ConversationCacheService();

  // استریم تغییرات مکالمات فقط برای userId جاری
  return conversationCache.watchCachedConversations(userId);
});

// پرووایدر برای سرویس چت
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// پرووایدر برای ProfileService
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// پرووایدر برای دریافت پروفایل کاربر
final userProfileProvider =
    FutureProvider.family<ProfileData?, String>((ref, userId) async {
  return await ref.watch(profileServiceProvider).getProfile(userId);
});

// پرووایدر برای دریافت چندین پروفایل
final multipleProfilesProvider =
    FutureProvider.family<Map<String, ProfileData?>, List<String>>(
        (ref, userIds) async {
  return await ref.watch(profileServiceProvider).getMultipleProfiles(userIds);
});

// پرووایدر برای وضعیت آنلاین کاربر
final userOnlineStatusProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  return await ref.watch(profileServiceProvider).isUserOnline(userId);
});

// پرووایدر برای آمار کشینگ
final profileCacheStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(profileServiceProvider).getCacheStats();
});

// پیام‌های یک مکالمه
final messagesProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  final chatService = ref.watch(chatServiceProvider);
  final messageCache = MessageCacheService();
  final userId = supabase.auth.currentUser!.id;

  // ابتدا پیام‌های کش را بازگردان
  final cachedMessages =
      await messageCache.getConversationMessages(conversationId, userId);

  // اگر کش داریم، فوراً آن را نشان بده
  if (cachedMessages.isNotEmpty) {
    // بروزرسانی از سرور را در پس‌زمینه انجام بده
    ref.listenSelf((previous, next) {
      chatService.getMessages(conversationId).then((serverMessages) {
        if (serverMessages.isNotEmpty) {
          // اگر پیام‌های جدید از سرور آمد، کش را بروزرسانی کن
          messageCache.cacheMessages(serverMessages, userId);
        }
      });
    });

    return cachedMessages;
  }

  // اگر کش نداریم، از سرور دریافت کن
  return chatService.getMessages(conversationId);
});

// Lazy loading provider برای پیام‌های بیشتر (با سیستم کش پیشرفته)
final lazyMessagesProvider = StateNotifierProvider.family
    .autoDispose<LazyMessagesNotifier, LazyMessagesState, String>(
        (ref, conversationId) {
  return LazyMessagesNotifier(conversationId);
});

// سیستم کش یکپارچه پیشرفته

// State برای lazy loading
class LazyMessagesState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const LazyMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  LazyMessagesState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return LazyMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

// Notifier برای lazy loading
class LazyMessagesNotifier extends StateNotifier<LazyMessagesState> {
  final String conversationId;
  final ChatService _chatService = ChatService();
  final MessageCacheService _messageCache = MessageCacheService();
  static const int _pageSize = 10;
  int _currentPage = 0;
  // مجموعه پیام‌هایی که کاربر به‌صورت خوشبینانه حذف کرده
  final Set<String> _locallyDeletedMessageIds = <String>{};
  bool _disposed = false;

  LazyMessagesNotifier(this.conversationId) : super(const LazyMessagesState()) {
    _loadInitialMessages();
    _setupRealTimeListener();
  }

  // متد بهینه شده برای فیلتر کردن پیام‌های تکراری
  List<MessageModel> _filterDuplicateMessages(List<MessageModel> messages) {
    if (messages.isEmpty) return messages;

    // استفاده از Map برای عملکرد O(n) به جای O(n²)
    final Map<String, MessageModel> uniqueMessages = {};
    final Set<String> realLocalIds = {};

    // ابتدا پیام‌های واقعی را شناسایی کنیم
    for (final message in messages) {
      if (!message.id.startsWith('temp_') && message.localId != null) {
        realLocalIds.add(message.localId!);
      }
    }

    // سپس پیام‌های منحصر به فرد را انتخاب کنیم
    for (final message in messages) {
      // حذف پیام‌های temp که پیام واقعی‌شان آمده
      if (message.id.startsWith('temp_') && realLocalIds.contains(message.id)) {
        continue;
      }

      // اولویت با ID اصلی، سپس localId
      final key = message.localId ?? message.id;

      // اگر پیام با این کلید وجود ندارد، یا پیام فعلی واقعی‌تر است
      if (!uniqueMessages.containsKey(key) ||
          (!uniqueMessages[key]!.id.startsWith('temp_') &&
              message.id.startsWith('temp_'))) {
        uniqueMessages[key] = message;
      }
    }

    return uniqueMessages.values.toList();
  }

  Future<void> _loadInitialMessages() async {
    if (_disposed) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = supabase.auth.currentUser!.id;
      final cachedMessages =
          await _messageCache.getConversationMessages(conversationId, userId);

      if (cachedMessages.isNotEmpty) {
        // فیلتر پیام‌های حذف شده محلی
        final filteredCachedMessages = cachedMessages
            .where((m) => !_locallyDeletedMessageIds.contains(m.id))
            .toList();
        final filteredMessages =
            _filterDuplicateMessages(filteredCachedMessages);
        state = state.copyWith(
          messages: filteredMessages,
          isLoading: false,
          hasMore: filteredMessages.length >= _pageSize,
        );
        _currentPage = (filteredMessages.length / _pageSize).ceil();
      } else {
        await _loadMoreMessages();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMoreMessages() async {
    if (_disposed || state.isLoading || !state.hasMore) return;
    await _loadMoreMessages();
  }

  Future<void> _loadMoreMessages() async {
    if (_disposed) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final newMessages = await _chatService.getMessages(
        conversationId,
        offset: _currentPage * _pageSize,
        limit: _pageSize,
      );

      if (newMessages.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasMore: false,
        );
        return;
      }

      // فیلتر پیام‌های حذف شده محلی از پیام‌های جدید
      final filteredNewMessages = newMessages
          .where((m) => !_locallyDeletedMessageIds.contains(m.id))
          .toList();
      final updatedMessages = [...state.messages, ...filteredNewMessages];
      final filteredMessages = _filterDuplicateMessages(updatedMessages);

      state = state.copyWith(
        messages: filteredMessages,
        isLoading: false,
        hasMore: newMessages.length >= _pageSize,
      );

      _currentPage++;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  StreamSubscription? _realTimeSubscription;

  void _setupRealTimeListener() {
    if (_disposed) return;

    // Listen to new messages from the messages stream
    _realTimeSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .listen((jsonList) {
          if (_disposed) return;

          final userId = supabase.auth.currentUser!.id;
          final newMessages = jsonList
              .map((json) => MessageModel.fromJson(json, currentUserId: userId))
              .where((msg) => !msg.id.startsWith('temp_'))
              .toList();

          // سریعاً بررسی کنیم که آیا پیام جدیدی وجود دارد
          final existingIds = state.messages.map((m) => m.id).toSet();
          final existingLocalIds = state.messages
              .where((m) => m.localId != null)
              .map((m) => m.localId!)
              .toSet();

          final trulyNewMessages = newMessages.where((msg) {
            return !existingIds.contains(msg.id) &&
                !_locallyDeletedMessageIds.contains(msg.id) &&
                !(msg.localId != null &&
                    existingLocalIds.contains(msg.localId!));
          }).toList();

          if (trulyNewMessages.isNotEmpty) {
            addNewMessages(trulyNewMessages);
          }
        });
  }

  void addNewMessages(List<MessageModel> newMessages) async {
    if (_disposed || newMessages.isEmpty) return;

    // بررسی سریع پیام‌های تکراری قبل از اضافه کردن
    final existingIds = state.messages.map((m) => m.id).toSet();
    final existingLocalIds = state.messages
        .where((m) => m.localId != null)
        .map((m) => m.localId!)
        .toSet();

    final uniqueNewMessages = newMessages.where((message) {
      return !existingIds.contains(message.id) &&
          !_locallyDeletedMessageIds.contains(message.id) &&
          !(message.localId != null &&
              existingLocalIds.contains(message.localId!));
    }).toList();

    if (uniqueNewMessages.isEmpty) return;

    final updatedMessages = [...uniqueNewMessages, ...state.messages];
    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  void addTempMessageToLazy(MessageModel tempMessage) async {
    if (_disposed) return;

    // بررسی سریع وجود پیام تکراری
    final existingMessage = state.messages.any((m) =>
        m.id == tempMessage.id ||
        (m.localId != null && m.localId == tempMessage.localId) ||
        (tempMessage.localId != null && m.id == tempMessage.localId));

    if (existingMessage) return; // پیام قبلاً وجود دارد

    final updatedMessages = [tempMessage, ...state.messages];
    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  void replaceTempWithRealInLazy(
      String tempId, MessageModel realMessage) async {
    if (_disposed) return;

    // بررسی سریع وجود پیام موقت
    final tempMessageExists = state.messages.any((m) => m.id == tempId);
    if (!tempMessageExists) return;

    final updatedMessages = state.messages.map((m) {
      return m.id == tempId ? realMessage : m;
    }).toList();

    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  void addNewMessage(MessageModel message) async {
    if (_disposed) return;

    // بررسی سریع وجود پیام تکراری
    final existingMessage = state.messages.any((m) =>
        m.id == message.id ||
        (m.localId != null && m.localId == message.localId) ||
        (message.localId != null && m.id == message.localId));

    if (existingMessage) return; // پیام قبلاً وجود دارد

    // بررسی اینکه پیام حذف شده محلی نباشد
    if (_locallyDeletedMessageIds.contains(message.id)) return;

    final updatedMessages = [message, ...state.messages];
    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  void updateMessage(MessageModel message) async {
    if (_disposed) return;

    final updatedMessages = state.messages.map((m) {
      return m.id == message.id ? message : m;
    }).toList();

    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  void removeMessage(String messageId) {
    if (_disposed) return;
    _locallyDeletedMessageIds.add(messageId);
    final updatedMessages =
        state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  @override
  void dispose() {
    _disposed = true;
    _realTimeSubscription?.cancel();
    super.dispose();
  }
}

// استریم پیام‌های یک مکالمه (real-time, بدون پیام temp برای مقصد)
final messagesStreamProvider = StreamProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async* {
  final userId = supabase.auth.currentUser!.id;
  final cache = MessageCacheService();
  final chatService = ref.watch(chatServiceProvider);

  final isOnline = await chatService.isDeviceOnline();

  if (isOnline) {
    // فقط استریم Supabase
    yield* supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((jsonList) {
          // پیام‌های واقعی (id واقعی) را نگه دار، پیام temp را حذف کن
          final messages = jsonList
              .map((json) => MessageModel.fromJson(json, currentUserId: userId))
              .where((msg) => !msg.id.startsWith('temp_'))
              .toList();
          // کش را sync کن (فقط برای آفلاین)
          cache.cacheMessages(messages, userId);
          return messages;
        });
  } else {
    // فقط کش (آفلاین)
    final cached = await cache.getConversationMessages(conversationId, userId);
    // پیام temp را حذف کن (در آفلاین هم نباید پیام temp نمایش داده شود)
    yield cached.where((msg) => !msg.id.startsWith('temp_')).toList();
  }
});

// پرووایدر برای بررسی پیام‌های جدید
final hasNewMessagesProvider = FutureProvider.autoDispose<bool>((ref) async {
  // قابلیت خوانده شده حذف شد
  return false;
});

// پرووایدر برای MessageNotifier
final messageNotifierProvider =
    StateNotifierProvider.autoDispose<MessageNotifier, AsyncValue<void>>((ref) {
  return MessageNotifier(ref);
});

// کنترل‌کننده برای ارسال پیام
class MessageNotifier extends StateNotifier<AsyncValue<void>> {
  MessageNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // حذف پیام با امکان حذف برای همه
  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    if (_disposed) return;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversationId =
          await chatService.deleteMessage(messageId, forEveryone: forEveryone);

      // حذف خوشبینانه از UI: پیام را بلافاصله از state گفتگو حذف کن
      try {
        ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .markLocallyDeleted(messageId);
      } catch (_) {}

      // بروزرسانی فوری پیام‌ها و مکالمات
      ref.invalidate(messagesStreamProvider);
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);

      if (!_disposed) {
        state = const AsyncValue.data(null);
      }
    } catch (e, stack) {
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> togglePinConversation(String conversationId) async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.toggleConversationPinLocal(conversationId);

      // Invalidate providers to reflect the change
      ref.invalidate(
          conversationsProvider); // Fetches from server then updates cache
      ref.invalidate(
          cachedConversationsStreamProvider); // Directly listens to cache
      ref.invalidate(
          conversationsStreamProvider); // Listens to supabase + invalidates on message

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleMuteConversation(String conversationId) async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.toggleConversationMute(conversationId);

      // Invalidate providers to reflect the change
      ref.invalidate(conversationsProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      ref.invalidate(conversationsStreamProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleArchiveConversation(String conversationId) async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.toggleConversationArchive(conversationId);

      // Invalidate providers to reflect the change
      ref.invalidate(conversationsProvider);
      ref.invalidate(cachedConversationsStreamProvider);
      ref.invalidate(conversationsStreamProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // پاکسازی کامل مکالمه
  Future<void> clearConversation(String conversationId,
      {bool bothSides = false}) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.clearConversation(conversationId, bothSides: bothSides);

      // پاک‌سازی فوری وضعیت لیست پیام‌های در حافظه + علامت‌گذاری برای جلوگیری از بازگشت کش
      try {
        await ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .clearAllAndMark();
      } catch (_) {}

      // بروزرسانی providerها برای جلوگیری از بازگشت پیام‌ها از کش/استریم
      ref.invalidate(conversationMessagesProvider(conversationId));
      ref.invalidate(messagesStreamProvider(conversationId));
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // جستجوی پیام‌ها
  Future<List<MessageModel>> searchMessages(
      String conversationId, String query) async {
    if (_disposed) {
      return [];
    }

    try {
      final chatService = ref.read(chatServiceProvider);
      return await chatService.searchMessages(conversationId, query);
    } catch (e) {
      print('خطا در جستجوی پیام‌ها: $e');
      rethrow;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteConversation(conversationId);

      // بروزرسانی لیست مکالمات
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  static const int maxRetry = 3;

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    if (_disposed) return;

    // بررسی وجود پیام تکراری در حال ارسال
    final messages = ref.read(conversationMessagesProvider(conversationId));
    final existingTempMessages = messages.where((m) =>
        m.id.startsWith('temp_') &&
        m.content == content &&
        m.attachmentUrl == attachmentUrl &&
        m.attachmentType == attachmentType &&
        m.senderId == supabase.auth.currentUser!.id);

    // اگر پیام مشابه در حال ارسال وجود دارد، از ارسال دوباره جلوگیری کن
    if (existingTempMessages.isNotEmpty) {
      print('⚠️ پیام تکراری تشخیص داده شد - از ارسال دوباره جلوگیری شد');
      return;
    }

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${content.hashCode}';
    final currentUser = supabase.auth.currentUser!;

    final tempMessage = MessageModel.temporary(
      tempId: tempId,
      conversationId: conversationId,
      senderId: currentUser.id,
      content: content,
      createdAt: DateTime.now(),
      isRead: false,
      isSent: false,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      senderName: currentUser.userMetadata?['username'],
      senderAvatar: currentUser.userMetadata?['avatar_url'],
      retryCount: 0,
    );

    final notifier =
        ref.read(conversationMessagesProvider(conversationId).notifier);
    notifier.addTempMessage(tempMessage);

    // Also add to lazy messages provider for ChatScreen compatibility
    final lazyNotifier =
        ref.read(lazyMessagesProvider(conversationId).notifier);
    lazyNotifier.addTempMessageToLazy(tempMessage);

    // فقط اگر آنلاین بود، تیک بلافاصله بخورد
    final chatService = ref.read(chatServiceProvider);
    final isOnline = await chatService.isDeviceOnline();
    if (isOnline) {
      notifier.replaceTempWithReal(
        tempMessage.id,
        tempMessage.copyWith(isSent: true),
      );
    }

    // تلاش برای ارسال پیام با منطق retry
    unawaited(_trySendWithRetry(
      tempMessage: tempMessage.copyWith(isSent: isOnline),
      conversationId: conversationId,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      retryCount: 0,
    ));
  }

  Future<void> retrySendMessage(MessageModel failedMessage) async {
    if (_disposed) return;

    // بررسی اینکه آیا پیام هنوز در حال ارسال هست یا نه
    final messages =
        ref.read(conversationMessagesProvider(failedMessage.conversationId));
    final existingTempMessages = messages
        .where((m) => m.id == failedMessage.id && (m.isSent || m.isPending));

    // اگر پیام در حال ارسال یا ارسال شده هست، از retry جلوگیری کن
    if (existingTempMessages.isNotEmpty) {
      print('⚠️ پیام در حال ارسال یا ارسال شده - از retry جلوگیری شد');
      return;
    }

    final notifier = ref.read(
        conversationMessagesProvider(failedMessage.conversationId).notifier);

    final messageToRetry = failedMessage.copyWith(
      isPending: true,
      isSent: false,
      retryCount: 0,
    );

    notifier.updateMessage(messageToRetry);

    return _trySendWithRetry(
      tempMessage: messageToRetry,
      conversationId: messageToRetry.conversationId,
      content: messageToRetry.content,
      attachmentUrl: messageToRetry.attachmentUrl,
      attachmentType: messageToRetry.attachmentType,
      replyToMessageId: messageToRetry.replyToMessageId,
      replyToContent: messageToRetry.replyToContent,
      replyToSenderName: messageToRetry.replyToSenderName,
      retryCount: 0,
    );
  }

  Future<void> _trySendWithRetry({
    required MessageModel tempMessage,
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    required int retryCount,
  }) async {
    try {
      final chatService = ref.read(chatServiceProvider);

      final serverMessage = await chatService.sendMessage(
        conversationId: tempMessage.conversationId,
        content: tempMessage.content,
        attachmentUrl: tempMessage.attachmentUrl,
        attachmentType: tempMessage.attachmentType,
        replyToMessageId: tempMessage.replyToMessageId,
        replyToContent: tempMessage.replyToContent,
        replyToSenderName: tempMessage.replyToSenderName,
        localId: tempMessage.id,
      );

      // جایگزینی پیام موقت با پیام واقعی
      ref
          .read(conversationMessagesProvider(conversationId).notifier)
          .replaceTempWithReal(tempMessage.id, serverMessage);

      ref
          .read(lazyMessagesProvider(conversationId).notifier)
          .replaceTempWithRealInLazy(tempMessage.id, serverMessage);
    } catch (e) {
      if (retryCount < maxRetry - 1) {
        // تلاش مجدد با تاخیر تصاعدی
        final delayDuration = Duration(seconds: (retryCount + 1) * 2);
        await Future.delayed(delayDuration);

        final updatedTemp = tempMessage.copyWith(
            retryCount: retryCount + 1, isPending: true, isSent: false);

        ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .updateMessage(updatedTemp);

        return _trySendWithRetry(
          tempMessage: updatedTemp,
          conversationId: conversationId,
          content: content,
          attachmentUrl: attachmentUrl,
          attachmentType: attachmentType,
          replyToMessageId: replyToMessageId,
          replyToContent: replyToContent,
          replyToSenderName: replyToSenderName,
          retryCount: retryCount + 1,
        );
      } else {
        // علامت‌گذاری به عنوان ناموفق
        ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .markTempFailed(tempMessage.id);
      }
    }
  }

  Future<void> markAsRead(String conversationId) async {
    // قابلیت خوانده شده حذف شد
    return;
  }

  Future<ConversationModel> createConversation(String otherUserId) async {
    if (_disposed) {
      throw Exception('Notifier has been disposed');
    }

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.createConversation(otherUserId);

      if (_disposed) {
        throw Exception('Notifier was disposed during operation');
      }

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);
      state = const AsyncValue.data(null);
      return conversation;
    } catch (e, stack) {
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  // حذف تمام پیام‌های یک مکالمه
  Future<void> deleteAllMessages(String conversationId,
      {bool forEveryone = false}) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteAllMessages(conversationId,
          forEveryone: forEveryone);

      // بروزرسانی فوری UI با پاک کردن state و علامت‌گذاری برای جلوگیری از بازگشت کش
      await ref
          .read(conversationMessagesProvider(conversationId).notifier)
          .clearAllAndMark();

      // بروزرسانی لیست مکالمات در صفحه اصلی
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);
      ref.invalidate(cachedConversationsStreamProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('خطا در پاکسازی مکالمه: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> blockUser(String userId) async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.blockUser(userId);
      ref.invalidate(conversationsProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> reportUser(String userId, String reason) async {
    if (_disposed) return;
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.reportUser(userId: 'userId', reason: 'reason');
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// این کلاس را به chat_provider.dart.dart اضافه کنید
// در فایل chat_provider.dart اضافه کنید
class SafeMessageHandler {
  final MessageNotifier _notifier;

  SafeMessageHandler(this._notifier);

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    try {
      await _notifier.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        replyToMessageId: replyToMessageId,
        replyToContent: replyToContent,
        replyToSenderName: replyToSenderName,
      );
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId, String conversationId) async {
    try {
      await _notifier.deleteMessage(messageId);
    } catch (e) {
      print('خطا در حذف پیام: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    // قابلیت خوانده شده حذف شد
    return;
  }
}

final safeMessageHandlerProvider = Provider<SafeMessageHandler>((ref) {
  final notifier = ref.watch(messageNotifierProvider.notifier);
  return SafeMessageHandler(notifier);
});

// پرووایدر برای وضعیت آنلاین
// // بهبود استریم وضعیت آنلاین با کاهش فاصله زمانی
// final userOnlineStatusStreamProvider =
//     StreamProvider.family<bool, String>((ref, userId) {
//   return Stream.periodic(const Duration(seconds: 10), (_) async {
//     final chatService = ref.read(chatServiceProvider);
//     return await chatService.isUserOnline(userId);
//   }).asyncMap((future) => future);
// });

class UserOnlineNotifier {
  final Ref _ref;
  Timer? _timer;
  bool _isDisposed = false;

  UserOnlineNotifier(this._ref) {
    // ایجاد تایمر برای به‌روزرسانی وضعیت آنلاین هر ۳۰ ثانیه
    _startTimer();

    // افزودن listener برای مدیریت وضعیت آنلاین هنگام خروج از برنامه
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

    // به‌روزرسانی اولیه
    updateOnlineStatus();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isDisposed) {
        updateOnlineStatus();
      }
    });
  }

  Future<void> updateOnlineStatus() async {
    if (_isDisposed) return;

    try {
      final chatService = _ref.read(chatServiceProvider);
      await chatService.updateUserOnlineStatus();
    } catch (e) {
      print('خطا در به‌روزرسانی وضعیت آنلاین: $e');
    }
  }

  // تنظیم وضعیت آفلاین هنگام خروج از برنامه
  Future<void> setOffline() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').update({
          'is_online': false,
          'last_online': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
        print('setOffline: وضعیت کاربر به آفلاین تغییر یافت');
      }
    } catch (e) {
      print('خطا در تنظیم وضعیت آفلاین: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
  }
}

// کلاس برای مدیریت چرخه حیات برنامه
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final UserOnlineNotifier _notifier;

  _AppLifecycleObserver(this._notifier);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      // وقتی برنامه به پس‌زمینه می‌رود یا بسته می‌شود
      _notifier.setOffline();
    } else if (state == AppLifecycleState.resumed) {
      // وقتی برنامه دوباره فعال می‌شود
      _notifier.updateOnlineStatus();
    }
  }
}

// تغییر پرووایدر برای اضافه کردن WidgetsBinding
final userOnlineNotifierProvider = Provider<UserOnlineNotifier>((ref) {
  final notifier = UserOnlineNotifier(ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// استریم وضعیت آنلاین کاربر - بروزرسانی بیشتر
final userOnlineStatusStreamProvider =
    StreamProvider.family.autoDispose<bool, String>((ref, userId) {
  // به جای Stream.periodic، به تغییرات جدول profiles گوش می‌دهیم
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .timeout(const Duration(seconds: 30))
      .asyncMap((list) async {
        if (list.isEmpty) return false;

        // ابتدا تنظیمات نمایش آخرین بازدید را برای کاربر مقابل بخوان
        try {
          final settings = await supabase
              .from('user_settings')
              .select('last_seen_visibility')
              .eq('user_id', userId)
              .maybeSingle();

          final visibility = settings?['last_seen_visibility'] as String?;

          // اگر هیچکس، همیشه آفلاین نشان بده
          if (visibility == 'nobody') {
            return false;
          }

          // اگر فقط مخاطبین من، بررسی کن آیا کاربر فعلی مخاطب است
          if (visibility == 'my_contacts') {
            final currentUserId = supabase.auth.currentUser?.id;
            if (currentUserId == null) return false;

            // تعریف مخاطب: فالو دوطرفه
            final otherFollowsMe = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', userId)
                .eq('following_id', currentUserId)
                .maybeSingle();
            if (otherFollowsMe == null) return false;

            final iFollowOther = await supabase
                .from('follows')
                .select('id')
                .eq('follower_id', currentUserId)
                .eq('following_id', userId)
                .maybeSingle();
            if (iFollowOther == null) return false;
          }
        } catch (e) {
          print('Error checking privacy settings for $userId: $e');
          // در صورت خطا، محدودیت اعمال نشود
        }

        // اگر تنظیمات اجازه نمایش می‌دهد، وضعیت فنی آنلاین بودن را بررسی کن
        final profileData = list.first;
        final bool isOnline = profileData['is_online'] ?? false;
        final String? lastOnlineStr = profileData['last_online'];

        if (!isOnline || lastOnlineStr == null) return false;

        final lastOnline = DateTime.parse(lastOnlineStr).toUtc();
        final now = DateTime.now().toUtc();
        // اگر آخرین فعالیت کمتر از ۲ دقیقه پیش بوده، آنلاین در نظر بگیر
        return now.difference(lastOnline).inMinutes < 2;
      })
      .handleError((e) {
        print('Error in userOnlineStatusStreamProvider for $userId: $e');
        return false; // در صورت خطا، آفلاین در نظر بگیر
      });
});

// مجموع تعداد پیام‌های خوانده‌نشده از لیست مکالمات (برای بج آیکون)
final totalUnreadMessagesProvider = StreamProvider<int>((ref) {
  // قابلیت خوانده شده حذف شد
  return Stream.value(0);
});

// پرووایدر برای آخرین بازدید
final userLastOnlineProvider =
    FutureProvider.family<DateTime?, String>((ref, userId) async {
  final chatService = ref.watch(chatServiceProvider);
  return await chatService.getUserLastOnline(userId);
});

// آیا کاربر فعلی مجاز است آخرین بازدید کاربر مقابل را ببیند؟
final canShowLastSeenProvider =
    FutureProvider.family<bool, String>((ref, String otherUserId) async {
  try {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    // خواندن تنظیمات کاربر مقابل
    final settings = await supabase
        .from('user_settings')
        .select('last_seen_visibility')
        .eq('user_id', otherUserId)
        .maybeSingle();
    final visibility = settings?['last_seen_visibility'] as String?;

    if (visibility == null || visibility == 'everyone') return true;
    if (visibility == 'nobody') return false;

    if (visibility == 'my_contacts') {
      // تعریف «مخاطب» به صورت فالو دوطرفه
      final aFollowsB = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', currentUserId)
          .eq('following_id', otherUserId)
          .maybeSingle();
      if (aFollowsB == null) return false;
      final bFollowsA = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', otherUserId)
          .eq('following_id', currentUserId)
          .maybeSingle();
      return bFollowsA != null;
    }

    return true;
  } catch (_) {
    return true; // در صورت خطا، محدودیت اعمال نشود
  }
});

// تنظیم Provider برای بلاک کردن کاربر
final userBlockStatusProvider =
    FutureProvider.family<bool, String>((ref, userId) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.isUserBlocked(userId);
});

// تنظیم Notifier برای اعمال تغییرات روی وضعیت بلاک
final userBlockNotifierProvider =
    StateNotifierProvider<UserBlockNotifier, AsyncValue<void>>((ref) {
  return UserBlockNotifier(ref);
});

class UserBlockNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  UserBlockNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> blockUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.blockUser(userId);

      // بروزرسانی وضعیت بلاک و لیست مکالمات
      ref.invalidate(userBlockStatusProvider(userId));
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.unblockUser(userId);

      // بروزرسانی وضعیت بلاک و لیست مکالمات
      ref.invalidate(userBlockStatusProvider(userId));
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Notifier برای گزارش کاربر
final userReportNotifierProvider =
    StateNotifierProvider<UserReportNotifier, AsyncValue<void>>((ref) {
  return UserReportNotifier(ref);
});

class UserReportNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  UserReportNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? additionalInfo,
  }) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.reportUser(
        userId: userId,
        reason: reason,
        additionalInfo: additionalInfo,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// شمارش پیام‌های خوانده‌نشده برای یک مکالمه
final unreadMessageCountProvider =
    FutureProvider.family<int, String>((ref, conversationId) async {
  // قابلیت خوانده شده حذف شد
  return 0;
});

// حذف پیام‌های قدیمی‌تر از یک تاریخ خاص
final deleteOldMessagesProvider =
    FutureProvider.family<void, DateTime>((ref, date) async {
  final messageCache = MessageCacheService();
  await messageCache.deleteMessagesOlderThan(date);
});

class ImageDownloadState {
  final bool isDownloading;
  final bool isDownloaded;
  final double progress;
  final String? error;
  final String? path;

  const ImageDownloadState({
    this.isDownloading = false,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.error,
    this.path,
  });

  ImageDownloadState copyWith({
    bool? isDownloading,
    bool? isDownloaded,
    double? progress,
    String? error,
    String? path,
  }) {
    return ImageDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      path: path ?? this.path,
    );
  }
}

// نوتیفایر برای مدیریت وضعیت دانلود تصاویر
class ImageDownloadNotifier
    extends StateNotifier<Map<String, ImageDownloadState>> {
  ImageDownloadNotifier() : super({});

  void startDownload(String imageUrl) {
    state = {
      ...state,
      imageUrl: const ImageDownloadState(isDownloading: true, progress: 0.0),
    };
  }

  void updateProgress(String imageUrl, double progress) {
    final currentState = state[imageUrl];
    if (currentState != null) {
      state = {
        ...state,
        imageUrl: currentState.copyWith(progress: progress),
      };
    }
  }

  void setDownloaded(String imageUrl, String filePath) {
    state = {
      ...state,
      imageUrl:
          ImageDownloadState(isDownloaded: true, progress: 1.0, path: filePath),
    };
  }

  void setError(String imageUrl, String error) {
    state = {
      ...state,
      imageUrl: ImageDownloadState(error: error),
    };
  }

  void reset(String imageUrl) {
    final newState = Map<String, ImageDownloadState>.from(state);
    newState.remove(imageUrl);
    state = newState;
  }
}

final imageDownloadProvider = StateNotifierProvider<ImageDownloadNotifier,
    Map<String, ImageDownloadState>>(
  (ref) => ImageDownloadNotifier(),
);

// Provider برای listen همه مکالمات و نمایش نوتیفیکیشن پیام جدید
final globalChatNotificationProvider = Provider<void>((ref) {
  // دریافت لیست مکالمات
  final conversationsAsync = ref.watch(conversationsProvider);

  conversationsAsync.whenData((conversations) {
    for (final conversation in conversations) {
      // برای هر مکالمه، استریم پیام‌ها را watch کن
      ref.listen<AsyncValue<List<MessageModel>>>(
        messagesStreamProvider(conversation.id),
        (previous, next) {
          // فقط کافی است که استریم فعال باشد تا ChatService.subscribeToMessages اجرا شود
          // منطق نمایش نوتیفیکیشن در خود ChatService است
        },
      );
    }
  });
});

// Provider ترکیبی برای نمایش بهتر مکالمات
final combinedConversationsProvider =
    Provider<AsyncValue<List<ConversationModel>>>((ref) {
  final streamAsync = ref.watch(conversationsStreamProvider);
  final cachedAsync = ref.watch(conversationsProvider);

  // اگر استریم در حال لود است ولی کش داریم، از کش استفاده کن
  if (streamAsync.isLoading && cachedAsync.hasValue) {
    return cachedAsync;
  }

  // در غیر این صورت از استریم استفاده کن
  return streamAsync;
});

// تنظیم مجدد پرووایدر برای بروزرسانی وضعیت خوانده شدن پیام‌ها
final unreadMessagesProvider = StreamProvider<Map<String, int>>((ref) {
  // قابلیت خوانده شده حذف شد
  return Stream.value({});
});

// Provider برای مدیریت وضعیت مکالمات
final conversationStateProvider =
    StateNotifierProvider<ConversationStateNotifier, AsyncValue<void>>((ref) {
  return ConversationStateNotifier(ref);
});

class ConversationStateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ConversationStateNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> refreshConversations() async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.refreshConversations();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAsRead(String conversationId) async {
    // قابلیت خوانده شده حذف شد
    return;
  }
}

final deviceOnlineStatusProvider = StreamProvider<bool>((ref) async* {
  final chatService = ref.watch(chatServiceProvider);
  bool lastStatus = await chatService.isDeviceOnline();
  yield lastStatus;
  while (true) {
    await Future.delayed(const Duration(seconds: 3));
    final isOnline = await chatService.isDeviceOnline();
    if (isOnline != lastStatus) {
      lastStatus = isOnline;
      yield isOnline;
    }
  }
});

final pendingMessagesSyncProvider = Provider<void>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  ref.listen<AsyncValue<bool>>(deviceOnlineStatusProvider, (prev, next) {
    if (next.value == true) {
      chatService.sendPendingMessages();
    }
  });
});

final conversationRefreshProvider =
    StateNotifierProvider<ConversationRefreshNotifier, AsyncValue<void>>((ref) {
  return ConversationRefreshNotifier(ref);
});

class ConversationRefreshNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ConversationRefreshNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> refreshConversations() async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.refreshConversations();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// --- اضافه کنید: StateNotifier برای پیام‌های هر مکالمه ---
class ConversationMessagesNotifier extends StateNotifier<List<MessageModel>> {
  final String conversationId;
  final MessageCacheService _cacheService = MessageCacheService();
  final ConversationCacheService _conversationCache =
      ConversationCacheService();
  // مجموعه پیام‌هایی که کاربر به‌صورت خوشبینانه حذف کرده تا از استریم مجدد ظاهر نشوند
  final Set<String> _locallyDeletedMessageIds = <String>{};
  // زمان آخرین پاک‌سازی کامل برای جلوگیری از بازگشت پیام‌های قدیمی از استریم/کش
  DateTime? _clearedAt;

  ConversationMessagesNotifier(this.conversationId) : super([]) {
    _init();
  }

  Future<void> _init() async {
    if (_disposed) return;

    final userId = supabase.auth.currentUser!.id;
    final cached =
        await _cacheService.getConversationMessages(conversationId, userId);
    if (!_disposed) {
      state = [...cached];
      _updateUnreadCount();
    }
  }

  // شمارش دقیق پیام‌های خوانده‌نشده و بروزرسانی کش مکالمه
  Future<void> _updateUnreadCount() async {
    if (_disposed) return;

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // فقط پیام‌هایی که:
    // - isRead == false
    // - senderId != currentUserId (یعنی پیام دریافتی)
    // - پیام مخفی نشده نباشد (در کش پیام‌ها فرض بر این است که پیام‌های مخفی حذف شده‌اند)
    final unreadCount = state
        .where((msg) => !msg.isRead && msg.senderId != currentUserId)
        .length;

    // بروزرسانی کش مکالمه
    final conversation =
        await _conversationCache.getConversation(conversationId, currentUserId);
    if (conversation != null) {
      final updated = conversation.copyWith(
        unreadCount: unreadCount,
        hasUnreadMessages: unreadCount > 0,
      );
      await _conversationCache.updateConversation(updated, currentUserId);
    }
  }

  // حذف پیام temp که پیام واقعی با localId آمده (برای هر بار set state)
  List<MessageModel> _filterTempDuplicates(List<MessageModel> messages) {
    final realLocalIds = messages
        .where((m) => !m.id.startsWith('temp_') && m.localId != null)
        .map((m) => m.localId)
        .toSet();
    return messages
        .where(
            (m) => !(m.id.startsWith('temp_') && realLocalIds.contains(m.id)))
        .toList();
  }

  void addTempMessage(MessageModel message) {
    if (_disposed) return;

    // ابتدا بررسی کن که آیا پیامی با همین localId (که در اینجا message.id است) وجود دارد یا خیر
    // این کار برای جلوگیری از افزودن مجدد پیام موقت در صورت رفرش‌های ناخواسته است.
    if (state.any((m) => m.id == message.id)) {
      return;
    }
    final newState = [
      ...state.where((m) => m.id != message.id && m.localId != message.id),
      message
    ];
    state = _filterTempDuplicates(newState);
    // کش کردن پیام موقت
    if (!message.id.startsWith('temp_')) {
      print("خطای منطقی: پیام موقت باید با temp_ شروع شود:  [31m");
    }
    final userId = supabase.auth.currentUser!.id;
    _cacheService.cacheMessage(
        message, userId); // پیام موقت را با همان ID موقت کش کن
  }

  void replaceTempWithReal(String tempId, MessageModel realMessage) {
    final newState = [
      ...state.where((m) => m.id != tempId && m.localId != tempId),
      realMessage
    ];
    state = _filterTempDuplicates(newState);
    // ابتدا پیام موقت را از کش حذف کن
    final userId = supabase.auth.currentUser!.id;
    _cacheService.clearMessage(conversationId, tempId, userId).then((_) {
      // سپس پیام واقعی را کش کن
      _cacheService.cacheMessage(realMessage, userId);
    }).catchError((e) {
      print("خطا در جایگزینی پیام در کش: $e");
    });
  }

  void markTempFailed(String tempId) {
    final newState = [
      for (final m in state)
        if (m.id == tempId)
          m.copyWith(isSent: false, isPending: false)
        else
          m // Ensure isPending is false
    ];
    state = _filterTempDuplicates(newState);
    _cacheService.markMessageAsFailed(conversationId, tempId);
  }

  // برای آپدیت کردن پیام موجود در لیست (مثلا برای retry)
  void updateMessage(MessageModel updatedMessage) {
    if (_disposed) return;

    final newState = state.map((m) {
      if (m.id == updatedMessage.id) {
        return updatedMessage;
      }
      return m;
    }).toList();
    state =
        newState; // این setter مرتب‌سازی و فیلتر _filterTempDuplicates را اعمال می‌کند
    final userId = supabase.auth.currentUser!.id;
    _cacheService.cacheMessage(
        updatedMessage, userId); // پیام آپدیت شده را در کش هم ذخیره کن
  }

  // اضافه کردن پیام جدید به state (بدون invalidate کردن کل provider)
  void addMessage(MessageModel message) {
    if (_disposed) return;

    final newState = [...state, message];
    state = _filterTempDuplicates(newState);
    final userId = supabase.auth.currentUser!.id;
    _cacheService.cacheMessage(message, userId);
  }

  // حذف پیام از state (بدون invalidate کردن کل provider)
  void removeMessage(String messageId) {
    if (_disposed) return;

    final newState = state.where((m) => m.id != messageId).toList();
    state = _filterTempDuplicates(newState);
    final userId = supabase.auth.currentUser!.id;
    _cacheService.clearMessage(conversationId, messageId, userId);
  }

  // علامت‌گذاری حذف خوشبینانه برای همگام‌سازی با استریم
  void markLocallyDeleted(String messageId) {
    if (_disposed) return;

    _locallyDeletedMessageIds.add(messageId);
    removeMessage(messageId);
  }

  // متد جدید برای پاک کردن تمام پیام‌ها از state
  void clearAll() {
    if (_disposed) return;
    state = [];
  }

  // پاک‌سازی کامل + ثبت زمان پاک‌سازی و حذف کش لوکال
  Future<void> clearAllAndMark() async {
    if (_disposed) return;

    _clearedAt = DateTime.now();
    if (!_disposed) {
      state = [];
    }
    final userId = supabase.auth.currentUser!.id;
    await _cacheService.clearConversationMessages(conversationId, userId);
  }

  // جایگزینی پیام موقت با پیام واقعی (بدون invalidate کردن کل provider)
  void replaceTempMessage(String tempId, MessageModel realMessage) {
    if (_disposed) return;

    final newState = state.map((m) {
      if (m.id == tempId) {
        return realMessage;
      }
      return m;
    }).toList();
    state = _filterTempDuplicates(newState);

    // آپدیت کش
    final userId = supabase.auth.currentUser!.id;
    _cacheService.clearMessage(conversationId, tempId, userId).then((_) {
      _cacheService.cacheMessage(realMessage, userId);
    }).catchError((e) {
      print("خطا در جایگزینی پیام در کش: $e");
    });
  }

  void markMessageAsFailed(String messageId) {
    if (_disposed) return;

    final newState = [
      for (final m in state)
        if (m.id == messageId)
          m.copyWith(isSent: false, isPending: false)
        else
          m
    ];
    state = newState;
    _cacheService.markMessageAsFailed(conversationId, messageId);
  }

  // Update unread count for the conversation
  Future<void> updateConversationUnreadCount() async {
    await _cacheService.countUnreadMessages(conversationId);
    // state = [
    //   for (final message in state) message.copyWith(unreadCount: unreadCount)
    // ];
  }

  @override
  set state(List<MessageModel> value) {
    // همیشه قبل از ست کردن state، پیام temp که پیام واقعی‌اش آمده حذف کن
    final filtered = _filterTempDuplicates(value);
    // مرتب‌سازی
    final sortedList = [...filtered]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    super.state = sortedList;
    Future.microtask(() {
      _updateUnreadCount();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final conversationMessagesProvider = StateNotifierProvider.family
    .autoDispose<ConversationMessagesNotifier, List<MessageModel>, String>(
  (ref, conversationId) {
    final link = ref
        .keepAlive(); // جلوگیری از dispose شدن زودهنگام تا زمانی که صفحه چت باز است
    final notifier = ConversationMessagesNotifier(conversationId);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final sub = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .listen((jsonDataList) async {
            // دریافت لیست پیام‌های مخفی شده برای کاربر فعلی در این گفتگو
            final hiddenIdsResp = await supabase
                .from('hidden_messages')
                .select('message_id')
                .eq('user_id', userId)
                .eq('conversation_id', conversationId);
            final hiddenIds =
                hiddenIdsResp.map((e) => e['message_id'] as String).toSet();

            // مجموعه شناسه‌های پیام‌های روی سرور (بعد از فیلتر مخفی)
            List<MessageModel> serverMessagesRaw = jsonDataList
                .map((jsonMsg) =>
                    MessageModel.fromJson(jsonMsg, currentUserId: userId))
                .where((m) =>
                    !hiddenIds.contains(m.id) &&
                    !notifier._locallyDeletedMessageIds.contains(m.id))
                .toList();
            // Process messages in stream for immediate UI
            try {
              if (serverMessagesRaw.isNotEmpty) {
                // Process messages
              }
            } catch (_) {}
            if (notifier._clearedAt != null) {
              serverMessagesRaw = serverMessagesRaw
                  .where((m) => m.createdAt.isAfter(notifier._clearedAt!))
                  .toList();
            }
            // final serverIds = serverMessagesRaw.map((m) => m.id).toSet();

            // پیام‌های temp موجود از کش که هنوز جایگزین نشده‌اند را نگه دار
            final cachedNow = await notifier._cacheService
                .getConversationMessages(conversationId, userId);
            final tempMessagesInState =
                cachedNow.where((m) => m.id.startsWith('temp_')).toList();

            // اگر سرور پیامی با localId برابر temp داشت، temp را حذف کن
            final tempIdsToRemove = tempMessagesInState
                .where((t) => serverMessagesRaw.any((s) => s.localId == t.id))
                .map((t) => t.id)
                .toSet();
            final remainingTempMessages = tempMessagesInState
                .where((t) => !tempIdsToRemove.contains(t.id))
                .toList();

            // ساخت state جدید: temp های باقی‌مانده + پیام‌های سرور (پس از فیلتر مخفی)
            final List<MessageModel> nextState = [
              ...remainingTempMessages,
              ...serverMessagesRaw,
            ];

            // آپدیت کش فقط برای پیام‌هایی که جدید هستند یا از خود کاربرند
            final existingIdsInCache = cachedNow.map((m) => m.id).toSet();
            final toCache = serverMessagesRaw
                .where((m) => !existingIdsInCache.contains(m.id))
                .toList();
            if (toCache.isNotEmpty) {
              await notifier._cacheService.cacheMessages(toCache, userId);
            }

            // حذف از کش پیام‌هایی که مخفی شده‌اند
            if (hiddenIds.isNotEmpty) {
              for (final hiddenId in hiddenIds) {
                await notifier._cacheService
                    .clearMessage(conversationId, hiddenId, userId);
              }
            }

            // به‌روزرسانی کش مکالمه بر اساس جدیدترین پیام سرور (در صورت وجود)
            if (serverMessagesRaw.isNotEmpty) {
              final latest = serverMessagesRaw
                  .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
              final conversationCache = ConversationCacheService();
              final conversation = await conversationCache.getConversation(
                  conversationId, userId);
              if (conversation != null &&
                  latest.createdAt.isAfter(conversation.updatedAt)) {
                final updatedConversation = conversation.copyWith(
                  lastMessage: latest.content,
                  lastMessageTime: latest.createdAt,
                  updatedAt: latest.createdAt,
                );
                await conversationCache.updateConversation(
                    updatedConversation, userId);
                ref.invalidate(conversationsStreamProvider);
                ref.invalidate(cachedConversationsStreamProvider);
              }
            }

            // ست کردن state جدید (مرتب‌سازی داخل setter انجام می‌شود)
            notifier.state = nextState;
          });

      ref.onDispose(() {
        sub.cancel();
        link.close(); // آزادسازی keepAlive هنگام dispose
      });
    }

    return notifier;
  },
);

final cachedConversationsStreamProvider =
    StreamProvider<List<ConversationModel>>((ref) async* {
  final conversationCache = ConversationCacheService();

  // Service is already initialized in main.dart
  // No need to initialize again

  // Use the advanced cache system for better performance
  yield* conversationCache
      .watchCachedConversations(supabase.auth.currentUser!.id);
});

// Provider ساده برای دریافت مکالمات با اطلاعات پروفایل کامل
final conversationsWithProfilesProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) {
    return [];
  }

  try {
    // دریافت مکالمات از ChatService
    final chatService = ChatService();
    final conversations = await chatService.getConversations();

    // تکمیل اطلاعات پروفایل برای هر مکالمه
    final userProfileService = UserProfileService();
    final enrichedConversations = <ConversationModel>[];

    for (final conversation in conversations) {
      try {
        final enrichedConversation =
            await userProfileService.enrichConversationWithUserData(
          conversation,
          currentUserId,
        );
        enrichedConversations.add(enrichedConversation);
      } catch (e) {
        print('Error enriching conversation ${conversation.id}: $e');
        enrichedConversations
            .add(conversation); // در صورت خطا، مکالمه اصلی را اضافه کنیم
      }
    }

    return enrichedConversations;
  } catch (e) {
    print('Error in conversationsWithProfilesProvider: $e');
    return [];
  }
});

// Provider استریم برای دریافت مکالمات با اطلاعات پروفایل تکمیل شده
final enrichedConversationsStreamProvider =
    StreamProvider<List<ConversationModel>>((ref) async* {
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) {
    yield [];
    return;
  }

  final conversationCache = ConversationCacheService();

  // Service is already initialized in main.dart
  // No need to initialize again

  // ابتدا اطلاعات اولیه را دریافت کنیم
  final conversationsAsync = ref.read(conversationsWithProfilesProvider);
  final conversations = conversationsAsync.when(
    data: (data) => data,
    loading: () => <ConversationModel>[],
    error: (error, stack) => <ConversationModel>[],
  );
  yield conversations;

  // سپس استریم real-time را شروع کنیم و اطلاعات پروفایل را تکمیل کنیم
  await for (final cachedConversations
      in conversationCache.watchCachedConversations(currentUserId)) {
    try {
      // تکمیل اطلاعات پروفایل برای مکالمات جدید
      final userProfileService = UserProfileService();
      final enrichedConversations = <ConversationModel>[];

      for (final conversation in cachedConversations) {
        try {
          // اگر اطلاعات پروفایل کامل نیست، آن را تکمیل کنیم
          if (conversation.otherUserName == null ||
              conversation.otherUserName == 'کاربر ناشناس' ||
              conversation.otherUserName!.isEmpty) {
            final enrichedConversation =
                await userProfileService.enrichConversationWithUserData(
              conversation,
              currentUserId,
            );

            enrichedConversations.add(enrichedConversation);
          } else {
            enrichedConversations.add(conversation);
          }
        } catch (e) {
          print('Error enriching conversation ${conversation.id}: $e');
          enrichedConversations.add(conversation);
        }
      }

      yield enrichedConversations;
    } catch (e) {
      print('Error processing cached conversations: $e');
      yield conversations; // در صورت خطا، از اطلاعات اولیه استفاده کن
    }
  }
});

final conversationProvider = StreamProvider.family
    .autoDispose<ConversationModel?, String>((ref, conversationId) async* {
  final cache = ConversationCacheService();

  // Service is already initialized in main.dart
  // No need to initialize again

  // همچنین، یکبار اطلاعات را از سرور برای اطمینان از به‌روز بودن کش، درخواست می‌دهیم.
  // نیازی به await کردن نیست؛ استریم به محض آپدیت شدن کش، UI را به‌روز می‌کند.
  Future.microtask(() {
    ref.read(chatServiceProvider).refreshConversation(conversationId);
  });

  final userId = supabase.auth.currentUser!.id;
  yield* cache.watchConversation(conversationId, userId);
});

final sharedMediaProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  final userId = supabase.auth.currentUser!.id;

  // کوئری مستقیم به سابابیس برای دریافت پیام‌های دارای ضمیمه
  final response = await supabase
      .from('messages')
      .select()
      .eq('conversation_id', conversationId)
      .not('attachment_type', 'is', null) // فقط پیام‌های دارای ضمیمه
      .order('created_at', ascending: false);

  final messages = response
      .map((json) => MessageModel.fromJson(json, currentUserId: userId))
      .toList();

  return messages;
});

// Provider برای دریافت و نمایش حجم کش پیام‌ها
final chatCacheSizeProvider = FutureProvider<String>((ref) async {
  // final messageCacheService = MessageCacheService(); // برای این مورد نیاز مستقیم نیست
  int sizeInBytes = -1; // مقدار اولیه برای تشخیص خطا یا عدم وجود فایل
  String? errorMessage;

  try {
    final file = await getMessageCacheDbFile(); // استفاده از تابع کمکی
    if (file != null && await file.exists()) {
      sizeInBytes = await file.length();
      if (sizeInBytes == 0) {
        return "خالی"; // اگر فایل وجود دارد ولی خالی است
      }
    } else {
      // اگر فایل اصلاً وجود ندارد (مثلاً اولین اجرا و بدون هیچ پیامی در کش)
      return "خالی";
    }
  } catch (e, stackTrace) {
    print("❌ خطا در دریافت حجم پایگاه داده کش: $e\n$stackTrace");
    errorMessage = "خطا در محاسبه";
    return errorMessage; // برگرداندن پیام خطا برای نمایش در UI
  }

  // اگر sizeInBytes هنوز -1 است و خطایی هم نداشتیم، یعنی وضعیت نامشخص
  if (sizeInBytes < 0) return "نامشخص";

  if (sizeInBytes < 1024) {
    return "$sizeInBytes بایت"; // sizeInBytes اینجا حتما >= 0 است
  }
  if (sizeInBytes < 1024 * 1024) {
    return "${(sizeInBytes / 1024).toStringAsFixed(2)} کیلوبایت"; // دقت بیشتر
  }
  return "${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} مگابایت"; // دقت بیشتر
});

final userProfileDetailsProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final response =
        await supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return response;
  } catch (e) {
    print('Error fetching user profile details for $userId: $e');
    return null;
  }
});
