import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:Vista/utils/env_config.dart';

import '../features/auth/providers/auth_controller.dart';
import '../utils/time_utils.dart';

enum UserPresenceStatus {
  online,
  away,
  offline,
  typing,
  recording,
}

enum LastSeenVisibility {
  everyone,
  myContacts,
  nobody,
}

class UserPresenceState {
  final String userId;
  final UserPresenceStatus status;
  final DateTime? lastOnline;
  final LastSeenVisibility visibility;
  final bool canViewLastSeen;
  final DateTime updatedAt;

  const UserPresenceState({
    required this.userId,
    required this.status,
    this.lastOnline,
    this.visibility = LastSeenVisibility.everyone,
    this.canViewLastSeen = true,
    required this.updatedAt,
  });

  bool get isOnline => status == UserPresenceStatus.online;
  bool get isTyping => status == UserPresenceStatus.typing;
  bool get isRecording => status == UserPresenceStatus.recording;
  bool get isAway => status == UserPresenceStatus.away;

  String get displayText {
    if (!canViewLastSeen) {
      return _getApproximateLastSeen();
    }

    switch (status) {
      case UserPresenceStatus.online:
        return 'آنلاین';
      case UserPresenceStatus.typing:
        return 'در حال نوشتن...';
      case UserPresenceStatus.recording:
        return 'در حال ضبط صدا...';
      case UserPresenceStatus.away:
      case UserPresenceStatus.offline:
        return TimeUtils.formatUserPresence(lastOnline);
    }
  }

  String _getApproximateLastSeen() {
    if (lastOnline == null) return 'آخرین بازدید: اخیرا';

    final diff = DateTime.now().difference(lastOnline!);
    if (diff.inDays < 1) return 'آخرین بازدید: اخیرا';
    if (diff.inDays < 7) return 'آخرین بازدید: این هفته';
    if (diff.inDays < 30) return 'آخرین بازدید: این ماه';
    return 'آخرین بازدید: مدتی پیش';
  }

  UserPresenceState copyWith({
    UserPresenceStatus? status,
    DateTime? lastOnline,
    LastSeenVisibility? visibility,
    bool? canViewLastSeen,
  }) {
    return UserPresenceState(
      userId: userId,
      status: status ?? this.status,
      lastOnline: lastOnline ?? this.lastOnline,
      visibility: visibility ?? this.visibility,
      canViewLastSeen: canViewLastSeen ?? this.canViewLastSeen,
      updatedAt: DateTime.now(),
    );
  }
}

class UserPresenceService with WidgetsBindingObserver {
  static final UserPresenceService _instance = UserPresenceService._internal();
  factory UserPresenceService() => _instance;
  UserPresenceService._internal();

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl ?? 'http://10.0.2.2:8080';

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '$_backendUrl/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  final Map<String, UserPresenceState> _presenceCache = {};
  final Map<String, StreamController<UserPresenceState>> _presenceStreams = {};
  final Map<String, Timer> _pollingTimers = {};

  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _currentUserId;

  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _pollingInterval = Duration(seconds: 20);
  static const Duration _cacheCleanupInterval = Duration(minutes: 5);

  Future<void> initialize() async {
    if (_isInitialized) return;

    _currentUserId = await TokenStorage.getUserId();
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint('UserPresenceService: user is not authenticated');
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    _startCacheCleanup();
    await _updateMyPresence(UserPresenceStatus.online);
    _isInitialized = true;
  }

  Stream<UserPresenceState> watchUserPresence(String userId) {
    if (_presenceStreams.containsKey(userId)) {
      return _presenceStreams[userId]!.stream;
    }

    late final StreamController<UserPresenceState> controller;
    controller = StreamController<UserPresenceState>.broadcast(
      onListen: () {
        controller.add(
          _presenceCache[userId] ??
              UserPresenceState(
                userId: userId,
                status: UserPresenceStatus.offline,
                updatedAt: DateTime.now(),
              ),
        );
        unawaited(refreshUserPresence(userId));
        _startPollingUser(userId);
      },
      onCancel: () {
        _pollingTimers.remove(userId)?.cancel();
        _presenceStreams.remove(userId)?.close();
      },
    );

    _presenceStreams[userId] = controller;
    return controller.stream;
  }

  Future<void> refreshUserPresence(String userId) async {
    try {
      final response = await _dio.get(
        '/presence/$userId',
        options: await _optionalAuthOptions(),
      );
      final state = _presenceFromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _presenceCache[userId] = state;
      _presenceStreams[userId]?.add(state);
    } catch (e) {
      debugPrint('Error fetching presence for $userId: $e');
      _emitFallbackPresence(userId);
    }
  }

