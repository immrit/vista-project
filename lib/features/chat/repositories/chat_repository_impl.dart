// lib/features/chat/repositories/chat_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';

import '../../../model/conversation_model.dart';
import '../data/datasources/chat_local_datasource_isar.dart';
import '../services/message_reactions_service.dart'; // ✅ اضافه شد
import '../domain/message_payload.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/vista_node_service.dart';
import '../../../../security/logging_utility.dart'; // Added
import '../../../DB/isar_database_manager.dart';
import '../../../DB/entities/deletion_task_entity.dart';
import 'chat_repository.dart';

/// A local-first ChatRepository implementation using Isar.
class ChatRepositoryImpl implements ChatRepository {
  static const String _messageSelectWithProfiles =
      '*, profiles!sender_id(username, full_name, avatar_url)';
  final ChatLocalDataSourceIsar _localDataSource;
  final SupabaseClient _supabase;
  final String? _injectedCurrentUserId;
  final RealtimeChannel _messagesChannel;
  final Map<String, RealtimeChannel> _priorityMessageChannels = {};
  final Map<String, int> _priorityMessageChannelRefs = {};
  final Map<String, bool> _priorityMessageChannelReady = {};
  late final MessageReactionsService _reactionService;
  final IsarDatabaseManager _dbManager = IsarDatabaseManager();

  // ✅ Controller for Realtime Status
  final _realtimeStatusController =
      StreamController<RealtimeSubscribeStatus>.broadcast();
  RealtimeSubscribeStatus _latestRealtimeStatus =
      RealtimeSubscribeStatus.closed;

