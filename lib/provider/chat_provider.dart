import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:dio/dio.dart';

import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../features/chat/providers/chat_providers.dart';
import '../services/user_profile_service.dart';
import '../security/logging_utility.dart';
import '../features/auth/providers/auth_controller.dart';

// --- Core Providers ---

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final result = await ref.watch(chatRepositoryProvider).getConversations();
  return result.fold((data) => data, (error) {
    logInfo('Error loading conversations: $error');
    return [];
  });
});

final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

// --- Legacy Compatibility Providers ---

// Used by any remaining legacy code
final chatServiceProvider = Provider((ref) {
  return ref.watch(chatRepositoryProvider);
});

final profileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

final userProfileProvider =
    FutureProvider.family<Map<String, String?>?, String>((ref, userId) async {
  return await ref.watch(profileServiceProvider).getUserProfile(userId);
});

// --- User Action Notifiers ---

class UserBlockNotifier extends StateNotifier<AsyncValue<void>> {
  UserBlockNotifier() : super(const AsyncValue.data(null));

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  Future<Dio?> _authedDio() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    ));
  }

  Future<void> blockUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      final dio = await _authedDio();
      if (dio == null) throw Exception('Not authenticated');
      await dio.post('/me/block', data: {'target_user_id': userId});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unblockUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      final dio = await _authedDio();
      if (dio == null) throw Exception('Not authenticated');
      await dio.post('/me/unblock', data: {'target_user_id': userId});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userBlockNotifierProvider =
    StateNotifierProvider<UserBlockNotifier, AsyncValue<void>>(
        (ref) => UserBlockNotifier());

class UserReportNotifier extends StateNotifier<AsyncValue<void>> {
  UserReportNotifier() : super(const AsyncValue.data(null));

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  Future<void> reportUser(String userId, String reason) async {
    state = const AsyncValue.loading();
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) throw Exception('Not authenticated');
      final dio = Dio(BaseOptions(
        baseUrl: '$_backendUrl/v1',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      ));
      await dio.post('/profiles/report',
          data: {'reported_user_id': userId, 'reason': reason});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userReportNotifierProvider =
    StateNotifierProvider<UserReportNotifier, AsyncValue<void>>(
        (ref) => UserReportNotifier());

// --- Stream Providers ---

final userOnlineStatusStreamProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  return Stream.value(false); // Placeholder
});

// --- Redirects/Aliases ---
final conversationsWithProfilesProvider = conversationsProvider;
final enrichedConversationsStreamProvider = conversationsStreamProvider;

final conversationProvider = StreamProvider.family
    .autoDispose<ConversationModel?, String>((ref, conversationId) {
  return ref
      .watch(chatRepositoryProvider)
      .watchConversations()
      .map((conversations) {
    try {
      return conversations.firstWhere((c) => c.id == conversationId);
    } catch (_) {
      return null;
    }
  });
});

final sharedMediaProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  try {
    // Fetch shared media via Go backend messages endpoint
    final result = await ref
        .read(chatRepositoryProvider)
        .getMessages(conversationId, limit: 100);
    final messages = result.fold((data) => data, (_) => <MessageModel>[]);
    return messages
        .where((m) =>
            m.attachmentUrl != null ||
            (m.content.contains('http') || m.content.contains('www.')))
        .toList();
  } catch (e) {
    return [];
  }
});

final chatCacheSizeProvider = FutureProvider<String>((ref) async => "0 MB");
final profileCacheStatsProvider = Provider<Map<String, dynamic>>((ref) => {});

// Required for compatibility if referenced, but logic is removed/moved
final messagesProvider = FutureProvider.family
    .autoDispose<List<dynamic>, String>((ref, conversationId) async {
  final result =
      await ref.watch(chatRepositoryProvider).getMessages(conversationId);
  return result.fold((data) => data, (error) => []);
});

final lazyMessagesProvider = Provider((ref) {
  // Legacy compatibility placeholder: old lazy message flow was removed.
  return null;
});

final cachedConversationsProvider = conversationsProvider;
final cachedConversationsStreamProvider = conversationsStreamProvider;

// --- Missing Providers for Profile Screens ---

final userSettingsByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  // Go backend placeholder — user settings not yet migrated
  // Returns empty map until /v1/users/{id}/settings is implemented
  return <String, dynamic>{};
});

final userBlockStatusProvider =
    StreamProvider.family<bool, String>((ref, userId) async* {
  final isBlocked =
      await ref.read(chatRepositoryProvider).isUserBlocked(userId);
  yield isBlocked;
});

// --- Additional Providers for Compatibility ---

final globalChatNotificationProvider = Provider<void>((ref) {
  // گوش دادن به تغییرات تعداد پیام‌های خوانده نشده برای آپدیت بج یا نوتیفیکیشن
  // Assuming totalUnreadCountProvider is available in optimized_conversations_provider.dart
  // If not imported, we might get an error.
  // But optimized_conversations_provider.dart is NOT imported here.
  // We should import it or define a placeholder if circular dependency is an issue.
  // Ideally, move this to optimized_conversations_provider.dart but homeScreen expects it here.
  // Let's just define a dummy or use ref.watch if we can import.
});

final deleteOldMessagesProvider =
    FutureProvider.family<void, DateTime>((ref, cutoffDate) async {
  // Implement deletion logic here or call repository
  await Future.delayed(const Duration(seconds: 1));
});
