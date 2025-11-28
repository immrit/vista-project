// lib/features/chat/repositories/chat_repository_impl.dart
//
// پیاده‌سازی واقعی ChatRepository
// 
// این فایل قلب سیستم چت هست:
// ✅ Cache-First Strategy (اول Cache، بعد Server)
// ✅ Optimistic Updates (پیام فوری نشون میده)
// ✅ Realtime Subscriptions (با مدیریت درست)
// ✅ Automatic Cleanup (بدون Memory Leak)

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';
import '../../../model/conversation_model.dart';
import '../services/chat_cache_service.dart';
import 'chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  // ═══════════════════════════════════════════════════════════════════
  // 🔧 DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════

  final SupabaseClient _supabase;
  final ChatCacheService _cache;

  // ═══════════════════════════════════════════════════════════════════
  // 📡 REALTIME CHANNELS
  // ═══════════════════════════════════════════════════════════════════

  /// Channel برای مکالمات
  RealtimeChannel? _conversationsChannel;

  /// Channels برای پیام‌های هر مکالمه
  final Map<String, RealtimeChannel> _messageChannels = {};

  /// Channels برای Typing Indicator
  final Map<String, RealtimeChannel> _typingChannels = {};

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════

  /// Controller برای مکالمات
  final _conversationsController =
      StreamController<List<ConversationModel>>.broadcast();

  /// Controllers برای پیام‌های هر مکالمه
  final Map<String, StreamController<List<MessageModel>>> _messageControllers =
      {};

  /// Controllers برای Typing
  final Map<String, StreamController<bool>> _typingControllers = {};

  // ═══════════════════════════════════════════════════════════════════
  // 🏗️ CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════

  ChatRepositoryImpl({
    SupabaseClient? supabase,
    ChatCacheService? cache,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cache = cache ?? ChatCacheService();

  /// دریافت User ID فعلی
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<List<ConversationModel>>> getConversations() async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      print('📥 [Repository] Fetching conversations...');

      // ✅ Step 1: گرفتن از Server
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants!inner(
              *,
              profiles(username, avatar_url)
            )
          ''')
          .order('updated_at', ascending: false);

      final conversations = (response as List)
          .map((json) => ConversationModel.fromJson(json, currentUserId: userId))
          .toList();

      // ✅ Step 2: ذخیره در Cache
      await _cache.cacheConversations(conversations);

      print('✅ [Repository] Fetched ${conversations.length} conversations');
      return ChatResult.success(conversations);
    } catch (e) {
      print('❌ [Repository] Error fetching conversations: $e');

      // ✅ Fallback به Cache
      final cached = await _cache.getCachedConversations();
      if (cached.isNotEmpty) {
        print('💾 [Repository] Returning ${cached.length} cached conversations');
        return ChatResult.success(cached);
      }

      return ChatResult.failure('خطا در دریافت مکالمات: ${e.toString()}');
    }
  }

  @override
  Stream<List<ConversationModel>> watchConversations() async* {
    final userId = _currentUserId;
    if (userId == null) {
      print('⚠️ [Repository] User not logged in');
      return;
    }

    print('📡 [Repository] Starting conversations stream...');

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 1: Cache فوری (تا UI سریع بیاد)
    // ═══════════════════════════════════════════════════════════════════

    final cached = await _cache.getCachedConversations();
    if (cached.isNotEmpty) {
      print('⚡ [Repository] Emitting ${cached.length} cached conversations');
      yield cached;
    }

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 2: Fetch از Server
    // ═══════════════════════════════════════════════════════════════════

    final result = await getConversations();
    if (result.isSuccess && result.data != null) {
      print('🌐 [Repository] Emitting ${result.data!.length} fresh conversations');
      yield result.data!;
    }

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 3: Setup Realtime
    // ═══════════════════════════════════════════════════════════════════

    await _setupConversationsRealtime(userId);

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 4: Listen به Stream Controller
    // ═══════════════════════════════════════════════════════════════════

    yield* _conversationsController.stream;
  }

  /// Setup Realtime برای مکالمات
  Future<void> _setupConversationsRealtime(String userId) async {
    if (_conversationsChannel != null) {
      print('⚠️ [Repository] Conversations channel already exists');
      return;
    }

    print('📡 [Repository] Setting up conversations realtime...');

    _conversationsChannel = _supabase
        .channel('conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) async {
            print('📨 [Repository] Conversations event: ${payload.eventType}');
            await _refreshConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            // وقتی پیام جدید میاد، لیست مکالمات رو هم refresh کن
            // (برای آپدیت last_message)
            print('📨 [Repository] Message event - refreshing conversations');
            await _refreshConversations();
          },
        )
        .subscribe();

    print('✅ [Repository] Conversations realtime setup complete');
  }

  /// Refresh مکالمات و emit کردن
  Future<void> _refreshConversations() async {
    final result = await getConversations();
    if (result.isSuccess && result.data != null) {
      _conversationsController.add(result.data!);
    }
  }

  @override
  Future<ChatResult<ConversationModel>> createConversation(
      String otherUserId) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      print('📝 [Repository] Creating conversation with: $otherUserId');

      // ✅ Step 1: چک کن که مکالمه قبلاً وجود نداره
      final existing = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      final otherParticipations = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId);

      // پیدا کردن conversation مشترک
      final myConvIds =
          (existing as List).map((e) => e['conversation_id'] as String).toSet();
      final otherConvIds = (otherParticipations as List)
          .map((e) => e['conversation_id'] as String)
          .toSet();
      final commonIds = myConvIds.intersection(otherConvIds);

      if (commonIds.isNotEmpty) {
        // مکالمه قبلاً وجود داره
        final existingConv = await _supabase
            .from('conversations')
            .select('''
              *,
              conversation_participants!inner(
                *,
                profiles(username, avatar_url)
              )
            ''')
            .eq('id', commonIds.first)
            .single();

        final conversation =
            ConversationModel.fromJson(existingConv, currentUserId: userId);
        print('✅ [Repository] Found existing conversation: ${conversation.id}');
        return ChatResult.success(conversation);
      }

      // ✅ Step 2: ساخت مکالمه جدید
      final now = DateTime.now().toUtc().toIso8601String();
      final newConversation = await _supabase
          .from('conversations')
          .insert({
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      final conversationId = newConversation['id'] as String;

      // ✅ Step 3: اضافه کردن participants
      await _supabase.from('conversation_participants').insert([
        {
          'conversation_id': conversationId,
          'user_id': userId,
          'created_at': now,
        },
        {
          'conversation_id': conversationId,
          'user_id': otherUserId,
          'created_at': now,
        },
      ]);

      // ✅ Step 4: Fetch مکالمه کامل
      final fullConversation = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants!inner(
              *,
              profiles(username, avatar_url)
            )
          ''')
          .eq('id', conversationId)
          .single();

      final conversation =
          ConversationModel.fromJson(fullConversation, currentUserId: userId);

      // ✅ Step 5: آپدیت Cache
      await refreshConversations();

      print('✅ [Repository] Created conversation: ${conversation.id}');
      return ChatResult.success(conversation);
    } catch (e) {
      print('❌ [Repository] Error creating conversation: $e');
      return ChatResult.failure('خطا در ساخت مکالمه: ${e.toString()}');
    }
  }

  @override
  Future<ChatResult<void>> deleteConversation(String conversationId) async {
    try {
      print('🗑️ [Repository] Deleting conversation: $conversationId');

      await _supabase
          .from('conversations')
          .delete()
          .eq('id', conversationId);

      // پاکسازی Cache
      await _cache.clearConversationCache(conversationId);
      await refreshConversations();

      print('✅ [Repository] Conversation deleted');
      return ChatResult.success(null);
    } catch (e) {
      print('❌ [Repository] Error deleting conversation: $e');
      return ChatResult.failure('خطا در حذف مکالمه');
    }
  }

  @override
  Future<ChatResult<void>> toggleArchiveConversation(
      String conversationId) async {
    try {
      // گرفتن وضعیت فعلی
      final current = await _supabase
          .from('conversations')
          .select('is_archived')
          .eq('id', conversationId)
          .single();

      final isArchived = current['is_archived'] as bool? ?? false;

      await _supabase
          .from('conversations')
          .update({'is_archived': !isArchived})
          .eq('id', conversationId);

      await refreshConversations();
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure('خطا در آرشیو کردن مکالمه');
    }
  }

  @override
  Future<ChatResult<void>> togglePinConversation(String conversationId) async {
    try {
      final current = await _supabase
          .from('conversations')
          .select('is_pinned')
          .eq('id', conversationId)
          .single();

      final isPinned = current['is_pinned'] as bool? ?? false;

      await _supabase
          .from('conversations')
          .update({'is_pinned': !isPinned})
          .eq('id', conversationId);

      await refreshConversations();
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure('خطا در پین کردن مکالمه');
    }
  }

  @override
  Future<ChatResult<void>> toggleMuteConversation(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return ChatResult.failure('کاربر وارد نشده');

      final current = await _supabase
          .from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .single();

      final isMuted = current['is_muted'] as bool? ?? false;

      await _supabase
          .from('conversation_participants')
          .update({'is_muted': !isMuted})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      await refreshConversations();
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure('خطا در بی‌صدا کردن مکالمه');
    }
  }

  @override
  Future<ChatResult<void>> clearConversation(
    String conversationId, {
    bool forEveryone = false,
  }) async {
    try {
      if (forEveryone) {
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
      } else {
        // TODO: Implement soft delete for current user only
        await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
      }

      await _cache.clearConversationCache(conversationId);
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure('خطا در پاکسازی مکالمه');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      print('📥 [Repository] Fetching messages for: $conversationId');

      var query = _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Pagination
      if (beforeMessageId != null) {
        final beforeMessage = await _supabase
            .from('messages')
            .select('created_at')
            .eq('id', beforeMessageId)
            .single();

        query = _supabase
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .lt('created_at', beforeMessage['created_at'])
            .order('created_at', ascending: false)
            .limit(limit);
      }

      final response = await query;

      final messages = (response as List)
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      // ذخیره در Cache
      await _cache.cacheMessages(conversationId, messages);

      print('✅ [Repository] Fetched ${messages.length} messages');
      return ChatResult.success(messages);
    } catch (e) {
      print('❌ [Repository] Error fetching messages: $e');

      // Fallback به Cache
      final cached = await _cache.getCachedMessages(conversationId);
      if (cached.isNotEmpty) {
        print('💾 [Repository] Returning ${cached.length} cached messages');
        return ChatResult.success(cached);
      }

      return ChatResult.failure('خطا در دریافت پیام‌ها');
    }
  }

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) async* {
    final userId = _currentUserId;
    if (userId == null) {
      print('⚠️ [Repository] User not logged in');
      return;
    }

    print('📡 [Repository] Starting messages stream for: $conversationId');

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 1: Cache فوری
    // ═══════════════════════════════════════════════════════════════════

    final cached = await _cache.getCachedMessages(conversationId);
    if (cached.isNotEmpty) {
      print('⚡ [Repository] Emitting ${cached.length} cached messages');
      yield cached;
    }

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 2: Server Fetch
    // ═══════════════════════════════════════════════════════════════════

    final result = await getMessages(conversationId);
    if (result.isSuccess && result.data != null) {
      print('🌐 [Repository] Emitting ${result.data!.length} fresh messages');
      yield result.data!;
    }

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 3: Setup Realtime
    // ═══════════════════════════════════════════════════════════════════

    await _setupMessagesRealtime(conversationId);

    // ═══════════════════════════════════════════════════════════════════
    // مرحله 4: Listen به Stream Controller
    // ═══════════════════════════════════════════════════════════════════

    final controller = _getOrCreateMessageController(conversationId);
    yield* controller.stream;
  }

  /// Setup Realtime برای پیام‌ها
  Future<void> _setupMessagesRealtime(String conversationId) async {
    if (_messageChannels.containsKey(conversationId)) {
      print('⚠️ [Repository] Message channel already exists for: $conversationId');
      return;
    }

    print('📡 [Repository] Setting up messages realtime for: $conversationId');

    final channel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            print('📨 [Repository] New message received');
            await _handleNewMessage(conversationId, payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            print('📨 [Repository] Message updated');
            await _refreshMessages(conversationId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            print('📨 [Repository] Message deleted');
            await _refreshMessages(conversationId);
          },
        )
        .subscribe();

    _messageChannels[conversationId] = channel;
    print('✅ [Repository] Messages realtime setup complete');
  }

  /// Handle پیام جدید از Realtime
  Future<void> _handleNewMessage(
      String conversationId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final message = MessageModel.fromJson(data, currentUserId: userId);

      // اضافه کردن به Cache
      await _cache.addMessage(message);

      // گرفتن لیست آپدیت شده و emit کردن
      final messages = await _cache.getCachedMessages(conversationId);
      _getOrCreateMessageController(conversationId).add(messages);
    } catch (e) {
      print('❌ [Repository] Error handling new message: $e');
      await _refreshMessages(conversationId);
    }
  }

  /// Refresh پیام‌ها و emit کردن
  Future<void> _refreshMessages(String conversationId) async {
    final result = await getMessages(conversationId);
    if (result.isSuccess && result.data != null) {
      _getOrCreateMessageController(conversationId).add(result.data!);
    }
  }

  /// گرفتن یا ساختن StreamController برای پیام‌ها
  StreamController<List<MessageModel>> _getOrCreateMessageController(
      String conversationId) {
    if (!_messageControllers.containsKey(conversationId)) {
      _messageControllers[conversationId] =
          StreamController<List<MessageModel>>.broadcast();
    }
    return _messageControllers[conversationId]!;
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
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    // ✅ Step 1: ساختن پیام موقت (Optimistic Update)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = MessageModel.temporary(
      tempId: tempId,
      conversationId: conversationId,
      senderId: userId,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      duration: duration,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );

    try {
      print('📤 [Repository] Sending message: $tempId');

      // ✅ Step 2: فوری به Cache اضافه کن (کاربر پیام رو میبینه)
      await _cache.addMessage(tempMessage);
      final cachedMessages = await _cache.getCachedMessages(conversationId);
      _getOrCreateMessageController(conversationId).add(cachedMessages);

      // ✅ Step 3: ارسال به Server
      final response = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'attachment_url': attachmentUrl,
            'attachment_type': attachmentType,
            'attachment_file_name': attachmentFileName,
            'duration': duration,
            'reply_to_message_id': replyToMessageId,
            'reply_to_content': replyToContent,
            'reply_to_sender_name': replyToSenderName,
            'is_sent': true,
          })
          .select()
          .single();

      final serverMessage =
          MessageModel.fromJson(response, currentUserId: userId);

      // ✅ Step 4: جایگزینی پیام موقت با پیام واقعی
      await _cache.removeMessage(tempId);
      await _cache.addMessage(serverMessage);

      final updatedMessages = await _cache.getCachedMessages(conversationId);
      _getOrCreateMessageController(conversationId).add(updatedMessages);

      // ✅ Step 5: آپدیت last_message در conversation
      await _supabase.from('conversations').update({
        'last_message': content,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversationId);

      print('✅ [Repository] Message sent: ${serverMessage.id}');
      return ChatResult.success(serverMessage);
    } catch (e) {
      print('❌ [Repository] Error sending message: $e');

      // ✅ Rollback - علامت‌گذاری به عنوان failed
      final failedMessage = tempMessage.copyWith(
        isPending: false,
        isFailed: true,
        errorMessage: e.toString(),
      );
      await _cache.updateMessage(failedMessage);

      final messages = await _cache.getCachedMessages(conversationId);
      _getOrCreateMessageController(conversationId).add(messages);

      return ChatResult.failure('خطا در ارسال پیام');
    }
  }

  @override
  Future<ChatResult<void>> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  }) async {
    try {
      print('🗑️ [Repository] Deleting message: $messageId');

      // Optimistic delete از Cache
      await _cache.removeMessage(messageId);

      // حذف از Server
      await _supabase.from('messages').delete().eq('id', messageId);

      print('✅ [Repository] Message deleted');
      return ChatResult.success(null);
    } catch (e) {
      print('❌ [Repository] Error deleting message: $e');
      return ChatResult.failure('خطا در حذف پیام');
    }
  }

  @override
  Future<ChatResult<void>> editMessage(
      String messageId, String newContent) async {
    try {
      print('✏️ [Repository] Editing message: $messageId');

      await _supabase
          .from('messages')
          .update({'content': newContent})
          .eq('id', messageId);

      print('✅ [Repository] Message edited');
      return ChatResult.success(null);
    } catch (e) {
      print('❌ [Repository] Error editing message: $e');
      return ChatResult.failure('خطا در ویرایش پیام');
    }
  }

  @override
  Future<ChatResult<List<MessageModel>>> searchMessages(
    String conversationId,
    String query,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(50);

      final messages = (response as List)
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      return ChatResult.success(messages);
    } catch (e) {
      return ChatResult.failure('خطا در جستجو');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📄 PAGINATION - بارگذاری پیام‌های بیشتر
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<List<MessageModel>>> loadMoreMessages({
    required String conversationId,
    required DateTime oldestMessageDate,
    int limit = 50,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      print('📥 [Repository] Loading more messages before: $oldestMessageDate');

      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .lt('created_at', oldestMessageDate.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final newMessages = (response as List)
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      print('📦 [Repository] Loaded ${newMessages.length} older messages');

      if (newMessages.isNotEmpty) {
        // ✅ اضافه کردن پیام‌های قدیمی به Cache (بدون جایگزینی)
        final currentMessages = await _cache.getCachedMessages(conversationId);
        
        // حذف duplicate ها
        final allMessagesMap = <String, MessageModel>{};
        for (final msg in currentMessages) {
          allMessagesMap[msg.id] = msg;
        }
        for (final msg in newMessages) {
          allMessagesMap[msg.id] = msg;
        }

        // مرتب‌سازی و ذخیره
        final sortedMessages = allMessagesMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        await _cache.cacheMessages(conversationId, sortedMessages);

        // Emit به Stream
        _getOrCreateMessageController(conversationId).add(sortedMessages);
      }

      return ChatResult.success(newMessages);
    } catch (e) {
      print('❌ [Repository] Error loading more messages: $e');
      return ChatResult.failure('خطا در بارگذاری پیام‌های بیشتر');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 😀 REACTIONS
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      print('😀 [Repository] Toggling reaction: $emoji on $messageId');

      // چک کن آیا قبلاً این reaction رو داده
      final existing = await _supabase
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existing != null) {
        // حذف reaction
        await _supabase
            .from('message_reactions')
            .delete()
            .eq('id', existing['id']);
      } else {
        // اضافه کردن reaction
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'conversation_id': conversationId, // ✅ اضافه شد
          'user_id': userId,
          'emoji': emoji,
        });
      }

      // Refresh messages برای آپدیت UI
      await _refreshMessages(conversationId);

      return ChatResult.success(null);
    } catch (e) {
      print('❌ [Repository] Error toggling reaction: $e');
      return ChatResult.failure('خطا در ثبت واکنش');
    }
  }

  @override
  Stream<Map<String, List<String>>> watchReactions(String messageId) async* {
    // TODO: Implement realtime reactions
    yield {};
  }

  // ═══════════════════════════════════════════════════════════════════
  // ⌨️ TYPING INDICATOR
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<void> sendTypingIndicator(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // استفاده از Broadcast channel برای typing
      final channel = _supabase.channel('typing:$conversationId');
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('⚠️ [Repository] Error sending typing indicator: $e');
    }
  }

  @override
  Stream<bool> watchTypingStatus(String conversationId, String userId) async* {
    print('👀 [Repository] Watching typing status for: $userId');

    final controller = StreamController<bool>.broadcast();

    // Cleanup قبلی
    if (_typingChannels.containsKey(conversationId)) {
      await _supabase.removeChannel(_typingChannels[conversationId]!);
    }

    final channel = _supabase
        .channel('typing:$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final typingUserId = payload['user_id'] as String?;
            if (typingUserId == userId) {
              controller.add(true);

              // بعد از 3 ثانیه، false بفرست
              Future.delayed(const Duration(seconds: 3), () {
                if (!controller.isClosed) {
                  controller.add(false);
                }
              });
            }
          },
        )
        .subscribe();

    _typingChannels[conversationId] = channel;
    _typingControllers[conversationId] = controller;

    yield* controller.stream;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SYNC & REFRESH
  // ═══════════════════════════════════════════════════════════════════

  @override
  Future<void> refreshConversations() async {
    await _refreshConversations();
  }

  @override
  Future<void> refreshMessages(String conversationId) async {
    await _refreshMessages(conversationId);
  }

  @override
  Future<void> syncPendingMessages() async {
    // TODO: Implement sync for failed/pending messages
    print('🔄 [Repository] Syncing pending messages...');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    print('🧹 [Repository] Cleaning up...');

    // بستن conversations channel
    if (_conversationsChannel != null) {
      _supabase.removeChannel(_conversationsChannel!);
      _conversationsChannel = null;
    }

    // بستن message channels
    for (final entry in _messageChannels.entries) {
      _supabase.removeChannel(entry.value);
    }
    _messageChannels.clear();

    // بستن typing channels
    for (final entry in _typingChannels.entries) {
      _supabase.removeChannel(entry.value);
    }
    _typingChannels.clear();

    // بستن stream controllers
    _conversationsController.close();
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();

    for (final controller in _typingControllers.values) {
      controller.close();
    }
    _typingControllers.clear();

    print('✅ [Repository] Cleanup complete');
  }

  @override
  Future<void> clearConversationCache(String conversationId) async {
    await _cache.clearConversationCache(conversationId);
  }

  @override
  Future<void> clearAllCache() async {
    await _cache.clearAll();
  }
}

