import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/logging_utility.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../services/user_profile_service.dart';
import '../services/telegram_read_receipt_service.dart';
import '../DB/unified_conversation_cache_service.dart';
import '../services/ChatService_LEGACY.dart';
import '../main.dart';

/// 🚀 Provider بهینه‌شده برای لیست مکالمات
/// این provider تمام نیازهای UI را با یک منبع واحد برطرف می‌کند:
/// - کش سریع برای نمایش فوری
/// - Real-time updates
/// - Profile enrichment یکپارچه
/// - Performance بهینه

// ============================================
// 1️⃣ State class برای مدیریت وضعیت مکالمات
// ============================================

enum ConversationsStatus { initial, loading, loaded, error }

class ConversationsState {
  final List<ConversationModel> conversations;
  final ConversationsStatus status;
  final String? errorMessage;
  final bool isRefreshing;

  const ConversationsState({
    this.conversations = const [],
    this.status = ConversationsStatus.initial,
    this.errorMessage,
    this.isRefreshing = false,
  });

  /// مکالمات پین شده (جدا برای نمایش بالای لیست)
  List<ConversationModel> get pinnedConversations =>
      conversations.where((c) => c.isPinned && !c.isArchived).toList();

  /// مکالمات عادی (بدون پین و بدون آرشیو)
  List<ConversationModel> get regularConversations =>
      conversations.where((c) => !c.isPinned && !c.isArchived).toList();

