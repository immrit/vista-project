// lib/features/chat/repositories/chat_repository_impl.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';
import '../../../model/conversation_model.dart';
import '../data/datasources/chat_local_datasource.dart';
import '../services/storage_service.dart';
import 'chat_repository.dart';
import '../../../../DB/unified_conversation_cache_service.dart';

/// A local-first ChatRepository implementation.
///
/// - UI reads only from local DB streams provided by `ChatLocalDataSource`.
/// - Repository syncs with Supabase in background and updates local DB.
class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSource _localDataSource;
  final SupabaseClient _supabase;
  final String? _injectedCurrentUserId;
  final RealtimeChannel _messagesChannel;
  late final StorageService _storageService;

  ChatRepositoryImpl({
    required ChatLocalDataSource localDataSource,
    required SupabaseClient supabase,
    String? currentUserId,
  })  : _localDataSource = localDataSource,
        _supabase = supabase,
        _injectedCurrentUserId = currentUserId,
        _messagesChannel = supabase.channel('public:messages') {
    _init();
  }

  void _init() {
    // Initialize storage service for cloud file management
    _storageService = StorageService(_supabase);
    
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
              '*, conversation_participants!inner(*, profiles(username, avatar_url))')
          .order('updated_at', ascending: false)
          .limit(50);

      final conversations = (response as List)
          .map(
              (json) => ConversationModel.fromJson(json, currentUserId: userId))
          .toList();

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

  /// This ensures that even if you are not in a chat, the conversation list updates
  /// immediately when a new message arrives.
  void initializeRealtime() {
    _messagesChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final userId = _currentUserId;
            if (userId == null) return;

            final newMessage =
                MessageModel.fromJson(payload.newRecord, currentUserId: userId);

            // 1. Save Message to Local DB
            await _localDataSource.saveMessage(newMessage);

            // 2. Update Conversation Metadata (Unread Count, Last Message)
            final conversationId = newMessage.conversationId;
            final existingConv =
                await _localDataSource.getConversation(conversationId, userId);

            if (existingConv != null) {
              // Calculate new unread count
              final newUnreadCount = newMessage.senderId != userId
                  ? existingConv.unreadCount + 1
                  : existingConv.unreadCount;

              final updatedConv = existingConv.copyWith(
                lastMessage: newMessage.content,
                updatedAt: newMessage.createdAt,
                unreadCount: newUnreadCount,
                hasUnreadMessages: newUnreadCount > 0,
              );
              await _localDataSource.saveConversation(updatedConv);
            } else {
              // If conversation doesn't exist locally, fetch it
              _fetchAndSaveConversation(conversationId);
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchAndSaveConversation(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles(username, avatar_url))')
          .eq('id', conversationId)
          .single();

      final conv = ConversationModel.fromJson(response, currentUserId: userId);
      await _localDataSource.saveConversation(conv);
    } catch (e) {
      print('Error fetching new conversation: $e');
    }
  }

  @override
  Stream<List<ConversationModel>> watchConversations() async* {
    final userId = _currentUserId;
    print('DEBUG: watchConversations called. userId: $userId');
    if (userId == null) {
      print('DEBUG: userId is null, returning empty stream.');
      return;
    }

    // Kick off background sync, but immediately return local stream
    print('DEBUG: Triggering _syncConversations');
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

    // ✅ بررسی اعتبار جلسه کاری
    try {
      await _ensureAuth();
    } catch (e) {
      return ChatResult.failure(e.toString());
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final tempMessage = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: userId,
      content: content,
      createdAt: now,
      isMe: true,
      isPending: true,
      isSent: false,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );

    try {
      await _localDataSource.saveMessage(tempMessage);

      // ✅ Trigger UI Update immediately via Unified Cache (Optimistic)
      // This bridges the gap between Sembast (Storage) and AdvancedCacheSystem (UI)
      await UnifiedConversationCacheService().cacheMessage(tempMessage);

      // ✅ Update Conversation Metadata (Optimistic)
      final existingConv =
          await _localDataSource.getConversation(conversationId, userId);
      if (existingConv != null) {
        final updatedConv = existingConv.copyWith(
          lastMessage: tempMessage.content,
          updatedAt: now,
          unreadCount: 0, // Sending a message implies we read the chat
        );
        await _localDataSource.saveConversation(updatedConv);
      }

      final response = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'attachment_url': attachmentUrl,
            'attachment_type': attachmentType,
            'is_sent': true,
            'is_pending': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      final serverMessage =
          MessageModel.fromJson(response, currentUserId: userId);
      await _localDataSource.deleteMessage(tempId);
      await _localDataSource.saveMessage(serverMessage);

      // ✅ Update UI with confirmed message
      await UnifiedConversationCacheService().cacheMessage(serverMessage);

      // ✅ Update Conversation Metadata (Confirmed)
      if (existingConv != null) {
        final updatedConv = existingConv.copyWith(
          lastMessage: serverMessage.content,
          updatedAt: serverMessage.createdAt,
        );
        await _localDataSource.saveConversation(updatedConv);
      }

      return ChatResult.success(serverMessage);
    } catch (e) {
      final failedMessage =
          tempMessage.copyWith(isPending: false, isFailed: true);
      await _localDataSource.saveMessage(failedMessage);
      return ChatResult.failure(e.toString());
    }
  }

  // SYNC
  Future<void> _syncMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(50);

      final messages = (response as List)
          .map((json) =>
              MessageModel.fromJson(json, currentUserId: _currentUserId ?? ''))
          .toList();

      await _localDataSource.saveMessages(messages);
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  Future<void> _syncConversations() async {
    try {
      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles(username, avatar_url))')
          .order('updated_at', ascending: false)
          .limit(50);

      final conversations = (response as List)
          .map((json) => ConversationModel.fromJson(json,
              currentUserId: _currentUserId ?? ''))
          .toList();

      await _localDataSource.saveConversations(conversations);
    } catch (e) {
      print('Sync conversations error: $e');
    }
  }

  // Remaining interface methods (minimal implementations)
  @override
  Future<ChatResult<ConversationModel>> createConversation(
      String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده');

    try {
      // Try to find existing or create new conversation
      final existing = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);
      final otherParticipations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId);

      final myConvIds =
          (existing as List).map((e) => e['conversation_id'] as String).toSet();
      final otherConvIds = (otherParticipations as List)
          .map((e) => e['conversation_id'] as String)
          .toSet();
      final common = myConvIds.intersection(otherConvIds);
      if (common.isNotEmpty) {
        final existingConv = await _supabase
            .from('conversations')
            .select(
                '*, conversation_participants!inner(*, profiles(username, avatar_url))')
            .eq('id', common.first)
            .single();
        return ChatResult.success(
            ConversationModel.fromJson(existingConv, currentUserId: userId));
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final newConversation = await _supabase
          .from('conversations')
          .insert({'created_at': now, 'updated_at': now})
          .select()
          .single();
      final conversationId = newConversation['id'] as String;
      await _supabase.from('conversation_participants').insert([
        {
          'conversation_id': conversationId,
          'user_id': userId,
          'created_at': now
        },
        {
          'conversation_id': conversationId,
          'user_id': otherUserId,
          'created_at': now
        },
      ]);

      final full = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles(username, avatar_url))')
          .eq('id', conversationId)
          .single();
      final conv = ConversationModel.fromJson(full, currentUserId: userId);
      await _syncConversations();
      return ChatResult.success(conv);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> deleteConversation(String conversationId) async {
    try {
      await _supabase.from('conversations').delete().eq('id', conversationId);
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
      await _supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    try {
      await _ensureAuth();
      
      final userId = _currentUserId;
      if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

      // ابتدا پیام را بگیر تا ببین آیا فایل ضمیمه دارد یا نه
      final messageData = await _supabase
          .from('messages')
          .select('id, attachment_url, attachment_type')
          .eq('id', messageId)
          .single();

      final attachmentUrl = messageData['attachment_url'] as String?;
      final attachmentType = messageData['attachment_type'] as String?;

      if (forEveryone) {
        // ✅ حذف دوطرفه - پیام و فایل ضمیمه‌اش را حذف کن
        
        if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
          // ✅ حذف فایل از Cloud Storage (Arvan/Supabase)
          // از StorageService استفاده می‌کنیم برای حذف متمرکز
          await _storageService.deleteFile(attachmentUrl, attachmentType);
          print('✅ Attachment deleted from cloud for message: $messageId');
        }
        
        // حذف پیام از دیتابیس
        await _supabase.from('messages').delete().eq('id', messageId);
        print('✅ Message deleted from database for everyone: $messageId');
      } else {
        // حذف برای خودم - پیام را فقط برای این کاربر مخفی کن
        // فایل را پاک نمی‌کنیم چون شاید طرف مقابل بخواهد ببیند
        await _supabase.from('hidden_messages').insert({
          'message_id': messageId,
          'user_id': userId,
          'hidden_at': DateTime.now().toUtc().toIso8601String(),
        }).onError((error, stackTrace) {
          // اگر رکورد قبلاً وجود دارد، خطای duplicate key رخ می‌دهد
          // این طبیعی است و مشکلی ندارد
          print('Note: Message may already be hidden or error: $error');
        });
        print('✅ Message hidden for user: $userId, messageId: $messageId');
      }

      // حذف از محلی (Sembast)
      await _localDataSource.deleteMessage(messageId);
      
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> editMessage(
      String messageId, String newContent) async {
    try {
      await _supabase
          .from('messages')
          .update({'content': newContent}).eq('id', messageId);
      return ChatResult.success(null);
    } catch (e) {
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
      final messages = (response as List)
          .map((j) => MessageModel.fromJson(j, currentUserId: userId))
          .toList();
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
      final messages = (response as List)
          .map((j) => MessageModel.fromJson(j, currentUserId: userId))
          .toList();
      await _localDataSource.saveMessages(messages);
      return ChatResult.success(messages);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> toggleReaction(
      {required String messageId,
      required String conversationId,
      required String emoji}) async {
    return ChatResult.failure('Not implemented');
  }

  @override
  Stream<Map<String, List<String>>> watchReactions(String messageId) async* {
    yield {};
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
      print('typing error: $e');
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
}
