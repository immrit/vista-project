import 'package:Vista/security/logging_utility.dart';
import 'dart:async';
import 'package:isar/isar.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/env_config.dart';
import 'package:uuid/uuid.dart';
import '../../../model/conversation_model.dart';
import '../../../model/message_model.dart';
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
import '../services/e2e_encryption_service.dart';

/// Thrown when a message meant to be end-to-end encrypted cannot be encrypted.
/// Callers must fail the send rather than downgrade to plaintext.
class E2EEEncryptionException implements Exception {
  final String detail;
  const E2EEEncryptionException(this.detail);
  @override
  String toString() => 'رمزنگاری پیام ناموفق بود';
}

class ChatRepositoryImpl implements ChatRepository {
  final ChatLocalDataSourceIsar _local;
  final UserModerationService _moderation = UserModerationService();
  final IsarDatabaseManager _dbManager = IsarDatabaseManager();
  late final Dio _dio;

  String? _activeConversationId;
  Timer? _heartbeatTimer;
  late final StreamSubscription<SseConnectionState> _realtimeStateSubscription;
  // جلوگیری از اجرای هم‌زمانِ ارسال مجدد (reconnectهای پشت‌سرهم / چند رویداد)
  bool _resendInFlight = false;

  // ── throttle maps (برای جلوگیری از sync بیش از حد) ──────────────
  final Map<String, Timer?> _msgSyncTimers = {};
  final Map<String, bool> _msgSyncInFlight = {};
  final Map<String, String?> _messageNextCursors = {};
  final Map<String, bool> _messageHasMore = {};
  // آخرین پیام دریافتی‌ای که برایش /read فرستادیم — جلوی POST تکراری در هر sync
  final Map<String, String> _lastAckedIncomingMsgId = {};
  Timer? _convSyncTimer;
  bool _convSyncInFlight = false;
  int _convRateLimitedUntilMs = 0;

  static const int _msgPageSize = 50;
  static const int _convPageSize = 100;
  static const int _maxConversationPagesPerSync = 100;

  static String get _base => EnvConfig.apiBaseUrl;

  ChatRepositoryImpl({required ChatLocalDataSourceIsar localDataSource})
      : _local = localDataSource {
    _dio = createApiV1Dio(baseUrl: _base);

    // ✅ SSE singleton شروع میشه — همه provider ها از یه کانکشن استفاده می‌کنن
    SseManager.instance.start();

    _realtimeStateSubscription =
        SseManager.instance.connectionState.listen((state) {
      if (state == SseConnectionState.connected) {
        _userId().then((uid) {
          if (uid != null) {
            _syncConversations(uid);
            if (_activeConversationId != null) {
              _syncMessages(_activeConversationId!, uid);
            }
            // شبکه دوباره وصل شد → پیام‌های ناموفق خروجی را خودکار بفرست.
            unawaited(resendFailedMessages());
          }
        });
      }
    });
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
      return ChatResult.failure('کاربر وارد نشده است');
    }

    // ── 1. local-first: اگه کش داریم فوراً برگردون و در پس‌زمینه sync کن
    final local = await _local.getConversations();
    if (local.isNotEmpty) {
      unawaited(_syncConversations(uid));
      return ChatResult.success(local);
    }