  void _startPollingUser(String userId) {
    _pollingTimers.remove(userId)?.cancel();
    _pollingTimers[userId] = Timer.periodic(_pollingInterval, (_) {
      if (!_isDisposed) {
        unawaited(refreshUserPresence(userId));
      }
    });
  }

  Future<void> _updateMyPresence(UserPresenceStatus status) async {
    if (_currentUserId == null) return;

    try {
      final response = await _dio.post(
        '/presence/update',
        data: {'status': _presenceStatusToWire(status)},
        options: await _authOptions(),
      );
      final state = _presenceFromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      _presenceCache[state.userId] = state;
      _presenceStreams[state.userId]?.add(state);
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  Future<void> setTyping(String conversationId, bool isTyping) async {}

  UserPresenceState? getCachedPresence(String userId) {
    return _presenceCache[userId];
  }

  void invalidateCache(String userId) {
    _presenceCache.remove(userId);
    if (_presenceStreams.containsKey(userId)) {
      unawaited(refreshUserPresence(userId));
    }
  }

  void invalidateAllCaches() {
    final userIds = _presenceStreams.keys.toList(growable: false);
    _presenceCache.clear();
    for (final userId in userIds) {
      unawaited(refreshUserPresence(userId));
    }
  }

  Future<DateTime?> getLastSeen(String userId) async {
    await refreshUserPresence(userId);
    final presence = _presenceCache[userId];
    return presence != null && presence.canViewLastSeen
        ? presence.lastOnline
        : null;
  }

  Future<bool> canViewLastSeen(String userId) async {
    await refreshUserPresence(userId);
    return _presenceCache[userId]?.canViewLastSeen ?? false;
  }

  void _emitFallbackPresence(String userId) {
    final fallback = _presenceCache[userId] ??
        UserPresenceState(
          userId: userId,
          status: UserPresenceStatus.offline,
          updatedAt: DateTime.now(),
        );
    _presenceCache[userId] = fallback;
    _presenceStreams[userId]?.add(fallback);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isDisposed) {
        unawaited(_updateMyPresence(UserPresenceStatus.online));
      }
    });
  }

  void _startCacheCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      final now = DateTime.now();
      final staleKeys = _presenceCache.entries
          .where(
              (entry) => now.difference(entry.value.updatedAt).inMinutes > 10)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final key in staleKeys) {
        _presenceCache.remove(key);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_updateMyPresence(UserPresenceStatus.online));
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        unawaited(_updateMyPresence(UserPresenceStatus.away));
        _heartbeatTimer?.cancel();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_updateMyPresence(UserPresenceStatus.offline));
        _heartbeatTimer?.cancel();
        break;
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_updateMyPresence(UserPresenceStatus.offline));
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    for (final timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
    for (final controller in _presenceStreams.values) {
      controller.close();
    }
    _presenceStreams.clear();
    _presenceCache.clear();
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Options> _optionalAuthOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return Options();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  UserPresenceState _presenceFromJson(Map<String, dynamic> json) {
    final lastOnlineRaw = json['last_online_at']?.toString();
    return UserPresenceState(
      userId: json['user_id']?.toString() ?? '',
      status: _parsePresenceStatus(json['status']?.toString()),
      lastOnline: lastOnlineRaw != null && lastOnlineRaw.isNotEmpty
          ? DateTime.tryParse(lastOnlineRaw)?.toLocal()
          : null,
      visibility: _parseVisibility(json['visibility']?.toString()),
      canViewLastSeen: json['can_view_last_seen'] as bool? ?? false,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  UserPresenceStatus _parsePresenceStatus(String? raw) {
    switch (raw) {
      case 'online':
        return UserPresenceStatus.online;
      case 'away':
        return UserPresenceStatus.away;
      default:
        return UserPresenceStatus.offline;
    }
  }

  LastSeenVisibility _parseVisibility(String? raw) {
    switch (raw) {
      case 'my_contacts':
        return LastSeenVisibility.myContacts;
      case 'nobody':
        return LastSeenVisibility.nobody;
      default:
        return LastSeenVisibility.everyone;
    }
  }

  String _presenceStatusToWire(UserPresenceStatus status) {
    switch (status) {
      case UserPresenceStatus.online:
      case UserPresenceStatus.typing:
      case UserPresenceStatus.recording:
        return 'online';
      case UserPresenceStatus.away:
        return 'away';
      case UserPresenceStatus.offline:
        return 'offline';
    }
  }
}