  @override
  Stream<RealtimeSubscribeStatus> get realtimeStatus async* {
    yield _latestRealtimeStatus;
    yield* _realtimeStatusController.stream;
  }

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
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('messages')
          .update({
            'is_seen': true,
            'is_read': true,
            'is_delivered': true,
            'seen_at': nowIso,
            'delivered_at': nowIso,
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId) // فقط پیام‌های طرف مقابل
          .or('is_seen.eq.false,is_seen.is.null'); // فقط دیده‌نشده‌ها

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

  final Map<String, int> _lastConversationCatchupAtMs = <String, int>{};
  final Map<String, bool> _conversationSyncInFlight = <String, bool>{};
  final Map<String, int> _lastSeenSyncAtMs = <String, int>{};
  final Map<String, int> _lastRealtimeHealthSyncAtMs = <String, int>{};
  final Map<String, DateTime> _lastMessageSyncCursor = <String, DateTime>{};
  final Map<String, int> _lastFullMessageSyncAtMs = <String, int>{};
  final Map<String, Set<String>> _hiddenIdsCache = <String, Set<String>>{};
  final Map<String, int> _hiddenIdsCacheAtMs = <String, int>{};
  int _lastConversationsCatchupAtMs = 0;
  bool _conversationsSyncInFlight = false;
  static const Duration _fallbackConversationSyncInterval =
      Duration(seconds: 2);
  static const Duration _fallbackMessageSyncInterval = Duration(seconds: 1);
  static const Duration _realtimeCatchupMessageInterval =
      Duration(milliseconds: 1200);
  static const Duration _realtimeCatchupConversationsInterval =
      Duration(milliseconds: 2500);
  static const Duration _hiddenIdsCacheTtl = Duration(seconds: 10);
  static const Duration _realtimeHealthCatchupInterval = Duration(seconds: 2);
  static const Duration _fullMessageReconcileInterval = Duration(seconds: 8);
  static const Duration _deltaMessageWindow = Duration(minutes: 2);
  static const int _fullMessageSnapshotLimit = 80;
  static const int _deltaMessageSnapshotLimit = 100;
  static const String _conversationHealthKey = '__conversations__';

  void _scheduleRealtimeCatchup(
    String conversationId, {
    bool includeConversations = true,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final messageCatchupIntervalMs =
        (_latestRealtimeStatus == RealtimeSubscribeStatus.subscribed
                ? _realtimeCatchupMessageInterval
                : _fallbackMessageSyncInterval)
            .inMilliseconds;
    final lastMessagesSync = _lastConversationCatchupAtMs[conversationId] ?? 0;
    if (nowMs - lastMessagesSync > messageCatchupIntervalMs) {
      _lastConversationCatchupAtMs[conversationId] = nowMs;
      unawaited(_syncMessages(conversationId));
    }

    if (!includeConversations) return;
    final conversationCatchupIntervalMs =
        (_latestRealtimeStatus == RealtimeSubscribeStatus.subscribed
                ? _realtimeCatchupConversationsInterval
                : _fallbackConversationSyncInterval)
            .inMilliseconds;
    if (nowMs - _lastConversationsCatchupAtMs > conversationCatchupIntervalMs) {
      _lastConversationsCatchupAtMs = nowMs;
      unawaited(_syncConversations());
    }
  }

  bool _isPriorityMessageChannelActive(String conversationId) {
    final key = conversationId.trim();
    return _priorityMessageChannels.containsKey(key) &&
        (_priorityMessageChannelReady[key] ?? false);
  }

  void _ensurePriorityMessageChannel(String conversationId) {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return;

    final refs = (_priorityMessageChannelRefs[normalizedConversationId] ?? 0) + 1;
    _priorityMessageChannelRefs[normalizedConversationId] = refs;
    if (_priorityMessageChannels.containsKey(normalizedConversationId)) {
      return;
    }
    _priorityMessageChannelReady[normalizedConversationId] = false;

    final channel = _supabase
        .channel('priority:messages:$normalizedConversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: normalizedConversationId,
          ),
          callback: (payload) async {
            try {
              final userId = _currentUserId;
              if (userId == null) return;
              await _handleRealtimeInsertRecord(
                userId: userId,
                conversationId: normalizedConversationId,
                newRecord: payload.newRecord,
                includeConversationSync: false,
              );
            } catch (e, stack) {
              logError(
                'Priority realtime insert failed',
                error: e,
                stackTrace: stack,
              );
              _scheduleRealtimeCatchup(
                normalizedConversationId,
                includeConversations: true,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: normalizedConversationId,
          ),
          callback: (payload) async {
            try {
              final userId = _currentUserId;
              if (userId == null) return;
              await _handleRealtimeUpdateRecord(
                userId: userId,
                conversationId: normalizedConversationId,
                newRecord: payload.newRecord,
                includeConversationSync: false,
              );
            } catch (e, stack) {
              logError(
                'Priority realtime update failed',
                error: e,
                stackTrace: stack,
              );
              _scheduleRealtimeCatchup(
                normalizedConversationId,
                includeConversations: true,
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: normalizedConversationId,
          ),
          callback: (payload) async {
            try {
              await _handleRealtimeDeleteRecord(
                oldRecord: payload.oldRecord,
                includeConversationSync: false,
              );
            } catch (e, stack) {
              logError(
                'Priority realtime delete failed',
                error: e,
                stackTrace: stack,
              );
              _scheduleRealtimeCatchup(
                normalizedConversationId,
                includeConversations: true,
              );
            }
          },
        )
        .subscribe((status, error) {
      logDebug(
          'Priority realtime [$normalizedConversationId] status: $status');
      _priorityMessageChannelReady[normalizedConversationId] =
          status == RealtimeSubscribeStatus.subscribed;
      if (error != null) {
        logError(
          'Priority realtime [$normalizedConversationId] error',
          error: error,
        );
      }
    });

    _priorityMessageChannels[normalizedConversationId] = channel;
  }

  Future<void> _releasePriorityMessageChannel(String conversationId) async {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return;

    final nextRefs = (_priorityMessageChannelRefs[normalizedConversationId] ?? 1) - 1;
    if (nextRefs > 0) {
      _priorityMessageChannelRefs[normalizedConversationId] = nextRefs;
      return;
    }

    _priorityMessageChannelRefs.remove(normalizedConversationId);
    _priorityMessageChannelReady.remove(normalizedConversationId);
    final channel = _priorityMessageChannels.remove(normalizedConversationId);
    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
  }

  Future<void> _handleRealtimeInsertRecord({
    required String userId,
    required String conversationId,
    required Map<String, dynamic> newRecord,
    bool includeConversationSync = true,
  }) async {
    if (newRecord.isEmpty) return;

    final newMessage = MessageModel.fromJson(newRecord, currentUserId: userId);

    if (await _isMessageTombstoned(
      conversationId: conversationId,
      messageId: newMessage.id,
    )) {
      return;
    }

    final existingMessage = await _localDataSource.getMessage(newMessage.id, userId);
    if (existingMessage != null) {
      final updatedMessage = existingMessage.copyWith(
        isSent: true,
        isPending: false,
        createdAt: newMessage.createdAt,
        attachmentUrl: newMessage.attachmentUrl ?? existingMessage.attachmentUrl,
        isDelivered: existingMessage.isDelivered || newMessage.isDelivered,
        isSeen: existingMessage.isSeen || newMessage.isSeen,
        isRead: existingMessage.isRead || newMessage.isRead,
        content: newMessage.content.isNotEmpty
            ? newMessage.content
            : existingMessage.content,
      );
      await _localDataSource.saveMessage(updatedMessage);
    } else {
      await _localDataSource.saveMessage(newMessage);
    }

    if (newMessage.senderId != userId &&
        newMessage.isDelivered == false &&
        newMessage.isSeen == false) {
      unawaited(_markMessageDelivered(newMessage.id));
    }

    if (conversationId == _activeConversationId) {
      await _localDataSource.resetUnreadCount(conversationId);
      if (newMessage.senderId != userId) {
        unawaited(markMessagesAsSeen(conversationId));
      }
    } else {
      final existingConvForUpdate =
          await _localDataSource.getConversation(conversationId, userId);
      if (existingConvForUpdate == null) {
        unawaited(_fetchAndSaveConversation(conversationId));
      }
    }

    _scheduleRealtimeCatchup(
      conversationId,
      includeConversations: includeConversationSync,
    );
  }

  Future<void> _markMessageDelivered(String messageId) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('messages')
          .update({'is_delivered': true, 'delivered_at': nowIso})
          .eq('id', messageId)
          .eq('is_delivered', false);
    } catch (e) {
      logDebug('mark_delivered_failed: $messageId -> $e');
    }
  }

  Future<void> _handleRealtimeUpdateRecord({
    required String userId,
    required String conversationId,
    required Map<String, dynamic> newRecord,
    bool includeConversationSync = true,
  }) async {
    final messageId = newRecord['id'] as String?;
    if (messageId == null || messageId.isEmpty) return;

    final isRead = newRecord['is_read'] as bool? ?? false;
    final isSeen = (newRecord['is_seen'] as bool? ?? false) || isRead;
    final isDelivered = (newRecord['is_delivered'] as bool? ?? false) || isSeen;
    final isSent = newRecord['is_sent'] as bool? ?? false;
    final isEdited = newRecord['is_edited'] as bool? ?? false;
    final newContent = newRecord['content'] as String?;

    final existingMessage = await _localDataSource.getMessage(messageId, userId);
    if (existingMessage == null) {
      _scheduleRealtimeCatchup(
        conversationId,
        includeConversations: includeConversationSync,
      );
      return;
    }

    if (existingMessage.isSeen != isSeen ||
        existingMessage.isRead != isRead ||
        existingMessage.isDelivered != isDelivered ||
        existingMessage.isSent != isSent ||
        (isEdited && existingMessage.content != newContent)) {
      final updatedMessage = existingMessage.copyWith(
        isRead: isRead,
        isSeen: isSeen,
        content:
            isEdited && newContent != null ? newContent : existingMessage.content,
        isSent: isSent || existingMessage.isSent,
        isDelivered: isDelivered,
      );
      await _localDataSource.saveMessage(updatedMessage);
    }
  }

  Future<void> _handleRealtimeDeleteRecord({
    required Map<String, dynamic> oldRecord,
    bool includeConversationSync = true,
  }) async {
    if (oldRecord.isEmpty) return;
    final messageId = oldRecord['id'] as String?;
    if (messageId == null || messageId.isEmpty) return;

    await _localDataSource.deleteMessage(messageId);
    logDebug('Realtime message deleted: $messageId');

    final conversationId = oldRecord['conversation_id'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      _scheduleRealtimeCatchup(
        conversationId,
        includeConversations: includeConversationSync,
      );
    }
  }

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
      final localConversations = await _localDataSource.getConversations();
      if (localConversations.isNotEmpty) {
        unawaited(_syncConversations());
        return ChatResult.success(localConversations);
      }

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
        final local = await _localDataSource.getConversations();
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

              // Active conversation channel handles this path with lower latency.
              if (_isPriorityMessageChannelActive(conversationId)) {
                return;
              }

              await _handleRealtimeInsertRecord(
                userId: userId,
                conversationId: conversationId,
                newRecord: newRecord,
                includeConversationSync: false,
              );
            } catch (e, stack) {
              logError('Error in realtime message callback',
                  error: e, stackTrace: stack);
              final fallbackConversationId =
                  payload.newRecord['conversation_id'] as String?;
              if (fallbackConversationId != null &&
                  fallbackConversationId.isNotEmpty) {
                _scheduleRealtimeCatchup(
                  fallbackConversationId,
                  includeConversations: true,
                );
              } else {
                unawaited(_syncConversations());
              }
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
                logWarning(
                    'Realtime update missing conversation_id for message $messageId');
                return;
              }

              // Active conversation channel handles this path with lower latency.
              if (_isPriorityMessageChannelActive(conversationId)) {
                return;
              }

              await _handleRealtimeUpdateRecord(
                userId: userId,
                conversationId: conversationId,
                newRecord: newRecord,
                includeConversationSync: false,
              );
            } catch (e) {
              logError('Error in realtime update callback', error: e);
              final fallbackConversationId =
                  payload.newRecord['conversation_id'] as String?;
              if (fallbackConversationId != null &&
                  fallbackConversationId.isNotEmpty) {
                _scheduleRealtimeCatchup(
                  fallbackConversationId,
                  includeConversations: true,
                );
              } else {
                unawaited(_syncConversations());
              }
            }
          },
        )
        // 3. ✅ Listen for MESSAGE DELETES (Delete for everyone)
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            try {
              final oldRecord = payload.oldRecord;
              if (oldRecord.isEmpty) return;

              final conversationId = oldRecord['conversation_id'] as String?;
              if (conversationId != null &&
                  conversationId.isNotEmpty &&
                  _isPriorityMessageChannelActive(conversationId)) {
                return;
              }

              await _handleRealtimeDeleteRecord(
                oldRecord: oldRecord,
                includeConversationSync: false,
              );
            } catch (e, stack) {
              logError(
                'Error in realtime delete callback',
                error: e,
                stackTrace: stack,
              );
              final fallbackConversationId =
                  payload.oldRecord['conversation_id'] as String?;
              if (fallbackConversationId != null &&
                  fallbackConversationId.isNotEmpty) {
                _scheduleRealtimeCatchup(
                  fallbackConversationId,
                  includeConversations: true,
                );
              } else {
                unawaited(_syncConversations());
              }
            }
          },
        )
        .subscribe((status, error) {
      logInfo('Realtime subscription status: $status');
      _latestRealtimeStatus = status;
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
                final serverUnreadCount =
                    (newRecord['unread_count'] as num?)?.toInt() ?? 0;

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
                  logDebug(
                      'Synced unread count for $conversationId: $serverUnreadCount');
                } else {
                  unawaited(_fetchAndSaveConversation(conversationId));
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
  Stream<List<ConversationModel>> watchConversations() {
    final userId = _currentUserId;
    logDebug('watchConversations called. userId: $userId');
    if (userId == null) {
      logWarning('watchConversations: userId is null');
      return const Stream.empty();
    }

    StreamSubscription<List<ConversationModel>>? localSub;
    Timer? periodicSyncTimer;
    late final StreamController<List<ConversationModel>> controller;

    controller = StreamController<List<ConversationModel>>(
      onListen: () {
        unawaited(_syncConversations());
        periodicSyncTimer =
            Timer.periodic(_fallbackConversationSyncInterval, (timer) {
          if (controller.isClosed) {
            timer.cancel();
            return;
          }

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (_latestRealtimeStatus == RealtimeSubscribeStatus.subscribed) {
            final lastHealth =
                _lastRealtimeHealthSyncAtMs[_conversationHealthKey] ?? 0;
            if (nowMs - lastHealth <
                _realtimeHealthCatchupInterval.inMilliseconds) {
              return;
            }
            _lastRealtimeHealthSyncAtMs[_conversationHealthKey] = nowMs;
          }

          unawaited(_syncConversations());
        });

        localSub = _localDataSource.watchConversations(userId).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                periodicSyncTimer?.cancel();
                if (!controller.isClosed) {
                  controller.close();
                }
              },
            );
      },
      onCancel: () async {
        periodicSyncTimer?.cancel();
        await localSub?.cancel();
        _lastRealtimeHealthSyncAtMs.remove(_conversationHealthKey);
      },
    );

    return controller.stream;
  }

  // MESSAGES
  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return const Stream.empty();

    StreamSubscription<List<MessageModel>>? localSub;
    Timer? periodicSyncTimer;
    late final StreamController<List<MessageModel>> controller;

    controller = StreamController<List<MessageModel>>(
      onListen: () {
        unawaited(_syncMessages(normalizedConversationId));
        _ensurePriorityMessageChannel(normalizedConversationId);
        periodicSyncTimer =
            Timer.periodic(_fallbackMessageSyncInterval, (timer) {
          if (controller.isClosed) {
            timer.cancel();
            return;
          }
          if (_latestRealtimeStatus == RealtimeSubscribeStatus.subscribed) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final lastHealth =
                _lastRealtimeHealthSyncAtMs[normalizedConversationId] ?? 0;
            if (nowMs - lastHealth <
                _realtimeHealthCatchupInterval.inMilliseconds) {
              return;
            }
            _lastRealtimeHealthSyncAtMs[normalizedConversationId] = nowMs;
          }
          unawaited(_syncMessages(normalizedConversationId));
        });
        localSub = _localDataSource
            .watchMessages(normalizedConversationId, userId)
            .listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            periodicSyncTimer?.cancel();
            unawaited(_releasePriorityMessageChannel(normalizedConversationId));
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      },
      onCancel: () async {
        periodicSyncTimer?.cancel();
        await localSub?.cancel();
        await _releasePriorityMessageChannel(normalizedConversationId);
        _lastRealtimeHealthSyncAtMs.remove(normalizedConversationId);
      },
    );

    return controller.stream;
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
  Future<ChatResult<MessageModel>> sendMessage(MessagePayload payload) async {
    final conversationId = payload.conversationId;
    final content = payload.content;
    final id = payload.id;
    final attachmentUrl = payload.attachmentUrl;
    final attachmentType = payload.attachmentType;
    final attachmentFileName = payload.attachmentFileName;
    final attachmentMimeType = payload.attachmentMimeType;
    final attachmentSizeBytes = payload.attachmentSizeBytes;
    final audioTitle = payload.audioTitle;
    final audioArtist = payload.audioArtist;
    final audioAlbum = payload.audioAlbum;
    final mediaGroupId = payload.mediaGroupId;
    final duration = payload.duration;
    final replyToMessageId = payload.replyToMessageId;
    final replyToContent = payload.replyToContent;
    final replyToSenderName = payload.replyToSenderName;

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
    final existingLocalMessage =
        await _localDataSource.getMessage(messageId, userId);

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
      attachmentFileName:
          attachmentFileName ?? existingLocalMessage?.attachmentFileName,
      attachmentMimeType:
          attachmentMimeType ?? existingLocalMessage?.attachmentMimeType,
      attachmentSizeBytes:
          attachmentSizeBytes ?? existingLocalMessage?.attachmentSizeBytes,
      audioTitle: audioTitle ?? existingLocalMessage?.audioTitle,
      audioArtist: audioArtist ?? existingLocalMessage?.audioArtist,
      audioAlbum: audioAlbum ?? existingLocalMessage?.audioAlbum,
      mediaGroupId: mediaGroupId ?? existingLocalMessage?.mediaGroupId,
      duration: duration ?? existingLocalMessage?.duration,
      localFilePath: existingLocalMessage?.localFilePath,
      localImagePath: existingLocalMessage?.localImagePath,
      uploadProgress: existingLocalMessage?.uploadProgress,
      isUploading: existingLocalMessage?.isUploading ?? false,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent, // ✅ Now passing reply content
      replyToSenderName: replyToSenderName, // ✅ Now passing reply sender name
    );

    try {
      // 1. Save Optimistic Message to Local DB (این متد به صورت خودکار کانورسیشن را نیز آپدیت می‌کند)
      await _localDataSource.saveMessage(messageModel);

      // 4. Send to Supabase (using the SAME ID)
      final insertPayload = <String, dynamic>{
        'id': messageId, // ✅ USE THE SAME ID
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'attachment_file_name': messageModel.attachmentFileName,
        'attachment_mime_type': messageModel.attachmentMimeType,
        'attachment_size_bytes': messageModel.attachmentSizeBytes,
        'audio_title': messageModel.audioTitle,
        'audio_artist': messageModel.audioArtist,
        'audio_album': messageModel.audioAlbum,
        'media_group_id': messageModel.mediaGroupId,
        'duration': messageModel.duration,
        'is_sent': true,
        'is_pending': false,
        'created_at': now.toUtc().toIso8601String(),
        'reply_to_message_id': replyToMessageId,
        'reply_to_content': replyToContent,
        'reply_to_sender_name': replyToSenderName,
      };
      final response = await _insertMessageWithMetadataFallback(insertPayload);

      final serverMessage =
          MessageModel.fromJson(response, currentUserId: userId);
      final mergedServerMessage = _mergeUploadMetadata(
          serverMessage, existingLocalMessage ?? messageModel);

      // 5. Update Local DB w/ Server Response (mark as sent)
      // این متد بصورت اتوماتیک کانورسیشن را آپدیت می‌کند
      await _localDataSource.saveMessage(mergedServerMessage);

      return ChatResult.success(mergedServerMessage);
    } catch (e) {
      // On Failure: Mark as failed in DB
      final err = e.toString();
      final failedMessage =
          messageModel.copyWith(isPending: false, isFailed: true, errorMessage: err);
      await _localDataSource.saveMessage(failedMessage);
      final isPrivacyDenied =
          err.contains('messages_insert_respect_message_privacy') ||
              err.contains('row-level security') ||
              err.contains('violates row level security') ||
              err.contains('violates row-level security');
      return ChatResult.failure(
          isPrivacyDenied ? 'این کاربر دریافت پیام را محدود کرده است' : err);
    }
  }

  @override
  Future<ChatResult<MessageModel>> createPendingMessage({
    required String conversationId,
    required String content,
    required String localId,
    required String attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
    String? localFilePath,
    int? duration,
    String? mediaGroupId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      final pending = MessageModel.temporary(
        tempId: localId,
        conversationId: conversationId,
        senderId: userId,
        content: content,
        attachmentType: attachmentType,
        attachmentFileName: attachmentFileName,
        attachmentMimeType: attachmentMimeType,
        attachmentSizeBytes: attachmentSizeBytes,
        audioTitle: audioTitle,
        audioArtist: audioArtist,
        audioAlbum: audioAlbum,
        mediaGroupId: mediaGroupId,
        localFilePath: localFilePath,
        duration: duration,
        uploadProgress: 0.0,
        isUploading: true,
      );

      await _localDataSource.saveMessage(pending);
      return ChatResult.success(pending);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> updateUploadProgress(
      String localId, double progress) async {
    try {
      await _localDataSource.updateUploadProgress(localId, progress);
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> markUploadSucceeded(
      String localId, MessageModel serverMessage) async {
    try {
      final userId = _currentUserId;
      final pending = userId == null
          ? null
          : await _localDataSource.getMessage(localId, userId);
      if (localId != serverMessage.id) {
        await _localDataSource.deleteMessage(localId);
      }
      final normalized = _mergeUploadMetadata(serverMessage, pending).copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        isPending: false,
        isFailed: false,
      );
      await _localDataSource.saveMessage(normalized);
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  MessageModel _mergeUploadMetadata(
    MessageModel serverMessage,
    MessageModel? localMessage,
  ) {
    if (localMessage == null) {
      return serverMessage.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        isPending: false,
        isFailed: false,
      );
    }

    return serverMessage.copyWith(
      attachmentFileName:
          (serverMessage.attachmentFileName?.isNotEmpty ?? false)
              ? serverMessage.attachmentFileName
              : localMessage.attachmentFileName,
      attachmentMimeType:
          serverMessage.attachmentMimeType ?? localMessage.attachmentMimeType,
      attachmentSizeBytes:
          serverMessage.attachmentSizeBytes ?? localMessage.attachmentSizeBytes,
      audioTitle: (serverMessage.audioTitle?.isNotEmpty ?? false)
          ? serverMessage.audioTitle
          : localMessage.audioTitle,
      audioArtist: (serverMessage.audioArtist?.isNotEmpty ?? false)
          ? serverMessage.audioArtist
          : localMessage.audioArtist,
      audioAlbum: (serverMessage.audioAlbum?.isNotEmpty ?? false)
          ? serverMessage.audioAlbum
          : localMessage.audioAlbum,
      mediaGroupId: serverMessage.mediaGroupId ?? localMessage.mediaGroupId,
      duration: serverMessage.duration ?? localMessage.duration,
      localFilePath: localMessage.localFilePath,
      localImagePath: localMessage.localImagePath,
      isUploading: false,
      uploadProgress: 1.0,
      isPending: false,
      isFailed: false,
    );
  }

  Future<Map<String, dynamic>> _insertMessageWithMetadataFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _supabase
          .from('messages')
          .insert(payload)
          .select(_messageSelectWithProfiles)
          .single();
    } on PostgrestException catch (e) {
      final details =
          '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'.toLowerCase();
      final missingMetadataColumn = details.contains('attachment_mime_type') ||
          details.contains('attachment_size_bytes') ||
          details.contains('audio_title') ||
          details.contains('audio_artist') ||
          details.contains('audio_album') ||
          details.contains('media_group_id');
      if (!missingMetadataColumn) rethrow;

      final fallbackPayload = Map<String, dynamic>.from(payload)
        ..remove('attachment_mime_type')
        ..remove('attachment_size_bytes')
        ..remove('audio_title')
        ..remove('audio_artist')
        ..remove('audio_album')
        ..remove('media_group_id');

      logWarning(
        'messages metadata columns are missing on server, retrying legacy insert',
      );

      return await _supabase
          .from('messages')
          .insert(fallbackPayload)
          .select(_messageSelectWithProfiles)
          .single();
    }
  }

  @override
  Future<ChatResult<void>> markUploadFailed(
    String localId, {
    String? errorMessage,
  }) async {
    try {
      await _localDataSource.markUploadFailed(
        localId,
        errorMessage: errorMessage,
      );
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  // SYNC
  Future<void> _syncMessages(String conversationId) async {
    final normalizedConversationId = conversationId.trim();
    if (normalizedConversationId.isEmpty) return;
    if (_conversationSyncInFlight[normalizedConversationId] == true) return;
    _conversationSyncInFlight[normalizedConversationId] = true;
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastCursor = _lastMessageSyncCursor[normalizedConversationId];
      final lastFullSyncAtMs =
          _lastFullMessageSyncAtMs[normalizedConversationId] ?? 0;
      final isRealtimeSubscribed =
          _latestRealtimeStatus == RealtimeSubscribeStatus.subscribed;

      // Telegram-style: realtime + periodic reconcile.
      // Use lightweight deltas most of the time, and periodic full snapshots
      // to heal missed deletes/updates.
      final shouldRunFullReconcile = !isRealtimeSubscribed ||
          lastCursor == null ||
          nowMs - lastFullSyncAtMs >=
              _fullMessageReconcileInterval.inMilliseconds;

      final dynamic response;
      if (shouldRunFullReconcile) {
        response = await _supabase
            .from('messages')
            .select(_messageSelectWithProfiles)
            .eq('conversation_id', normalizedConversationId)
            .order('created_at', ascending: false)
            .limit(_fullMessageSnapshotLimit);
      } else {
        final since = lastCursor
            .subtract(_deltaMessageWindow)
            .toUtc()
            .toIso8601String();
        response = await _supabase
            .from('messages')
            .select(_messageSelectWithProfiles)
            .eq('conversation_id', normalizedConversationId)
            .gte('created_at', since)
            .order('created_at', ascending: false)
            .limit(_deltaMessageSnapshotLimit);
      }

      // 2. hidden_messages best-effort + short TTL cache
      final hiddenIds = await _getHiddenIds(
        userId: userId,
        conversationId: normalizedConversationId,
      );

      final tombstoneIds = await _getTombstoneIds(normalizedConversationId);
      final blockedIds = {...hiddenIds, ...tombstoneIds};

      final filteredData = (response as List)
          .where((json) => !blockedIds.contains(json['id'] as String))
          .toList();

      List<MessageModel> serverMessages;
      try {
        serverMessages = await compute(
          _parseMessagesIsolate,
          {'data': filteredData, 'userId': userId},
        );
      } catch (e, stack) {
        logWarning(
          'Background parse failed in syncMessages, fallback to main isolate',
          error: e,
          stackTrace: stack,
        );
        serverMessages = _parseMessagesIsolate(
          {'data': filteredData, 'userId': userId},
        );
      }

      if (serverMessages.isNotEmpty) {
        DateTime latestCreatedAt = serverMessages.first.createdAt;
        for (final message in serverMessages.skip(1)) {
          if (message.createdAt.isAfter(latestCreatedAt)) {
            latestCreatedAt = message.createdAt;
          }
        }

        final existingCursor = _lastMessageSyncCursor[normalizedConversationId];
        if (existingCursor == null || latestCreatedAt.isAfter(existingCursor)) {
          _lastMessageSyncCursor[normalizedConversationId] = latestCreatedAt;
        }
      }

      // اگر پیام از مسیر sync کشف شد (و realtime miss شده بود)، delivered را همگام کن.
      for (final message in serverMessages) {
        if (message.senderId != userId &&
            message.isDelivered == false &&
            message.isSeen == false) {
          unawaited(_markMessageDelivered(message.id));
        }
      }

      if (shouldRunFullReconcile) {
        _lastFullMessageSyncAtMs[normalizedConversationId] = nowMs;
        await _localDataSource.reconcileMessages(
          normalizedConversationId,
          serverMessages,
        );
      } else {
        await _localDataSource.saveMessages(serverMessages);
      }

      // اگر این چت فعال است، seen/unread را با تأخیر کم و throttled همگام نگه دار.
      if (normalizedConversationId == _activeConversationId) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastSeenSync = _lastSeenSyncAtMs[normalizedConversationId] ?? 0;
        if (nowMs - lastSeenSync > 1200) {
          _lastSeenSyncAtMs[normalizedConversationId] = nowMs;
          unawaited(markMessagesAsSeen(normalizedConversationId));
        }
      }
    } catch (e) {
      logError('Sync messages error', error: e);
      // در صورت خطای شبکه، دیتای لوکال دست نخورده باقی می‌ماند (Offline First)
    } finally {
      _conversationSyncInFlight.remove(normalizedConversationId);
    }
  }

  Future<void> _syncConversations() async {
    if (_conversationsSyncInFlight) return;
    if (_latestRealtimeStatus == RealtimeSubscribeStatus.subscribed) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastConversationsCatchupAtMs <
          _fallbackConversationSyncInterval.inMilliseconds) {
        return;
      }
      _lastConversationsCatchupAtMs = nowMs;
    }
    _conversationsSyncInFlight = true;
    try {
      final response = await _supabase
          .from('conversations')
          .select(
              '*, conversation_participants!inner(*, profiles!user_id(username, avatar_url))')
          .order('updated_at', ascending: false)
          .limit(50);

      List<ConversationModel> conversations;
      try {
        conversations = await compute(
          _parseConversationsIsolate,
          {'data': response, 'userId': _currentUserId ?? ''},
        );
      } catch (e, stack) {
        logWarning(
          'Background parse failed in syncConversations, fallback to main isolate',
          error: e,
          stackTrace: stack,
        );
        conversations = _parseConversationsIsolate(
          {'data': response, 'userId': _currentUserId ?? ''},
        );
      }

      await _localDataSource.saveConversations(conversations);
    } catch (e) {
      logError('Sync conversations error', error: e);
    } finally {
      _conversationsSyncInFlight = false;
    }
  }

  Future<void> _persistConversationFlag({
    required String conversationId,
    required String fieldName,
    required bool value,
    bool preferParticipantTable = false,
  }) async {
    final userId = _currentUserId;
    final attempts = <Future<void> Function()>[];

    Future<void> updateConversationsTable() async {
      await _supabase
          .from('conversations')
          .update({fieldName: value}).eq('id', conversationId);
    }

    Future<void> updateParticipantsTable() async {
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is required for participant-level update');
      }
      await _supabase
          .from('conversation_participants')
          .update({fieldName: value})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    }

    if (preferParticipantTable) {
      attempts
        ..add(updateParticipantsTable)
        ..add(updateConversationsTable);
    } else {
      attempts
        ..add(updateConversationsTable)
        ..add(updateParticipantsTable);
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final attempt in attempts) {
      try {
        await attempt();
        return;
      } catch (e, stack) {
        lastError = e;
        lastStackTrace = stack;
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw Exception('Failed to persist conversation flag: $fieldName');
  }

  Future<Set<String>> _getHiddenIds({
    required String userId,
    required String conversationId,
  }) async {
    if (userId.trim().isEmpty) return <String>{};
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastFetchedAtMs = _hiddenIdsCacheAtMs[conversationId] ?? 0;
    final cached = _hiddenIdsCache[conversationId];
    if (cached != null &&
        nowMs - lastFetchedAtMs <= _hiddenIdsCacheTtl.inMilliseconds) {
      return cached;
    }

    try {
      final hiddenResponse = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId);
      final hiddenIds = (hiddenResponse as List)
          .map((e) => e['message_id'] as String)
          .toSet();
      _hiddenIdsCache[conversationId] = hiddenIds;
      _hiddenIdsCacheAtMs[conversationId] = nowMs;
      return hiddenIds;
    } catch (e) {
      logWarning(
        'hidden_messages lookup failed; continuing sync without hidden filter',
        error: e,
      );
      return cached ?? <String>{};
    }
  }

  Future<Set<String>> _getTombstoneIds(String conversationId) async {
    try {
      final isar = await _dbManager.instance;
      final rows = await isar.deletionTaskEntitys
          .filter()
          .conversationIdEqualTo(conversationId)
          .findAll();
      return rows.map((e) => e.messageId).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<bool> _isMessageTombstoned({
    required String conversationId,
    required String messageId,
  }) async {
    final ids = await _getTombstoneIds(conversationId);
    return ids.contains(messageId);
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
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

    ConversationModel? backupConversation;
    List<MessageModel> backupMessages = const [];

    try {
      backupConversation =
          await _localDataSource.getConversation(conversationId, userId);
      backupMessages =
          await _localDataSource.watchMessages(conversationId, userId).first;

      // 1️⃣ حذف optimistic لوکال
      await _localDataSource.deleteConversation(conversationId);
      await _localDataSource.clearMessages(conversationId);
      _hiddenIdsCache.remove(conversationId);
      _hiddenIdsCacheAtMs.remove(conversationId);
      _lastConversationCatchupAtMs.remove(conversationId);
      _lastRealtimeHealthSyncAtMs.remove(conversationId);
      _lastMessageSyncCursor.remove(conversationId);
      _lastFullMessageSyncAtMs.remove(conversationId);
      _lastSeenSyncAtMs.remove(conversationId);

      // 2️⃣ سپس حذف سمت سرور (blocking برای اطمینان از صحت عملیات)
      await _supabase.from('conversations').delete().eq('id', conversationId);

      return ChatResult.success(null);
    } catch (e, stack) {
      // 3️⃣ rollback در صورت خطا برای جلوگیری از وضعیت ناسازگار
      try {
        if (backupConversation != null) {
          await _localDataSource.saveConversation(backupConversation);
        }
        if (backupMessages.isNotEmpty) {
          await _localDataSource.saveMessages(backupMessages);
        }
      } catch (rollbackError, rollbackStack) {
        logError(
          'Failed to rollback deleteConversation',
          error: rollbackError,
          stackTrace: rollbackStack,
        );
      }

      logError(
        'deleteConversation failed',
        error: e,
        stackTrace: stack,
      );
      return ChatResult.failure(
        'حذف گفتگو انجام نشد. لطفاً اتصال اینترنت را بررسی و دوباره تلاش کنید.',
      );
    }
  }

  @override
  Future<ChatResult<void>> toggleArchiveConversation(
      String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');
    try {
      final localConversation =
          await _localDataSource.getConversation(conversationId, userId);
      if (localConversation == null) {
        return ChatResult.failure('گفتگو یافت نشد');
      }

      final archivedValue = !localConversation.isArchived;
      final optimistic = localConversation.copyWith(isArchived: archivedValue);
      await _localDataSource.saveConversation(optimistic);

      try {
        await _persistConversationFlag(
          conversationId: conversationId,
          fieldName: 'is_archived',
          value: archivedValue,
          preferParticipantTable: true,
        );
      } catch (e, stack) {
        await _localDataSource.saveConversation(localConversation);
        logError(
          'toggleArchiveConversation remote sync failed',
          error: e,
          stackTrace: stack,
        );
        return ChatResult.failure('بایگانی گفتگو انجام نشد');
      }

      unawaited(_syncConversations());
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> togglePinConversation(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');
    try {
      final localConversation =
          await _localDataSource.getConversation(conversationId, userId);
      if (localConversation == null) {
        return ChatResult.failure('گفتگو یافت نشد');
      }

      final pinnedValue = !localConversation.isPinned;
      final optimistic = localConversation.copyWith(isPinned: pinnedValue);
      await _localDataSource.saveConversation(optimistic);

      try {
        await _persistConversationFlag(
          conversationId: conversationId,
          fieldName: 'is_pinned',
          value: pinnedValue,
          preferParticipantTable: true,
        );
      } catch (e, stack) {
        await _localDataSource.saveConversation(localConversation);
        logError(
          'togglePinConversation remote sync failed',
          error: e,
          stackTrace: stack,
        );
        return ChatResult.failure('سنجاق گفتگو انجام نشد');
      }

      unawaited(_syncConversations());
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> toggleMuteConversation(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return ChatResult.failure('کاربر وارد نشده است');
    try {
      final localConversation =
          await _localDataSource.getConversation(conversationId, userId);
      if (localConversation == null) {
        return ChatResult.failure('گفتگو یافت نشد');
      }

      final mutedValue = !localConversation.isMuted;
      final optimistic = localConversation.copyWith(isMuted: mutedValue);
      await _localDataSource.saveConversation(optimistic);

      try {
        await _persistConversationFlag(
          conversationId: conversationId,
          fieldName: 'is_muted',
          value: mutedValue,
          preferParticipantTable: true,
        );
      } catch (e, stack) {
        await _localDataSource.saveConversation(localConversation);
        logError(
          'toggleMuteConversation remote sync failed',
          error: e,
          stackTrace: stack,
        );
        return ChatResult.failure('بی‌صدا کردن گفتگو انجام نشد');
      }

      unawaited(_syncConversations());
      return ChatResult.success(null);
    } catch (e) {
      return ChatResult.failure(e.toString());
    }
  }

  @override
  Future<ChatResult<void>> clearConversation(String conversationId,
      {bool forEveryone = false}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return ChatResult.failure('کاربر وارد نشده است');

      // ✅ 1. ابتدا پاکسازی فوری لوکال (Sembast) - UI فوراً خالی می‌شود
      await _localDataSource.clearMessages(conversationId);
      _hiddenIdsCache.remove(conversationId);
      _hiddenIdsCacheAtMs.remove(conversationId);
      _lastConversationCatchupAtMs.remove(conversationId);
      _lastRealtimeHealthSyncAtMs.remove(conversationId);
      _lastMessageSyncCursor.remove(conversationId);
      _lastFullMessageSyncAtMs.remove(conversationId);
      _lastSeenSyncAtMs.remove(conversationId);

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
            logWarning('Direct delete attempted (may already be cleared)',
                error: e);
          }
        } catch (e) {
          logWarning(
              'Server clear error (non-fatal), but local cleanup completed',
              error: e);
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
      final localMessage = await _localDataSource.getMessage(messageId, userId);
      final localConversationId = localMessage?.conversationId;

      // 1. دریافت conversationId برای پاکسازی کش (اگر نیاز بود)
      // در حال حاضر با حذف UnifiedMessageCacheService نیازی به conversationId نیست
      // مگر اینکه برای لاگ یا منطق دیگری بخواهیم.

      // 2. ارسال به سرور (سرور خودش S3 و DB را مدیریت می‌کند)
      if (forEveryone) {
        try {
          await _supabase.from('messages').delete().eq('id', messageId);
        } catch (_) {
          logInfo('Fallback to node service for deletion');
          await VistaNodeService.deleteMessage(messageId);
        }
        logInfo('Server deletion successful');
      } else {
        // حذف یک‌طرفه: فقط در hidden_messages ذخیره کن
        await _supabase.from('hidden_messages').upsert({
          'message_id': messageId,
          'user_id': userId,
          'hidden_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (localConversationId != null && localConversationId.isNotEmpty) {
          final cached = _hiddenIdsCache[localConversationId];
          if (cached != null) {
            cached.add(messageId);
            _hiddenIdsCacheAtMs[localConversationId] =
                DateTime.now().millisecondsSinceEpoch;
          }
        }
        logInfo('Message hidden for user');
      }

      // 3. پاکسازی کش لوکال
      logDebug('Cleaning up local cache');
      await _localDataSource.deleteMessage(messageId);

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
          .select(_messageSelectWithProfiles)
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
          .select(_messageSelectWithProfiles)
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
      final userId = _currentUserId ?? '';
      final response = await _supabase
          .from('messages')
          .select(_messageSelectWithProfiles)
          .eq('conversation_id', conversationId)
          .lt('created_at', oldestMessageDate.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final hiddenIds = await _getHiddenIds(
        userId: userId,
        conversationId: conversationId,
      );
      final tombstoneIds = await _getTombstoneIds(conversationId);
      final blockedIds = {...hiddenIds, ...tombstoneIds};

      final filteredData = (response as List)
          .where((json) => !blockedIds.contains(json['id'] as String))
          .toList();

      final messages = await compute(
          _parseMessagesIsolate, {'data': filteredData, 'userId': userId});
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

      if (await _isMessageTombstoned(
        conversationId: conversationId,
        messageId: message.id,
      )) {
        return;
      }

      // 3. ذخیره در لوکال دیتابیس (Isar)
      await _localDataSource.saveMessage(message);

      // 4. آپدیت UI (حذف شده - Unified Cache)
      // await UnifiedMessageCacheService().cacheMessage(message);

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

      _scheduleRealtimeCatchup(conversationId);
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
    try {
      await _syncConversations();
      final conversations = await _localDataSource.getConversations();
      for (final conversation in conversations) {
        await _syncMessages(conversation.id);
      }
    } catch (e) {
      logError('Failed to sync pending messages', error: e);
    }
  }

  @override
  void dispose() {
    // no-op for now
  }

  @override
  Future<void> clearConversationCache(String conversationId) async {
    try {
      await _localDataSource.clearMessages(conversationId);
      await _localDataSource.deleteConversation(conversationId);
      _hiddenIdsCache.remove(conversationId);
      _hiddenIdsCacheAtMs.remove(conversationId);
      _lastConversationCatchupAtMs.remove(conversationId);
      _lastRealtimeHealthSyncAtMs.remove(conversationId);
      _lastMessageSyncCursor.remove(conversationId);
      _lastFullMessageSyncAtMs.remove(conversationId);
      _lastSeenSyncAtMs.remove(conversationId);
    } catch (e) {
      logError('Failed to clear conversation cache', error: e);
    }
  }

  @override
  Future<void> clearAllCache() async {
    try {
      await _localDataSource.clearAllData();
      _hiddenIdsCache.clear();
      _hiddenIdsCacheAtMs.clear();
    } catch (e) {
      logError('Failed to clear all chat cache', error: e);
    }
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
    final parsed = <ConversationModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        parsed.add(
          ConversationModel.fromJson(
            Map<String, dynamic>.from(item),
            currentUserId: userId,
          ),
        );
      } catch (_) {
        // Skip malformed rows instead of failing the whole batch.
      }
    }
    return parsed;
  }

  static List<MessageModel> _parseMessagesIsolate(Map<String, dynamic> params) {
    final list = params['data'] as List;
    final userId = params['userId'] as String;
    final parsed = <MessageModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        parsed.add(
          MessageModel.fromJson(
            Map<String, dynamic>.from(item),
            currentUserId: userId,
          ),
        );
      } catch (_) {
        // Skip malformed rows instead of failing the whole batch.
      }
    }
    return parsed;
  }
}
