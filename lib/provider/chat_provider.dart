import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../DB/conversation_cache_service.dart';
import '../DB/message_cache_service.dart';
import '../main.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';
import '../view/Exeption/app_exceptions.dart';

// لیست مکالمات
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  print('🔍 درخواست دریافت مکالمات از conversationsProvider');
  final chatService = ref.watch(chatServiceProvider);
  final conversations = await chatService.getConversations();
  print('📥 تعداد مکالمات دریافت شده: ${conversations.length}');
  return conversations;
});

// استریم مکالمات برای بروزرسانی خودکار
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  print('🔄 شروع استریم مکالمات');
  final chatService = ref.watch(chatServiceProvider);
  final conversationCache = ConversationCacheService();

  // استریم تغییرات مکالمات
  final conversationsStream = chatService.subscribeToConversations();

  // استریم پیام‌های جدید (برای آپدیت فوری مکالمه)
  final messagesStream = supabase
      .from('messages')
      .stream(primaryKey: ['id']).order('created_at', ascending: false);

  messagesStream.listen((event) async {
    final updatedConversations = <String>{};
    for (final msg in event) {
      final conversationId = msg['conversation_id'] as String?;
      if (conversationId != null &&
          !updatedConversations.contains(conversationId)) {
        updatedConversations.add(conversationId);
        // مکالمه را از سرور بگیر و کش را آپدیت کن
        await chatService.refreshConversation(conversationId);
      }
    }
    // conversationsStreamProvider را invalidate کن تا UI فوراً رفرش شود
    ref.invalidateSelf();
    ref.invalidate(conversationsProvider);
    ref.invalidate(cachedConversationsStreamProvider);
  });

  // هر بار که کش مکالمات تغییر کرد، لیست را مجدداً از کش بخوان
  return conversationCache.watchCachedConversations();
});

