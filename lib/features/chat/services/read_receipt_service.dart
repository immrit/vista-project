// lib/features/chat/services/read_receipt_service.dart
//
// سرویس مدیریت وضعیت خوانده شدن پیام‌ها
//
// ویژگی‌ها:
// ✅ علامت‌گذاری پیام‌ها به عنوان خوانده شده
// ✅ دریافت realtime وضعیت تحویل/خوانده شدن
// ✅ ارسال notification خوانده شدن به فرستنده
// ✅ مدیریت batch read receipts
//

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// وضعیت تحویل پیام
enum DeliveryStatus {
  pending,    // در انتظار ارسال
  sent,       // ارسال شده به سرور ✓
  delivered,  // تحویل داده شده به دستگاه ✓✓
  read,       // خوانده شده ✓✓ (آبی)
  failed,     // خطا در ارسال
}

/// سرویس مدیریت Read Receipts
class ReadReceiptService {
  final SupabaseClient _supabase;
  final _readReceiptsController = StreamController<Map<String, DeliveryStatus>>.broadcast();
  RealtimeChannel? _channel;

  ReadReceiptService(this._supabase);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Stream<Map<String, DeliveryStatus>> get readReceiptsStream => 
      _readReceiptsController.stream;

  /// شروع listening به تغییرات وضعیت
  void startListening(String conversationId) {
    _channel?.unsubscribe();

    _channel = _supabase
        .channel('read_receipts:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final messageId = newRecord['id'] as String;
            final isDelivered = newRecord['is_delivered'] as bool? ?? false;
            final isSeen = newRecord['is_seen'] as bool? ?? false;

            DeliveryStatus status;
            if (isSeen) {
              status = DeliveryStatus.read;
            } else if (isDelivered) {
              status = DeliveryStatus.delivered;
            } else {
              status = DeliveryStatus.sent;
            }

            _readReceiptsController.add({messageId: status});
          },
        )
        .subscribe();
  }

  /// علامت‌گذاری پیام به عنوان تحویل داده شده
  Future<void> markAsDelivered(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_delivered': true})
          .eq('id', messageId)
          .neq('sender_id', _currentUserId ?? '');
    } catch (e) {
      print('❌ Error marking as delivered: $e');
    }
  }

  /// علامت‌گذاری پیام به عنوان خوانده شده
  Future<void> markAsRead(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'is_seen': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .neq('sender_id', _currentUserId ?? '');
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  /// علامت‌گذاری همه پیام‌های یک مکالمه به عنوان خوانده شده
  Future<void> markAllAsRead(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'is_seen': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_seen', false);

      print('✅ All messages marked as read in $conversationId');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  /// علامت‌گذاری پیام‌های دیده شده در صفحه
  Future<void> markVisibleMessagesAsRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'is_seen': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .inFilter('id', messageIds)
          .neq('sender_id', userId)
          .eq('is_seen', false);
    } catch (e) {
      print('❌ Error marking visible messages as read: $e');
    }
  }

  /// دریافت وضعیت تحویل پیام‌ها
  Future<Map<String, DeliveryStatus>> getDeliveryStatuses(
    List<String> messageIds,
  ) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id, is_sent, is_delivered, is_seen')
          .inFilter('id', messageIds);

      final Map<String, DeliveryStatus> statuses = {};

      for (final record in response as List) {
        final id = record['id'] as String;
        final isSent = record['is_sent'] as bool? ?? false;
        final isDelivered = record['is_delivered'] as bool? ?? false;
        final isSeen = record['is_seen'] as bool? ?? false;

        if (isSeen) {
          statuses[id] = DeliveryStatus.read;
        } else if (isDelivered) {
          statuses[id] = DeliveryStatus.delivered;
        } else if (isSent) {
          statuses[id] = DeliveryStatus.sent;
        } else {
          statuses[id] = DeliveryStatus.pending;
        }
      }

      return statuses;
    } catch (e) {
      print('❌ Error getting delivery statuses: $e');
      return {};
    }
  }

  void stopListening() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    stopListening();
    _readReceiptsController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final readReceiptServiceProvider = Provider<ReadReceiptService>((ref) {
  final service = ReadReceiptService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider برای listening به یک مکالمه خاص
final conversationReadReceiptsProvider =
    StreamProvider.family<Map<String, DeliveryStatus>, String>(
        (ref, conversationId) {
  final service = ref.watch(readReceiptServiceProvider);
  service.startListening(conversationId);
  return service.readReceiptsStream;
});

/// Provider برای علامت‌گذاری پیام‌ها
final readReceiptActionsProvider = Provider<ReadReceiptActions>((ref) {
  final service = ref.watch(readReceiptServiceProvider);
  return ReadReceiptActions(service);
});

class ReadReceiptActions {
  final ReadReceiptService _service;

  ReadReceiptActions(this._service);

  Future<void> markAsRead(String messageId) => _service.markAsRead(messageId);

  Future<void> markAllAsRead(String conversationId) =>
      _service.markAllAsRead(conversationId);

  Future<void> markVisibleAsRead(List<String> messageIds) =>
      _service.markVisibleMessagesAsRead(messageIds);
}