    // ── 2. اگه کش خالیه، از سرور بگیر
    return _fetchConversationsFromServer(uid);
  }

  @override
  Stream<List<ConversationModel>> watchConversations() async* {
    final uid = await _userId();
    if (uid == null) {
      yield const [];
      return;
    }

    // ── emit کش فوری
    final local = await _local.getConversations();
    yield local;
    unawaited(_syncConversations(uid));

    // ── Isar stream (برای تغییرات local)
    final isarStream = _local.watchConversations(uid);

    // ── SSE events (برای تغییرات remote)
    StreamSubscription? sseSub;
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

    try {
      yield* isarStream.transform(
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
      // The Isar stream never completes, so handleDone never fires; without
      // this, every open/close of the chat-list left a live SSE listener
      // running _syncConversations forever (multiplying syncs + traffic).
      // Mirrors the fix already in watchMessages.
      await sseSub.cancel();
    }
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
      return ChatResult.failure('کاربر وارد نشده است');
    }

    // optimistic local delete
    await _local.deleteConversation(conversationId);
    await _local.clearMessages(conversationId);

    try {
      await _dio.delete('/chat/conversations/$conversationId', options: opts);
      return ChatResult.success(null);
    } on DioException catch (e) {
      // rollback از سرور: مکالمه هنوز آنجا زنده است، دوباره sync کن تا لیست
      // محلی با واقعیت یکی شود (وگرنه مکالمه تا restart غیب می‌ماند).
      final uid = await _userId();
      if (uid != null) unawaited(_syncConversations(uid));
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
    // The backend has exactly two routes for this:
    //   POST /chat/conversations/{id}/accept
    //   POST /chat/conversations/{id}/reject
    // The old guess-list fired up to 4 extra 404s per accept and reject
    // NEVER worked (it guessed `decline`, the backend only knows `reject`).
    final uid = await _userId();
    if (uid == null) {
      return ChatResult.failure('کاربر وارد نشده است');
    }

    final result = accept
        ? await acceptMessageRequest(conversationId)
        : await rejectMessageRequest(conversationId);
    if (result.isSuccess) {
      await _syncConversations(uid);
    }
    return result;
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
      // rollback: تاریخچه سمت سرور پاک نشده — دوباره بکش تا چت خالی نماند.
      final uid = await _userId();
      if (uid != null) unawaited(_syncMessages(conversationId, uid));
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
      return ChatResult.failure('کاربر وارد نشده است');
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

    // SSE: وقتی event مربوط به این conversation میاد، sync کن
    StreamSubscription? sseSub;
    sseSub = SseManager.instance.events.listen((event) {
      final type = event['type'] as String?;

      // حذف دوطرفه باید «سرعت نور» باشد: به‌محض رسیدن message_deleted، پیام را
      // مستقیماً از Isar پاک کن تا watch محلی فوراً بدون آن re-emit کند. قبلاً
      // این event در watchMessages هندل نمی‌شد و صفحه‌ی باز به listenerِ یک
      // provider دیگر (لیست مکالمات) وابسته بود که ممکن بود زنده نباشد → تأخیر.
      if (type == 'message_deleted') {
        final data = event['data'] as Map<String, dynamic>?;
        final convId = data?['conversation_id']?.toString();
        if (convId != conversationId) return;
        final msgId = data?['message_id']?.toString();
        if (msgId != null && msgId.isNotEmpty) {
          // بدون sync سرور — حذف محلی فوری، صفر round-trip.
          unawaited(_local.deleteMessage(msgId));
          unawaited(MessageTombstoneService()
              .markDeletedRemotely(msgId, conversationId));
        } else {
          // پاک‌سازی کل مکالمه (message_id ندارد) → clear + sync.
          unawaited(_local.clearMessages(conversationId));
          unawaited(_syncMessages(conversationId, uid));
        }
        return;
      }

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
            // رسید خواندن خودِ ما (echo از سرور) هیچ دیتای جدیدی نداره.
            // sync کردن روی اون دوباره markMessagesAsSeen → receipt جدید →
            // حلقه بی‌نهایت GET/POST می‌ساخت که سهمیه rate limit کاربر را
            // می‌خورد و ارسال پیام‌های بعدی 429 می‌گرفت.
            if (readerId == uid) return;
            if (readerId.isNotEmpty && readAt != null) {
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
      return ChatResult.failure('کاربر وارد نشده است');
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

    // Encrypt BEFORE sending. For an E2EE conversation (recipient public key
    // present) a crypto failure must abort — never silently send plaintext.
    // The quoted reply preview text must be encrypted too: it contains the
    // decrypted body of an earlier E2EE message, and sending it plaintext
    // would hand the server exactly what the encryption is hiding.
    final String encryptedContent;
    final String? encryptedReplyContent;
    try {
      final localConversation =
          await _local.getConversation(payload.conversationId, uid);
      final requireEncryption = payload.requireEncryption ||
          localConversation?.isSecret == true ||
          (payload.recipientPublicKey?.isNotEmpty ?? false);
      var recipientPublicKey = payload.recipientPublicKey;
      if (requireEncryption) {
        // The key exchanged inside this conversation is authoritative. Profile
        // keys may be absent or rotated independently and previously caused
        // attachment/retry sends to fail while text sends still worked.
        final prefs = await SharedPreferences.getInstance();
        final conversationKey =
            prefs.getString('e2e_peer_pub_${payload.conversationId}')?.trim();
        if (conversationKey != null && conversationKey.isNotEmpty) {
          recipientPublicKey = conversationKey;
        }
      }
      encryptedContent = await _encryptContent(
        payload.content,
        recipientPublicKey,
        userId: uid,
        conversationId: payload.conversationId,
        messageId: messageId,
        field: 'content',
        requiredEncryption: requireEncryption,
      );
      encryptedReplyContent = payload.replyToContent == null
          ? null
          : await _encryptContent(
              payload.replyToContent!,
              recipientPublicKey,
              userId: uid,
              conversationId: payload.conversationId,
              messageId: messageId,
              field: 'reply',
              requiredEncryption: requireEncryption,
            );
    } on E2EEEncryptionException catch (e) {
      final failed = optimistic.copyWith(
        isPending: false,
        isFailed: true,
        errorMessage: 'رمزنگاری پیام ناموفق بود',
      );
      await _local.saveMessage(failed);
      return ChatResult.failure(e.toString());
    }

    // ── ارسال به Go backend ───────────────────────────────────────
    try {
      final res = await _dio.post(
        '/chat/conversations/${payload.conversationId}/messages',
        data: {
          'id': messageId,
          'content': encryptedContent,
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
          if (encryptedReplyContent != null)
            'reply_to_content': encryptedReplyContent,
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
    String rawContent,
    String? recipientPublicKey, {
    required String userId,
    required String conversationId,
    required String messageId,
    required String field,
    required bool requiredEncryption,
  }) async {
    if (requiredEncryption &&
        E2EEncryptionService().isEncryptedEnvelope(rawContent)) {
      // Failed rows created by older clients may already contain ciphertext.
      // Retrying the same id must not wrap the envelope again.
      return rawContent;
    }
    if (recipientPublicKey == null || recipientPublicKey.isEmpty) {
      if (requiredEncryption) {
        throw const E2EEEncryptionException('recipient key is unavailable');
      }
      return rawContent;
    }
    try {
      final e2e = E2EEncryptionService();
      final keyPair = await e2e.getSavedKeyPair(userId);
      if (keyPair == null) {
        throw StateError('local E2EE key is unavailable');
      }
      final sharedSecret = await e2e.computeSharedSecret(
        myKeyPair: keyPair,
        peerPublicKeyBytes: base64Decode(recipientPublicKey),
      );
      return e2e.encryptMessage(
        rawContent,
        sharedSecret,
        binding: E2EEncryptionService.messageBinding(
          conversationId: conversationId,
          senderId: userId,
          messageId: messageId,
          field: field,
        ),
      );
    } catch (e) {
      // The caller explicitly provided a recipient key, so this message was
      // meant to be end-to-end encrypted. Silently sending plaintext would be
      // an invisible security downgrade — fail the send instead.
      logWarning('E2EE Encryption failed: $e');
      throw E2EEEncryptionException(e.toString());
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
      return ChatResult.failure('کاربر وارد نشده است');
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

    final opts = await _authOptions();
    if (opts == null) return ChatResult.success(null);

    try {
      await _dio.delete(
        '/chat/messages/$messageId',
        queryParameters: {'for_everyone': forEveryone},
        options: opts,
      );
      // پاک‌سازی مدیا فقط بعد از تأیید سرور — حذفِ زودهنگام، مدیایی را که
      // هنوز برای طرف مقابل زنده است از storage می‌کشت.
      unawaited(_queueDeletedMessageMediaCleanup(
        existing,
        deleteForEveryone: forEveryone,
      ));
      return ChatResult.success(null);
    } on DioException catch (e) {
      // rollback: پیام محلی را برگردان تا با سرور ناسازگار نمانیم
      if (existing != null) await _local.saveMessage(existing);
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
      return ChatResult.failure('کاربر وارد نشده است');
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
      return ChatResult.failure('کاربر وارد نشده است');
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
      return ChatResult.failure('کاربر وارد نشده است');
    }

    try {
      if (_messageHasMore[conversationId] == false) {
        return ChatResult.success(const []);
      }
      final cursor = _messageNextCursors[conversationId];
      final res = await _dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          if (cursor == null || cursor.isEmpty)
            'before_time': oldestMessageDate.toUtc().toIso8601String(),
        },
        options: opts,
      );
      final response = _asMap(res.data);
      _captureMessagePageState(conversationId, response);
      final msgs = _asList(response['messages'])
          .whereType<Map>()
          .map((e) => _msgFromGo(e.cast<String, dynamic>(), uid))
          .toList()
          .reversed
          .toList();

      if (msgs.isNotEmpty) {
        // A history page is only a partial slice. Date-range reconciliation can
        // delete valid local rows when several messages share the boundary
        // timestamp but fall on adjacent composite-cursor pages.
        await _local.saveMessages(msgs);
      }
      return ChatResult.success(msgs);
    } on DioException catch (e) {
      return ChatResult.failure(_dioError(e));
    }
  }

  @override
  bool hasMoreMessages(String conversationId) =>
      _messageHasMore[conversationId] ?? true;

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
      return ChatResult.failure('کاربر وارد نشده است');
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
      } catch (e) {
        logError('Silent error swallowed', error: e);
      }
    }

    // SSE updates — فقط رویدادهای reaction_updated (نه هر پیام/تایپ).
    await for (final event
        in SseManager.instance.eventsOfType('reaction_updated')) {
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
    } catch (e) {
      logError('Silent error swallowed', error: e);
    }
  }

  /// Go backend باید این event رو از SSE بفرسته:
  /// { "type": "typing", "data": { "conversation_id": "...", "user_id": "...", "is_typing": true } }
  @override
  Stream<bool> watchTypingStatus(String conversationId, String userId) {
    late StreamSubscription<Map<String, dynamic>> subscription;
    Timer? clearTimer;
    bool isTyping = false;

    late final StreamController<bool> controller;
    controller = StreamController<bool>.broadcast(
      onListen: () {
        subscription =
            SseManager.instance.eventsOfType('typing').listen((event) {
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
    } catch (e) {
      logError('Silent error swallowed', error: e);
    }
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
    if (_convSyncTimer?.isActive ?? false) return;
    _convSyncTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_convSyncInFlight) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _convRateLimitedUntilMs) return;
      _convSyncInFlight = true;

      try {
        final result = await _fetchConversationsFromServer(uid);
        if (result.isSuccess) {
          await _local.saveConversations(result.data!);
        }
      } finally {
        _convSyncInFlight = false;
      }
    });
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
        final conversationsById = <String, ConversationModel>{};
        final seenCursors = <String>{};
        String? cursor;

        for (var page = 0; page < _maxConversationPagesPerSync; page++) {
          final res = await _dio.get(
            '/chat/conversations',
            queryParameters: {
              'limit': _convPageSize,
              if (cursor != null) 'cursor': cursor,
            },
            options: opts,
          );
          final response = _asMap(res.data);
          for (final raw
              in _asList(response['conversations']).whereType<Map>()) {
            final conversation = _convFromGo(raw.cast<String, dynamic>(), uid);
            conversationsById[conversation.id] = conversation;
          }

          final hasMore = response['has_more'] == true;
          final nextCursor = response['next_cursor']?.toString();
          if (!hasMore || nextCursor == null || nextCursor.isEmpty) break;
          if (!seenCursors.add(nextCursor)) {
            logWarning('Conversation pagination returned a repeated cursor');
            break;
          }
          cursor = nextCursor;
        }

        final conversations = conversationsById.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return ChatResult.success(conversations);
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
    if (_msgSyncTimers[conversationId]?.isActive ?? false) return;
    _msgSyncTimers[conversationId] =
        Timer(const Duration(milliseconds: 500), () async {
      if (_msgSyncInFlight[conversationId] == true) return;
      _msgSyncInFlight[conversationId] = true;

      try {
        final opts = await _authOptions();
        if (opts == null) return;

        final res = await _dio.get(
          '/chat/conversations/$conversationId/messages',
          queryParameters: {'limit': _msgPageSize},
          options: opts,
        );

        final response = _asMap(res.data);
        _messageNextCursors.putIfAbsent(
            conversationId, () => response['next_cursor']?.toString());
        _messageHasMore.putIfAbsent(
            conversationId, () => response['has_more'] == true);
        final tombstones = await _getTombstones(conversationId);
        final msgs = _asList(response['messages'])
            .whereType<Map>()
            .map((e) => _msgFromGo(e.cast<String, dynamic>(), uid))
            .where((m) => !tombstones.contains(m.id))
            .toList()
            .reversed
            .toList();

        if (response['has_more'] == true) {
          // The latest server page is partial; absence from it is not evidence
          // that an older local row was deleted.
          await _local.saveMessages(msgs);
        } else {
          await _local.reconcileMessages(conversationId, msgs);
        }

        // mark seen اگه این conversation فعاله
        // فقط وقتی پیام دریافتیِ جدیدی از طرف مقابل آمده باشد /read بفرست.
        // POST /read در هر sync باعث می‌شد read_receipt از SSE برگردد، sync
        // بعدی را فعال کند و بین دو کلاینتِ باز حلقه بی‌پایان درخواست بسازد
        // که سهمیه rate limit کاربر را می‌خورد (429 روی ارسال پیام بعدی).
        if (conversationId == _activeConversationId) {
          String? newestIncomingId;
          DateTime? newestIncomingAt;
          for (final m in msgs) {
            if (m.senderId == uid) continue;
            if (newestIncomingAt == null ||
                m.createdAt.isAfter(newestIncomingAt)) {
              newestIncomingAt = m.createdAt;
              newestIncomingId = m.id;
            }
          }
          if (newestIncomingId != null &&
              _lastAckedIncomingMsgId[conversationId] != newestIncomingId) {
            _lastAckedIncomingMsgId[conversationId] = newestIncomingId;
            unawaited(markMessagesAsSeen(conversationId));
          }
        }
      } on DioException catch (e) {
        // Error bodies may echo message payload fields; status/type are enough
        // for diagnostics without risking plaintext, ciphertext, or media URLs.
        logWarning(
            '_syncMessages DioException: status=${e.response?.statusCode}, type=${e.type}');
      } catch (e) {
        logWarning('_syncMessages error: $e');
      } finally {
        _msgSyncInFlight.remove(conversationId);
      }
    });
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
  Future<void> resendFailedMessages() async {
    if (_resendInFlight) return;
    _resendInFlight = true;
    try {
      final failed = await _local.getFailedOutgoingMessages();
      if (failed.isEmpty) return;

      SharedPreferences? prefs;
      for (final message in failed) {
        // آپلودِ ناتمام (فایل محلی هست ولی هنوز URL ندارد) از این مسیر رد
        // نمی‌شود؛ نیازمند upload pipeline است، نه resend ساده‌ی متن.
        final needsUpload = (message.localFilePath?.isNotEmpty ?? false) &&
            (message.attachmentUrl?.isEmpty ?? true);
        if (needsUpload) continue;

        // کلید عمومی مخاطب برای secret chat — بدون آن، resend یک پیام E2EE
        // به‌صورت plaintext ارسال می‌شود (همان باگی که در resend دستی رفع شد).
        prefs ??= await SharedPreferences.getInstance();
        final recipientPublicKey =
            prefs.getString('e2e_peer_pub_${message.conversationId}');

        final payload = MessagePayload(
          conversationId: message.conversationId,
          content: message.content,
          id: message.id, // همان id → سرور upsert، بدون duplicate
          recipientPublicKey: recipientPublicKey,
          attachmentUrl: message.attachmentUrl,
          attachmentType: message.attachmentType,
          attachmentFileName: message.attachmentFileName,
          attachmentMimeType: message.attachmentMimeType,
          attachmentSizeBytes: message.attachmentSizeBytes,
          audioTitle: message.audioTitle,
          audioArtist: message.audioArtist,
          audioAlbum: message.audioAlbum,
          duration: message.duration,
          replyToMessageId: message.replyToMessageId,
          replyToContent: message.replyToContent,
          replyToSenderName: message.replyToSenderName,
          mediaGroupId: message.mediaGroupId,
        );

        // ترتیبی می‌فرستیم تا یک burst به بکند نخورد؛ شکست هر کدام دوباره
        // isFailed می‌شود و در reconnect بعدی retry خواهد شد.
        await sendMessage(payload);
      }
    } catch (e) {
      logWarning('resendFailedMessages failed', error: e);
    } finally {
      _resendInFlight = false;
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
    _convSyncTimer?.cancel();
    for (final timer in _msgSyncTimers.values) {
      timer?.cancel();
    }
    _msgSyncTimers.clear();
    _msgSyncInFlight.clear();
    unawaited(_realtimeStateSubscription.cancel());
    if (_activeConversationId != null) {
      unawaited(_setPresence(_activeConversationId!, false));
    }
    // SseManager singleton رو dispose نکن — برای همه برنامه زنده‌ست
  }

  @override
  Future<void> clearAllCache() => _local.clearAllData();

  @override
  Future<void> clearConversationCache(String conversationId) async {
    await _local.clearMessages(conversationId);
    await _local.deleteConversation(conversationId);
    _msgSyncInFlight.remove(conversationId);
    _msgSyncTimers.remove(conversationId)?.cancel();
    _messageNextCursors.remove(conversationId);
    _messageHasMore.remove(conversationId);
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
    } catch (e) {
      logError('Silent error swallowed', error: e);
    }
  }

  Future<void> _heartbeat(String conversationId) async {
    final opts = await _authOptions();
    if (opts == null) return;
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/heartbeat',
        options: opts,
      );
    } catch (e) {
      logError('Silent error swallowed', error: e);
    }
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

  void _captureMessagePageState(
      String conversationId, Map<String, dynamic> response) {
    final nextCursor = response['next_cursor']?.toString();
    final hasMore = response['has_more'];
    _messageNextCursors[conversationId] =
        nextCursor == null || nextCursor.isEmpty ? null : nextCursor;
    _messageHasMore[conversationId] =
        hasMore is bool ? hasMore : nextCursor != null && nextCursor.isNotEmpty;
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
    if (E2EEncryptionService().isEncryptedEnvelope(serverValue)) {
      return serverValue;
    }
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
        'DioException: status=$status, type=${e.type}, path=${e.requestOptions.path}');

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

    // سرور دو شکل envelope دارد:
    //   nested → {"error": {"code": "...", "message": "پیام فارسی"}}
    //   flat   → {"error": "متن خطا"}
    // پیام فارسی سرور همیشه بر متن عمومی مقدم است.
    final serverMessage = _serverErrorMessage(data);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      if (status == 500) logError('Chat server returned HTTP 500');
      return serverMessage;
    }

    if (status == 500) {
      logError('Chat server returned HTTP 500');
      return 'خطای داخلی سرور رخ داد.';
    }
    if (status == 429) {
      return 'تعداد درخواست‌ها بیش از حد مجاز است. لطفاً کمی صبر کنید.';
    }
    if (status == 403) return 'این کاربر دریافت پیام را محدود کرده است';
    if (status == 404) return 'آیتم مورد نظر یافت نشد';
    if (status == 401) return 'لطفاً دوباره وارد شوید';
    return e.message ?? 'خطا در ارتباط با سرور';
  }

  /// هر دو شکل envelope خطا را باز می‌کند؛ روی nested، فیلد message (فارسی)
  /// را برمی‌گرداند نه Map.toString().
  String? _serverErrorMessage(dynamic data) {
    if (data is! Map) return null;
    final err = data['error'];
    if (err is String) return err.trim().isEmpty ? null : err;
    if (err is Map) {
      final msg = err['message']?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg;
      final code = err['code']?.toString();
      if (code != null && code.trim().isNotEmpty) return code;
    }
    return null;
  }

  int _retryAfterSeconds(String? retryAfterHeader) {
    final parsed = int.tryParse(retryAfterHeader ?? '');
    if (parsed == null || parsed <= 0) return 60;
    return parsed.clamp(10, 180);
  }
}
