// lib/features/chat/repositories/chat_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';
import '../../../DB/unified_message_cache_service.dart'; // ✅ Added
import '../../../model/conversation_model.dart';
import '../data/datasources/chat_local_datasource_isar.dart';
import '../services/message_reactions_service.dart'; // ✅ اضافه شد
import 'package:uuid/uuid.dart';
import '../../../../services/vista_node_service.dart';
import '../../../../security/logging_utility.dart'; // Added
import 'chat_repository.dart';

/// A local-first ChatRepository implementation using Isar.
class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSourceIsar _localDataSource;
  final SupabaseClient _supabase;
  final String? _injectedCurrentUserId;
  final RealtimeChannel _messagesChannel;
  late final MessageReactionsService _reactionService;

  // ✅ Controller for Realtime Status
  final _realtimeStatusController =
      StreamController<RealtimeSubscribeStatus>.broadcast();

  @override
  Stream<RealtimeSubscribeStatus> get realtimeStatus =>
      _realtimeStatusController.stream;

  ChatRepositoryImpl({
    required ChatLocalDataSourceIsar localDataSource,
    required SupabaseClient supabase,
    String? currentUserId,
  })  : _localDataSource = localDataSource,
        _supabase = supabase,
        _injectedCurrentUserId = currentUserId,
        _messagesChannel = supabase.channel('public:messages') {
    _init();
  }
  @override
  Future<void> markMessagesAsSeen(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // ✅ 0. Optimistic Update (Local) - آپدیت فوری تیک‌ها در UI
      await _localDataSource.markMessagesAsSeenLocally(conversationId);

      // 1. آپدیت کردن همه پیام‌های طرف مقابل که دیده نشده‌اند
      await _supabase
          .from('messages')
          .update({'is_seen': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId) // فقط پیام‌های طرف مقابل
          .eq('is_seen', false); // فقط آنهایی که هنوز دیده نشده‌اند

      // 2. ریست کردن شمارنده پیام‌های ناخوانده (کد قبلی شما)
      await resetUnreadCount(conversationId);
    } catch (e) {
      logWarning('Error marking messages as seen', error: e);
    }
  }

  void _init() {
    // Initialize services
    _reactionService = MessageReactionsService(); // ✅ مقداردهی شد

    // Start listening to realtime changes immediately
    initializeRealtime();
  }

  String? get _currentUserId =>
      _injectedCurrentUserId ?? _supabase.auth.currentUser?.id;

  /// بررسی اعتبار جلسه کاری
  /// تضمین می‌کند که توکن منقضی نشده است
  Future<void> _ensureAuth() async {
    final session = _supabase.auth.currentSession;
    if (session == null || session.isExpired) {
      // تلاش برای رفرش توکن
      try {
        final response = await _supabase.auth.refreshSession();
        if (response.session == null) {
          throw Exception('Session expired - please login again');
        }
      } catch (e) {
        throw Exception('User not authenticated. Please login again.');
      }
    }
  }

  Future<bool> _isConversationParticipant(
      String conversationId, String userId) async {
    try {
      final response = await _supabase
          .from('conversation_participants')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .limit(1);
      return response.isNotEmpty;
    } catch (e, stack) {
      logWarning(
        'Failed to verify conversation participant for $conversationId',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  // CONVERSATIONS
  @override
  Future<ChatResult<List<ConversationModel>>> getConversations() async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

    try {
      // Fetch from server and store locally
      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles!user_id(username, avatar_url))')
          .order('updated_at', ascending: false)
          .limit(50);

      // map in background
      final conversations = await (Future.microtask(() => compute(
          _parseConversationsIsolate, {'data': response, 'userId': userId})));

      await _localDataSource.saveConversations(conversations);
      return ChatResult.success(conversations);
    } catch (e) {
      // fallback to local DB
      try {
        final local = await _localDataSource.watchConversations(userId).first;
        return ChatResult.success(local);
      } catch (err) {
        return ChatResult.failure(e.toString());
      }
    }
  }

  // ✅ Active Conversation Tracking
  String? _activeConversationId;

  @override
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    logInfo('Active conversation set to: $conversationId');
    if (conversationId != null) {
      // Clear unread count immediately when entering a chat
      resetUnreadCount(conversationId);
    }
  }

  /// This ensures that even if you are not in a chat, the conversation list updates
  /// immediately when a new message arrives.
  void initializeRealtime() {
    // 1. Listen for NEW MESSAGES & MESSAGE UPDATES (Chained)
    _messagesChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            try {
              final userId = _currentUserId;
              if (userId == null) {
                logWarning('Realtime: userId is null');
                return;
              }

              logDebug('Realtime: new message event received');
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) {
                logWarning('Realtime message payload is empty');
                return;
              }

              final conversationId = newRecord['conversation_id'] as String?;
              if (conversationId == null || conversationId.isEmpty) {
                logWarning('Realtime message missing conversation_id');
                return;
              }

              final existingConv =
                  await _localDataSource.getConversation(conversationId, userId);
              if (existingConv == null) {
                final isParticipant = await _isConversationParticipant(
                    conversationId, userId);
                if (!isParticipant) {
                  logWarning(
                      'Skipping realtime message for non-member conversation: $conversationId');
                  return;
                }
              }

              final newMessage =
                  MessageModel.fromJson(newRecord, currentUserId: userId);

              logDebug('Realtime message parsed: ${newMessage.id}');

              // ✅ Check if message already exists locally (by ID)
              final existingMessage =
                  await _localDataSource.getMessage(newMessage.id, userId);

              if (existingMessage != null) {
                // MERGE: Keep local data, update status to 'sent'
                logDebug('Merging existing message: ${newMessage.id}');
                final updatedMessage = existingMessage.copyWith(
                  isSent: true,
                  isPending: false, // Confirmed on server
                  createdAt: newMessage.createdAt,
                  attachmentUrl: newMessage.attachmentUrl, // Ensure url sync
                );
                await _localDataSource.saveMessage(updatedMessage);
              } else {
                // INSERT: New message from others
                logDebug('New message from others: ${newMessage.id}');
                await _localDataSource.saveMessage(newMessage);
              }

              // 2. Update Conversation Metadata (Unread Count, Last Message)
              final existingConvForUpdate =
                  existingConv ??
                      await _localDataSource.getConversation(
                          conversationId, userId);

              if (existingConvForUpdate != null) {
                // ✅ Active Chat Logic: Don't increment unread if active
                int newUnreadCount;
                if (conversationId == _activeConversationId) {
                  newUnreadCount = 0; // User is looking at the chat
                } else {
                  newUnreadCount = newMessage.senderId != userId
                      ? existingConvForUpdate.unreadCount + 1
                      : existingConvForUpdate.unreadCount;
                }

                final updatedConv = existingConvForUpdate.copyWith(
                  lastMessage: newMessage.content,
                  updatedAt: newMessage.createdAt,
                  unreadCount: newUnreadCount,
                  hasUnreadMessages: newUnreadCount > 0,
                );
                await _localDataSource.saveConversation(updatedConv);
              } else {
                // If conversation doesn't exist locally, fetch it
                logInfo('Conversation not found locally, fetching: $conversationId');
                _fetchAndSaveConversation(conversationId);
              }
            } catch (e, stack) {
              logError('Error in realtime message callback', error: e, stackTrace: stack);
            }
          },
        )
        // 2. ✅ Listen for MESSAGE UPDATES (Read Receipts / Edits)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            try {
              final userId = _currentUserId;
              if (userId == null) return;

              final newRecord = payload.newRecord;
              final messageId = newRecord['id'] as String;
              final conversationId = newRecord['conversation_id'] as String?;
              if (conversationId == null || conversationId.isEmpty) {
                logWarning('Realtime update missing conversation_id for message $messageId');
                return;
              }

              final existingConv = await _localDataSource.getConversation(
                  conversationId, userId);
              if (existingConv == null) {
                final isParticipant = await _isConversationParticipant(
                    conversationId, userId);
                if (!isParticipant) {
                  logWarning(
                      'Skipping realtime update for non-member conversation: $conversationId');
                  return;
                }
              }

              final isSeen = newRecord['is_seen'] as bool? ?? false;
              final isEdited = newRecord['is_edited'] as bool? ?? false;
              final newContent = newRecord['content'] as String?;

              // Update Local DB
              final existingMessage =
                  await _localDataSource.getMessage(messageId, userId);

              if (existingMessage != null) {
                // Only update if something changed
                if (existingMessage.isSeen != isSeen ||
                    (isEdited && existingMessage.content != newContent)) {
                  final updatedMessage = existingMessage.copyWith(
                    isSeen: isSeen,
                    // If edited, update content too
                    content: isEdited && newContent != null
                        ? newContent
                        : existingMessage.content,
                    isSent: true, // If updated on server, it must be sent
                    isDelivered: true, // Likely delivered too if seen/updated
                  );

                  await _localDataSource.saveMessage(updatedMessage);

                  // Update UI Cache
                  await UnifiedMessageCacheService()
                      .cacheMessage(updatedMessage);

                  logDebug('Message updated: $messageId (Seen: $isSeen)');
                }
              }
            } catch (e) {
              logError('Error in realtime update callback', error: e);
            }
          },
        )
        .subscribe((status, error) {
      logInfo('Realtime subscription status: $status');
      // ✅ Update status stream
      _realtimeStatusController.add(status);

      if (error != null) {
        logError('Realtime subscription error', error: error);
      }
    });

    // 3. ✅ Listen for UNREAD COUNT changes (Multi-device Sync)
    // FIX: Only subscribe if user ID is available
    final currentUserId = _currentUserId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      _supabase
          .channel('public:conversation_participants')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'conversation_participants',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUserId,
            ),
            callback: (payload) async {
              try {
                final userId = _currentUserId;
                if (userId == null) return;

                final newRecord = payload.newRecord;
                final conversationId = newRecord['conversation_id'] as String;
                final serverUnreadCount = newRecord['unread_count'] as int;

                // ✅ Active Chat Logic: If active, force logic 0 logic
                if (conversationId == _activeConversationId &&
                    serverUnreadCount > 0) {
                  // If server says we have unread, but we are active, reset it back!
                  resetUnreadCount(conversationId);
                  return;
                }

                // Sync to local Isar
                final existingConv = await _localDataSource.getConversation(
                    conversationId, userId);
                if (existingConv != null) {
                  final updatedConv = existingConv.copyWith(
                    unreadCount: serverUnreadCount,
                    hasUnreadMessages: serverUnreadCount > 0,
                  );
                  await _localDataSource.saveConversation(updatedConv);
                  logDebug('Synced unread count for $conversationId: $serverUnreadCount');
                }
              } catch (e) {
                logError('Error in realtime unread callback', error: e);
              }
            },
          )
          .subscribe();
    } else {
      logWarning('Skipping conversation_participants subscription: no user id');
    }
  }

  Future<void> _fetchAndSaveConversation(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles!user_id(username, avatar_url))')
          .eq('id', conversationId)
          .single();

      final conv = ConversationModel.fromJson(response, currentUserId: userId);
      await _localDataSource.saveConversation(conv);
    } catch (e) {
      logError('Error fetching new conversation', error: e);
    }
  }

  @override
  Stream<List<ConversationModel>> watchConversations() async* {
    final userId = _currentUserId;
    logDebug('watchConversations called. userId: $userId');
    if (userId == null) {
      logWarning('watchConversations: userId is null');
      return;
    }

    // Kick off background sync, but immediately return local stream
    logDebug('Triggering _syncConversations');
    _syncConversations();
    yield* _localDataSource.watchConversations(userId);
  }

  // MESSAGES
  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) async* {
    final userId = _currentUserId;
    if (userId == null) return;

    _syncMessages(conversationId);
    yield* _localDataSource.watchMessages(conversationId, userId);
  }

  @override
  Future<ChatResult<List<MessageModel>>> getMessages(String conversationId,
      {int limit = 50, String? beforeMessageId}) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده');

    await _syncMessages(conversationId);
    final msgs =
        await _localDataSource.watchMessages(conversationId, userId).first;
    return ChatResult.success(msgs.take(limit).toList());
  }

  @override
  Future<ChatResult<MessageModel>> sendMessage({
    required String conversationId,
    required String content,
    String? id,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    int? duration,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

    try {
      await _ensureAuth();
    } catch (e) {
      return ChatResult.failure(e.toString());
    }

    // ✅ Generate ID client-side (UUID v4)
    final messageId = id ?? const Uuid().v4();
    final now = DateTime.now();

    final messageModel = MessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: userId,
      content: content,
      createdAt: now,
      isMe: true,
      isPending: true, // Initially pending
      isSent: false,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent, // ✅ Now passing reply content
      replyToSenderName: replyToSenderName, // ✅ Now passing reply sender name
    );

    try {
      // 1. Save Optimistic Message to Local DB
      await _localDataSource.saveMessage(messageModel);

      // 2. Update Unified Cache (UI Update)
      await UnifiedMessageCacheService().cacheMessage(messageModel);

      // 3. Update Conversation Metadata (Optimistic)
      final existingConv =
          await _localDataSource.getConversation(conversationId, userId);
      if (existingConv != null) {
        final updatedConv = existingConv.copyWith(
          lastMessage: messageModel.content,
          updatedAt: now,
          unreadCount: 0,
        );
        await _localDataSource.saveConversation(updatedConv);
      } else {
        // Handle case where conversation doesn't exist locally yet (rare but possible)
      }

      // 4. Send to Supabase (using the SAME ID)
      final response = await _supabase
          .from('messages')
          .insert({
            'id': messageId, // ✅ USE THE SAME ID
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'attachment_url': attachmentUrl,
            'attachment_type': attachmentType,
            'is_sent': true,
            'is_pending': false,
            'created_at': now.toUtc().toIso8601String(),
            'reply_to_message_id': replyToMessageId,
            'reply_to_content': replyToContent,
            'reply_to_sender_name': replyToSenderName,
          })
          .select()
          .single();

      final serverMessage =
          MessageModel.fromJson(response, currentUserId: userId);

      // 5. Update Local DB w/ Server Response (mark as sent)
      // No delete needed! Just update.
      await _localDataSource.saveMessage(serverMessage);

      // 6. Update Unified Cache (Confirmed)
      await UnifiedMessageCacheService().cacheMessage(serverMessage);

      // 7. Sync Conversation Metadata (Confirmed)
      if (existingConv != null) {
        final updatedConv = existingConv.copyWith(
          lastMessage: serverMessage.content,
          updatedAt: serverMessage.createdAt,
        );
        await _localDataSource.saveConversation(updatedConv);
      }

      return ChatResult.success(serverMessage);
    } catch (e) {
      // On Failure: Mark as failed in DB
      final failedMessage =
          messageModel.copyWith(isPending: false, isFailed: true);
      await _localDataSource.saveMessage(failedMessage);
      await UnifiedMessageCacheService()
          .cacheMessage(failedMessage); // Update UI
      return ChatResult.failure(e.toString());
    }
  }

  // SYNC
  Future<void> _syncMessages(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      // 1. دریافت آخرین 50 پیام از سرور
      // تلگرام هم همیشه یک "Snapshot" از آخرین وضعیت می‌گیرد.
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(50);

      // 2. اگر جدول hidden_messages دارید، باید چک کنید که این پیام‌ها برای یوزر فعلی مخفی نشده باشند.
      // روش کلاینت-ساید (سریع برای اجرا):
      // ابتدا شناسه پیام‌های مخفی شده خودتان را بگیرید
      final hiddenResponse = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId);

      final hiddenIds = (hiddenResponse as List)
          .map((e) => e['message_id'] as String)
          .toSet();

      final filteredData = (response as List)
          .where((json) =>
              !hiddenIds.contains(json['id'] as String)) // فیلتر کردن مخفی‌ها
          .toList();

      final serverMessages = await compute(
          _parseMessagesIsolate, {'data': filteredData, 'userId': userId});

      // 3. استفاده از Reconciliation به جای saveMessages خالی
      // این خط باعث می‌شود پیام‌هایی که در سرور نیستند، از لوکال هم پاک شوند.
      await _localDataSource.reconcileMessages(conversationId, serverMessages);
    } catch (e) {
      logError('Sync messages error', error: e);
      // در صورت خطای شبکه، دیتای لوکال دست نخورده باقی می‌ماند (Offline First)
    }
  }

  Future<void> _syncConversations() async {
    try {
      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles!user_id(username, avatar_url))')
          .order('updated_at', ascending: false)
          .limit(50);

      final conversations = await compute(_parseConversationsIsolate,
          {'data': response, 'userId': _currentUserId ?? ''});

      await _localDataSource.saveConversations(conversations);
    } catch (e) {
      logError('Sync conversations error', error: e);
    }
  }

  // Remaining interface methods (minimal implementations)
  @override
  Future<ChatResult<ConversationModel>> createConversation(
      String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده');

    try {
      // ✅ استفاده از RPC function برای جلوگیری از ایجاد مکالمه تکراری
      // این تابع SQL با قفل‌گذاری کار می‌کند و تضمین می‌کند که هرگز مکالمه تکراری ساخته نمی‌شود
      final conversationId = await _supabase.rpc(
        'create_or_get_conversation',
        params: {
          'current_user_id': userId,
          'target_user_id': otherUserId,
        },
      );

      if (conversationId == null) {
        return ChatResult.failure('خطا در ایجاد مکالمه: RPC returned null');
      }

      // دریافت اطلاعات کامل مکالمه
      final full = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles!user_id(username, avatar_url))')
          .eq('id', conversationId.toString())
          .single();

      final conv = ConversationModel.fromJson(full, currentUserId: userId);
      await _syncConversations();
      return ChatResult.success(conv);
    } catch (e) {
      return ChatResult.failure('خطا در ایجاد مکالمه: ${e.toString()}');
    }
  }

  @override
  Future<ChatResult<void>> deleteConversation(String conversationId) async {
    try {
      // 1️⃣ ابتدا از Isar حذف کن (UI فوراً آپدیت میشه چون Stream گوش میده)
      await _localDataSource.deleteConversation(conversationId);
      await _localDataSource.clearMessages(conversationId);

      // 2️⃣ سپس از Supabase حذف کن (در background - بدون بلاک کردن UI)
      _supabase.from('conversations').delete().eq('id', conversationId).then(
            (_) => null,
            onError: (e) => logWarning('Server delete failed (non-blocking)', error: e),
          );

      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> toggleArchiveConversation(
      String conversationId) async {
    return ChatResult.failure('Not implemented');
  }

  @override
  Future<ChatResult<void>> togglePinConversation(String conversationId) async {
    return ChatResult.failure('Not implemented');
  }

  @override
  Future<ChatResult<void>> toggleMuteConversation(String conversationId) async {
    return ChatResult.failure('Not implemented');
  }

  @override
  Future<ChatResult<void>> clearConversation(String conversationId,
      {bool forEveryone = false}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

      // ✅ 1. ابتدا پاکسازی فوری لوکال (Sembast) - UI فوراً خالی می‌شود
      await _localDataSource.clearMessages(conversationId);

      // ✅ 2. عملیات سمت سرور
      if (forEveryone) {
        // پاکسازی برای همه
        try {
          // استفاده از RPC برای امنیت و سرعت بالاتر (اگر تعریف کرده‌اید)
          await _supabase.rpc(
            'clear_chat_for_everyone',
            params: {'chat_id_in': conversationId},
          ).onError((error, stackTrace) {
            // اگر RPC وجود نداشت، fallback به حذف مستقیم
            logWarning('RPC not available, using direct delete', error: error);
          });

          // Fallback: حذف مستقیم از جدول messages
          try {
            await _supabase
                .from('messages')
                .delete()
                .eq('conversation_id', conversationId);
            logInfo('Chat cleared for everyone: $conversationId');
          } catch (e) {
            // اگر RPC موفق بود، این خطا طبیعی است
            logWarning('Direct delete attempted (may already be cleared)', error: e);
          }
        } catch (e) {
          logWarning('Server clear error (non-fatal), but local cleanup completed', error: e);
        }
      } else {
        // پاکسازی یک‌طرفه - فقط لوکال پاک شده است
        // در آینده می‌توانید یک flag در conversation_participants مثل cleared_history_at اضافه کنید
        logInfo('Chat cleared locally for user: $userId');
      }

      return ChatResult.success(null);
    } catch (e) {
      // حتی در صورت خطا، مطمئن شویم لوکال پاک شده است
      try {
        await _localDataSource.clearMessages(conversationId);
      } catch (_) {}
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    try {
      logInfo('Delete requested: $messageId, forEveryone: $forEveryone');
      await _ensureAuth();

      final userId = _currentUserId;
      if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

      // 1. دریافت conversationId برای پاکسازی کش
      String? conversationId;
      try {
        final localMessage =
            await _localDataSource.getMessage(messageId, userId);
        conversationId = localMessage?.conversationId;
      } catch (e) {
        logWarning('Could not get conversationId', error: e);
      }

      // 2. ارسال به سرور (سرور خودش S3 و DB را مدیریت می‌کند)
      if (forEveryone) {
        logInfo('Calling node service for deletion');
        await VistaNodeService.deleteMessage(messageId);
        logInfo('Server deletion successful');
      } else {
        // حذف یک‌طرفه: فقط در hidden_messages ذخیره کن
        await _supabase.from('hidden_messages').upsert({
          'message_id': messageId,
          'user_id': userId,
          'hidden_at': DateTime.now().toUtc().toIso8601String(),
        });
        logInfo('Message hidden for user');
      }

      // 3. پاکسازی کش لوکال
      logDebug('Cleaning up local cache');
      await _localDataSource.deleteMessage(messageId);
      if (conversationId != null) {
        await UnifiedMessageCacheService()
            .deleteMessage(messageId, conversationId);
      }

      return ChatResult.success(null);
    } catch (e) {
      logError('Delete failed', error: e);
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> editMessage(
      String messageId, String newContent) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

    try {
      await _ensureAuth();

      // 1. Update on Supabase with is_edited flag
      final response = await _supabase
          .from('messages')
          .update({
            'content': newContent,
            'is_edited': true,
            'edited_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .select()
          .maybeSingle();

      if (response == null) {
        return ChatResult.failure('پیام یافت نشد یا امکان ویرایش نیست');
      }

      // 2. Update local Isar database (just update content, is_edited is stored on server)
      final existingMessage =
          await _localDataSource.getMessage(messageId, userId);
      if (existingMessage != null) {
        final updatedMessage = existingMessage.copyWith(
          content: newContent,
        );
        await _localDataSource.saveMessage(updatedMessage);

        // 3. Update Unified Cache (UI refresh)
        await UnifiedMessageCacheService().cacheMessage(updatedMessage);
      }

      return ChatResult.success(null);
    } catch (e) {
      logInfo('❌ Edit message failed: $e');
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<List<MessageModel>>> searchMessages(
      String conversationId, String query) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(50);
      final userId = _currentUserId ?? '';
      final messages = await compute(
          _parseMessagesIsolate, {'data': response as List, 'userId': userId});
      return ChatResult.success(messages);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<List<MessageModel>>> loadMoreMessages(
      {required String conversationId,
      required DateTime oldestMessageDate,
      int limit = 50}) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .lt('created_at', oldestMessageDate.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      final userId = _currentUserId ?? '';
      final messages = await compute(
          _parseMessagesIsolate, {'data': response as List, 'userId': userId});
      await _localDataSource.saveMessages(messages);
      return ChatResult.success(messages);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    try {
      // ✅ ارسال conversationId به سرویس
      await _reactionService.toggleReaction(
        messageId: messageId,
        conversationId: conversationId, // ✅ اضافه شد
        emoji: emoji,
      );
      return ChatResult.success(null);
    } catch (e) {
      logError('Toggle reaction failed', error: e);
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Stream<Map<String, List<String>>> watchReactions(String messageId) {
    // ✅ تبدیل استریم سرویس به فرمت مورد نظر
    // نکته: UI شما (ModernChatScreen) مستقیماً از سرویس استفاده می‌کند (از طریق _setupReactionsStream)
    // بنابراین این متد ممکن است استفاده نشود، اما پیاده‌سازی آن ضرری ندارد.
    return _reactionService.watchMessageReactions(messageId).map((reactions) {
      final Map<String, List<String>> result = {};
      for (final reaction in reactions) {
        if (!result.containsKey(reaction.emoji)) {
          result[reaction.emoji] = [];
        }
        result[reaction.emoji]!.add(reaction.userId);
      }
      return result;
    });
  }

  @override
  Future<void> sendTypingIndicator(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final channel = _supabase.channel('typing:$conversationId');
      await channel.sendBroadcastMessage(event: 'typing', payload: {
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String()
      });
    } catch (e) {
      logWarning('Typing indicator error', error: e);
    }
  }

  // ✅ پیاده‌سازی handleNotificationMessage
  @override
  Future<void> handleNotificationMessage(Map<String, dynamic> payload) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      logDebug('Optimistic save: processing notification payload');

      // 1. استخراج داده‌ها
      String? messageId =
          payload['id']?.toString() ?? payload['message_id']?.toString();
      final conversationId = payload['conversation_id']?.toString();
      final content =
          payload['content']?.toString() ?? payload['body']?.toString();
      final senderId = payload['sender_id']?.toString();

      if (conversationId == null || content == null || senderId == null) {
        logWarning('Optimistic save: missing critical fields');
        return;
      }

      final existingConvForNotification =
          await _localDataSource.getConversation(conversationId, userId);
      if (existingConvForNotification == null) {
        final isParticipant = await _isConversationParticipant(
            conversationId, userId);
        if (!isParticipant) {
          logWarning(
              'Skipping notification for non-member conversation: $conversationId');
          return;
        }
      }

      // تولید ID موقت اگر در پیلود نبود (که معمولاً هست)
      messageId ??= const Uuid().v4();

      final createdAtStr = payload['created_at']?.toString();
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now();

      // 2. ساخت مدل پیام
      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        isMe: senderId == userId,
        isSent: true,
        isPending: false,
        isDelivered: true,
        isSeen: false,
        // سایر فیلدها را می‌توان از payload استخراج کرد در صورت وجود
        senderName:
            payload['sender_name']?.toString() ?? payload['title']?.toString(),
        senderAvatar: payload['sender_avatar']?.toString(),
        attachmentUrl: payload['attachment_url']?.toString(),
        attachmentType: payload['attachment_type']?.toString(),
      );

      // 3. ذخیره در لوکال دیتابیس (Isar)
      await _localDataSource.saveMessage(message);

      // 4. آپدیت UI (Unified Cache)
      await UnifiedMessageCacheService().cacheMessage(message);

      // 5. آپدیت متادیتای مکالمه (آخرین پیام و تعداد خوانده نشده)
      final existingConv =
          await _localDataSource.getConversation(conversationId, userId);

      if (existingConv != null) {
        // محاسبه unread count
        // اگر مکالمه فعال باشد، 0، وگرنه یکی زیاد می‌شود (مگر اینکه از قبل unreadCount در پیلود باشد)
        int newUnreadCount = existingConv.unreadCount;
        if (conversationId == _activeConversationId) {
          newUnreadCount = 0;
        } else {
          // اگر خودمان فرستنده نیستیم
          if (senderId != userId) {
            newUnreadCount += 1;
          }
        }

        final updatedConv = existingConv.copyWith(
          lastMessage: content,
          updatedAt: createdAt,
          unreadCount: newUnreadCount,
          hasUnreadMessages: newUnreadCount > 0,
        );
        await _localDataSource.saveConversation(updatedConv);
        logDebug('Optimistic save: message and conversation updated');
      } else {
        // اگر مکالمه وجود نداشت، شاید بهتر باشد آن را فچ کنیم
        // اما برای سرعت فعلاً فقط پیام را ذخیره کردیم.
        // متد _fetchAndSaveConversation می‌تواند صدا زده شود.
        _fetchAndSaveConversation(conversationId);
      }
    } catch (e) {
      logError('Optimistic save failed', error: e);
    }
  }

  @override
  Stream<bool> watchTypingStatus(String conversationId, String userId) async* {
    final controller = StreamController<bool>.broadcast();
    yield* controller.stream;
  }

  @override
  Future<void> refreshConversations() async {
    await _syncConversations();
  }

  @override
  Future<void> refreshMessages(String conversationId) async {
    await _syncMessages(conversationId);
  }

  @override
  Future<void> syncPendingMessages() async {
    // TODO: implement retrying pending messages
  }

  @override
  void dispose() {
    // no-op for now
  }

  @override
  Future<void> clearConversationCache(String conversationId) async {
    // not implemented
  }

  @override
  Future<void> clearAllCache() async {
    // not implemented
  }

  @override
  Future<void> resetUnreadCount(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // 1️⃣ ابتدا Isar آپدیت کن (UI فوراً آپدیت میشه چون Stream گوش میده)
      await _localDataSource.resetUnreadCount(conversationId);

      // 2️⃣ سپس Supabase آپدیت کن (در background - بدون بلاک کردن UI)
      _supabase
          .from('conversation_participants')
          .update({'unread_count': 0})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .then((_) => null,
              onError: (e) => logInfo('⚠️ Server update failed: $e'));
    } catch (e) {
      logInfo('Error resetting unread count: $e');
    }
  }

  @override
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final count = await _supabase
          .from('blocked_users')
          .count(CountOption.exact)
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId);

      return count > 0;
    } catch (e) {
      logInfo('Error checking blocked status: $e');
      return false;
    }
  }

  @override
  Future<bool> isCurrentUserBlockedBy(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final count = await _supabase
          .from('blocked_users')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('blocked_user_id', currentUserId);

      return count > 0;
    } catch (e) {
      logInfo('Error checking blocked by status: $e');
      return false;
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('user_id', currentUserId)
          .eq('blocked_user_id', userId);
    } catch (e) {
      logInfo('Error unblocking user: $e');
      rethrow;
    }
  }

  // ✅ STATIC HELPERS FOR BACKGROUND PARSING (ISOLATES)

  static List<ConversationModel> _parseConversationsIsolate(
      Map<String, dynamic> params) {
    final list = params['data'] as List;
    final userId = params['userId'] as String;
    return list
        .map((json) => ConversationModel.fromJson(json, currentUserId: userId))
        .toList();
  }

  static List<MessageModel> _parseMessagesIsolate(Map<String, dynamic> params) {
    final list = params['data'] as List;
    final userId = params['userId'] as String;
    return list
        .map((json) => MessageModel.fromJson(json, currentUserId: userId))
        .toList();
  }
}
