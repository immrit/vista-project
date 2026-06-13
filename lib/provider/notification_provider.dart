import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_controller.dart';
import '../model/notificationModel.dart';
import '../security/logging_utility.dart';
import '../services/current_user_service.dart';
import '../services/local_notification_center.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    LocalNotificationCenter.plugin;

final userIdProvider = Provider<String?>((ref) {
  return CurrentUserService.cachedUserId;
});

const int _kPageSize = 20;

enum FollowRequestActionState { success, alreadyHandled, failed }

class FollowRequestActionResult {
  const FollowRequestActionResult(this.state, this.message);

  final FollowRequestActionState state;
  final String message;

  bool get isSuccess => state == FollowRequestActionState.success;
}

bool notificationTypeMatchesFilter(
  String notificationType,
  String? filterType,
) {
  if (filterType == null || filterType == 'all') return true;

  final canonicalType = NotificationModel.canonicalType(notificationType);
  final canonicalFilter = NotificationModel.canonicalType(filterType);

  switch (canonicalFilter) {
    case 'follow':
      return canonicalType == 'follow' ||
          canonicalType == 'follow_request' ||
          canonicalType == 'follow_request_accepted';
    case 'comment':
      return canonicalType == 'comment';
    case 'comment_reply':
      return canonicalType == 'comment_reply';
    case 'follow_request':
      return canonicalType == 'follow_request';
    case 'daily_suggestion_digest':
      return canonicalType == 'daily_suggestion_digest' ||
          canonicalType == 'suggest_follow' ||
          canonicalType == 'suggest_post';
    default:
      return canonicalType == canonicalFilter;
  }
}

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  static const bool _showRealtimeLocalNotifications = false;
  static const Duration _rateLimitCooldown = Duration(seconds: 30);

  NotificationsNotifier(this._ref) : super([]) {
    // Defer bootstrap so we never mutate sibling providers during init.
    Future.microtask(_bootstrap);
  }

  final Ref _ref;
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '${EnvConfig.apiBaseUrl}/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  String? _userId;
  int _page = 0;
  bool _isFetching = false;
  bool _hasMore = true;
  bool _isDisposed = false;
  DateTime? _nextAllowedFetchAt;

  bool get hasMore => _hasMore;
  bool get isFetching => _isFetching;

  Future<void> _bootstrap() async {
    _userId = _ref.read(userIdProvider) ??
        await CurrentUserService.instance.resolveUserId();
    if (_userId != null && !_isDisposed) {
      await fetchNotifications(refresh: true);
      _subscribeToNotificationRealtime();
    }
  }

  Future<String?> _resolveUserId() async {
    if (_userId != null && _userId!.isNotEmpty) return _userId;
    _userId = await CurrentUserService.instance.resolveUserId();
    return _userId;
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isFetching || _isDisposed) return;
    final nextAllowed = _nextAllowedFetchAt;
    if (nextAllowed != null && DateTime.now().isBefore(nextAllowed)) return;
    _isFetching = true;
    _publishFetchMeta();

    final userId = await _resolveUserId();
    if (userId == null) {
      if (!_isDisposed) state = [];
      _isFetching = false;
      _hasMore = false;
      _publishFetchMeta();
      return;
    }

    if (refresh && !_isDisposed) {
      _page = 0;
      _hasMore = true;
      state = [];
    }

    try {
      final offset = _page * _kPageSize;
      final response = await _dio.get(
        '/notifications',
        queryParameters: {'limit': _kPageSize, 'offset': offset},
        options: await _authOptions(),
      );
      if (_isDisposed) return;

      final rawItems = (response.data['notifications'] as List? ?? []);
      final notifications = rawItems
          .map((item) =>
              NotificationModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (refresh) {
        state = notifications;
      } else {
        final existingIds = state.map((n) => n.id).toSet();
        final newNotifications =
            notifications.where((n) => !existingIds.contains(n.id)).toList();
        state = [...state, ...newNotifications];
      }

      _hasMore = response.data['has_more'] == true;
      if (_hasMore) _page++;
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 429) {
        _nextAllowedFetchAt = DateTime.now().add(_rateLimitCooldown);
        logInfo('⚠️ Notifications rate-limited (429). Cooling down requests.');
      } else {
        logError('Failed to fetch notifications', error: e, stackTrace: st);
      }
      if (refresh && !_isDisposed) state = [];
      _hasMore = false;
    } catch (e, st) {
      logError('Failed to fetch notifications', error: e, stackTrace: st);
      if (refresh && !_isDisposed) state = [];
      _hasMore = false;
    } finally {
      _isFetching = false;
      _publishFetchMeta();
    }
  }

  void _publishFetchMeta() {
    if (_isDisposed) return;
    final isFetching = _isFetching;
    final hasMore = _hasMore;
    Future.microtask(() {
      if (_isDisposed) return;
      _ref.read(notificationsLoadingProvider.notifier).state = isFetching;
      _ref.read(notificationsHasMoreProvider.notifier).state = hasMore;
    });
  }

  Future<void> fetchMore() async {
    if (_hasMore && !_isFetching) {
      await fetchNotifications();
    }
  }

  void _subscribeToNotificationRealtime() {
    // Social notifications now arrive through FCM and are persisted by Go.
  }

  void _unsubscribe() {}

  String _filterLinksFromText(String text) {
    if (text.isEmpty) return text;
    var filteredText = text;
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*vista[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*post/[^\s]*'), '');
    filteredText = filteredText.replaceAll(
      RegExp(r'https?://[^\s]*coffevista[^\s]*'),
      '',
    );
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*arvan[^\s]*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'https?://[^\s]*'), '');
    return filteredText.trim();
  }

  Future<void> _showLocalNotification(NotificationModel notif) async {
    String? title;
    String? body;
    final senderUsername = notif.username.isNotEmpty ? notif.username : 'کاربر';
    final notificationType = NotificationModel.canonicalType(notif.type);

    switch (notificationType) {
      case 'like':
        title = 'لایک جدید';
        body = '$senderUsername پست شما را لایک کرد';
        break;
      case 'comment':
        title = 'نظر جدید';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'comment_reply':
        title = 'پاسخ به نظر شما';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'follow':
        title = 'دنبال کننده جدید';
        body = '$senderUsername شما را دنبال کرد';
        break;
      case 'follow_request':
        title = 'درخواست دنبال کردن';
        body = '$senderUsername درخواست دنبال کردن داد';
        break;
      case 'follow_request_accepted':
        title = 'درخواست پذیرفته شد';
        body = '$senderUsername درخواست دنبال کردن شما را پذیرفت';
        break;
      case 'message':
      case 'new_message':
        title = 'پیام جدید';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      default:
        title = 'اعلان';
        body = notif.content;
    }

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'social_notify',
          'فعالیت های اجتماعی',
          channelDescription: 'اعلان رویدادهای اجتماعی',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(notif.toPayloadJson()),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _unsubscribe();
    super.dispose();
  }

  Future<void> deleteAllNotifications() async {
    if (_isDisposed) return;
    final userId = await _resolveUserId();
    if (userId == null) {
      if (!_isDisposed) state = [];
      return;
    }

    try {
      await _dio.delete('/notifications', options: await _authOptions());
      if (!_isDisposed) state = [];
    } catch (e, st) {
      logError('Failed to delete all notifications', error: e, stackTrace: st);
    }
  }

  Future<void> markAllAsRead() async {
    if (_isDisposed) return;
    final userId = await _resolveUserId();
    if (userId == null) return;

    try {
      await _dio.post('/notifications/read-all', options: await _authOptions());
      if (!_isDisposed) {
        state = [
          for (final notification in state)
            if (!notification.isRead)
              notification.copyWith(isRead: true)
            else
              notification
        ];
      }
    } catch (e, st) {
      logError('Failed to mark all notifications as read',
          error: e, stackTrace: st);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_isDisposed || notificationId.isEmpty) return;
    final userId = await _resolveUserId();
    if (userId == null) return;

    try {
      await _dio.post(
        '/notifications/$notificationId/read',
        options: await _authOptions(),
      );
      if (!_isDisposed) {
        state = [
          for (final notification in state)
            if (notification.id == notificationId)
              notification.copyWith(isRead: true)
            else
              notification
        ];
      }
    } catch (e, st) {
      logError('Failed to mark notification as read', error: e, stackTrace: st);
    }
  }

  Future<void> refresh() async {
    await fetchNotifications(refresh: true);
  }

  Future<void> removeNotification(String notificationId) async {
    if (_isDisposed || notificationId.isEmpty) return;
    try {
      await _dio.delete('/notifications/$notificationId',
          options: await _authOptions());
      if (!_isDisposed) {
        state = state.where((n) => n.id != notificationId).toList();
      }
    } catch (e, st) {
      logError('Failed to remove notification', error: e, stackTrace: st);
    }
  }

  Future<void> removeFollowRequestById(String notificationId) async {
    if (_isDisposed || notificationId.isEmpty) return;
    await removeNotification(notificationId);
  }

  void _removeFollowRequestNotifications({
    required String requesterId,
    required String recipientId,
    String? notificationId,
  }) {
    if (_isDisposed) return;
    state = state.where((n) {
      if (notificationId != null && notificationId.isNotEmpty) {
        if (n.id == notificationId) return false;
      }
      return !(NotificationModel.canonicalType(n.type) == 'follow_request' &&
          n.senderId == requesterId &&
          n.recipientId == recipientId);
    }).toList(growable: false);
  }

  Future<FollowRequestActionResult> respondToFollowRequest({
    required String requesterId,
    required bool accept,
    String? notificationId,
  }) async {
    if (_isDisposed) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'سیستم اعلان در دسترس نیست',
      );
    }

    final userId = await _resolveUserId();
    if (userId == null) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'ابتدا وارد حساب کاربری شوید',
      );
    }
    if (requesterId.isEmpty || requesterId == userId) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'شناسه درخواست نامعتبر است',
      );
    }

    try {
      final response = await _dio.post(
        '/me/follow-request/respond',
        data: {'requester_id': requesterId, 'accept': accept},
        options: await _authOptions(),
      );
      _removeFollowRequestNotifications(
        requesterId: requesterId,
        recipientId: userId,
        notificationId: notificationId,
      );

      final message =
          response.data is Map ? response.data['message']?.toString() : null;
      return FollowRequestActionResult(
        FollowRequestActionState.success,
        message ?? (accept ? 'درخواست با موفقیت پذیرفته شد' : 'درخواست رد شد'),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _removeFollowRequestNotifications(
          requesterId: requesterId,
          recipientId: userId,
          notificationId: notificationId,
        );
        return const FollowRequestActionResult(
          FollowRequestActionState.alreadyHandled,
          'این درخواست قبلا مدیریت شده است',
        );
      }
      return FollowRequestActionResult(
        FollowRequestActionState.failed,
        'خطا در پردازش درخواست: ${e.message ?? e.response?.statusCode}',
      );
    } catch (e) {
      return FollowRequestActionResult(
        FollowRequestActionState.failed,
        'خطا در پردازش درخواست: $e',
      );
    }
  }

  void addNotificationFromPush(RemoteMessage message) {
    if (_isDisposed) return;
    try {
      final notification = NotificationModel.fromFCM(message);
      if (!state.any((n) => n.id == notification.id)) {
        state = [notification, ...state];
        if (_showRealtimeLocalNotifications) {
          _showLocalNotification(notification);
        }
      }
    } catch (e, st) {
      logError('Failed to add push notification', error: e, stackTrace: st);
    }
  }

  Future<void> checkConnectionAndRetry() async {
    if (_isDisposed) return;
    try {
      final userId = await _resolveUserId();
      if (userId == null) return;

      await _dio.get(
        '/notifications',
        queryParameters: {'limit': 1, 'offset': 0},
        options: await _authOptions(),
      );
      if (_isDisposed) return;
      if (state.isEmpty) {
        await fetchNotifications(refresh: true);
      }
    } catch (e, st) {
      logError('Notification connection check failed',
          error: e, stackTrace: st);
    }
  }
}

