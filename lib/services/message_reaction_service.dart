import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import '../features/chat/services/sse_manager.dart';
import '../model/message_reaction.dart';
import '../security/logging_utility.dart';

class MessageReactionService {
  MessageReactionService();

  static String get _backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final Map<String, StreamSubscription<Map<String, dynamic>>> _subscriptions =
      {};

  Future<bool> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty || messageId.startsWith('temp_')) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/chat/messages/$messageId/reactions',
        data: {'emoji': emoji},
        options: await _authOptions(),
      );
      final reactions = _parseReactions(response.data);
      return reactions.any(
        (reaction) =>
            reaction.userId == userId &&
            reaction.messageId == messageId &&
            reaction.emoji == emoji,
      );
    } catch (e, stackTrace) {
      logError(
        'Failed to toggle chat reaction',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> addReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) {
    return toggleReaction(
      messageId: messageId,
      conversationId: conversationId,
      emoji: emoji,
    );
  }

  Future<void> removeReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty || messageId.startsWith('temp_')) {
      return;
    }

    final reactions = await getMessageReactions(messageId);
    final hasCurrentReaction = reactions.any(
      (reaction) =>
          reaction.userId == userId &&
          reaction.messageId == messageId &&
          reaction.emoji == emoji,
    );
    if (!hasCurrentReaction) return;

    await toggleReaction(
      messageId: messageId,
      conversationId: conversationId,
      emoji: emoji,
    );
  }

  Future<Map<String, List<String>>> getMessageReactionsSummary(
    String messageId,
  ) async {
    final reactions = await getMessageReactions(messageId);
    final grouped = <String, List<String>>{};
    for (final reaction in reactions) {
      grouped
          .putIfAbsent(reaction.emoji, () => <String>[])
          .add(reaction.userId);
    }
    return grouped;
  }

  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    if (messageId.startsWith('temp_')) return const [];
    try {
      final response = await _dio.get(
        '/chat/messages/$messageId/reactions',
        options: await _authOptions(),
      );
      return _parseReactions(response.data);
    } catch (e, stackTrace) {
      logError(
        'Failed to load chat reactions',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Stream<List<MessageReaction>> watchConversationReactions(
    String conversationId,
  ) {
    SseManager.instance.start();
    return SseManager.instance.events.where((event) {
      if (event['type'] != 'reaction_updated') return false;
      final data = event['data'];
      return data is Map &&
          data['conversation_id']?.toString() == conversationId;
    }).map(
      (event) => _parseReactionList((event['data'] as Map?)?['reactions']),
    );
  }

  void listenToReactions(String conversationId) {
    if (_subscriptions.containsKey(conversationId)) return;
    SseManager.instance.start();
    _subscriptions[conversationId] = SseManager.instance.events.where((event) {
      if (event['type'] != 'reaction_updated') return false;
      final data = event['data'];
      return data is Map &&
          data['conversation_id']?.toString() == conversationId;
    }).listen((_) {});
  }

  void stopListening(String conversationId) {
    unawaited(_subscriptions.remove(conversationId)?.cancel());
  }

  void dispose() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  List<MessageReaction> _parseReactions(dynamic payload) {
    if (payload is Map) return _parseReactionList(payload['reactions']);
    return const [];
  }

  List<MessageReaction> _parseReactionList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => MessageReaction.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
