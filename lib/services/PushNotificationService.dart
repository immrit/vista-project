import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // ✅ کامل شد برای کار با فایل
import 'dart:typed_data'; // ✅ برای Uint8List
import 'package:path_provider/path_provider.dart'; // ✅ برای مسیردهی
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../model/message_model.dart';
import 'package:image/image.dart' as img;
import '../provider/notification_provider.dart';
import '../utils/avatar_asset_utils.dart';
import '../utils/const.dart';
import 'notification_navigation_service.dart';
import 'session_manager_service_v2.dart';
import 'current_chat_tracker.dart';
import 'local_notification_center.dart';
import 'notification_id.dart';
import '../features/chat/data/datasources/chat_local_datasource_isar.dart';
import '../features/chat/services/e2e_encryption_service.dart';
import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import '../DB/settings_cache_service.dart';
import 'device_id_service.dart';
import 'package:Vista/core/theme/app_theme.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.enqueueBackgroundNotificationAction(details);
  try {
    await PushNotificationService.processPendingNotificationActions();
  } catch (e) {
    debugPrint('Background processing failed: $e');
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

class PushNotificationService {
  final Ref? ref;
  PushNotificationService(this.ref);

  static const String _pendingActionsPrefsKey =
      'pending_notification_actions_v1';
  static const String _fcmSyncEpochAckKey = 'fcm_sync_epoch_ack';
  static const String _fcmLastSyncOkMsKey = 'fcm_last_sync_ok_ms';
  static const String _fcmLastSyncedTokenKey = 'fcm_last_synced_token';
  static const String _chatReadWatermarkPrefix = 'chat_notification_read_at:';
  static const String _chatLatestNotificationPrefix =
      'chat_notification_latest_at:';
  static const Duration _fcmMinRetryInterval = Duration(minutes: 5);
  static DateTime? _lastFcmAttemptAt;
  static int? _lastSeenSystemEpoch;
  static Future<bool>? _syncInFlight;
  static const int _maxPendingActions = 30;
  static const Uuid _uuid = Uuid();
  static String get _backendUrl => EnvConfig.apiBaseUrl;

  static FlutterLocalNotificationsPlugin get notificationsPlugin =>
      LocalNotificationCenter.plugin;

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _flutterLocalNotifications = LocalNotificationCenter.plugin;
  static final Map<String, DateTime> _recentMessageEvents = {};

  final List<RemoteMessage> _notifications = [];
  List<RemoteMessage> get notifications => _notifications;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;

  bool _isInitialized = false; // جلوگیری از initialize چندگانه (local plugin)
  bool _listenersBound = false;

  bool _isTruthy(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  bool _shouldShowBackgroundLocalNotification(RemoteMessage message) {
    // Default policy: do not render local notifications in background.
    // This prevents duplicate "FCM(system) + local(app)" notifications.
    // Backend can explicitly opt in for local rendering via data payload.
    return _isTruthy(message.data['show_local_in_background']?.toString());
  }

  bool _isRecentDuplicate(RemoteMessage message) {
    final data = message.data;
    final eventId =
        data['event_id']?.toString() ?? data['notification_id']?.toString();
    final fallback = data['message_id']?.toString() ?? message.messageId;
    final key = eventId ?? fallback;
    if (key == null || key.isEmpty) return false;

    final now = DateTime.now();
    _recentMessageEvents.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 2),
    );
    final existing = _recentMessageEvents[key];
    if (existing != null &&
        now.difference(existing) < const Duration(seconds: 10)) {
      return true;
    }
    _recentMessageEvents[key] = now;
    return false;
  }

  bool _isChatForActiveConversation(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type != 'chat_message' && type != 'message') return false;
    final conversationId = data['conversation_id']?.toString();
    if (conversationId == null || conversationId.isEmpty) return false;
    return CurrentChatTracker.instance.isConversationActive(conversationId);
  }

  Future<void> cancelConversationNotification(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _flutterLocalNotifications.cancel(
      id: stableConversationNotificationId(conversationId),
      tag: conversationId,
    );
  }

  Future<bool> _handleNotificationControl(RemoteMessage message) async {
    if (message.data['type']?.toString() != 'chat_notification_clear') {
      return false;
    }
    final conversationId = message.data['conversation_id']?.toString() ?? '';
    if (conversationId.isNotEmpty) {
      final readAt = DateTime.tryParse(
            message.data['read_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_chatReadWatermarkPrefix$conversationId',
        readAt.toIso8601String(),
      );
      final latestMessageAt = DateTime.tryParse(
        prefs.getString('$_chatLatestNotificationPrefix$conversationId') ?? '',
      )?.toUtc();
      if (shouldClearLatestChatNotification(latestMessageAt, readAt)) {
        await cancelConversationNotification(conversationId);
        logInfo('🧹 Cleared read chat notification for $conversationId');
      } else {
        logInfo('ℹ️ Kept newer chat notification for $conversationId');
      }
    }
    return true;
  }

  static bool _isActionPersistable(NotificationResponse details) {
    final action = details.actionId?.trim();
    if (action == null || action.isEmpty) return false;
    return action == 'reply' || action == 'mark_read';
  }

  static Future<void> enqueueBackgroundNotificationAction(
    NotificationResponse details,
  ) async {
    try {
      if (!_isActionPersistable(details)) return;
      final payload = details.payload?.trim();
      if (payload == null || payload.isEmpty) return;

      final pendingItem = <String, dynamic>{
        'action_id': details.actionId,
        'payload': payload,
        'input': details.input?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      final existing =
          prefs.getStringList(_pendingActionsPrefsKey) ?? <String>[];
      existing.add(jsonEncode(pendingItem));
      while (existing.length > _maxPendingActions) {
        existing.removeAt(0);
      }
      await prefs.setStringList(_pendingActionsPrefsKey, existing);
    } catch (e) {
      logInfo('⚠️ Failed to persist background notification action: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _readPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_pendingActionsPrefsKey) ?? <String>[];
    final pending = <Map<String, dynamic>>[];
    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          pending.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return pending;
  }

  Future<void> _writePendingActions(List<Map<String, dynamic>> actions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = actions.map(jsonEncode).toList(growable: false);
    await prefs.setStringList(_pendingActionsPrefsKey, encoded);
  }

  static Future<void> processPendingNotificationActions() async {
    await PushNotificationService(null)._processPendingNotificationActions();
  }

  Future<void> _processPendingNotificationActions() async {
    final token = await _resolveAuthToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final pending = await _readPendingActions();
    if (pending.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final item in pending) {
      final actionId = item['action_id']?.toString() ?? '';
      final payloadRaw = item['payload']?.toString() ?? '';
      if (payloadRaw.isEmpty) {
        continue;
      }

      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is! Map) {
          continue;
        }
        payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }

      final conversationId = payload['conversation_id']?.toString() ?? '';
      if (conversationId.isEmpty) {
        continue;
      }

      bool success = false;
      if (actionId == 'reply') {
        final input = item['input']?.toString().trim() ?? '';
        if (input.isNotEmpty) {
          success = await handleQuickReply(conversationId, input);
        }
      } else if (actionId == 'mark_read') {
        success = await _markConversationAsRead(conversationId);
      }

      if (!success) {
        remaining.add(item);
      }
    }

    await _writePendingActions(remaining);
  }

  /// ✅ تابع Initialize که هم در Foreground و هم Background استفاده می‌شود
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return; // جلوگیری از initialize چندگانه

    // تنظیمات Android برای Local Notification
    const androidInit =
        AndroidInitializationSettings('@drawable/ic_notification');
    final iOSInit = DarwinInitializationSettings(
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'CHAT_MESSAGE',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.text(
              'reply',
              'پاسخ',
              buttonTitle: 'ارسال',
              placeholder: 'پیام خود را بنویسید...',
            ),
            DarwinNotificationAction.plain('mark_read', 'خواندم'),
          ],
        ),
      ],
    );
    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iOSInit,
    );

    await _flutterLocalNotifications.initialize(
      settings: initSettings,
      // هندلر کلیک وقتی اپ باز است (Foreground)
      onDidReceiveNotificationResponse: (details) {
        _onNotificationTap(details);
      },
      // ✅ هندلر کلیک/پاسخ وقتی اپ بسته است (حیاتی برای دکمه پاسخ)
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _isInitialized = true;
    logInfo('✅ Notification plugin initialized');
  }

  Future<void> ensureLocalNotificationsInitialized() async {
    await _ensureInitialized();
  }

  /// هندلر مرکزی کلیک روی اعلان (برای Foreground)
  void _onNotificationTap(NotificationResponse details) {
    unawaited(_handleNotificationResponse(details));
  }

  Future<void> _handleNotificationResponse(NotificationResponse details) async {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final conversationId = data['conversation_id']?.toString() ?? '';

      if (details.actionId == 'reply') {
        final input = details.input?.trim() ?? '';
        if (conversationId.isNotEmpty && input.isNotEmpty) {
          await handleQuickReply(conversationId, input);
        }
        return;
      }

      if (details.actionId == 'mark_read') {
        if (conversationId.isNotEmpty) {
          await _markConversationAsRead(conversationId);
        }
        return;
      }

      if (conversationId.isNotEmpty) {
        await cancelConversationNotification(conversationId);
      }

      // تلاش برای گرفتن کانتکست با تاخیر در صورت نیاز
      _handleTapWithContext(data);
    } catch (e) {
      logInfo('Error handling notification tap: $e');
    }
  }

  void _handleTapWithContext(Map<String, dynamic> data, [int attempts = 0]) {
    final navContext =
        navigatorKey.currentContext ?? navigatorKey.currentState?.context;
    if (navContext != null) {
      NotificationNavigationService.handleFCMPayload(
        context: navContext,
        data: data,
      );
    } else if (attempts < 10) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _handleTapWithContext(data, attempts + 1);
      });
    } else {
      logInfo(
          '❌ Failed to handle notification tap: context is null after retries');
    }
  }

  Future<void> init(BuildContext context) async {
    try {
      logInfo('🔔 Initializing Push Notification Service...');

      if (Firebase.apps.isEmpty) {
        logInfo(
          '⚠️ Firebase not initialized, skipping PushNotificationService init',
        );
        return;
      }

      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // پاک کردن اجباری توکن قدیمی برای جلوگیری از خطای SenderId Mismatch
      // در آپدیت‌های جدید که کلید فایربیس تغییر کرده است.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('fcm_cleared_for_vista_v1') != true) {
          logInfo('⚠️ Clearing old FCM token to force project sync...');
          await _firebaseMessaging.deleteToken();
          await prefs.setBool('fcm_cleared_for_vista_v1', true);
        }
      } catch (e) {
        logInfo('Error checking token clear status: $e');
      }

      // Keep one foreground rendering path (local notifications) and prevent
      // native foreground FCM banners from duplicating the same event.
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // کانال چت (حیاتی برای نمایش درست در اندروید 8+)
      const chatChannel = AndroidNotificationChannel(
        'chat_messages',
        'پیام‌های چت',
        description: 'اعلان برای پیام‌های دریافتی',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      const socialChannel = AndroidNotificationChannel(
        'social_notify',
        'فعالیت‌های اجتماعی',
        description: 'اعلان‌های اجتماعی (لایک، کامنت، فالو و ...)',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);

      await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(socialChannel);

      // ✅ Initialize کردن پلاگین (یکپارچه برای foreground و background)
      await _ensureInitialized();

      unawaited(syncIfNeeded(afterAuth: true));
      await _processPendingNotificationActions();

      if (_listenersBound) {
        logInfo('✅ Push listeners already bound, skipping re-bind');
        return;
      }

      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((
        newToken,
      ) {
        unawaited(syncIfNeeded(tokenHint: newToken, tokenChanged: true));
      });

      _onMessageSubscription = FirebaseMessaging.onMessage.listen((
        RemoteMessage message,
      ) async {
        logInfo('📱 Foreground Message: ${message.data}');
        if (await _handleNotificationControl(message)) return;
        if (_isRecentDuplicate(message)) {
          logInfo('⚠️ Duplicate FCM ignored in foreground');
          return;
        }
        _notifications.add(message);

        if (_isChatForActiveConversation(message.data)) {
          logInfo('🔕 Chat notification suppressed for active conversation');
        } else {
          _showNotification(message);
        }

        if (ref != null) {
          _addNotificationToProvider(message);
        }
      });

      _onMessageOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logInfo('📬 FCM notification opened (background)');
        _handleTapWithContext(message.data);
      });
      _listenersBound = true;
    } catch (e) {
      logInfo('❌ خطا در راه‌اندازی PushNotificationService: $e');
    }
  }

  /// ✅ متد مخصوص بک‌گراند که اول Init میکند بعد نمایش میدهد
  Future<void> showBackgroundNotification(RemoteMessage message) async {
    // حیاتی: در بک‌گراند باید دستی Init کنیم تا استایل‌ها و اکشن‌ها کار کنند
    await _ensureInitialized();
    if (await _handleNotificationControl(message)) return;
    if (_isRecentDuplicate(message)) {
      logInfo('⚠️ Duplicate background FCM ignored');
      return;
    }

    final type = message.data['type']?.toString() ?? '';
    final isChatMessage = _isChatMessageType(type);

    // پیام‌های چت: data-only هستند، باید local notification نمایش دهیم
    if (isChatMessage) {
      // اگر system notification وجود دارد (غیرمعمول)، از آن استفاده می‌شود
      if (message.notification != null) {
        logInfo('ℹ️ Skipping local chat notification (system handled)');
        await _saveMessageToLocalDB(message.data);
        return;
      }
      if (!_shouldShowBackgroundLocalNotification(message)) {
        logInfo('ℹ️ Background local notification disabled by policy');
        await _saveMessageToLocalDB(message.data);
        return;
      }
      await _showNotification(message);
      return;
    }

    // سایر نوتیف‌ها (social): backend یک notification payload می‌فرستد
    // که توسط سیستم مستقیماً نمایش می‌یابد.
    // اگر به هر دلیلی notification null بود، local نمایش می‌دهیم
    if (message.notification == null) {
      logInfo('ℹ️ Social notification without system payload — showing local');
      await _showStandardNotification(message);
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (_isChatMessageType(type?.toString())) {
      if (_isChatForActiveConversation(data)) {
        return;
      }
      // ✅ Fallback: Save to Local DB immediately
      await _saveMessageToLocalDB(data);

      if (await _isCoveredByChatReadWatermark(data)) {
        logInfo('🔕 Old chat notification suppressed by read watermark');
        return;
      }
      if (await _isOlderThanLatestChatNotification(data)) {
        logInfo('🔕 Out-of-order older chat notification suppressed');
        return;
      }

      if (await _shouldShowNotification('chat')) {
        await _recordLatestChatNotification(data);
        await _showMessagingStyleNotification(data);
      } else {
        logInfo(
            '🔕 Notification suppressed by global settings or quiet hours.');
      }
    } else {
      if (await _shouldShowNotification('social')) {
        await _showStandardNotification(message);
      } else {
        logInfo(
            '🔕 Notification suppressed by global settings or quiet hours.');
      }
    }
  }

  Future<bool> _isCoveredByChatReadWatermark(
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    if (conversationId.isEmpty) return false;
    final createdAt = _chatMessageCreatedAt(data);
    if (createdAt == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final watermark = DateTime.tryParse(
      prefs.getString('$_chatReadWatermarkPrefix$conversationId') ?? '',
    )?.toUtc();
    return watermark != null && isAtOrBeforeReadWatermark(createdAt, watermark);
  }

  Future<void> _recordLatestChatNotification(
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    final createdAt = _chatMessageCreatedAt(data);
    if (conversationId.isEmpty || createdAt == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_chatLatestNotificationPrefix$conversationId',
      createdAt.toIso8601String(),
    );
  }

  Future<bool> _isOlderThanLatestChatNotification(
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    final createdAt = _chatMessageCreatedAt(data);
    if (conversationId.isEmpty || createdAt == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final latestMessageAt = DateTime.tryParse(
      prefs.getString('$_chatLatestNotificationPrefix$conversationId') ?? '',
    )?.toUtc();
    return isChatMessageOlderThanLatestNotification(
      createdAt,
      latestMessageAt,
    );
  }

  DateTime? _chatMessageCreatedAt(Map<String, dynamic> data) {
    final rawCreatedAt = data['created_at']?.toString() ?? '';
    final parsedCreatedAt = DateTime.tryParse(rawCreatedAt)?.toUtc();
    if (parsedCreatedAt != null) return parsedCreatedAt;
    final rawTimestamp = data['timestamp'];
    final millis = rawTimestamp is int
        ? rawTimestamp
        : int.tryParse(rawTimestamp?.toString() ?? '');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  /// ✅ Fallback: Save incoming FCM message to Isar
  /// This ensures message appears in chat even if SSE is disconnected.
  Future<void> _saveMessageToLocalDB(Map<String, dynamic> data) async {
    try {
      final conversationId = data['conversation_id']?.toString();
      final messageId = data['message_id']?.toString();
      final senderId = data['sender_id']?.toString();
      final content = data['content']?.toString();
      final timestamp = data['timestamp']; // Can be String or int

      if (conversationId == null || messageId == null || senderId == null) {
        return;
      }

      // Parse timestamp
      DateTime createdAt = DateTime.now();
      if (timestamp != null) {
        if (timestamp is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          createdAt = DateTime.tryParse(timestamp) ?? DateTime.now();
          // Sometimes legacy payloads send timestamp as int in string (milliseconds)
          if (createdAt.year < 2000) {
            final millis = int.tryParse(timestamp);
            if (millis != null) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(millis);
            }
          }
        }
      }

      final senderName = data['sender_name']?.toString() ?? 'User';
      final attachmentType = data['attachment_type']?.toString() ??
          data['message_type']?.toString();
      final mediaUrl =
          data['media_url']?.toString() ?? data['attachment_url']?.toString();
      final audioUrl = data['audio_url']?.toString();
      final resolvedAttachmentUrl = (mediaUrl?.trim().isNotEmpty == true)
          ? mediaUrl!.trim()
          : (audioUrl?.trim().isNotEmpty == true ? audioUrl!.trim() : null);
      final isMediaMessage = attachmentType != null &&
          attachmentType.isNotEmpty &&
          attachmentType.toLowerCase() != 'text';
      final resolvedContent = isMediaMessage ? '' : (content ?? '');

      final currentUserId = await TokenStorage.getUserId() ?? '';

      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        content: resolvedContent,
        createdAt: createdAt,
        isSeen: false,
        isSent: true, // It came from server, so it is sent.
        isDelivered: true,
        attachmentUrl: resolvedAttachmentUrl,
        attachmentType: attachmentType,
        audioUrl: audioUrl,
        messageType:
            attachmentType?.isNotEmpty == true ? attachmentType : 'text',
        replyToMessageId: data['reply_to_message_id']?.toString(),
        // isEdited: false, // Not in constructor
        // isDeleted: false, // Not in constructor
        isMe: currentUserId == senderId, // ✅ Required field
        senderName: senderName,
        senderAvatar: AvatarAssetUtils.resolveUrl(data['sender_avatar']),
      );

      logInfo('💾 FCM Fallback: Saving message to Isar: $messageId');
      final localSource = ChatLocalDataSourceIsar();
      await localSource.saveMessage(message);

      // We should also update the conversation metadata (unread count etc) logic
      // But ChatRepositoryImpl handles that complex logic.
      // Replicating it here might be tricky without access to ChatRepository.
      // However, saving the message alone triggers the stream listener in ChatScreen
      // which is the most important part for "seeing the message".
    } catch (e) {
      logInfo('❌ FCM Fallback Error: $e');
    }
  }

  /// 🎨 نمایش اعلان حرفه‌ای با عکس پروفایل دانلود شده
  Future<void> _showMessagingStyleNotification(
    Map<String, dynamic> data,
  ) async {
    final String? conversationId = data['conversation_id']?.toString();

    if (conversationId == null || conversationId.isEmpty) return;
    if (_isChatForActiveConversation(data)) return;

    final int notificationId = stableConversationNotificationId(conversationId);
    final String groupKey = conversationId;

    // واکشی اطلاعات مکالمه از دیتابیس لوکال برای تشخیص گروه و استخراج اطلاعات
    final localSource = ChatLocalDataSourceIsar();
    final conversation = await localSource.getConversation(conversationId, '');

    // ۱. بررسی میوت بودن خود گروه/پی‌وی
    if (conversation?.isMuted == true) {
      logInfo('🔕 Notification suppressed: conversation is muted.');
      return;
    }

    final bool isGroup =
        conversation?.isGroup == true || data['is_group'] == 'true';

    String senderName = data['sender_name']?.toString() ?? 'کاربر';
    String messageContent = _buildReadableMessageBody(
      data,
      fallback: 'پیام جدید',
    );
    String? senderAvatarUrl = AvatarAssetUtils.firstResolvedUrl(
      data['sender_avatar'],
      data['avatar_url'] ?? data['actor_avatar'],
    );

    String? groupAvatarUrl;
    String? conversationTitle;

    if (isGroup) {
      conversationTitle = conversation?.otherUserName ??
          data['group_name']?.toString() ??
          senderName;
      groupAvatarUrl =
          AvatarAssetUtils.resolveUrl(conversation?.otherUserAvatar);

      // در صورتی که نام ارسال کننده همان نام گروه باشد و پیام فرمت نام: محتوا داشته باشد
      if (conversationTitle == senderName && messageContent.contains(': ')) {
        final parts = messageContent.split(': ');
        senderName = parts[0];
        messageContent = parts.sublist(1).join(': ');
      }

      // تلاش برای دریافت آخرین پیام از دیتابیس لوکال برای دقت بیشتر در مشخصات فرستنده
      try {
        final messages =
            await localSource.watchMessages(conversationId, '', limit: 1).first;
        if (messages.isNotEmpty) {
          final latestMsg = messages.first;
          if (latestMsg.id == data['message_id']) {
            senderName = latestMsg.senderName ?? senderName;
            senderAvatarUrl =
                AvatarAssetUtils.resolveUrl(latestMsg.senderAvatar);
            messageContent = latestMsg.content;
          }
        }
      } catch (_) {}
    } else {
      conversationTitle = null;
    }

    // ✅ ۱. دانلود هوشمند عکس پروفایل
    ByteArrayAndroidIcon? personIcon;
    ByteArrayAndroidBitmap? largeIcon;
    Uint8List? senderBytes;
    Uint8List? groupBytes;

    if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
      senderBytes = await _downloadFileWithCache(senderAvatarUrl);
    }
    if (isGroup && groupAvatarUrl != null && groupAvatarUrl.isNotEmpty) {
      groupBytes = await _downloadFileWithCache(groupAvatarUrl);
    }

    try {
      if (senderBytes != null) {
        final decodedSender = img.decodeImage(senderBytes);
        if (decodedSender != null) {
          final int size = decodedSender.width < decodedSender.height
              ? decodedSender.width
              : decodedSender.height;
          final squared = img.copyCrop(
            decodedSender,
            x: (decodedSender.width - size) ~/ 2,
            y: (decodedSender.height - size) ~/ 2,
            width: size,
            height: size,
          );
          final circled = img.copyCropCircle(squared, radius: size ~/ 2);
          final circledBytes = Uint8List.fromList(img.encodePng(circled));
          personIcon = ByteArrayAndroidIcon(circledBytes);
          if (!isGroup) {
            largeIcon = ByteArrayAndroidBitmap(circledBytes);
          }
        } else {
          personIcon = ByteArrayAndroidIcon(senderBytes);
          if (!isGroup) largeIcon = ByteArrayAndroidBitmap(senderBytes);
        }
      }

      if (isGroup) {
        if (groupBytes != null && senderBytes != null) {
          // ترکیب دو عکس برای گروه (عکس گروه در پس‌زمینه و عکس فرستنده در جلو) مثل تلگرام
          final compositeBytes =
              await _createGroupCompositeAvatar(groupBytes, senderBytes);
          if (compositeBytes != null) {
            largeIcon = ByteArrayAndroidBitmap(compositeBytes);
          } else {
            // در صورت خطا، فقط عکس گروه را به صورت گرد نمایش بده
            final decodedGroup = img.decodeImage(groupBytes);
            if (decodedGroup != null) {
              final int size = decodedGroup.width < decodedGroup.height
                  ? decodedGroup.width
                  : decodedGroup.height;
              final squared = img.copyCrop(
                decodedGroup,
                x: (decodedGroup.width - size) ~/ 2,
                y: (decodedGroup.height - size) ~/ 2,
                width: size,
                height: size,
              );
              final circled = img.copyCropCircle(squared, radius: size ~/ 2);
              largeIcon = ByteArrayAndroidBitmap(
                  Uint8List.fromList(img.encodePng(circled)));
            } else {
              largeIcon = ByteArrayAndroidBitmap(groupBytes);
            }
          }
        } else if (groupBytes != null) {
          // فقط عکس گروه وجود دارد
          final decodedGroup = img.decodeImage(groupBytes);
          if (decodedGroup != null) {
            final int size = decodedGroup.width < decodedGroup.height
                ? decodedGroup.width
                : decodedGroup.height;
            final squared = img.copyCrop(
              decodedGroup,
              x: (decodedGroup.width - size) ~/ 2,
              y: (decodedGroup.height - size) ~/ 2,
              width: size,
              height: size,
            );
            final circled = img.copyCropCircle(squared, radius: size ~/ 2);
            largeIcon = ByteArrayAndroidBitmap(
                Uint8List.fromList(img.encodePng(circled)));
          } else {
            largeIcon = ByteArrayAndroidBitmap(groupBytes);
          }
        } else if (personIcon != null && senderBytes != null) {
          // در نبود عکس گروه، عکس فرستنده را به عنوان آیکون بزرگ می‌گذاریم
          final decodedSender = img.decodeImage(senderBytes);
          if (decodedSender != null) {
            final int size = decodedSender.width < decodedSender.height
                ? decodedSender.width
                : decodedSender.height;
            final squared = img.copyCrop(
              decodedSender,
              x: (decodedSender.width - size) ~/ 2,
              y: (decodedSender.height - size) ~/ 2,
              width: size,
              height: size,
            );
            final circled = img.copyCropCircle(squared, radius: size ~/ 2);
            largeIcon = ByteArrayAndroidBitmap(
                Uint8List.fromList(img.encodePng(circled)));
          } else {
            largeIcon = ByteArrayAndroidBitmap(senderBytes);
          }
        }
      }
    } catch (e) {
      if (senderBytes != null) personIcon = ByteArrayAndroidIcon(senderBytes);
      if (groupBytes != null && isGroup) {
        largeIcon = ByteArrayAndroidBitmap(groupBytes);
      } else if (senderBytes != null && !isGroup) {
        largeIcon = ByteArrayAndroidBitmap(senderBytes);
      }
    }

    // ۲. ساخت Person با آیکون دانلود شده
    Person senderPerson = Person(
      name: senderName,
      icon: personIcon, // 🔥 اینجا عکس نمایش داده می‌شود
      key: data['sender_id']?.toString() ?? 'unknown',
      bot: false,
      important: true,
    );

    final message = Message(messageContent, DateTime.now(), senderPerson);

    final style = MessagingStyleInformation(
      senderPerson,
      groupConversation: isGroup,
      conversationTitle: conversationTitle,
      messages: [message],
    );

    // ۳. دکمه‌های اکشن (Reply / Read)
    final List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        'reply',
        'پاسخ',
        inputs: [
          AndroidNotificationActionInput(label: 'پیام خود را بنویسید...'),
        ],
        icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        showsUserInterface: false,
        allowGeneratedReplies: true,
      ),
      AndroidNotificationAction(
        'mark_read',
        'خواندم',
        icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'پیام‌های چت',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: style,
      largeIcon: largeIcon,
      groupKey: groupKey,
      color: AppColors.info,
      actions: actions,
      enableLights: true,
      ledColor: AppColors.info,
      ledOnMs: 1000,
      ledOffMs: 500,
      tag: groupKey,
      category: AndroidNotificationCategory.message,
    );

    // ۴. ساخت Payload
    final payloadJson = jsonEncode(data);

    await _flutterLocalNotifications.show(
      id: notificationId,
      title: conversationTitle ?? senderName,
      body: messageContent,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'CHAT_MESSAGE',
          threadIdentifier: conversationId,
        ),
      ),
      payload: payloadJson,
    );
  }

  Future<Uint8List?> _createGroupCompositeAvatar(
      Uint8List groupBytes, Uint8List senderBytes) async {
    try {
      final groupImage = img.decodeImage(groupBytes);
      final senderImage = img.decodeImage(senderBytes);
      if (groupImage == null || senderImage == null) return null;

      final int size = 150;
      final int senderSize = 74; // کمی بزرگتر تا واضح باشد
      final int senderX = size - senderSize - 4; // فاصله از لبه راست پایین
      final int senderY = size - senderSize - 4;

      // ساخت دایره برای عکس گروه
      final int gMin = groupImage.width < groupImage.height
          ? groupImage.width
          : groupImage.height;
      final gSquared = img.copyCrop(
        groupImage,
        x: (groupImage.width - gMin) ~/ 2,
        y: (groupImage.height - gMin) ~/ 2,
        width: gMin,
        height: gMin,
      );
      final gScaled = img.copyResize(gSquared, width: size, height: size);
      final groupCircled = img.copyCropCircle(gScaled, radius: size ~/ 2);

      // ساخت دایره برای عکس کاربر
      final int sMin = senderImage.width < senderImage.height
          ? senderImage.width
          : senderImage.height;
      final sSquared = img.copyCrop(
        senderImage,
        x: (senderImage.width - sMin) ~/ 2,
        y: (senderImage.height - sMin) ~/ 2,
        width: sMin,
        height: sMin,
      );
      final sScaled =
          img.copyResize(sSquared, width: senderSize, height: senderSize);
      final senderCircled =
          img.copyCropCircle(sScaled, radius: senderSize ~/ 2);

      // ساخت پس‌زمینه شفاف
      final composite = img.Image(width: size, height: size);

      // رسم عکس گروه
      img.compositeImage(composite, groupCircled);

      // بریدن قسمت زیرین عکس کاربر از عکس گروه (پاک کردن پیکسل‌ها)
      final cx = senderX + senderSize ~/ 2;
      final cy = senderY + senderSize ~/ 2;
      final cutoutRadius = (senderSize ~/ 2) + 6;
      final sqCutout = cutoutRadius * cutoutRadius;
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= sqCutout) {
            // شفاف کردن پیکسل
            composite.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }

      // رسم عکس کاربر روی قسمت بریده شده
      img.compositeImage(composite, senderCircled,
          dstX: senderX, dstY: senderY);

      return Uint8List.fromList(img.encodePng(composite));
    } catch (e) {
      return null;
    }
  }

  Future<void> _showStandardNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    final String? imageUrl =
        data['post_image'] ?? data['image_url'] ?? data['post_image_url'];
    ByteArrayAndroidBitmap? bigPicture;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // ✅ دانلود هوشمند تصویر پست
      final bytes = await _downloadFileWithCache(imageUrl);
      if (bytes != null) {
        bigPicture = ByteArrayAndroidBitmap(bytes);
      }
    }

    final String? senderAvatarUrl = AvatarAssetUtils.firstResolvedUrl(
      data['sender_avatar'],
      data['avatar_url'] ?? data['actor_avatar'],
    );
    ByteArrayAndroidBitmap? largeIcon;
    if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
      // ✅ دانلود عکس پروفایل برای نمایش به عنوان آیکون بزرگ
      final bytes = await _downloadFileWithCache(senderAvatarUrl);
      if (bytes != null) {
        // کراپ کردن عکس به صورت دایره‌ای برای اطمینان از گرد بودن در همه نسخه‌های اندروید
        try {
          final decodedImage = img.decodeImage(bytes);
          if (decodedImage != null) {
            final int size = decodedImage.width < decodedImage.height
                ? decodedImage.width
                : decodedImage.height;
            final squared = img.copyCrop(
              decodedImage,
              x: (decodedImage.width - size) ~/ 2,
              y: (decodedImage.height - size) ~/ 2,
              width: size,
              height: size,
            );
            final circled = img.copyCropCircle(squared, radius: size ~/ 2);
            final circledBytes = Uint8List.fromList(img.encodePng(circled));
            largeIcon = ByteArrayAndroidBitmap(circledBytes);
          } else {
            largeIcon = ByteArrayAndroidBitmap(bytes);
          }
        } catch (e) {
          largeIcon = ByteArrayAndroidBitmap(bytes);
        }
      }
    }

    StyleInformation? style;
    if (bigPicture != null) {
      style = BigPictureStyleInformation(
        bigPicture,
        contentTitle: data['sender_name']?.toString() ?? notification?.title,
        summaryText:
            data['content']?.toString() ?? notification?.body ?? 'اعلان جدید',
      );
    }

    final androidDetails = AndroidNotificationDetails(
      'social_notify',
      'فعالیت‌های اجتماعی',
      channelDescription: 'اعلان‌های اجتماعی (لایک، کامنت، دنبال‌کننده و ...)',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      styleInformation: style,
      largeIcon: largeIcon,
      icon: '@mipmap/ic_launcher',
      // تنظیمات LED
      enableLights: true,
      ledColor: AppColors.warning,
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final title = data['title']?.toString() ??
        data['sender_name']?.toString() ??
        notification?.title ??
        'Vista';
    String body = _buildReadableMessageBody(
      data,
      fallback: data['message']?.toString() ??
          data['content']?.toString() ??
          notification?.body ??
          'خبر جدید',
    );

    body = body.isNotEmpty
        ? body
        : data['message']?.toString() ??
            data['content']?.toString() ??
            notification?.body ??
            'خبر جدید';

    await _flutterLocalNotifications.show(
      id: stableNotificationId(
        'social:${data['notification_id'] ?? data['event_id'] ?? message.messageId ?? jsonEncode(data)}',
      ),
      title: title,
      body: _shorten(body),
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  // -----------------------------------------------------------------------------
  // 🔥 سیستم کشینگ پیشرفته فایل‌ها (بهینه برای نوتیفیکیشن)
  // -----------------------------------------------------------------------------

  /// ✅ متد اصلی مدیریت دانلود و کش
  /// 1. چک میکنه فایل تو حافظه گوشی هست؟ اگه بود همونو برمیگردونه.
  /// 2. اگه نبود دانلود میکنه و ذخیره میکنه.
  Future<Uint8List?> _downloadFileWithCache(String url) async {
    final resolvedUrl = AvatarAssetUtils.resolveUrl(url);
    if (resolvedUrl == null) return null;

    try {
      // ساخت نام فایل یکتا بر اساس URL (برای جلوگیری از تکرار)
      final fileName = _generateFileName(resolvedUrl);
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // ۱. اگر فایل وجود داشت و حجمش اوکی بود، از همون استفاده کن
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          // logInfo('📂 Loaded from cache: $fileName');
          return bytes;
        }
      }

      // ۲. اگر نبود، دانلود کن
      // logInfo('⬇️ Downloading: $url');
      final response = await http
          .get(Uri.parse(resolvedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // ۳. ذخیره در حافظه برای دفعه بعد
        await file.writeAsBytes(response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (e) {
      logInfo('⚠️ Cache/Download Error: $e');
    }
    return null;
  }

  /// تبدیل آدرس عکس به اسم فایل معتبر
  String _generateFileName(String url) {
    // ساده‌سازی URL برای تبدیل به نام فایل (حذف کاراکترهای خاص)
    return "${url.hashCode}.jpg";
  }

  // (Removed _downloadIconWithCache as it was unused)

  // -----------------------------------------------------------------------------

  /// Sync FCM token to backend after auth/session is ready.
  static Future<bool> syncTokenToBackend({String? token}) async {
    return syncIfNeeded(tokenHint: token, afterAuth: true);
  }

  /// Connect session lifecycle to automatic FCM registration.
  static void wireSessionHooks() {
    final sessionManager = SessionManagerServiceV2.instance;
    sessionManager.fcmSyncEpochAckProvider = getAckEpoch;
    sessionManager.onSessionTouchResult = handleTouchSyncHints;
    sessionManager.onSessionReadyForFcm = () => syncIfNeeded(afterAuth: true);
  }

  static Future<int> getAckEpoch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fcmSyncEpochAckKey) ?? 0;
  }

  static Future<void> setAckEpoch(int epoch) async {
    if (epoch <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fcmSyncEpochAckKey, epoch);
  }

  static Future<String?> _getLastSyncedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_fcmLastSyncedTokenKey)?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<bool> _hasSuccessfulSync() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_fcmLastSyncOkMsKey) ?? 0) > 0;
  }

  static Future<void> _markSyncSuccess({
    required String token,
    int? serverEpoch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmLastSyncedTokenKey, token);
    await prefs.setInt(
      _fcmLastSyncOkMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (serverEpoch != null && serverEpoch > 0) {
      await setAckEpoch(serverEpoch);
    }
  }

  /// Modern-style: sync only when token changed, after auth, or server epoch bump.
  static Future<bool> syncIfNeeded({
    String? tokenHint,
    bool afterAuth = false,
    bool tokenChanged = false,
    int? serverEpoch,
    bool serverRequested = false,
  }) async {
    final inFlight = _syncInFlight;
    if (inFlight != null) return inFlight;

    final future = _syncIfNeededInternal(
      tokenHint: tokenHint,
      afterAuth: afterAuth,
      tokenChanged: tokenChanged,
      serverEpoch: serverEpoch,
      serverRequested: serverRequested,
    );
    _syncInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    }
  }

  @Deprecated('Use syncIfNeeded instead')
  static Future<bool> ensureRegistered({
    bool force = false,
    int? serverEpoch,
    bool requireSync = false,
  }) {
    return syncIfNeeded(
      afterAuth: force,
      serverEpoch: serverEpoch,
      serverRequested: requireSync || force,
      tokenChanged: force,
    );
  }

  static Future<bool> _syncIfNeededInternal({
    String? tokenHint,
    bool afterAuth = false,
    bool tokenChanged = false,
    int? serverEpoch,
    bool serverRequested = false,
  }) async {
    try {
      final hasSession = await TokenStorage.hasValidSession();
      if (!hasSession) return false;
      if (Firebase.apps.isEmpty) return false;

      final ack = await getAckEpoch();
      final epochBump =
          serverRequested || (serverEpoch != null && serverEpoch > ack);

      if (!tokenChanged && !epochBump) {
        if (await _hasSuccessfulSync()) {
          final lastSynced = await _getLastSyncedToken();
          if (lastSynced != null && lastSynced.isNotEmpty) {
            if (tokenHint != null && tokenHint == lastSynced) {
              return true;
            }
            if (tokenHint == null && !afterAuth) {
              return true;
            }
          } else if (!afterAuth) {
            return true;
          }
        } else if (!afterAuth &&
            _lastFcmAttemptAt != null &&
            DateTime.now().difference(_lastFcmAttemptAt!) <
                _fcmMinRetryInterval) {
          return false;
        }
      }

      final service = PushNotificationService(null);
      final fcmToken = tokenHint ?? await service._firebaseMessaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        logInfo('FCM token is null or empty from Firebase');
        return false;
      }

      if (!tokenChanged && !epochBump) {
        final lastSynced = await _getLastSyncedToken();
        if (lastSynced == fcmToken && await _hasSuccessfulSync()) {
          return true;
        }
      }

      _lastFcmAttemptAt = DateTime.now();
      for (var attempt = 1; attempt <= 3; attempt++) {
        final synced = await SessionManagerServiceV2.instance.updateFcmToken(
          fcmToken,
        );
        if (synced) {
          logInfo('FCM token synced with Go backend session.');
          await _markSyncSuccess(token: fcmToken, serverEpoch: serverEpoch);
          // اطمینان از ثبت در user_devices با استفاده از endpoint اختصاصی
          unawaited(_registerFcmTokenDirect(fcmToken));
          return true;
        }
        if (attempt < 3) {
          logInfo('FCM token sync retry $attempt/3');
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      // در صورت شکست session touch، مستقیم با endpoint اختصاصی تلاش کن
      logInfo(
          'FCM session touch failed, attempting direct token registration...');
      final directOk = await _registerFcmTokenDirect(fcmToken);
      if (directOk) {
        logInfo('FCM token registered via direct endpoint.');
        await _markSyncSuccess(token: fcmToken, serverEpoch: serverEpoch);
        return true;
      }

      logInfo('FCM token sync failed: all attempts exhausted.');
      return false;
    } catch (e) {
      logInfo('Error syncing FCM token with backend: $e');
      return false;
    }
  }

  /// ثبت مستقیم token از طریق endpoint اختصاصی FCM (POST /v1/fcm/token)
  /// این مستقل از session state بوده و token را مستقیماً در user_devices ذخیره می‌کند
  static Future<bool> _registerFcmTokenDirect(String fcmToken) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return false;

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      final uri = Uri.parse('${EnvConfig.apiBaseUrl}/v1/fcm/token');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'token': fcmToken,
              'platform': platform,
              'device_type': 'mobile',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        logInfo('✅ FCM token registered via /v1/fcm/token');
        return true;
      }
      logInfo('⚠️ FCM direct registration failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      logInfo('⚠️ FCM direct registration error: $e');
      return false;
    }
  }

  static Future<void> handleTouchSyncHints(Map<String, dynamic> result) async {
    if (result['require_fcm_sync'] == true) {
      final epoch = _readEpoch(result['fcm_resync_epoch']);
      final ack = await getAckEpoch();
      if (epoch != null && epoch <= ack) return;

      unawaited(
        syncIfNeeded(
          serverEpoch: epoch,
          serverRequested: true,
          tokenChanged: true,
        ),
      );
      return;
    }

    // Never synced yet: one lightweight client-side retry (no extra server DB work).
    if (!(await _hasSuccessfulSync())) {
      unawaited(syncIfNeeded(afterAuth: true));
    }
  }

  static Future<void> handleSystemResyncEpoch(int? epoch) async {
    if (epoch == null || epoch <= 0) return;
    if (_lastSeenSystemEpoch == epoch) return;
    _lastSeenSystemEpoch = epoch;

    final ack = await getAckEpoch();
    if (epoch <= ack) return;

    unawaited(
      syncIfNeeded(
        serverEpoch: epoch,
        serverRequested: true,
        tokenChanged: true,
      ),
    );
  }

  static int? _readEpoch(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<bool> saveToken({String? token, int? serverEpoch}) async {
    return syncIfNeeded(
      tokenHint: token,
      afterAuth: true,
      serverEpoch: serverEpoch,
      serverRequested: serverEpoch != null,
    );
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedSubscription?.cancel();
    _onMessageOpenedSubscription = null;
    _listenersBound = false;
  }

  bool _isChatMessageType(String? type) {
    final normalized = (type ?? '').trim().toLowerCase();
    return normalized == 'chat_message' || normalized == 'message';
  }

  String _buildReadableMessageBody(
    Map<String, dynamic> data, {
    String fallback = 'پیام جدید',
  }) {
    final attachmentType = (data['attachment_type'] ?? data['attachmentType'])
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final rawContent =
        (data['content'] ?? data['message'] ?? '').toString().trim();
    final decodedMap = _tryParseJsonMap(rawContent);

    if (attachmentType == 'post' ||
        attachmentType == 'shared_post' ||
        _looksLikeSharedPostPayload(decodedMap)) {
      return _buildSharedPostPreview(decodedMap);
    }

    switch (attachmentType) {
      case 'image':
        return 'تصویر';
      case 'video':
        return 'ویدیو';
      case 'voice':
      case 'audio':
        return 'پیام صوتی';
      case 'gif':
        return 'GIF';
      case 'file':
      case 'document':
        return 'فایل';
    }

    if (rawContent.isEmpty) return fallback;
    // Secret-chat content arrives as an E2EE envelope the server can't read;
    // never show the raw ciphertext as the notification body.
    if (E2EEncryptionService().isEncryptedEnvelope(rawContent)) {
      return fallback;
    }
    final filtered = _filterLinksFromText(rawContent);
    return filtered.isEmpty ? fallback : filtered;
  }

  Map<String, dynamic>? _tryParseJsonMap(String raw) {
    if (raw.isEmpty || !raw.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  bool _looksLikeSharedPostPayload(Map<String, dynamic>? map) {
    if (map == null) return false;
    return map.containsKey('postId') ||
        map.containsKey('post_id') ||
        map.containsKey('postAuthorName') ||
        map.containsKey('authorName');
  }

  String _buildSharedPostPreview(Map<String, dynamic>? postMap) {
    if (postMap == null) {
      return 'یک پست به اشتراک گذاشته شد';
    }

    final content = (postMap['content'] ?? postMap['post_content'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .trim();

    if (content.isNotEmpty) {
      return _shorten(content, 70);
    }

    final author = (postMap['authorName'] ??
            postMap['postAuthorName'] ??
            postMap['post_author_name'] ??
            '')
        .toString()
        .trim();
    if (author.isNotEmpty) {
      return 'پست اشتراک‌گذاری‌شده از $author';
    }

    return 'یک پست به اشتراک گذاشته شد';
  }

  String _filterLinksFromText(String text) {
    if (text.isEmpty) return text;
    String filteredText = text;
    filteredText = filteredText.replaceAll(
      RegExp(r'https?://[^\s]*vista[^\s]*'),
      '',
    );
    filteredText = filteredText.replaceAll(
      RegExp(r'https?://[^\s]*post/[^\s]*'),
      '',
    );
    filteredText = filteredText.replaceAll(
      RegExp(r'https?://[^\s]*coffevista[^\s]*'),
      '',
    );
    filteredText = filteredText.replaceAll(
      RegExp(r'https?://[^\s]*arvan[^\s]*'),
      '',
    );
    filteredText = filteredText.replaceAll(RegExp(r'https?://[^\s]*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🖼️ آواتار:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🎥 ویدیو:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🏷️ تگ‌ها:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🔗.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'📝 پست از.*'), '');
    return filteredText.trim();
  }

  String _shorten(String text, [int maxLength = 80]) {
    if (text.length <= maxLength) return text;
    return "${text.substring(0, maxLength)}...";
  }

  @Deprecated('Use NotificationNavigationService.handleFCMPayload instead')
  void handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    NotificationNavigationService.handleFCMPayload(
      context: context,
      data: data,
    );
  }

  Future<bool> _markConversationAsRead(String conversationId) async {
    final trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) return false;

    try {
      final token = await _resolveAuthToken();
      if (token == null || token.isEmpty) return false;

      final deviceId = await DeviceIdService.getDeviceId();
      final uri = Uri.parse(
        '$_backendUrl/v1/chat/conversations/${Uri.encodeComponent(trimmedConversationId)}/read',
      );
      final response = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
        'X-Device-ID': deviceId,
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logInfo('mark read backend failed: ${response.statusCode}');
        return false;
      }

      await cancelConversationNotification(trimmedConversationId);
      return true;
    } catch (e) {
      logInfo('mark read backend failed: $e');
      return false;
    }
  }

  Future<String?> _resolveAuthToken() async {
    final sessionReady =
        await SessionManagerServiceV2.instance.ensureValidAuthSession();
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    if (!sessionReady) {
      logInfo(
          'quick reply auth session not fully refreshed; using cached token');
    }
    return token;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _resolveAuthToken();
    if (token == null || token.isEmpty) {
      throw StateError('missing auth token');
    }
    final deviceId = await DeviceIdService.getDeviceId();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
    };
  }

  Future<bool> _sendQuickReplyToBackend(
    String conversationId,
    String replyText,
  ) async {
    try {
      final headers = await _authorizedHeaders();
      final uri = Uri.parse(
        '$_backendUrl/v1/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
      );
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'id': _uuid.v4(),
              'content': replyText,
              'message_type': 'text',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      logInfo(
        'quick reply backend failed: ${response.statusCode} ${response.body}',
      );
      return false;
    } catch (e) {
      logInfo('quick reply backend failed: $e');
      return false;
    }
  }

  Future<bool> handleQuickReply(String conversationId, String replyText) async {
    final trimmedConversationId = conversationId.trim();
    final trimmedReply = replyText.trim();
    if (trimmedConversationId.isEmpty || trimmedReply.isEmpty) {
      return false;
    }

    try {
      logInfo('sending quick reply to conversation: $trimmedConversationId');
      logInfo('reply text: $trimmedReply');

      final sent = await _sendQuickReplyToBackend(
        trimmedConversationId,
        trimmedReply,
      );
      if (sent) {
        logInfo('quick reply sent successfully');
        await _markConversationAsRead(trimmedConversationId);
      }
      return sent;
    } catch (e) {
      logInfo('quick reply failed: $e');
      return false;
    }
  }

  void _addNotificationToProvider(RemoteMessage message) {
    try {
      if (ref != null) {
        final type = message.data['type']?.toString() ?? '';
        if (type == 'chat_message' || type == 'message') {
          return;
        }
        if ((message.data['notification_id']?.toString().isEmpty ?? true) &&
            (message.data['id']?.toString().isEmpty ?? true)) {
          return;
        }
        final notifier = ref!.read(notificationsProvider.notifier);
        notifier.addNotificationFromPush(message);
        logInfo(
          '✅ اعلان با موفقیت به provider اضافه شد: ${message.data['type']}',
        );
      }
    } catch (e) {
      logInfo('❌ خطا در اضافه کردن اعلان به provider: $e');
    }
  }

  /// ✅ تابع کمکی برای بررسی تنظیمات سراسری نوتیفیکیشن و Quiet Hours
  Future<bool> _shouldShowNotification(String type) async {
    try {
      final currentUserId = await TokenStorage.getUserId();
      if (currentUserId == null || currentUserId.isEmpty) return true;

      final settingsCache = SettingsCacheService();
      final settings =
          await settingsCache.getNotificationSettings(currentUserId);
      if (settings == null) return true;

      // بررسی نوع نوتیفیکیشن
      final bool pushEnabled = settings['push_notifications'] == true;
      if (!pushEnabled) return false;

      if (type == 'chat') {
        if (settings['message_notifications'] == false) return false;
      } else {
        // برای سوشال نوتیفیکیشن‌ها فرض می‌کنیم به طور کلی بر اساس pushEnabled کنترل می‌شود
        // می‌توان لاجیک پیچیده‌تری برای like/comment و... گذاشت
      }

      // بررسی Quiet Hours (ساعات سکوت)
      final bool quietHoursEnabled = settings['quiet_hours_enabled'] == true;
      if (quietHoursEnabled) {
        final String startStr =
            settings['quiet_hours_start']?.toString() ?? '22:00';
        final String endStr =
            settings['quiet_hours_end']?.toString() ?? '08:00';

        final now = DateTime.now();
        final currentMinutes = now.hour * 60 + now.minute;

        int parseTime(String t) {
          final parts = t.split(':');
          if (parts.length == 2) {
            return (int.tryParse(parts[0]) ?? 0) * 60 +
                (int.tryParse(parts[1]) ?? 0);
          }
          return 0;
        }

        final startMins = parseTime(startStr);
        final endMins = parseTime(endStr);

        bool inQuietHours = false;
        if (startMins <= endMins) {
          inQuietHours =
              currentMinutes >= startMins && currentMinutes <= endMins;
        } else {
          // از شب تا صبح روز بعد
          inQuietHours =
              currentMinutes >= startMins || currentMinutes <= endMins;
        }

        if (inQuietHours) {
          return false;
        }
      }

      return true;
    } catch (e) {
      logInfo('⚠️ Failed to check notification settings: $e');
      return true;
    }
  }
}