  /// تعداد کل پیام‌های خوانده‌نشده
  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  ConversationsState copyWith({
    List<ConversationModel>? conversations,
    ConversationsStatus? status,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

// ============================================
// 2️⃣ Notifier برای مدیریت state
// ============================================

class OptimizedConversationsNotifier extends StateNotifier<ConversationsState> {
  final String? _userId;
  final UserProfileService _profileService = UserProfileService();
  final UnifiedConversationCacheService _cacheService =
      UnifiedConversationCacheService();

  StreamSubscription<List<ConversationModel>>? _cacheSubscription;
  bool _disposed = false;

  OptimizedConversationsNotifier(this._userId)
      : super(const ConversationsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_disposed) return;
    
    if (_userId == null) {
      state = const ConversationsState(
        status: ConversationsStatus.error,
        errorMessage: 'کاربر لاگین نیست',
      );
      return;
    }

    state = state.copyWith(status: ConversationsStatus.loading);

    try {
      // 1️⃣ ابتدا کش را سریع نمایش بده
      final hasCache = await _loadFromCache();

      // 2️⃣ سپس به real-time updates گوش بده
      _subscribeToUpdates();

      // 3️⃣ اگر کش نداشتیم، مستقیماً از سرور لود کن
      if (!hasCache) {
        await _loadFromServer();
      } else {
        // اگر کش داشتیم، در پس‌زمینه از سرور refresh کن
        _refreshFromServer();
      }
    } catch (e) {
      logInfo('❌ Error initializing conversations: $e');
      if (!_disposed) {
        state = state.copyWith(
          status: ConversationsStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// بارگذاری سریع از کش - برمی‌گردونه آیا کش داشتیم یا نه
  Future<bool> _loadFromCache() async {
    if (_userId == null || _disposed) return false;

    try {
      final cachedConversations =
          await _cacheService.getCachedConversations(_userId);

      if (cachedConversations.isEmpty) {
        logInfo('📱 OptimizedProvider: No cache found');
        return false;
      }

      logInfo(
          '📱 OptimizedProvider: Loaded ${cachedConversations.length} from cache');

      // Enrich با پروفایل‌ها (از memory cache برای سرعت)
      final enriched = await _enrichConversations(cachedConversations);

      if (!_disposed) {
        state = state.copyWith(
          conversations: _sortConversations(enriched),
          status: ConversationsStatus.loaded,
        );
      }
      return true;
    } catch (e) {
      logInfo('⚠️ Error loading from cache: $e');
      return false;
    }
  }

  /// بارگذاری مستقیم از سرور (وقتی کش نداریم)
  Future<void> _loadFromServer() async {
    if (_userId == null || _disposed) return;

    try {
      logInfo('📱 OptimizedProvider: Loading from server...');
      final chatService = ChatService();
      final serverConversations = await chatService.getConversations();

      if (_disposed) return;

      if (serverConversations.isEmpty) {
        // اگر هیچ مکالمه‌ای نیست، state رو به loaded تغییر بده
        if (!_disposed) {
          state = state.copyWith(
            conversations: [],
            status: ConversationsStatus.loaded,
          );
        }
        logInfo('📱 OptimizedProvider: No conversations found');
        return;
      }

      // ذخیره در کش
      for (final conversation in serverConversations) {
        await _cacheService.cacheConversation(conversation, _userId);
      }

      // Enrich و update state
      final enriched = await _enrichConversations(serverConversations);

      if (!_disposed) {
        state = state.copyWith(
          conversations: _sortConversations(enriched),
          status: ConversationsStatus.loaded,
        );
      }

      logInfo(
          '✅ OptimizedProvider: Loaded ${serverConversations.length} from server');
    } catch (e) {
      logInfo('⚠️ Error loading from server: $e');
      if (!_disposed) {
        state = state.copyWith(
          status: ConversationsStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// گوش دادن به تغییرات real-time
  void _subscribeToUpdates() {
    if (_userId == null || _disposed) return;

    _cacheSubscription?.cancel();
    _cacheSubscription =
        _cacheService.watchCachedConversations(_userId).listen(
      (conversations) async {
        if (_disposed) return;

        logInfo(
            '📱 OptimizedProvider: Stream update - ${conversations.length} conversations');

        // Enrich و update state
        final enriched = await _enrichConversations(conversations);

        if (!_disposed) {
          state = state.copyWith(
            conversations: _sortConversations(enriched),
            status: ConversationsStatus.loaded,
            isRefreshing: false,
          );
        }
      },
      onError: (e) {
        logInfo('⚠️ Stream error: $e');
        if (!_disposed) {
          state = state.copyWith(
            status: ConversationsStatus.error,
            errorMessage: e.toString(),
          );
        }
      },
    );
  }

  /// Refresh از سرور در پس‌زمینه (برای به‌روزرسانی کش)
  Future<void> _refreshFromServer() async {
    if (_userId == null || _disposed) return;

    try {
      final chatService = ChatService();
      final serverConversations = await chatService.getConversations();

      if (_disposed) return;

      // ذخیره در کش (stream خودش UI رو update میکنه)
      for (final conversation in serverConversations) {
        await _cacheService.cacheConversation(conversation, _userId);
      }

      if (serverConversations.isNotEmpty) {
        logInfo(
            '✅ OptimizedProvider: Refreshed ${serverConversations.length} from server');
      }
    } catch (e) {
      logInfo('⚠️ Error refreshing from server: $e');
      // خطا رو ignore میکنیم چون stream خودش handle میکنه
    }
  }

  /// Enrich مکالمات با اطلاعات پروفایل
  Future<List<ConversationModel>> _enrichConversations(
      List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return [];

    final enriched = <ConversationModel>[];
    final userIdsToLoad = <String>[];

    // اول از memory cache استفاده کن (خیلی سریع)
    for (final conversation in conversations) {
      if (_needsEnrichment(conversation) && conversation.otherUserId != null) {
        final cached =
            _profileService.getCachedProfile(conversation.otherUserId!);
        if (cached != null) {
          enriched.add(_applyProfile(conversation, cached));
        } else {
          userIdsToLoad.add(conversation.otherUserId!);
          enriched.add(conversation);
        }
      } else {
        enriched.add(conversation);
      }
    }

    // اگر پروفایل‌هایی نیاز به لود دارن، در background انجام بده
    if (userIdsToLoad.isNotEmpty) {
      _loadMissingProfiles(userIdsToLoad, conversations);
    }

    return enriched;
  }

  /// بارگذاری پروفایل‌های missing در background
  Future<void> _loadMissingProfiles(
      List<String> userIds, List<ConversationModel> conversations) async {
    if (_disposed) return;

    try {
      // حداکثر 10 پروفایل همزمان
      final limitedIds = userIds.take(10).toList();
      await _profileService.preloadProfiles(limitedIds);

      if (_disposed) return;

      // Re-enrich conversations با پروفایل‌های جدید
      final reEnriched = conversations.map((conversation) {
        if (_needsEnrichment(conversation) && conversation.otherUserId != null) {
          final cached =
              _profileService.getCachedProfile(conversation.otherUserId!);
          if (cached != null) {
            return _applyProfile(conversation, cached);
          }
        }
        return conversation;
      }).toList();

      if (!_disposed) {
        state = state.copyWith(
          conversations: _sortConversations(reEnriched),
        );
      }
    } catch (e) {
      logInfo('⚠️ Error loading missing profiles: $e');
    }
  }

  /// چک کن آیا مکالمه نیاز به enrichment داره
  bool _needsEnrichment(ConversationModel conversation) {
    final name = conversation.otherUserName ?? '';
    return name.isEmpty ||
        name == 'کاربر' ||
        name == 'کاربر ناشناس' ||
        name == 'Unknown User';
  }

  /// اعمال پروفایل به مکالمه
  ConversationModel _applyProfile(
      ConversationModel conversation, Map<String, String?> profile) {
    return conversation.copyWith(
      otherUserName:
          profile['username'] ?? profile['full_name'] ?? 'VISTA USER',
      otherUserAvatar: profile['avatar_url'],
    );
  }

  /// مرتب‌سازی مکالمات: pinned اول، بعد بر اساس آخرین پیام
  List<ConversationModel> _sortConversations(
      List<ConversationModel> conversations) {
    final sorted = List<ConversationModel>.from(conversations);
    sorted.sort((a, b) {
      // پین شده‌ها اول
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // بعد بر اساس زمان آخرین پیام
      final aTime = a.lastMessageTime ?? a.updatedAt;
      final bTime = b.lastMessageTime ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  // ============================================
  // Public Methods
  // ============================================

  /// Refresh دستی
  Future<void> refresh() async {
    if (_disposed) return;

    state = state.copyWith(isRefreshing: true);
    
    try {
      // بارگذاری مستقیم از سرور
      await _loadFromServer();
    } catch (e) {
      logInfo('⚠️ Error in refresh: $e');
      if (!_disposed) {
        state = state.copyWith(
          isRefreshing: false,
          status: ConversationsStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// جستجو در مکالمات
  List<ConversationModel> search(String query) {
    if (query.isEmpty) return state.conversations;

    final lowerQuery = query.toLowerCase();
    return state.conversations.where((c) {
      final name = c.otherUserName?.toLowerCase() ?? '';
      final message = c.lastMessage?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || message.contains(lowerQuery);
    }).toList();
  }

  /// ✅ به‌روزرسانی فوری مکالمه با MessageModel (آفلاین - مثل تلگرام)
  /// این متد باید وقتی پیام جدید ارسال یا دریافت میشه صدا زده بشه
  Future<void> updateConversationWithMessage(
    MessageModel message, {
    required String currentUserId,
  }) async {
    if (_userId == null || _disposed) return;

    try {
      // تعیین نوع پیام
      String? messageType;
      if (message.isForwarded) {
        messageType = 'forward';
      } else if (message.sharedPostData != null) {
        messageType = 'post';
      } else if (message.attachmentType != null && message.attachmentType!.isNotEmpty) {
        final attachType = message.attachmentType!.toLowerCase();
        if (attachType.contains('audio') || attachType.contains('voice')) {
          messageType = 'voice';
        } else if (attachType.contains('image') || attachType.contains('photo')) {
          messageType = 'image';
        } else if (attachType.contains('video')) {
          messageType = 'video';
        } else {
          messageType = 'file';
        }
      } else if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
        final url = message.attachmentUrl!.toLowerCase();
        if (url.contains('.mp3') || url.contains('.wav') || url.contains('.ogg') || url.contains('.m4a')) {
          messageType = 'voice';
        } else if (url.contains('.jpg') || url.contains('.jpeg') || url.contains('.png') || url.contains('.gif')) {
          messageType = 'image';
        } else if (url.contains('.mp4') || url.contains('.mov') || url.contains('.avi')) {
          messageType = 'video';
        } else {
          messageType = 'file';
        }
      } else {
        messageType = message.messageType ?? 'text';
      }

      // ✅ تعیین وضعیت تحویل از فیلدهای پیام
      MessageDeliveryStatus deliveryStatus;
      if (message.isSeen) {
        deliveryStatus = MessageDeliveryStatus.read;
      } else if (message.isDelivered) {
        deliveryStatus = MessageDeliveryStatus.delivered;
      } else if (message.isSent) {
        deliveryStatus = MessageDeliveryStatus.sent;
      } else {
        deliveryStatus = MessageDeliveryStatus.pending;
      }

      await updateConversationWithLastMessage(
        conversationId: message.conversationId,
        lastMessage: message.content,
        lastMessageTime: message.createdAt,
        lastMessageType: messageType,
        senderId: message.senderId,
        isFromMe: message.isMe,
        deliveryStatus: deliveryStatus,
      );
    } catch (e) {
      logInfo('⚠️ Error updating conversation with message: $e');
    }
  }

  /// ✅ به‌روزرسانی فوری مکالمه با آخرین پیام (آفلاین - مثل تلگرام)
  /// این متد باید وقتی پیام جدید ارسال یا دریافت میشه صدا زده بشه
  Future<void> updateConversationWithLastMessage({
    required String conversationId,
    required String lastMessage,
    required DateTime lastMessageTime,
    String? lastMessageType,
    required String senderId,
    bool isFromMe = false,
    MessageDeliveryStatus? deliveryStatus,
  }) async {
    if (_userId == null || _disposed) return;

    try {
      // 1️⃣ دریافت مکالمه از کش
      final conversation = await _cacheService.getConversation(conversationId, _userId);
      
      if (conversation == null) {
        logInfo('⚠️ Conversation not found in cache: $conversationId');
        return;
      }

      // 2️⃣ تعیین نوع پیام اگر داده نشده
      String? messageType = lastMessageType;
      if (messageType == null) {
        // تشخیص نوع از محتوا
        if (lastMessage.trim().startsWith('{') && lastMessage.contains('post_id')) {
          messageType = 'post';
        } else {
          messageType = 'text';
        }
      }

      // 3️⃣ به‌روزرسانی مکالمه
      final updatedConversation = conversation.copyWith(
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        updatedAt: lastMessageTime,
        lastMessageType: messageType,
        isLastMessageFromMe: isFromMe,
        lastMessageSenderId: senderId,
        // اگر پیام از من نیست، unreadCount رو افزایش بده
        unreadCount: isFromMe 
            ? conversation.unreadCount 
            : conversation.unreadCount + 1,
        hasUnreadMessages: isFromMe 
            ? conversation.hasUnreadMessages 
            : true,
        // ✅ وضعیت تحویل پیام - هماهنگ با صفحه چت
        lastMessageDeliveryStatus: isFromMe 
            ? (deliveryStatus ?? MessageDeliveryStatus.pending)
            : conversation.lastMessageDeliveryStatus,
      );

      // 4️⃣ ذخیره در کش (آفلاین - فوری)
      await _cacheService.updateConversation(updatedConversation, _userId);

      // 5️⃣ به‌روزرسانی state برای UI (بدون نیاز به سرور)
      final currentConversations = List<ConversationModel>.from(state.conversations);
      final index = currentConversations.indexWhere((c) => c.id == conversationId);
      
      if (index != -1) {
        currentConversations[index] = updatedConversation;
      } else {
        // اگر مکالمه در state نیست، اضافه کن
        currentConversations.add(updatedConversation);
      }

      // 6️⃣ مرتب‌سازی و به‌روزرسانی state
      if (!_disposed) {
        state = state.copyWith(
          conversations: _sortConversations(currentConversations),
        );
      }

      logInfo('✅ Conversation updated offline: $conversationId');
    } catch (e) {
      logInfo('⚠️ Error updating conversation offline: $e');
    }
  }

  /// ✅ به‌روزرسانی وضعیت تحویل آخرین پیام (برای Real-time sync با صفحه چت)
  Future<void> updateLastMessageDeliveryStatus({
    required String conversationId,
    required MessageDeliveryStatus status,
  }) async {
    if (_userId == null || _disposed) return;

    try {
      final currentConversations = List<ConversationModel>.from(state.conversations);
      final index = currentConversations.indexWhere((c) => c.id == conversationId);
      
      if (index == -1) return;
      
      final conversation = currentConversations[index];
      
      // فقط اگر پیام از من باشه، وضعیت رو آپدیت کن
      if (!conversation.isLastMessageFromMe) return;

      final updatedConversation = conversation.copyWith(
        lastMessageDeliveryStatus: status,
      );

      currentConversations[index] = updatedConversation;

      // ذخیره در کش
      await _cacheService.updateConversation(updatedConversation, _userId);

      // به‌روزرسانی state
      if (!_disposed) {
        state = state.copyWith(
          conversations: currentConversations,
        );
      }

      logInfo('✅ Updated delivery status for $conversationId: $status');
    } catch (e) {
      logInfo('⚠️ Error updating delivery status: $e');
    }
  }

  /// ✅ علامت‌گذاری پیام‌های یک مکالمه به عنوان خوانده شده (آفلاین)
  Future<void> markConversationAsRead(String conversationId) async {
    if (_userId == null || _disposed) return;

    try {
      final conversation = await _cacheService.getConversation(conversationId, _userId);
      
      if (conversation == null || conversation.unreadCount == 0) return;

      final updatedConversation = conversation.copyWith(
        unreadCount: 0,
        hasUnreadMessages: false,
      );

      await _cacheService.updateConversation(updatedConversation, _userId);

      // به‌روزرسانی state
      final currentConversations = List<ConversationModel>.from(state.conversations);
      final index = currentConversations.indexWhere((c) => c.id == conversationId);
      
      if (index != -1) {
        currentConversations[index] = updatedConversation;
        if (!_disposed) {
          state = state.copyWith(
            conversations: _sortConversations(currentConversations),
          );
        }
      }

      logInfo('✅ Conversation marked as read offline: $conversationId');
    } catch (e) {
      logInfo('⚠️ Error marking conversation as read: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cacheSubscription?.cancel();
    super.dispose();
  }
}

// ============================================
// 3️⃣ Provider اصلی
// ============================================

final optimizedConversationsProvider =
    StateNotifierProvider<OptimizedConversationsNotifier, ConversationsState>(
        (ref) {
  final userId = supabase.auth.currentUser?.id;
  return OptimizedConversationsNotifier(userId);
});

// ============================================
// 4️⃣ Provider های کمکی
// ============================================

/// فقط مکالمات پین شده
final pinnedConversationsProvider = Provider<List<ConversationModel>>((ref) {
  return ref.watch(optimizedConversationsProvider).pinnedConversations;
});

/// فقط مکالمات عادی
final regularConversationsProvider = Provider<List<ConversationModel>>((ref) {
  return ref.watch(optimizedConversationsProvider).regularConversations;
});

/// تعداد پیام‌های خوانده‌نشده
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(optimizedConversationsProvider).totalUnreadCount;
});

/// وضعیت loading
final conversationsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(optimizedConversationsProvider);
  return state.status == ConversationsStatus.loading ||
      state.status == ConversationsStatus.initial;
});

/// جستجو در مکالمات
final searchedConversationsProvider =
    Provider.family<List<ConversationModel>, String>((ref, query) {
  return ref.read(optimizedConversationsProvider.notifier).search(query);
});

