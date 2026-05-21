import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_presence_service.dart';

final presenceServiceProvider = Provider<UserPresenceService>((ref) {
  final service = UserPresenceService();
  unawaited(service.initialize());
  ref.onDispose(service.dispose);
  return service;
});

final userPresenceStreamProvider =
    StreamProvider.family.autoDispose<UserPresenceState, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.watchUserPresence(userId);
});

final cachedPresenceProvider =
    Provider.family<UserPresenceState?, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.getCachedPresence(userId);
});

final isUserOnlineProvider =
    Provider.family.autoDispose<bool, String>((ref, userId) {
  final presenceAsync = ref.watch(userPresenceStreamProvider(userId));
  return presenceAsync.maybeWhen(
    data: (state) => state.isOnline,
    orElse: () => false,
  );
});

final userStatusTextProvider =
    Provider.family.autoDispose<String, String>((ref, userId) {
  final presenceAsync = ref.watch(userPresenceStreamProvider(userId));
  return presenceAsync.maybeWhen(
    data: (state) => state.displayText,
    orElse: () => 'در حال بررسی...',
  );
});

class ChatHeaderPresenceState {
  final UserPresenceState? presence;
  final bool isTyping;
  final bool isRecording;
  final String? typingUserName;
  final bool isLoading;
  final String? error;

  const ChatHeaderPresenceState({
    this.presence,
    this.isTyping = false,
    this.isRecording = false,
    this.typingUserName,
    this.isLoading = false,
    this.error,
  });

  String get displayText {
    if (isTyping) return 'در حال نوشتن...';
    if (isRecording) return 'در حال ضبط صدا...';
    if (isLoading) return 'در حال بررسی...';
    if (error != null) return 'نامشخص';
    return presence?.displayText ?? 'آفلاین';
  }

  UserPresenceStatus get effectiveStatus {
    if (isTyping) return UserPresenceStatus.typing;
    if (isRecording) return UserPresenceStatus.recording;
    return presence?.status ?? UserPresenceStatus.offline;
  }

  bool get isOnline => presence?.isOnline ?? false;
}

final chatHeaderPresenceProvider = Provider.family.autoDispose<
    ChatHeaderPresenceState,
    ({String userId, String conversationId})>((ref, params) {
  final presenceAsync = ref.watch(userPresenceStreamProvider(params.userId));

  return presenceAsync.when(
    data: (presence) => ChatHeaderPresenceState(presence: presence),
    loading: () => const ChatHeaderPresenceState(isLoading: true),
    error: (error, _) => ChatHeaderPresenceState(error: error.toString()),
  );
});

final lastSeenProvider =
    FutureProvider.family<DateTime?, String>((ref, userId) async {
  return ref.watch(presenceServiceProvider).getLastSeen(userId);
});

final canViewLastSeenProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  return ref.watch(presenceServiceProvider).canViewLastSeen(userId);
});

class CurrentUserPresenceNotifier extends StateNotifier<UserPresenceStatus> {
  final UserPresenceService _service;
  Timer? _heartbeatTimer;

  CurrentUserPresenceNotifier(this._service)
      : super(UserPresenceStatus.online) {
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_service.initialize());
    });
  }

  void setOnline() {
    state = UserPresenceStatus.online;
  }

  void setAway() {
    state = UserPresenceStatus.away;
  }

  void setOffline() {
    state = UserPresenceStatus.offline;
    _heartbeatTimer?.cancel();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final currentUserPresenceProvider =
    StateNotifierProvider<CurrentUserPresenceNotifier, UserPresenceStatus>(
        (ref) {
  return CurrentUserPresenceNotifier(ref.watch(presenceServiceProvider));
});
