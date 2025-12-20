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
import '../provider/notification_provider.dart';
import '../main.dart';
import 'notification_navigation_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

class PushNotificationService {
  final Ref? ref;
  PushNotificationService(this.ref);

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

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

  bool _isInitialized = false; // جلوگیری از initialize چندگانه

  /// ✅ تابع Initialize که هم در Foreground و هم Background استفاده می‌شود
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return; // جلوگیری از initialize چندگانه

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const initSettings =
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

  /// هندلر مرکزی کلیک روی اعلان (برای Foreground)
  void _onNotificationTap(NotificationResponse details) {
    if (details.payload != null) {
      try {
        final data = jsonDecode(details.payload!) as Map<String, dynamic>;
        final conversationId = data['conversation_id'];

        // ۱. هندل پاسخ سریع (Reply) در فورگراند
        if (details.actionId == 'reply' && details.input != null) {
          if (conversationId != null && _supabase != null) {
            handleQuickReply(conversationId.toString(), details.input!);
          }
        }
        // ۲. هندل دکمه "خواندم"
        else if (details.actionId == 'mark_read') {
          if (conversationId != null && _supabase != null) {
            _supabase!.rpc('mark_conversation_as_read', params: {
              'p_conversation_id': conversationId.toString(),
            });
            _flutterLocalNotifications.cancel(conversationId.hashCode);
          }
        }
        // ۳. کلیک عادی (باز کردن چت)
        else {
          final navContext = navigatorKey.currentContext;
          if (navContext != null) {
            NotificationNavigationService.handleFCMPayload(
              context: navContext,
              data: data,
            );
          }
        }
      } catch (e) {
        logInfo('❌ Error handling notification tap: $e');
      }
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

      _authStateSubscription?.cancel();
      if (_supabase != null) {
        _authStateSubscription =
            _supabase!.auth.onAuthStateChange.listen((data) {
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed) {
            logInfo('👤 User Signed In/Refreshed. Updating Token...');
            saveToken();
          }
        });
      }

      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // کانال چت (حیاتی برای نمایش درست در اندروید 8+)
      const androidChannel = AndroidNotificationChannel(
        'chat_messages',
        'پیام‌های چت',
        description: 'اعلان برای پیام‌های دریافتی',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // ✅ Initialize کردن پلاگین (یکپارچه برای foreground و background)
      await _ensureInitialized();

      await saveToken();

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        saveToken(token: newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logInfo('📱 Foreground Message: ${message.data}');
        _notifications.add(message);

        if (message.notification == null && message.data.isNotEmpty) {
          _showNotification(message);
        } else if (message.notification != null) {
          _showNotification(message);
        }

        if (ref != null) {
          _addNotificationToProvider(message);
        }
      });

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
    } catch (e) {
      logInfo('❌ خطا در راه‌اندازی PushNotificationService: $e');
    }
  }

  /// ✅ متد مخصوص بک‌گراند که اول Init میکند بعد نمایش میدهد
  Future<void> showBackgroundNotification(RemoteMessage message) async {
    // حیاتی: در بک‌گراند باید دستی Init کنیم تا استایل‌ها و اکشن‌ها کار کنند
    await _ensureInitialized();
    await _showNotification(message);
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (type == 'chat_message') {
      await _showMessagingStyleNotification(data);
    } else {
      await _showStandardNotification(message);
    }
  }

  /// 🎨 نمایش اعلان حرفه‌ای با عکس پروفایل دانلود شده
  Future<void> _showMessagingStyleNotification(
      Map<String, dynamic> data) async {
    final String? conversationId = data['conversation_id']?.toString();

    if (conversationId == null || conversationId.isEmpty) return;

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
        showsUserInterface: true,
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
          android: androidDetails, iOS: const DarwinNotificationDetails()),
      payload: payloadJson,
    );
  }

  Future<void> _showStandardNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    final String? imageUrl = data['post_image'];
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

  Future<void> handleQuickReply(String conversationId, String replyText) async {
    try {
      logInfo('📱 در حال ارسال پاسخ سریع به چت: $conversationId');
      logInfo('   متن پاسخ: $replyText');

      // اطمینان از اینکه کلاینت سوپابیس وجود دارد
      if (_supabase == null) {
        logInfo('⚠️ Supabase client not initialized in isolate');
        // اینجا در حالت واقعی باید دوباره Supabase.initialize کنید اگر نال بود
        return;
      }

      await _supabase!.rpc('send_reply_message', params: {
        'p_conversation_id':
            conversationId, // ✅ مطمئن شوید این ID درست پاس داده می‌شود
        'p_content': replyText,
      });

      logInfo('✅ پاسخ سریع با موفقیت ارسال شد');
    } catch (e) {
      logInfo('❌ خطا در ارسال پاسخ سریع: $e');
    }
  }

  void _addNotificationToProvider(RemoteMessage message) {
    try {
      if (ref != null) {
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
