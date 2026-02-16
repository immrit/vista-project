import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // ✅ کامل شد برای کار با فایل
import 'dart:typed_data'; // ✅ برای Uint8List
import 'package:path_provider/path_provider.dart'; // ✅ برای مسیردهی
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../provider/notification_provider.dart';
import '../utils/const.dart';
import 'notification_navigation_service.dart';
import 'current_chat_tracker.dart';
import 'local_notification_center.dart';
import '../features/chat/data/datasources/chat_local_datasource_isar.dart';
import '../model/message_model.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  PushNotificationService.enqueueBackgroundNotificationAction(
    notificationResponse,
  );
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

class PushNotificationService {
  final Ref? ref;
  PushNotificationService(this.ref);

  static const String _pendingActionsPrefsKey =
      'pending_notification_actions_v1';
  static const int _maxPendingActions = 30;
  static const Uuid _uuid = Uuid();

  static FlutterLocalNotificationsPlugin get notificationsPlugin =>
      LocalNotificationCenter.plugin;

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _flutterLocalNotifications = LocalNotificationCenter.plugin;
  static final Map<String, DateTime> _recentMessageEvents = {};

  // ✅ Getter امن برای Supabase (ممکن است در بک‌گراند initialize نشده باشد)
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final List<RemoteMessage> _notifications = [];
  List<RemoteMessage> get notifications => _notifications;

  StreamSubscription<AuthState>? _authStateSubscription;
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
    await _flutterLocalNotifications.cancel(conversationId.hashCode);
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

  Future<void> _processPendingNotificationActions() async {
    final supabase = _supabase;
    if (supabase == null || supabase.auth.currentUser == null) {
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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    final initSettings =
        InitializationSettings(android: androidInit, iOS: iOSInit);

    await _flutterLocalNotifications.initialize(
      initSettings,
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
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final conversationId = data['conversation_id']?.toString() ?? '';

      if (details.actionId == 'reply') {
        final input = details.input?.trim() ?? '';
        if (conversationId.isNotEmpty && input.isNotEmpty) {
          handleQuickReply(conversationId, input);
        }
        return;
      }

      if (details.actionId == 'mark_read') {
        if (conversationId.isNotEmpty) {
          _markConversationAsRead(conversationId);
        }
        return;
      }

      if (conversationId.isNotEmpty) {
        cancelConversationNotification(conversationId);
      }
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        NotificationNavigationService.handleFCMPayload(
          context: navContext,
          data: data,
        );
      }
    } catch (e) {
      logInfo('Error handling notification tap: $e');
    }
  }

  Future<void> init(BuildContext context) async {
    try {
      logInfo('🔔 Initializing Push Notification Service...');

      if (Firebase.apps.isEmpty) {
        logInfo(
            '⚠️ Firebase not initialized, skipping PushNotificationService init');
        return;
      }

      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

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

      await saveToken();
      await _processPendingNotificationActions();

      if (_listenersBound) {
        logInfo('✅ Push listeners already bound, skipping re-bind');
        return;
      }

      if (_supabase != null && _authStateSubscription == null) {
        _authStateSubscription =
            _supabase!.auth.onAuthStateChange.listen((data) {
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed) {
            logInfo('👤 User Signed In/Refreshed. Updating Token...');
            saveToken();
            _processPendingNotificationActions();
          }
        });
      }

      _tokenRefreshSubscription =
          _firebaseMessaging.onTokenRefresh.listen((newToken) {
        saveToken(token: newToken);
      });

      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logInfo('📱 Foreground Message: ${message.data}');
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
        final navContext = navigatorKey.currentContext;
        if (navContext != null) {
          NotificationNavigationService.handleFCMPayload(
            context: navContext,
            data: message.data,
          );
        }
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
    if (_isRecentDuplicate(message)) {
      logInfo('⚠️ Duplicate background FCM ignored');
      return;
    }
    // When system notification payload exists, avoid showing a second local one.
    if (message.notification != null) {
      logInfo('ℹ️ Skipping local background notification (system handled)');
      return;
    }
    if (!_shouldShowBackgroundLocalNotification(message)) {
      logInfo(
          'ℹ️ Background local notification disabled by single-path policy');
      if (message.data['type']?.toString() == 'chat_message') {
        // Keep offline fallback so incoming chat message appears in local cache.
        await _saveMessageToLocalDB(message.data);
      }
      return;
    }
    await _showNotification(message);
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (type == 'chat_message') {
      if (_isChatForActiveConversation(data)) {
        return;
      }
      // ✅ Fallback: Save to Local DB immediately
      await _saveMessageToLocalDB(data);
      await _showMessagingStyleNotification(data);
    } else {
      await _showStandardNotification(message);
    }
  }