// پرووایدر برای سرویس چت
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// پیام‌های یک مکالمه
final messagesProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  final chatService = ref.watch(chatServiceProvider);
  final messageCache = MessageCacheService();

  // ابتدا پیام‌های کش را بازگردان
  final cachedMessages =
      await messageCache.getConversationMessages(conversationId);

  // اگر کش داریم، فوراً آن را نشان بده
  if (cachedMessages.isNotEmpty) {
    // بروزرسانی از سرور را در پس‌زمینه انجام بده
    ref.listenSelf((previous, next) {
      chatService.getMessages(conversationId).then((serverMessages) {
        if (serverMessages.isNotEmpty) {
          // اگر پیام‌های جدید از سرور آمد، کش را بروزرسانی کن
          messageCache.cacheMessages(serverMessages);
        }
      });
    });

    return cachedMessages;
  }

  // اگر کش نداریم، از سرور دریافت کن
  return chatService.getMessages(conversationId);
});

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
          cache.cacheMessages(messages);
          return messages;
        });
  } else {
    // فقط کش (آفلاین)
    final cached = await cache.getConversationMessages(conversationId);
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
  final MessageCacheService _messageCache =
      MessageCacheService(); // اضافه کردن این خط

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
      await chatService.deleteMessage(messageId, forEveryone: forEveryone);

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

      // بروزرسانی پیام‌ها
      ref.invalidate(messagesStreamProvider(conversationId));
      ref.invalidate(conversationsProvider);

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

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
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

    // فقط اگر آنلاین بود، تیک بلافاصله بخورد
    final chatService = ref.read(chatServiceProvider);
    final isOnline = await chatService.isDeviceOnline();
    if (isOnline) {
      notifier.replaceTempWithReal(
        tempMessage.id,
        tempMessage.copyWith(isSent: true),
      );
    }

    // --- حذف شد: invalidate کردن کل provider پیام‌ها ---
    // ref.invalidate(conversationMessagesProvider(conversationId));

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

    final notifier = ref.read(
        conversationMessagesProvider(failedMessage.conversationId).notifier);

    final messageToRetry = failedMessage.copyWith(
      isPending: true,
      isSent: false,
      retryCount: 0, // Reset retry count for a new set of retries
    );

    notifier.updateMessage(messageToRetry); // Update UI to show pending

    unawaited(_trySendWithRetry(
      tempMessage: messageToRetry, // Pass the message with its original tempId
      conversationId: messageToRetry.conversationId, // اضافه شد
      content: messageToRetry.content, // اضافه شد
      // سایر پارامترها از messageToRetry خوانده می‌شوند
      retryCount: 0, // Start retries from 0 for this attempt sequence
    ));
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
    // پارامترهای content و ... را از tempMessage بگیرید
    print(
        '🚀 تلاش برای ارسال پیام (تلاش ${retryCount + 1}): ${tempMessage.id}');
    try {
      final chatService = ref.read(chatServiceProvider);
      final serverMessage = await chatService.sendMessage(
        conversationId: tempMessage.conversationId, // استفاده از tempMessage
        content: tempMessage.content, // استفاده از tempMessage
        attachmentUrl:
            tempMessage.attachmentUrl, //  <-- اصلاح شد: استفاده از tempMessage
        attachmentType:
            tempMessage.attachmentType, //  <-- اصلاح شد: استفاده از tempMessage
        replyToMessageId: tempMessage
            .replyToMessageId, //  <-- اصلاح شد: استفاده از tempMessage
        replyToContent:
            tempMessage.replyToContent, //  <-- اصلاح شد: استفاده از tempMessage
        replyToSenderName: tempMessage
            .replyToSenderName, //  <-- اصلاح شد: استفاده از tempMessage
        localId: tempMessage.id, // اطمینان از ارسال localId صحیح
      );
      print(
          '✅ پیام ${tempMessage.id} با موفقیت به سرور ارسال و با ${serverMessage.id} جایگزین شد.');
      ref
          .read(conversationMessagesProvider(conversationId).notifier)
          .replaceTempWithReal(tempMessage.id, serverMessage);
    } catch (e) {
      print(
          '❌ خطا در ارسال پیام ${tempMessage.id} (تلاش ${retryCount + 1}): $e');
      if (retryCount < maxRetry - 1) {
        // افزایش شمارنده و تلاش مجدد بعد از کمی تاخیر
        final updatedTemp = tempMessage.copyWith(
            retryCount: retryCount + 1, isPending: true, isSent: false);
        ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .updateMessage(updatedTemp); // Use updateMessage to keep it as temp
        await Future.delayed(const Duration(seconds: 2));
        unawaited(_trySendWithRetry(
          tempMessage: updatedTemp,
          conversationId: updatedTemp.conversationId,
          content: updatedTemp.content,
          attachmentUrl:
              updatedTemp.attachmentUrl, //  <-- اصلاح شد: ارسال از updatedTemp
          attachmentType:
              updatedTemp.attachmentType, //  <-- اصلاح شد: ارسال از updatedTemp
          replyToMessageId: updatedTemp
              .replyToMessageId, //  <-- اصلاح شد: ارسال از updatedTemp
          replyToContent:
              updatedTemp.replyToContent, //  <-- اصلاح شد: ارسال از updatedTemp
          replyToSenderName: updatedTemp
              .replyToSenderName, //  <-- اصلاح شد: ارسال از updatedTemp
          retryCount: retryCount + 1,
        ));
      } else {
        // اگر به سقف رسید failed کن
        ref
            .read(conversationMessagesProvider(conversationId).notifier)
            .markTempFailed(tempMessage.id);
        print("❌ ارسال پیام ${tempMessage.id} ناموفق پس از $maxRetry بار تلاش");
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

      // بروزرسانی لیست مکالمات و پیام‌ها
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(messagesStreamProvider(conversationId));
      ref.invalidate(conversationsProvider);
      ref.invalidate(conversationsStreamProvider);

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

  // Future<void> clearConversation(String conversationId) async {
  //   try {
  //     await _notifier.clearConversation(conversationId);
  //   } catch (e) {
  //     print('خطا در پاکسازی مکالمه: $e');
  //     rethrow;
  //   }
  // }

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
  final chatService = ref.watch(chatServiceProvider);
  // به جای Stream.periodic، به تغییرات جدول profiles گوش می‌دهیم
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((list) {
        if (list.isEmpty) return false;
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

// --- اضافه کنید: StreamProvider برای وضعیت آنلاین بودن دستگاه ---
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

// --- اضافه کنید: Provider برای ارسال پیام‌های آفلاین به محض آنلاین شدن ---
final pendingMessagesSyncProvider = Provider<void>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  ref.listen<AsyncValue<bool>>(deviceOnlineStatusProvider, (prev, next) {
    if (next.value == true) {
      chatService.sendPendingMessages();
    }
  });
});

// --- اضافه کنید: Provider برای مدیریت وضعیت مکالمات (با قابلیت Refresh) ---
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

  ConversationMessagesNotifier(this.conversationId) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final cached = await _cacheService.getConversationMessages(conversationId);
    state = [...cached];
    _updateUnreadCount();
  }

  // شمارش دقیق پیام‌های خوانده‌نشده و بروزرسانی کش مکالمه
  Future<void> _updateUnreadCount() async {
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
        await _conversationCache.getConversation(conversationId);
    if (conversation != null) {
      final updated = conversation.copyWith(
        unreadCount: unreadCount,
        hasUnreadMessages: unreadCount > 0,
      );
      await _conversationCache.updateConversation(updated);
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
      print("خطای منطقی: پیام موقت باید با temp_ شروع شود: ${message.id}");
    }
    _cacheService.cacheMessage(message); // پیام موقت را با همان ID موقت کش کن
  }

  void replaceTempWithReal(String tempId, MessageModel realMessage) {
    final newState = [
      ...state.where((m) => m.id != tempId && m.localId != tempId),
      realMessage
    ];
    state = _filterTempDuplicates(newState);
    // ابتدا پیام موقت را از کش حذف کن
    _cacheService.clearMessage(conversationId, tempId).then((_) {
      // سپس پیام واقعی را کش کن
      _cacheService.cacheMessage(realMessage);
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
    final newState = state.map((m) {
      if (m.id == updatedMessage.id) {
        return updatedMessage;
      }
      return m;
    }).toList();
    state =
        newState; // این setter مرتب‌سازی و فیلتر _filterTempDuplicates را اعمال می‌کند
    _cacheService
        .cacheMessage(updatedMessage); // پیام آپدیت شده را در کش هم ذخیره کن
  }

  // --- اضافه شد: متدهای optimistic update ---

  // اضافه کردن پیام جدید به state (بدون invalidate کردن کل provider)
  void addMessage(MessageModel message) {
    final newState = [...state, message];
    state = _filterTempDuplicates(newState);
    _cacheService.cacheMessage(message);
  }

  // حذف پیام از state (بدون invalidate کردن کل provider)
  void removeMessage(String messageId) {
    final newState = state.where((m) => m.id != messageId).toList();
    state = _filterTempDuplicates(newState);
    _cacheService.clearMessage(conversationId, messageId);
  }

  // جایگزینی پیام موقت با پیام واقعی (بدون invalidate کردن کل provider)
  void replaceTempMessage(String tempId, MessageModel realMessage) {
    final newState = state.map((m) {
      if (m.id == tempId) {
        return realMessage;
      }
      return m;
    }).toList();
    state = _filterTempDuplicates(newState);

    // آپدیت کش
    _cacheService.clearMessage(conversationId, tempId).then((_) {
      _cacheService.cacheMessage(realMessage);
    }).catchError((e) {
      print("خطا در جایگزینی پیام در کش: $e");
    });
  }

  void markMessageAsFailed(String messageId) {
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
    final unreadCount = await _cacheService.countUnreadMessages(conversationId);
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
}

// --- Provider جدید برای پیام‌های هر مکالمه ---
final conversationMessagesProvider = StateNotifierProvider.family
    .autoDispose<ConversationMessagesNotifier, List<MessageModel>, String>(
  (ref, conversationId) {
    final link = ref
        .keepAlive(); // جلوگیری از dispose شدن زودهنگام تا زمانی که صفحه چت باز است
    final notifier = ConversationMessagesNotifier(conversationId);

    // --- اضافه شد: گوش دادن به استریم Supabase برای بروزرسانی سریع ---
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final sub = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .listen((jsonDataList) async {
            var currentMessagesState = List<MessageModel>.from(notifier.state);
            final List<MessageModel> newMessagesFromOthersToCache = [];
            final List<MessageModel> updatedOrNewOwnMessagesToCache = [];
            bool stateWasModified = false;

            for (final jsonMsg in jsonDataList) {
              final serverMessage =
                  MessageModel.fromJson(jsonMsg, currentUserId: userId);

              // حذف پیام temp اگر پیام واقعی با localId مشابه آمد
              if (serverMessage.localId != null &&
                  serverMessage.localId!.isNotEmpty) {
                final int tempIndex = currentMessagesState
                    .indexWhere((m) => m.id == serverMessage.localId);
                if (tempIndex != -1) {
                  currentMessagesState.removeAt(tempIndex);
                  stateWasModified = true;
                }
              }

              final existingIndex = currentMessagesState
                  .indexWhere((m) => m.id == serverMessage.id);
              if (existingIndex == -1) {
                currentMessagesState.add(serverMessage);
                stateWasModified = true;
                if (serverMessage.senderId == userId) {
                  updatedOrNewOwnMessagesToCache.add(serverMessage);
                } else {
                  newMessagesFromOthersToCache.add(serverMessage);
                }
              } else {
                // فقط اگر پیام تغییر کرده باشد، آپدیت کن
                if (currentMessagesState[existingIndex] != serverMessage) {
                  currentMessagesState[existingIndex] = serverMessage;
                  stateWasModified = true;
                  if (serverMessage.senderId == userId) {
                    updatedOrNewOwnMessagesToCache.add(serverMessage);
                  } else {
                    newMessagesFromOthersToCache.add(serverMessage);
                  }
                }
              }

              // --- آپدیت فوری کش مکالمه فقط اگر پیام جدیدتر است ---
              final conversationIdForUpdate = serverMessage.conversationId;
              final conversationCache = ConversationCacheService();
              final conversation = await conversationCache
                  .getConversation(conversationIdForUpdate);
              if (conversation != null) {
                // فقط اگر پیام جدیدتر است، مکالمه را آپدیت کن
                if (serverMessage.createdAt.isAfter(conversation.updatedAt)) {
                  final updatedConversation = conversation.copyWith(
                    lastMessage: serverMessage.content,
                    lastMessageTime: serverMessage.createdAt,
                    updatedAt: serverMessage.createdAt,
                  );
                  await conversationCache
                      .updateConversation(updatedConversation);
                  // invalidate providers
                  ref.invalidate(conversationsStreamProvider);
                  ref.invalidate(cachedConversationsStreamProvider);
                }
              }
            }

            if (stateWasModified) {
              notifier.state = currentMessagesState;
            }

            if (newMessagesFromOthersToCache.isNotEmpty) {
              await notifier._cacheService
                  .cacheMessages(newMessagesFromOthersToCache);
            }
            if (updatedOrNewOwnMessagesToCache.isNotEmpty) {
              await notifier._cacheService
                  .cacheMessages(updatedOrNewOwnMessagesToCache);
            }
          });

      ref.onDispose(() {
        sub.cancel();
        link.close(); // آزادسازی keepAlive هنگام dispose
      });
    }

    return notifier;
  },
);

// --- Provider جدید برای گوش دادن به تغییرات کش مکالمات (Drift) ---
final cachedConversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  final conversationCache = ConversationCacheService();
  // Make sure ConversationCacheService is a singleton or provided correctly
  return conversationCache.watchCachedConversations();
});

// --- اضافه کنید: Provider برای دریافت آنی اطلاعات یک گفتگوی خاص ---
final conversationProvider = StreamProvider.family
    .autoDispose<ConversationModel?, String>((ref, conversationId) {
  final cache = ConversationCacheService();

  // همچنین، یکبار اطلاعات را از سرور برای اطمینان از به‌روز بودن کش، درخواست می‌دهیم.
  // نیازی به await کردن نیست؛ استریم به محض آپدیت شدن کش، UI را به‌روز می‌کند.
  Future.microtask(() {
    ref.read(chatServiceProvider).refreshConversation(conversationId);
  });

  return cache.watchConversation(conversationId);
});

// --- اضافه کنید: Provider برای دریافت رسانه‌های اشتراک‌گذاری شده در یک گفتگو ---
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
    if (await file.exists()) {
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
  if (sizeInBytes < 0 && errorMessage == null) return "نامشخص";
  if (errorMessage != null)
    return errorMessage; // این خط اضافی است چون بالا return شده

  if (sizeInBytes < 1024)
    return "$sizeInBytes بایت"; // sizeInBytes اینجا حتما >= 0 است
  if (sizeInBytes < 1024 * 1024)
    return "${(sizeInBytes / 1024).toStringAsFixed(2)} کیلوبایت"; // دقت بیشتر
  return "${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} مگابایت"; // دقت بیشتر
});

// --- اضافه کنید: Provider برای دریافت جزئیات کامل پروفایل کاربر ---
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