final notificationsProvider = StateNotifierProvider<
    NotificationsNotifier, List<NotificationModel>>(
  (ref) => NotificationsNotifier(ref),
);

final notificationsLoadingProvider = StateProvider<bool>((ref) => false);

final notificationsHasMoreProvider = StateProvider<bool>((ref) => true);

/// Single-pass unread counts for all notification tabs.
final unreadCountsByFilterProvider = Provider<Map<String, int>>((ref) {
  final notifications = ref.watch(notificationsProvider);
  const tabTypes = <String>[
    'all',
    'follow_request',
    'follow',
    'like',
    'comment',
    'comment_reply',
    'mention',
    'daily_suggestion_digest',
  ];

  final counts = <String, int>{
    for (final type in tabTypes) type: 0,
  };

  for (final notification in notifications) {
    if (notification.isRead) continue;
    counts['all'] = (counts['all'] ?? 0) + 1;
    for (final type in tabTypes) {
      if (type == 'all') continue;
      if (notificationTypeMatchesFilter(notification.type, type)) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
  }

  return counts;
});

final hasNewNotificationProvider = Provider.autoDispose<bool>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.any((n) => !n.isRead);
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((notification) => !notification.isRead).length;
});

final notificationCountByTypeProvider =
    Provider.family<int, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') return notifications.length;
  return notifications
      .where((notification) =>
          notificationTypeMatchesFilter(notification.type, type))
      .length;
});

final filteredNotificationsProvider =
    Provider.family<List<NotificationModel>, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') return notifications;
  return notifications
      .where((notification) =>
          notificationTypeMatchesFilter(notification.type, type))
      .toList();
});

final unreadNotificationCountByFilterProvider =
    Provider.family<int, String?>((ref, type) {
  final counts = ref.watch(unreadCountsByFilterProvider);
  final key = type ?? 'all';
  return counts[key] ?? 0;
});
