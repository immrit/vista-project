import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/session_model.dart';
import '../services/session_manager_service.dart';

// Provider برای SessionManagerService
// استفاده از singleton instance برای اطمینان از یکسان بودن instance
final sessionManagerProvider = Provider<SessionManagerService>((ref) {
  return SessionManagerService.instance;
});

// Provider برای لیست نشست‌های فعال
final activeSessionsProvider =
    StreamProvider<List<SessionModel>>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.watchActiveSessions();
});

// Provider برای وضعیت نشست فعلی
final currentSessionProvider = Provider<String?>((ref) {
  final sessionManager = ref.watch(sessionManagerProvider);
  return sessionManager.currentSessionId;
});

// Provider برای تعداد نشست‌های فعال
final sessionCountProvider = Provider<int>((ref) {
  final sessionsAsync = ref.watch(activeSessionsProvider);
  return sessionsAsync.when(
    data: (sessions) => sessions.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});







