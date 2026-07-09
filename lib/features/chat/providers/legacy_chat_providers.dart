import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/services/http_client_factory.dart';

import 'package:Vista/model/conversation_model.dart';
import 'package:Vista/model/message_model.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/services/user_profile_service.dart';
import 'package:Vista/security/logging_utility.dart';

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

class UserBlockNotifier extends StateNotifier<AsyncValue<void>> {
  UserBlockNotifier() : super(const AsyncValue.data(null));

  Future<Dio?> _authedDio() => createAuthedPinnedDio();

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

  Future<void> reportUser(String userId, String reason) async {
    state = const AsyncValue.loading();
    try {
      final dio = await createAuthedPinnedDio();
      if (dio == null) throw Exception('Not authenticated');
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

final userOnlineStatusStreamProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, userId) {
  return Stream.value(false);
});

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

final chatCacheSizeProvider = FutureProvider<String>((ref) async => '0 MB');
final profileCacheStatsProvider = Provider<Map<String, dynamic>>((ref) => {});

final messagesProvider = FutureProvider.family
    .autoDispose<List<dynamic>, String>((ref, conversationId) async {
  final result =
      await ref.watch(chatRepositoryProvider).getMessages(conversationId);
  return result.fold((data) => data, (error) => []);
});

final lazyMessagesProvider = Provider((ref) => null);

final cachedConversationsProvider = conversationsProvider;
final cachedConversationsStreamProvider = conversationsStreamProvider;

final userBlockStatusProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, userId) async* {
  final isBlocked =
      await ref.read(chatRepositoryProvider).isUserBlocked(userId);
  yield isBlocked;
});

final globalChatNotificationProvider = Provider<void>((ref) {});

final deleteOldMessagesProvider =
    FutureProvider.autoDispose.family<void, DateTime>((ref, cutoffDate) async {
  await Future.delayed(const Duration(seconds: 1));
});