  /// ✅ Fallback: Save incoming FCM message to Isar
  /// This ensures message appears in chat even if Realtime is disconnected.
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
          // Sometimes Supabase sends timestamp as int in string (milliseconds)
          if (createdAt.year < 2000) {
            final millis = int.tryParse(timestamp);
            if (millis != null) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(millis);
            }
          }
        }
      }

      final senderName = data['sender_name']?.toString() ?? 'User';
      // We don't have full profile profile here, but we have enough for the message list
      // Note: MessageModel usually needs just senderId.

      // Check current user to determine 'isMyMessage'
      final currentUser = _supabase?.auth.currentUser;
      final currentUserId = currentUser?.id ?? '';

      // Construct MessageModel
      // Note: We need to match the JSON structure MessageModel expects, OR use constructor.
      // MessageModel.fromJson expects database columns usually.
      // Let's manually construct it to be safe.

      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        content: content ?? '',
        createdAt: createdAt,
        isSeen: false,
        isSent: true, // It came from server, so it is sent.
        isDelivered: true,
        messageType: 'text', // Use 'messageType', not 'type'. Default to text.
        replyToMessageId: data['reply_to_message_id']?.toString(),
        // isEdited: false, // Not in constructor
        // isDeleted: false, // Not in constructor
        isMe: currentUserId == senderId, // ✅ Required field
        senderName: senderName,
        senderAvatar: data['sender_avatar'],
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
      Map<String, dynamic> data) async {
    final String? conversationId = data['conversation_id']?.toString();

    if (conversationId == null || conversationId.isEmpty) return;
    if (_isChatForActiveConversation(data)) return;

    final int notificationId = conversationId.hashCode;
    final String groupKey = conversationId;
    final String senderName = data['sender_name']?.toString() ?? 'کاربر';
    final String messageContent = data['content']?.toString() ?? 'پیام جدید';
    final String? senderAvatarUrl = data['sender_avatar'];

    // ✅ ۱. دانلود هوشمند عکس پروفایل
    ByteArrayAndroidIcon? personIcon;
    if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
      // از همان تابع کش که قبلاً نوشتیم استفاده می‌کنیم
      personIcon = await _downloadIconWithCache(senderAvatarUrl);
    }

    // ۲. ساخت Person با آیکون دانلود شده
    Person senderPerson = Person(
      name: senderName,
      icon: personIcon, // 🔥 اینجا عکس نمایش داده می‌شود
      key: data['sender_id']?.toString() ?? 'unknown',
      bot: false,
      important: true,
    );

    final message = Message(
      messageContent,
      DateTime.now(),
      senderPerson,
    );

    final style = MessagingStyleInformation(
      senderPerson,
      groupConversation: data['is_group'] == 'true',
      conversationTitle: data['is_group'] == 'true' ? senderName : null,
      messages: [message],
    );

    // ۳. دکمه‌های اکشن (Reply / Read)
    final List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        'reply',
        'پاسخ',
        inputs: [
          AndroidNotificationActionInput(label: 'پیام خود را بنویسید...')
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
      groupKey: groupKey,
      color: const Color(0xFF2196F3),
      actions: actions,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      tag: groupKey,
      category: AndroidNotificationCategory.message,
    );

    // ۴. ساخت Payload
    // اگر متد toPayloadJson در مدل ندارید، دستی می‌سازیم:
    final payloadJson = jsonEncode(data);

    await _flutterLocalNotifications.show(
      notificationId,
      senderName,
      messageContent,
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'CHAT_MESSAGE',
          threadIdentifier: conversationId,
        ),
      ),
      payload: payloadJson,
    );
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
      styleInformation: style,
      icon: '@mipmap/ic_launcher',
      // تنظیمات LED
      enableLights: true,
      ledColor: const Color(0xFFFF9800),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final title = data['title']?.toString() ??
        data['sender_name']?.toString() ??
        notification?.title ??
        'Vista';
    String body = data['message']?.toString() ??
        data['content']?.toString() ??
        notification?.body ??
        'خبر جدید';

    body = _filterLinksFromText(body);

    await _flutterLocalNotifications.show(
      message.hashCode,
      title,
      _shorten(body),
      NotificationDetails(
          android: androidDetails, iOS: const DarwinNotificationDetails()),
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
    try {
      // ساخت نام فایل یکتا بر اساس URL (برای جلوگیری از تکرار)
      final fileName = _generateFileName(url);
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
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

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

  /// ✅ نسخه مخصوص آیکون نوتیفیکیشن (برای استفاده در Person.icon)
  Future<ByteArrayAndroidIcon?> _downloadIconWithCache(String url) async {
    final bytes = await _downloadFileWithCache(url);
    if (bytes != null) {
      return ByteArrayAndroidIcon(bytes);
    }
    return null;
  }

  // -----------------------------------------------------------------------------

  Future<void> saveToken({String? token}) async {
    try {
      if (_supabase?.auth.currentUser == null) {
        logInfo('⚠️ Skipping Token Registration: User is NOT logged in.');
        return;
      }
      if (Firebase.apps.isEmpty) {
        logInfo('⚠️ Firebase not initialized, skipping FCM token save');
        return;
      }

      final fcmToken = token ?? await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        logInfo('⚠️ FCM Token is null');
        return;
      }

      final user = _supabase!.auth.currentUser;
      if (user == null) return;

      final deviceType = Platform.isIOS ? 'ios' : 'android';
      String deviceModel = 'Unknown';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = '${iosInfo.name} ${iosInfo.model}';
        }
      } catch (e) {
        deviceModel = 'Vista App';
      }

      String appVersion = '1.0.0';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {}

      logInfo('🔄 Registering Device for User: ${user.id}');
      await _supabase!.rpc('register_device', params: {
        'p_fcm_token': fcmToken,
        'p_device_type': deviceType,
        'p_device_model': deviceModel,
        'p_app_version': appVersion,
      });

      logInfo('✅ Device Token Registered in DB Successfully');
      logInfo('   User ID: ${user.id}');
      logInfo('   Device Type: $deviceType');
      logInfo('   Device Model: $deviceModel');
      logInfo('   App Version: $appVersion');
    } catch (e) {
      logInfo('❌ Error registering device in DB: $e');
    }
  }

  void dispose() {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedSubscription?.cancel();
    _onMessageOpenedSubscription = null;
    _listenersBound = false;
  }

  String _filterLinksFromText(String text) {
    if (text.isEmpty) return text;
    String filteredText = text;
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*vista[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*post/[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*coffevista[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*arvan[^\s]*'), '');
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
    if (_supabase == null) return false;

    try {
      await _supabase!.rpc('mark_conversation_as_read', params: {
        'p_conversation_id': trimmedConversationId,
      });
      await _flutterLocalNotifications.cancel(trimmedConversationId.hashCode);
      return true;
    } catch (rpcError) {
      logInfo(
          'mark_conversation_as_read RPC failed, trying fallback: $rpcError');
    }

    try {
      final currentUserId = _supabase!.auth.currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        return false;
      }
      await _supabase!
          .from('messages')
          .update({'is_seen': true})
          .eq('conversation_id', trimmedConversationId)
          .neq('sender_id', currentUserId)
          .eq('is_seen', false);
      await _supabase!
          .from('conversation_participants')
          .update({'unread_count': 0})
          .eq('conversation_id', trimmedConversationId)
          .eq('user_id', currentUserId);
      await _flutterLocalNotifications.cancel(trimmedConversationId.hashCode);
      return true;
    } catch (fallbackError) {
      logInfo('mark read fallback failed: $fallbackError');
      return false;
    }
  }

  Future<bool> _sendQuickReplyFallbackInsert(
    String conversationId,
    String replyText,
  ) async {
    final currentUserId = _supabase?.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': replyText,
      'message_type': 'text',
      'is_sent': true,
      'is_pending': false,
      'created_at': nowIso,
    };

    try {
      await _supabase!.from('messages').insert(payload);
      return true;
    } on PostgrestException catch (_) {
      final legacyPayload = Map<String, dynamic>.from(payload)
        ..remove('message_type')
        ..remove('is_pending');
      await _supabase!.from('messages').insert(legacyPayload);
      return true;
    } catch (e) {
      logInfo('quick reply fallback insert failed: $e');
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

      if (_supabase == null) {
        logInfo('Supabase client not initialized in isolate');
        return false;
      }

      await _supabase!.rpc('send_reply_message', params: {
        'p_conversation_id': trimmedConversationId,
        'p_content': trimmedReply,
      });

      logInfo('quick reply sent successfully');
      return true;
    } catch (e) {
      logInfo('send_reply_message RPC failed, trying fallback insert: $e');
      final fallbackSent = await _sendQuickReplyFallbackInsert(
        trimmedConversationId,
        trimmedReply,
      );
      if (!fallbackSent) {
        logInfo('quick reply failed after fallback: $e');
      }
      return fallbackSent;
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
            '✅ اعلان با موفقیت به provider اضافه شد: ${message.data['type']}');
      }
    } catch (e) {
      logInfo('❌ خطا در اضافه کردن اعلان به provider: $e');
    }
  }
}
