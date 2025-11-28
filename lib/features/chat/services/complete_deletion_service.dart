// lib/features/chat/services/complete_deletion_service.dart
//
// سرویس حذف کامل با قابلیت Undo
//
// ویژگی‌ها:
// ✅ حذف با قابلیت بازگشت
// ✅ ذخیره backup برای undo
// ✅ مدیریت timeout برای undo
//

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../security/logging_utility.dart';
import 'message_deletion_service.dart';

/// رکورد حذف برای undo
class DeletionRecord {
  final String id;
  final String conversationId;
  final List<Map<String, dynamic>> messagesBackup;
  final DateTime deletedAt;
  final bool isForEveryone;

  DeletionRecord({
    required this.id,
    required this.conversationId,
    required this.messagesBackup,
    required this.deletedAt,
    required this.isForEveryone,
  });
}

/// سرویس حذف کامل با Undo
class CompleteDeletionService {
  final SupabaseClient _supabase = supabase;
  final MessageDeletionService _deletionService = MessageDeletionService();
  
  // ذخیره backup برای undo
  final Map<String, DeletionRecord> _deletionRecords = {};
  
  // تایمر برای پاک کردن backup های قدیمی
  Timer? _cleanupTimer;

  CompleteDeletionService() {
    _startCleanupTimer();
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupOldRecords();
    });
  }

  void _cleanupOldRecords() {
    final now = DateTime.now();
    _deletionRecords.removeWhere((key, record) {
      // حذف رکوردهای قدیمی‌تر از 5 دقیقه
      return now.difference(record.deletedAt).inMinutes > 5;
    });
  }

  /// پاکسازی چت با قابلیت Undo
  Future<String> clearChatWithUndo({
    required String conversationId,
    required bool isForEveryone,
  }) async {
    try {
      // 1. Backup پیام‌ها
      final messages = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      final messagesBackup = List<Map<String, dynamic>>.from(messages);

      // 2. حذف پیام‌ها
      final result = await _deletionService.clearChat(
        conversationId: conversationId,
        type: isForEveryone ? DeletionType.forEveryone : DeletionType.forMe,
      );

      if (!result.success) {
        throw Exception(result.error ?? 'خطا در حذف');
      }

      // 3. ذخیره backup
      final deletionId = DateTime.now().millisecondsSinceEpoch.toString();
      _deletionRecords[deletionId] = DeletionRecord(
        id: deletionId,
        conversationId: conversationId,
        messagesBackup: messagesBackup,
        deletedAt: DateTime.now(),
        isForEveryone: isForEveryone,
      );

      logInfo('✅ Chat cleared with undo ID: $deletionId');

      return deletionId;
    } catch (e, stackTrace) {
      logInfo('❌ Error clearing chat with undo: $e\n$stackTrace');
      rethrow;
    }
  }

  /// بازگردانی حذف
  Future<bool> undoDeletion(String deletionId) async {
    try {
      final record = _deletionRecords[deletionId];
      if (record == null) {
        logInfo('⚠️ Deletion record not found: $deletionId');
        return false;
      }

      // بازگردانی پیام‌ها
      if (record.messagesBackup.isNotEmpty) {
        await _supabase.from('messages').insert(record.messagesBackup);
      }

      // حذف از records
      _deletionRecords.remove(deletionId);

      logInfo('✅ Deletion undone: $deletionId');

      return true;
    } catch (e, stackTrace) {
      logInfo('❌ Error undoing deletion: $e\n$stackTrace');
      return false;
    }
  }

  /// Dispose
  void dispose() {
    _cleanupTimer?.cancel();
    _deletionRecords.clear();
  }
}

