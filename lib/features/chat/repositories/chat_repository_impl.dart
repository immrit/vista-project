// lib/features/chat/repositories/chat_repository_impl.dart
//
// âœ… Ù¾ÛŒØ§Ø¯Ù‡â€ŒØ³Ø§Ø²ÛŒ Ú©Ø§Ù…Ù„ Ø¨Ø§ Go backend
// Go backend implementation with no external realtime dependency.
// âœ… SSE Ø¨Ø±Ø§ÛŒ real-time (Ø§Ø² SseManager singleton)
// âœ… Isar Ø¨Ø±Ø§ÛŒ local cache / offline-first
//

import 'dart:async';
import 'package:isar/isar.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../../../../utils/env_config.dart';
import 'package:uuid/uuid.dart';

import '../../../model/conversation_model.dart';
import '../../../model/message_model.dart';
import '../../../../security/logging_utility.dart';
import '../../../DB/isar_database_manager.dart';
import '../../../DB/entities/deletion_task_entity.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../services/orphaned_media_cleanup_service.dart';
import '../../../services/session_manager_service_v2.dart';
import '../../../services/system_status_service.dart';
import '../../../services/http_client_factory.dart';
import '../data/datasources/chat_local_datasource_isar.dart';
import '../domain/message_payload.dart';
import '../services/sse_manager.dart';
import '../services/user_moderation_service.dart';
import '../services/message_tombstone_service.dart';
import 'chat_repository.dart';
import '../../../../security/e2ee_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSourceIsar _local;
  final UserModerationService _moderation = UserModerationService();
  final IsarDatabaseManager _dbManager = IsarDatabaseManager();
  late final Dio _dio;

  String? _activeConversationId;
  Timer? _heartbeatTimer;

  // â”€â”€ throttle maps (Ø¨Ø±Ø§ÛŒ Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² sync Ø¨ÛŒØ´ Ø§Ø² Ø­Ø¯) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final Map<String, int> _lastMsgSyncMs = {};
  final Map<String, bool> _msgSyncInFlight = {};
  int _lastConvSyncMs = 0;
  bool _convSyncInFlight = false;
  int _convRateLimitedUntilMs = 0;

  static const Duration _msgSyncThrottle = Duration(milliseconds: 800);
  static const Duration _convSyncThrottle = Duration(seconds: 2);
  static const int _msgPageSize = 50;

  static String get _base => EnvConfig.apiBaseUrl;

  ChatRepositoryImpl({required ChatLocalDataSourceIsar localDataSource})
      : _local = localDataSource {
    _dio = createApiV1Dio(baseUrl: _base);

    // âœ… SSE singleton Ø´Ø±ÙˆØ¹ Ù…ÛŒØ´Ù‡ â€” Ù‡Ù…Ù‡ provider Ù‡Ø§ Ø§Ø² ÛŒÙ‡ Ú©Ø§Ù†Ú©Ø´Ù† Ø§Ø³ØªÙØ§Ø¯Ù‡ Ù…ÛŒâ€ŒÚ©Ù†Ù†
    SseManager.instance.start();
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ” AUTH HELPERS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<Options?> _authOptions() async {
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    if (!sessionReady) return null;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<String?> _userId() async {
    final cached = await TokenStorage.getUserId();
    if (cached != null && cached.isNotEmpty) return cached;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final raw =
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final map = json.decode(raw) as Map<String, dynamic>;
        final sub = map['sub']?.toString();
        if (sub != null && sub.isNotEmpty) {
          await TokenStorage.saveUserId(sub);
          return sub;
        }
      }
    } catch (e) {
      logWarning('JWT parse failed', error: e);
    }
    return null;
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ“‚ CONVERSATIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<ChatResult<List<ConversationModel>>> getConversations() async {
    final uid = await _userId();
    if (uid == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    // â”€â”€ 1. local-first: Ø§Ú¯Ù‡ Ú©Ø´ Ø¯Ø§Ø±ÛŒÙ… ÙÙˆØ±Ø§Ù‹ Ø¨Ø±Ú¯Ø±Ø¯ÙˆÙ† Ùˆ Ø¯Ø± Ù¾Ø³â€ŒØ²Ù…ÛŒÙ†Ù‡ sync Ú©Ù†
    final local = await _local.getConversations();
    if (local.isNotEmpty) {
      unawaited(_syncConversations(uid));
      return ChatResult.success(local);
    }

    // â”€â”€ 2. Ø§Ú¯Ù‡ Ú©Ø´ Ø®Ø§Ù„ÛŒÙ‡ØŒ Ø§Ø² Ø³Ø±ÙˆØ± Ø¨Ú¯ÛŒØ±
    return _fetchConversationsFromServer(uid);
  }

  @override
  Stream<List<ConversationModel>> watchConversations() async* {
    final uid = await _userId();
    if (uid == null) {
      yield const [];
      return;
    }

    // â”€â”€ emit Ú©Ø´ ÙÙˆØ±ÛŒ
    final local = await _local.getConversations();
    yield local;
    unawaited(_syncConversations(uid));

    // â”€â”€ Isar stream (Ø¨Ø±Ø§ÛŒ ØªØºÛŒÛŒØ±Ø§Øª local)
    final isarStream = _local.watchConversations(uid);

    // â”€â”€ SSE events (Ø¨Ø±Ø§ÛŒ ØªØºÛŒÛŒØ±Ø§Øª remote)
    StreamSubscription? sseSub;
    final controller = StreamController<List<ConversationModel>>.broadcast();

    sseSub = SseManager.instance.events.listen((event) async {
      final type = event['type'] as String?;
      
      if (type == 'message_deleted') {
        final data = event['data'] as Map<String, dynamic>?;
        final msgId = data?['message_id']?.toString();
        final conversationId = data?['conversation_id']?.toString();
        if (msgId != null && conversationId != null) {
          unawaited(_local.deleteMessage(msgId));
          unawaited(MessageTombstoneService()
              .markDeletedRemotely(msgId, conversationId));
        }
      }
      
      if (type == 'new_message' ||
          type == 'conversation_updated' ||
          type == 'conversation_cleared') {
        unawaited(_syncConversations(uid));
      }
    });

    yield* isarStream.transform(
      StreamTransformer.fromHandlers(
        handleDone: (_) {
          sseSub?.cancel();
          controller.close();
        },
        handleError: (e, st, sink) {
          sseSub?.cancel();
          sink.addError(e, st);
        },
        handleData: (data, sink) => sink.add(data),
      ),
    );
  }

  @override
  Future<ChatResult<ConversationModel>> createConversation(String otherUserId,
      {bool isSecret = false}) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.chat,
        forceRefresh: true,
      );
    } on FeatureDisabledException catch (e) {
      return ChatResult.failure(e.message);
    } on MaintenanceModeException catch (e) {
      return ChatResult.failure(e.toString());
    }

    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      final res = await _dio.post(
        '/chat/conversations',
        data: {
          'peer_id': otherUserId,
          if (isSecret) 'is_secret': true,
        },
        options: opts,
      );
      final conv = _convFromGo(_asMap(res.data), uid);
      await _local.saveConversation(conv);
      return ChatResult.success(conv);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<void>> deleteConversation(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    // optimistic local delete
    await _local.deleteConversation(conversationId);
    await _local.clearMessages(conversationId);

    try {
      await _dio.delete('/chat/conversations/$conversationId', options: opts);
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<void>> toggleArchiveConversation(String conversationId) =>
      _toggleFlag(conversationId, 'archive');

  @override
  Future<ChatResult<void>> togglePinConversation(String conversationId) =>
      _toggleFlag(conversationId, 'pin');

  @override
  Future<ChatResult<void>> toggleMuteConversation(String conversationId) =>
      _toggleFlag(conversationId, 'mute');

  @override
  Future<ChatResult<void>> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  }) async {
    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    final endpointAttempts = <({String path, bool withBody})>[
      (
        path: '/chat/conversations/$conversationId/message-request/respond',
        withBody: true
      ),
      (
        path: '/chat/conversations/$conversationId/request/respond',
        withBody: true
      ),
      (
        path: '/chat/conversations/$conversationId/requests/respond',
        withBody: true
      ),
      (
        path:
            '/chat/conversations/$conversationId/${accept ? 'accept-request' : 'decline-request'}',
        withBody: false
      ),
      (
        path:
            '/chat/conversations/$conversationId/${accept ? 'accept' : 'decline'}',
        withBody: false
      ),
    ];

    DioException? lastDioError;
    for (final attempt in endpointAttempts) {
      try {
        await _dio.post(
          attempt.path,
          data: attempt.withBody ? {'accept': accept} : null,
          options: opts,
        );
        await _syncConversations(uid);
        return ChatResult.success(null);
      } on DioException catch (e) {
        lastDioError = e;
        final status = e.response?.statusCode;
        if (status == 404 || status == 405) {
          continue;
        }
        return ChatResult.failure(_dioError(e));
      }
    }

    if (lastDioError != null) {
      return ChatResult.failure(_dioError(lastDioError));
    }
    return ChatResult.failure('پاسخ به درخواست پیام انجام نشد');
  }

  @override
  Future<ChatResult<void>> clearConversation(
    String conversationId, {
    bool forEveryone = false,
  }) async {
    await _local.clearMessages(conversationId);

    final opts = await _authOptions();
    if (opts == null) return ChatResult.success(null);

    try {
      await _dio.post(
        '/chat/conversations/$conversationId/clear',
        data: {'for_everyone': forEveryone},
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ’¬ MESSAGES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<ChatResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  }) async {
    final uid = await _userId();
    if (uid == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    // local-first
    unawaited(_syncMessages(conversationId, uid));
    final msgs = await _local.watchMessages(conversationId, uid).first;
    return ChatResult.success(msgs.take(limit).toList());
  }

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId,
      {int? limit}) async* {
    final uid = await _userId();
    if (uid == null) {
      yield const [];
      return;
    }

    unawaited(_syncMessages(conversationId, uid));

    // SSE: ÙˆÙ‚ØªÛŒ event Ù…Ø±Ø¨ÙˆØ· Ø¨Ù‡ Ø§ÛŒÙ† conversation Ù…ÛŒØ§Ø¯ØŒ sync Ú©Ù†
    StreamSubscription? sseSub;
    sseSub = SseManager.instance.events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'new_message' ||
          type == 'message_updated' ||
          type == 'read_receipt') {
        final data = event['data'] as Map<String, dynamic>?;
        final convId = data?['conversation_id']?.toString();
        if (convId == conversationId) {
          if (type == 'read_receipt') {
            final readerId = data?['user_id']?.toString() ?? '';
            final readAtRaw = data?['read_at']?.toString() ?? '';
            final readAt = DateTime.tryParse(readAtRaw);
            if (readerId.isNotEmpty && readerId != uid && readAt != null) {
              unawaited(
                _local.markOwnMessagesReadUpTo(conversationId, readAt),
              );
            }
          }
          unawaited(_syncMessages(conversationId, uid));
        }
      } else if (type == 'conversation_cleared') {
        final data = event['data'] as Map<String, dynamic>?;
        final convId = data?['conversation_id']?.toString();
        if (convId == conversationId) {
          unawaited(_local.clearMessages(conversationId));
          unawaited(_syncMessages(conversationId, uid));
        }
      }
    });

    try {
      yield* _local.watchMessages(conversationId, uid, limit: limit).transform(
            StreamTransformer.fromHandlers(
              handleDone: (sink) {
                sseSub?.cancel();
                sink.close();
              },
              handleError: (e, st, sink) {
                sseSub?.cancel();
                sink.addError(e, st);
              },
              handleData: (data, sink) => sink.add(data),
            ),
          );
    } finally {
      // Cancel on consumer cancel (dispose) too. handleDone/handleError only
      // fire on completion/error, so without this the SSE subscription leaked
      // every time a chat screen closed.
      await sseSub.cancel();
    }
  }

  @override
  Future<ChatResult<MessageModel>> sendMessage(MessagePayload payload) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.chat,
        forceRefresh: false,
      );
    } on FeatureDisabledException catch (e) {
      return ChatResult.failure(e.message);
    } on MaintenanceModeException catch (e) {
      return ChatResult.failure(e.toString());
    }

    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    final messageId = payload.id ?? const Uuid().v4();
    final now = DateTime.now();

    final storyReplyData = StoryReplyData.parseFromReplyFields(
      replyToMessageId: payload.replyToMessageId,
      replyToContent: payload.replyToContent,
      replyToSenderName: payload.replyToSenderName,
    );
    final isStoryReplyMessage = storyReplyData != null;

    // â”€â”€ optimistic local save â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final optimistic = MessageModel(
      id: messageId,
      conversationId: payload.conversationId,
      senderId: uid,
      content: payload.content,
      createdAt: now,
      isMe: true,
      isPending: true,
      isSent: false,
      attachmentUrl: payload.attachmentUrl,
      attachmentType: payload.attachmentType,
      attachmentFileName: payload.attachmentFileName,
      attachmentMimeType: payload.attachmentMimeType,
      attachmentSizeBytes: payload.attachmentSizeBytes,
      audioTitle: payload.audioTitle,
      audioArtist: payload.audioArtist,
      audioAlbum: payload.audioAlbum,
      mediaGroupId: payload.mediaGroupId,
      duration: payload.duration,
      replyToMessageId: payload.replyToMessageId,
      replyToContent: payload.replyToContent,
      replyToSenderName: payload.replyToSenderName,
      messageType: isStoryReplyMessage ? 'storyReply' : null,
      storyReplyData: storyReplyData,
    );
    await _local.saveMessage(optimistic);

    // â”€â”€ Ø§Ø±Ø³Ø§Ù„ Ø¨Ù‡ Go backend â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    try {
      final res = await _dio.post(
        '/chat/conversations/${payload.conversationId}/messages',
        data: {
          'id': messageId,
          'content': await _encryptContent(
              payload.content, payload.recipientPublicKey),
          'message_type': payload.attachmentType ?? 'text',
          if (payload.attachmentUrl != null) 'media_url': payload.attachmentUrl,
          if (payload.attachmentFileName != null)
            'attachment_file_name': payload.attachmentFileName,
          if (payload.attachmentMimeType != null)
            'attachment_mime_type': payload.attachmentMimeType,
          if (payload.attachmentSizeBytes != null)
            'attachment_size_bytes': payload.attachmentSizeBytes,
          if (payload.audioTitle != null) 'audio_title': payload.audioTitle,
          if (payload.audioArtist != null) 'audio_artist': payload.audioArtist,
          if (payload.audioAlbum != null) 'audio_album': payload.audioAlbum,
          if (payload.mediaGroupId != null)
            'media_group_id': payload.mediaGroupId,
          if (payload.duration != null) 'duration': payload.duration,
          if (payload.replyToMessageId != null)
            'reply_to_message_id': payload.replyToMessageId,
          if (payload.replyToContent != null)
            'reply_to_content': payload.replyToContent,
          if (payload.replyToSenderName != null)
            'reply_to_sender_name': payload.replyToSenderName,
          if (payload.replyToKind != null) 'reply_to_kind': payload.replyToKind,
        },
        options: opts,
      );

      final serverMsg = _msgFromGo(_asMap(res.data), uid);
      final merged = _mergeLocal(serverMsg, optimistic);
      await _local.saveMessage(merged);
      return ChatResult.success(merged);
    } on DioException catch (e) {
      final failed = optimistic.copyWith(
        isPending: false,
        isFailed: true,
        errorMessage: _dioError(e),
      );
      await _local.saveMessage(failed);
      return ChatResult.failure(_dioError(e));
    }
  }

  Future<String> _encryptContent(
      String rawContent, String? recipientPublicKey) async {
    if (recipientPublicKey == null || recipientPublicKey.isEmpty) {
      return rawContent;
    }
    try {
      return await E2EEService().encryptMessage(rawContent, recipientPublicKey);
    } catch (e) {
      logWarning('E2EE Encryption failed: $e');
      return rawContent;
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
    final uid = await _userId();
    if (uid == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    final pending = MessageModel.temporary(
      tempId: localId,
      conversationId: conversationId,
      senderId: uid,
      content: content,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      attachmentMimeType: attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes,
      audioTitle: audioTitle,
      audioArtist: audioArtist,
      audioAlbum: audioAlbum,
      localFilePath: localFilePath,
      duration: duration,
      mediaGroupId: mediaGroupId,
      uploadProgress: 0.0,
      isUploading: true,
    );
    await _local.saveMessage(pending);
    return ChatResult.success(pending);
  }

  @override
  Future<ChatResult<void>> updateUploadProgress(
      String localId, double progress) async {
    await _local.updateUploadProgress(localId, progress);
    return ChatResult.success(null);
  }

  @override
  Future<ChatResult<void>> markUploadSucceeded(
      String localId, MessageModel serverMessage) async {
    final uid = await _userId();
    final local = uid == null ? null : await _local.getMessage(localId, uid);
    if (localId != serverMessage.id) {
      await _local.deleteMessage(localId);
    }
    await _local.saveMessage(
      _mergeLocal(serverMessage, local).copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        isPending: false,
        isFailed: false,
      ),
    );
    return ChatResult.success(null);
  }

  @override
  Future<ChatResult<void>> markUploadFailed(
    String localId, {
    String? errorMessage,
  }) async {
    await _local.markUploadFailed(localId, errorMessage: errorMessage);
    return ChatResult.success(null);
  }

  @override
  Future<ChatResult<void>> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  }) async {
    final uid = await _userId();
    final existing =
        uid == null ? null : await _local.getMessage(messageId, uid);

    // optimistic local
    await _local.deleteMessage(messageId);
    unawaited(_queueDeletedMessageMediaCleanup(
      existing,
      deleteForEveryone: forEveryone,
    ));

    final opts = await _authOptions();
    if (opts == null) return ChatResult.success(null);

    try {
      await _dio.delete(
        '/chat/messages/$messageId',
        queryParameters: {'for_everyone': forEveryone},
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  Future<void> _queueDeletedMessageMediaCleanup(
    MessageModel? message, {
    required bool deleteForEveryone,
  }) async {
    if (message == null) return;
    final isLocalOnly = message.isPending ||
        message.isUploading ||
        message.isFailed == true ||
        message.id.startsWith('temp_');
    if (!deleteForEveryone && !isLocalOnly) return;

    await OrphanedMediaCleanupService.enqueueUrls(
      [message.attachmentUrl, message.audioUrl],
      source: 'chat_repository_delete',
      reason: deleteForEveryone
          ? 'message_deleted_for_everyone'
          : 'local_failed_message_discarded',
      conversationId: message.conversationId,
    );
  }

  @override
  Future<ChatResult<void>> editMessage(
      String messageId, String newContent) async {
    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    // optimistic local update
    final existing = await _local.getMessage(messageId, uid);
    if (existing != null) {
      await _local.saveMessage(
        existing.copyWith(
          content: newContent,
          editedAt: DateTime.now(),
        ),
      );
    }

    try {
      await _dio.put(
        '/chat/messages/$messageId',
        data: {'content': newContent},
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      // rollback
      if (existing != null) await _local.saveMessage(existing);
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<List<MessageModel>>> searchMessages(
      String conversationId, String query) async {
    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    try {
      final res = await _dio.get(
        '/chat/conversations/$conversationId/search',
        queryParameters: {'q': query, 'limit': 50},
        options: opts,
      );
      final msgs = _asList(_asMap(res.data)['messages'])
          .whereType<Map>()
          .map((e) => _msgFromGo(e.cast<String, dynamic>(), uid))
          .toList();
      return ChatResult.success(msgs);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<List<MessageModel>>> loadMoreMessages({
    required String conversationId,
    required DateTime oldestMessageDate,
    int limit = 50,
  }) async {
    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    try {
      final res = await _dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'limit': limit,
          'before_time': oldestMessageDate.toUtc().toIso8601String(),
        },
        options: opts,
      );
      final msgs = _asList(_asMap(res.data)['messages'])
          .whereType<Map>()
          .map((e) => _msgFromGo(e.cast<String, dynamic>(), uid))
          .toList()
          .reversed
          .toList();
          
      if (msgs.isNotEmpty) {
        final sortedServer = List<MessageModel>.from(msgs)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        await _local.reconcileMessages(conversationId, msgs,
            endDate: sortedServer.last.createdAt);
      }
      return ChatResult.success(msgs);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<void>> acceptMessageRequest(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      await _dio.post(
        '/chat/conversations/$conversationId/accept',
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Future<ChatResult<void>> rejectMessageRequest(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      await _dio.post(
        '/chat/conversations/$conversationId/reject',
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 😀 REACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final opts = await _authOptions();
    if (opts == null) {
      return ChatResult.failure('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    try {
      await _dio.post(
        '/chat/messages/$messageId/reactions',
        data: {'emoji': emoji},
        options: opts,
      );
      return ChatResult.success(null);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  Stream<Map<String, List<String>>> watchReactions(String messageId) async* {
    // initial load
    final opts = await _authOptions();
    if (opts != null) {
      try {
        final res = await _dio.get(
          '/chat/messages/$messageId/reactions',
          options: opts,
        );
        yield _reactionMap(_asList(_asMap(res.data)['reactions']));
      } catch (_) {}
    }

    // SSE updates
    await for (final event in SseManager.instance.events) {
      if (event['type'] != 'reaction_updated') continue;
      final data = event['data'] as Map<String, dynamic>?;
      if (data?['message_id']?.toString() != messageId) continue;
      yield _reactionMap(_asList(data!['reactions']));
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // âŒ¨ï¸ TYPING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<void> sendTypingIndicator(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) return;
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/typing',
        options: opts,
      );
    } catch (_) {}
  }

  /// Go backend Ø¨Ø§ÛŒØ¯ Ø§ÛŒÙ† event Ø±Ùˆ Ø§Ø² SSE Ø¨ÙØ±Ø³ØªÙ‡:
  /// { "type": "typing", "data": { "conversation_id": "...", "user_id": "...", "is_typing": true } }
  @override
  Stream<bool> watchTypingStatus(String conversationId, String userId) {
    late StreamSubscription<Map<String, dynamic>> subscription;
    Timer? clearTimer;
    bool isTyping = false;

    late final StreamController<bool> controller;
    controller = StreamController<bool>.broadcast(
      onListen: () {
        subscription = SseManager.instance.events.listen((event) {
          if (event['type'] != 'typing') return;
          final data = event['data'] as Map<String, dynamic>?;
          if (data == null) return;
          if (data['conversation_id']?.toString() != conversationId) return;
          if (data['user_id']?.toString() != userId) return;

          final typing = data['is_typing'] as bool? ?? false;

          if (typing && !isTyping) {
            isTyping = true;
            controller.add(true);
            clearTimer?.cancel();
            clearTimer = Timer(const Duration(seconds: 4), () {
              if (!isTyping) return;
              isTyping = false;
              controller.add(false);
            });
          } else if (!typing && isTyping) {
            isTyping = false;
            clearTimer?.cancel();
            controller.add(false);
          }
        });
      },
      onCancel: () async {
        clearTimer?.cancel();
        await subscription.cancel();
      },
    );

    return controller.stream.distinct();
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // âœ‰ï¸ SEEN / UNREAD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<void> markMessagesAsSeen(String conversationId) async {
    await _local.markMessagesAsSeenLocally(conversationId);
    await resetUnreadCount(conversationId);
  }

  @override
  Future<void> resetUnreadCount(String conversationId) async {
    await _local.resetUnreadCount(conversationId);

    final opts = await _authOptions();
    if (opts == null) return;
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/read',
        options: opts,
      );
    } catch (_) {}
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ”” NOTIFICATIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<void> handleNotificationMessage(Map<String, dynamic> payload) async {
    final uid = await _userId();
    if (uid == null) return;

    final messageId =
        payload['id']?.toString() ?? payload['message_id']?.toString();
    final conversationId = payload['conversation_id']?.toString();
    final content =
        payload['content']?.toString() ?? payload['body']?.toString();
    final senderId = payload['sender_id']?.toString();

    if (conversationId == null || content == null || senderId == null) return;
    if (await _isTombstoned(conversationId, messageId ?? '')) return;

    final createdAt =
        DateTime.tryParse(payload['created_at']?.toString() ?? '') ??
            DateTime.now();

    final message = MessageModel(
      id: messageId ?? const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      isMe: senderId == uid,
      isSent: true,
      isPending: false,
      isDelivered: true,
      senderName: payload['sender_name']?.toString(),
      senderAvatar: payload['sender_avatar']?.toString(),
      attachmentUrl: payload['attachment_url']?.toString(),
      attachmentType: payload['attachment_type']?.toString(),
    );

    await _local.saveMessage(message);

    final conv = await _local.getConversation(conversationId, uid);
    if (conv != null) {
      final unread = conversationId == _activeConversationId
          ? 0
          : (senderId != uid ? conv.unreadCount + 1 : conv.unreadCount);
      await _local.saveConversation(conv.copyWith(
        lastMessage: content,
        updatedAt: createdAt,
        unreadCount: unread,
        hasUnreadMessages: unread > 0,
      ));
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸšª ACTIVE CONVERSATION / PRESENCE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  void setActiveConversation(String? conversationId) {
    final prev = _activeConversationId;
    if (prev == conversationId) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _activeConversationId = conversationId;

    if (prev != null) unawaited(_setPresence(prev, false));
    if (conversationId != null) {
      unawaited(_setPresence(conversationId, true));
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(_heartbeat(conversationId));
      });
      unawaited(resetUnreadCount(conversationId));
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸš« MODERATION
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<bool> isUserBlocked(String userId) =>
      _moderation.isUserBlocked(userId);

  @override
  Future<void> unblockUser(String userId) => _moderation.unblockUser(userId);

  @override
  Future<bool> isCurrentUserBlockedBy(String userId) =>
      _moderation.isCurrentUserBlocked(userId);

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ”„ SYNC (private)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _syncConversations(String uid) async {
    if (_convSyncInFlight) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < _convRateLimitedUntilMs) return;
    if (now - _lastConvSyncMs < _convSyncThrottle.inMilliseconds) return;
    _lastConvSyncMs = now;
    _convSyncInFlight = true;

    try {
      final result = await _fetchConversationsFromServer(uid);
      if (result.isSuccess) {
        await _local.saveConversations(result.data!);
      }
    } finally {
      _convSyncInFlight = false;
    }
  }

  Future<ChatResult<List<ConversationModel>>> _fetchConversationsFromServer(
      String uid) async {
    int retries = 0;
    while (retries < 2) {
      final opts = await _authOptions();
      if (opts == null) {
        return ChatResult.failure('کاربر وارد نشده است');
      }

      try {
        final res = await _dio.get(
          '/chat/conversations',
          queryParameters: {'limit': _msgPageSize},
          options: opts,
        );
        final convs = _asList(_asMap(res.data)['conversations'])
            .whereType<Map>()
            .map((e) => _convFromGo(e.cast<String, dynamic>(), uid))
            .toList();
        return ChatResult.success(convs);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 && retries == 0) {
          logInfo(
              '⚠️ 401 in _fetchConversationsFromServer. Refreshing token...');
          final refreshed = await SessionManagerServiceV2.instance
              .performSessionRefreshPublic();
          if (refreshed == RefreshResult.success) {
            retries++;
            continue;
          }
        }
        if (e.response?.statusCode == 429) {
          final retryAfter =
              _retryAfterSeconds(e.response?.headers.value('retry-after'));
          _convRateLimitedUntilMs = DateTime.now()
              .add(Duration(seconds: retryAfter))
              .millisecondsSinceEpoch;
          logInfo(
              '⚠️ Conversations rate-limited (429). Cooling down for ${retryAfter}s');
        }
        logInfo(
            '⚠️ DioException in _fetchConversationsFromServer: ${e.type} - ${e.message} - ${e.response?.statusCode}');
        return ChatResult.failure(_dioError(e));
      } catch (e) {
        logInfo('⚠️ Exception in _fetchConversationsFromServer: $e');
        return ChatResult.failure(e.toString());
      }
    }
    return ChatResult.failure('خطا در بارگزاری لیست مکالمات');
  }

  Future<void> _syncMessages(String conversationId, String uid) async {
    if (_msgSyncInFlight[conversationId] == true) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMsgSyncMs[conversationId] ?? 0) <
        _msgSyncThrottle.inMilliseconds) {
      return;
    }
    _lastMsgSyncMs[conversationId] = now;
    _msgSyncInFlight[conversationId] = true;

    try {
      final opts = await _authOptions();
      if (opts == null) return;

      final res = await _dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {'limit': _msgPageSize},
        options: opts,
      );

      final tombstones = await _getTombstones(conversationId);
      final msgs = _asList(_asMap(res.data)['messages'])
          .whereType<Map>()
          .map((e) => _msgFromGo(e.cast<String, dynamic>(), uid))
          .where((m) => !tombstones.contains(m.id))
          .toList()
          .reversed
          .toList();

      await _local.reconcileMessages(conversationId, msgs);

      // mark seen Ø§Ú¯Ù‡ Ø§ÛŒÙ† conversation ÙØ¹Ø§Ù„Ù‡
      if (conversationId == _activeConversationId) {
        unawaited(markMessagesAsSeen(conversationId));
      }
    } on DioException catch (e) {
      logWarning(
          '_syncMessages DioException: ${e.response?.statusCode} - ${e.response?.data}');
    } catch (e) {
      logWarning('_syncMessages error: $e');
    } finally {
      _msgSyncInFlight.remove(conversationId);
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ” REFRESH / SYNC (public)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Future<void> refreshConversations() async {
    final uid = await _userId();
    if (uid != null) await _syncConversations(uid);
  }

  @override
  Future<void> refreshMessages(String conversationId) async {
    final uid = await _userId();
    if (uid != null) await _syncMessages(conversationId, uid);
  }

  @override
  Future<void> syncPendingMessages() async {
    final uid = await _userId();
    if (uid == null) return;
    final convs = await _local.getConversations();
    for (final c in convs) {
      await _syncMessages(c.id, uid);
    }
  }

  @override
  Future<void> cacheConversationProfile({
    required String conversationId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
  }) {
    return _local.updateConversationProfile(
      conversationId: conversationId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ§¹ CLEANUP
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    if (_activeConversationId != null) {
      unawaited(_setPresence(_activeConversationId!, false));
    }
    // SseManager singleton Ø±Ùˆ dispose Ù†Ú©Ù† â€” Ø¨Ø±Ø§ÛŒ Ù‡Ù…Ù‡ Ø¨Ø±Ù†Ø§Ù…Ù‡ Ø²Ù†Ø¯Ù‡â€ŒØ³Øª
  }

  @override
  Future<void> clearAllCache() => _local.clearAllData();

  @override
  Future<void> clearConversationCache(String conversationId) async {
    await _local.clearMessages(conversationId);
    await _local.deleteConversation(conversationId);
    _msgSyncInFlight.remove(conversationId);
    _lastMsgSyncMs.remove(conversationId);
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ“¡ REAL-TIME STATUS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Stream<SseConnectionState> get realtimeStatus =>
      SseManager.instance.connectionState;

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ðŸ”§ PRIVATE HELPERS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Future<void> _setPresence(String conversationId, bool active) async {
    final opts = await _authOptions();
    if (opts == null) return;
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/active',
        data: {'active': active},
        options: opts,
      );
    } catch (_) {}
  }

  Future<void> _heartbeat(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) return;
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/heartbeat',
        options: opts,
      );
    } catch (_) {}
  }

  Future<ChatResult<void>> _toggleFlag(
      String conversationId, String action) async {
    final uid = await _userId();
    final opts = await _authOptions();
    if (uid == null || opts == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    // Optimistic UI Update
    final currentConv = await _local.getConversation(conversationId, uid);
    if (currentConv != null) {
      ConversationModel updatedConv = currentConv;
      if (action == 'archive') {
        updatedConv = currentConv.copyWith(isArchived: !currentConv.isArchived);
      } else if (action == 'pin') {
        updatedConv = currentConv.copyWith(isPinned: !currentConv.isPinned);
      } else if (action == 'mute') {
        updatedConv = currentConv.copyWith(isMuted: !currentConv.isMuted);
      }
      await _local.saveConversation(updatedConv);
    }

    try {
      final res = await _dio.post(
        '/chat/conversations/$conversationId/$action',
        options: opts,
      );
      await _local.saveConversation(_convFromGo(_asMap(res.data), uid));
      return ChatResult.success(null);
    } on DioException catch (e) {
      // Revert Optimistic UI Update
      if (currentConv != null) {
        await _local.saveConversation(currentConv);
      }
      return ChatResult.failure(_dioError(e));
    }
  }

  Future<bool> _isTombstoned(String conversationId, String messageId) async {
    final ids = await _getTombstones(conversationId);
    return ids.contains(messageId);
  }

  Future<Set<String>> _getTombstones(String conversationId) async {
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

  Map<String, List<String>> _reactionMap(List<dynamic> raw) {
    final map = <String, List<String>>{};
    for (final item in raw.whereType<Map>()) {
      final m = item.cast<String, dynamic>();
      final emoji = m['emoji']?.toString() ?? '';
      final uid = m['user_id']?.toString() ?? '';
      if (emoji.isEmpty || uid.isEmpty) continue;
      map.putIfAbsent(emoji, () => []).add(uid);
    }
    return map;
  }

  MessageModel _mergeLocal(MessageModel server, MessageModel? local) {
    if (local == null) return server;

    final replyToMessageId = _preferNonEmpty(
      server.replyToMessageId,
      local.replyToMessageId,
    );
    final replyToContent = _preferStoryReplyContent(
      server.replyToContent,
      local.replyToContent,
    );
    final replyToSenderName = _preferNonEmpty(
      server.replyToSenderName,
      local.replyToSenderName,
    );

    StoryReplyData? storyReplyData =
        local.storyReplyData ?? server.storyReplyData;
    storyReplyData ??= StoryReplyData.parseFromReplyFields(
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );

    return server.copyWith(
      content:
          server.hasMediaPlaceholderContent && !local.hasMediaPlaceholderContent
              ? local.content
              : (server.hasMediaPlaceholderContent &&
                      (server.resolvedMediaUrl != null ||
                          local.resolvedMediaUrl != null))
                  ? ''
                  : server.content,
      attachmentUrl: _preferNonEmpty(server.attachmentUrl, local.attachmentUrl),
      audioUrl: _preferNonEmpty(server.audioUrl, local.audioUrl),
      attachmentType:
          _preferNonEmpty(server.attachmentType, local.attachmentType) ??
              local.messageType,
      attachmentFileName: server.attachmentFileName?.isNotEmpty == true
          ? server.attachmentFileName
          : local.attachmentFileName,
      attachmentMimeType: server.attachmentMimeType ?? local.attachmentMimeType,
      attachmentSizeBytes:
          server.attachmentSizeBytes ?? local.attachmentSizeBytes,
      audioTitle: server.audioTitle?.isNotEmpty == true
          ? server.audioTitle
          : local.audioTitle,
      audioArtist: server.audioArtist?.isNotEmpty == true
          ? server.audioArtist
          : local.audioArtist,
      audioAlbum: server.audioAlbum?.isNotEmpty == true
          ? server.audioAlbum
          : local.audioAlbum,
      mediaGroupId: server.mediaGroupId ?? local.mediaGroupId,
      duration: server.duration ?? local.duration,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      messageType: storyReplyData != null
          ? 'storyReply'
          : (_preferNonEmpty(server.messageType, local.messageType) ??
              local.messageType),
      storyReplyData: storyReplyData,
      localFilePath: local.localFilePath,
      localImagePath: local.localImagePath,
      isUploading: false,
      uploadProgress: 1.0,
      isPending: false,
      isFailed: false,
    );
  }

  String? _preferNonEmpty(String? primary, String? fallback) {
    final primaryValue = primary?.trim() ?? '';
    if (primaryValue.isNotEmpty) return primaryValue;
    final fallbackValue = fallback?.trim() ?? '';
    return fallbackValue.isNotEmpty ? fallbackValue : null;
  }

  String? _preferStoryReplyContent(String? server, String? local) {
    final serverValue = server?.trim() ?? '';
    final localValue = local?.trim() ?? '';
    if (localValue.startsWith('{') && !serverValue.startsWith('{')) {
      return localValue;
    }
    if (serverValue.startsWith('{')) return serverValue;
    if (localValue.length > serverValue.length) return localValue;
    if (serverValue.isNotEmpty) return serverValue;
    return localValue.isNotEmpty ? localValue : null;
  }

  ConversationModel _convFromGo(Map<String, dynamic> j, String uid) {
    final peerId = (j['peer_id'] ??
            j['peerId'] ??
            j['other_user_id'] ??
            j['otherUserId'] ??
            '')
        .toString();
    final isSecretFlag =
        (j['is_secret'] as bool?) ?? (j['isSecret'] as bool?) ?? false;
    final rawType = (j['conversation_type'] ?? j['type'] ?? 'private')
        .toString()
        .toLowerCase();
    final type = isSecretFlag
        ? 'secret'
        : (rawType == 'group'
            ? 'group'
            : (rawType == 'secret' ? 'secret' : 'private'));
    final createdAt = _firstNonEmpty(j['created_at'], j['createdAt']) ??
        DateTime.now().toIso8601String();
    final lastMessageText =
        _firstNonEmpty(j['last_message_text'], j['last_message']);
    final lastMessageAt =
        _firstNonEmpty(j['last_message_at'], j['last_message_time']);
    final lastMessageType =
        _firstNonEmpty(j['last_message_type'], j['message_type']);
    final hasLastMessage = (lastMessageText?.trim().isNotEmpty ?? false) ||
        (lastMessageType != null &&
            lastMessageType.trim().isNotEmpty &&
            lastMessageType.toLowerCase() != 'text');
    final updatedAt =
        _firstNonEmpty(j['updated_at'], j['updatedAt'], lastMessageAt) ??
            createdAt;
    final peerUsername =
        (j['peer_username'] ?? j['other_user_username'] ?? j['username'] ?? '')
            .toString();
    final peerFullName =
        (j['peer_full_name'] ?? j['other_user_full_name'] ?? '').toString();
    final peerAvatar = (j['peer_avatar_url'] ??
            j['other_user_avatar'] ??
            j['avatar_url'] ??
            j['image'])
        ?.toString();

    final conv = ConversationModel.fromJson({
      'id': j['id'],
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_message': hasLastMessage ? lastMessageText : null,
      'last_message_time': hasLastMessage ? lastMessageAt : null,
      'unread_count': j['unread_count'] ?? 0,
      'is_archived': j['is_archived'] ?? false,
      'is_pinned': j['is_pinned'] ?? false,
      'is_muted': j['is_muted'] ?? false,
      'type': type,
      'is_secret': isSecretFlag,
      'is_message_request':
          j['is_message_request'] ?? j['message_request'] ?? false,
      'message_request_status':
          j['message_request_status'] ?? j['request_status'],
      'last_message_type': hasLastMessage ? lastMessageType : null,
      'name': j['name'],
      'image': j['image'],
      'participants': [
        {
          'id': '${j['id']}_$uid',
          'conversation_id': j['id'],
          'user_id': uid,
          'created_at': createdAt,
          'unread_count': j['unread_count'] ?? 0,
        },
        if (peerId.isNotEmpty)
          {
            'id': '${j['id']}_$peerId',
            'conversation_id': j['id'],
            'user_id': peerId,
            'created_at': createdAt,
            'profiles': {},
          },
      ],
    }, currentUserId: uid);
    final immediateName = peerUsername.trim().isNotEmpty
        ? peerUsername.trim()
        : (peerFullName.trim().isNotEmpty ? peerFullName.trim() : '');
    return conv.copyWith(
      otherUserName:
          immediateName.isNotEmpty ? immediateName : conv.otherUserName,
      otherUserAvatar: (peerAvatar?.trim().isNotEmpty ?? false)
          ? peerAvatar?.trim()
          : conv.otherUserAvatar,
      otherUserId: conv.otherUserId?.isNotEmpty == true
          ? conv.otherUserId
          : peerId.trim(),
    );
  }

  MessageModel _msgFromGo(Map<String, dynamic> j, String uid) {
    return MessageModel.fromJson({
      'id': j['id'],
      'conversation_id': j['conversation_id'],
      'sender_id': j['sender_id'],
      'sender_name':
          _firstNonEmpty(j['sender_name'], j['sender_username'], j['username']),
      'sender_avatar': _firstNonEmpty(
          j['sender_avatar'], j['sender_avatar_url'], j['avatar_url']),
      'content': j['content'] ?? '',
      'created_at': j['created_at'] ?? DateTime.now().toIso8601String(),
      'attachment_url': j['media_url'] ?? j['attachment_url'],
      'audio_url': j['audio_url'],
      'message_type': j['message_type'] ?? j['attachment_type'],
      'attachment_type': j['message_type'] ?? j['attachment_type'],
      'attachment_file_name': j['attachment_file_name'],
      'attachment_mime_type': j['attachment_mime_type'],
      'attachment_size_bytes': j['attachment_size_bytes'],
      'audio_title': j['audio_title'],
      'audio_artist': j['audio_artist'],
      'audio_album': j['audio_album'],
      'media_group_id': j['media_group_id'],
      'duration': j['duration'],
      'reply_to_message_id': j['reply_to_message_id'],
      'reply_to_content': j['reply_to_content'],
      'reply_to_sender_name': j['reply_to_sender_name'],
      'reply_to_kind': j['reply_to_kind'],
      'is_forwarded': j['is_forwarded'] ?? false,
      'original_sender_id': j['original_sender_id'],
      'original_message_id': j['original_message_id'],
      'forwarded_from_sender_name': j['forwarded_from_sender_name'],
      'is_sent': j['is_sent'] ?? true,
      'is_delivered': j['is_delivered'] ?? false,
      'is_read': j['is_read'] ?? false,
      'is_seen': j['is_seen'] ?? false,
      'edited_at': j['edited_at'],
      'is_edited': j['edited_at'] != null || (j['is_edited'] ?? false),
    }, currentUserId: uid);
  }

  Map<String, dynamic> _asMap(dynamic d) {
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.cast<String, dynamic>();
    return {};
  }

  List<dynamic> _asList(dynamic d) => d is List ? d : [];

  String? _firstNonEmpty(Object? first, [Object? second, Object? third]) {
    for (final value in [first, second, third]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String _dioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    logError(
        'DioException: status=$status, data=$data, url=${e.requestOptions.path}');

    if (status == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'زمان پاسخ‌دهی سرور به پایان رسید. دوباره تلاش کنید.';
        case DioExceptionType.connectionError:
          return 'ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کنید.';
        default:
          return 'ارتباط با سرور برقرار نشد.';
      }
    }

    if (status == 500) {
      logError('Server Error 500: $data');
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      return 'خطای داخلی سرور رخ داد. $data';
    }

    if (status == 400) {
      logError('Bad Request 400: $data');
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    }

    if (status == 429) {
      return 'تعداد درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.';
    }
    if (status == 403) return 'این کاربر دریافت پیام را محدود کرده است';
    if (status == 404) return 'آیتم مورد نظر یافت نشد';
    if (status == 401) return 'لطفاً دوباره وارد شوید';
    return e.message ?? 'خطا در ارتباط با سرور';
  }

  int _retryAfterSeconds(String? retryAfterHeader) {
    final parsed = int.tryParse(retryAfterHeader ?? '');
    if (parsed == null || parsed <= 0) return 60;
    return parsed.clamp(10, 180);
  }
}
