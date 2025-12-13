// lib/provider/read_receipt_provider.dart
//
// پرووایدرهای وضعیت خوانده شدن پیام - Real-time
//

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/telegram_read_receipt_service.dart';

/// پرووایدر سرویس Read Receipt
final telegramReadReceiptServiceProvider = Provider<TelegramReadReceiptService>((ref) {
  final service = TelegramReadReceiptService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// پرووایدر برای شروع گوش دادن به یک مکالمه
final startReadReceiptListenerProvider = Provider.family<void, String>((ref, conversationId) {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  service.startListening(conversationId);
  
  ref.onDispose(() {
    service.stopListening(conversationId);
  });
});

/// استریم آپدیت‌های وضعیت پیام‌ها
final messageStatusUpdatesProvider = StreamProvider<Map<String, MessageStatusInfo>>((ref) {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  return service.statusUpdates;
});

/// پرووایدر وضعیت یک پیام خاص
final messageStatusProvider = FutureProvider.family<MessageStatusInfo?, String>((ref, messageId) async {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  return service.getMessageStatus(messageId);
});

/// پرووایدر وضعیت کش شده (سریع، بدون async)
final cachedMessageStatusProvider = Provider.family<MessageStatusInfo?, String>((ref, messageId) {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  return service.getCachedStatus(messageId);
});

/// تعداد پیام‌های خوانده نشده در یک مکالمه
final conversationUnreadCountProvider = StreamProvider.family<int, String>((ref, conversationId) {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  return service.watchUnreadCount(conversationId);
});

/// اکشن‌های مربوط به Read Receipt
class ReadReceiptActionsNotifier extends StateNotifier<void> {
  final TelegramReadReceiptService _service;

  ReadReceiptActionsNotifier(this._service) : super(null);

  /// علامت‌گذاری یک پیام
  void markAsRead(String messageId) {
    _service.markAsRead(messageId);
  }

  /// علامت‌گذاری همه پیام‌های یک مکالمه
  Future<void> markAllAsRead(String conversationId) {
    return _service.markAllAsRead(conversationId);
  }

  /// علامت‌گذاری پیام‌های قابل مشاهده
  void markVisibleAsRead(List<String> messageIds) {
    _service.markVisibleMessagesAsRead(messageIds);
  }

  /// علامت‌گذاری به عنوان تحویل داده شده
  Future<void> markAsDelivered(String messageId) {
    return _service.markAsDelivered(messageId);
  }
}

final readReceiptActionsProvider = StateNotifierProvider<ReadReceiptActionsNotifier, void>((ref) {
  final service = ref.watch(telegramReadReceiptServiceProvider);
  return ReadReceiptActionsNotifier(service);
});

/// Helper برای تبدیل وضعیت قدیمی به جدید
MessageDeliveryStatus convertToDeliveryStatus({
  bool isPending = false,
  bool isSent = false,
  bool isDelivered = false,
  bool isSeen = false,
  bool isFailed = false,
}) {
  if (isFailed) return MessageDeliveryStatus.failed;
  if (isSeen) return MessageDeliveryStatus.read;
  if (isDelivered) return MessageDeliveryStatus.delivered;
  if (isSent) return MessageDeliveryStatus.sent;
  if (isPending) return MessageDeliveryStatus.pending;
  return MessageDeliveryStatus.pending;
}






