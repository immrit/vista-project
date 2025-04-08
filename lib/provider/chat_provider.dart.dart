import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';

// سرویس چت
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// لیست مکالمات
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getConversations();
});

// استریم مکالمات برای بروزرسانی خودکار
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.subscribeToConversations();
});

// پیام‌های یک مکالمه
final messagesProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessages(conversationId);
});

// استریم پیام‌های یک مکالمه
final messagesStreamProvider = StreamProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.subscribeToMessages(conversationId);
});

// پرووایدر برای بررسی پیام‌های جدید
final hasNewMessagesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final conversationsAsync = ref.watch(conversationsProvider);
  return conversationsAsync.when(
    data: (conversations) {
      return conversations
          .any((conversation) => conversation.hasUnreadMessages);
    },
    loading: () => false,
    error: (_, __) => false,
  );
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
      await chatService.deleteMessage(messageId, forEveryone: forEveryone);

      // بروزرسانی لیست پیام‌ها و مکالمات
      ref.invalidateSelf();
      ref.invalidate(conversationsProvider);

      if (_disposed) return;
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('خطا در حذف پیام: $e');
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  // پاکسازی کامل مکالمه
// اضافه کردن متد clearConversation به MessageNotifier
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

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    if (_disposed) return;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);

      // اضافه کردن لاگ برای تشخیص مشکل
      print('MessageNotifier: ارسال پیام به $conversationId');

      await chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      if (_disposed) return;

      // بروزرسانی پیام‌ها
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);

      if (_disposed) return;
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('MessageNotifier: خطا در ارسال پیام: $e');
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> markAsRead(String conversationId) async {
    if (_disposed) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markConversationAsRead(conversationId);

      if (_disposed) return;

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);
    } catch (e) {
      print('خطا در علامت‌گذاری به عنوان خوانده شده: $e');
    }
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
  }) async {
    try {
      await _notifier.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
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
    try {
      await _notifier.markAsRead(conversationId);
    } catch (e) {
      print('خطا در علامت‌گذاری به عنوان خوانده‌شده: $e');
      rethrow;
    }
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
    StreamProvider.family<bool, String>((ref, userId) {
  // استفاده از Supabase Realtime برای دریافت تغییرات آنلاین
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return false;

        final lastOnline = DateTime.parse(data[0]['last_online'] ?? '');
        final now = DateTime.now().toUtc();
        return now.difference(lastOnline).inMinutes < 2;
      });
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
