import 'package:Vista/security/logging_utility.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../../features/auth/providers/auth_controller.dart';
import '../../../services/http_client_factory.dart';
import '../models/message_reaction.dart';
import 'sse_manager.dart';

class MessageReactionsService {
  final Dio _dio = createApiV1Dio(baseUrl: EnvConfig.apiBaseUrl);

  final Map<String, StreamController<List<MessageReaction>>> _controllers = {};
  final Map<String, List<MessageReaction>> _cache = {};
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;

  Future<MessageReaction?> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    if (messageId.startsWith('temp_')) return null;
    final response = await _dio.post(
      '/chat/messages/$messageId/reactions',
      data: {'emoji': emoji},
      options: await _authOptions(),
    );
    final reactions = _parseReactions(response.data);
    _publish(messageId, reactions);
    for (final reaction in reactions) {
      if (reaction.emoji == emoji) return reaction;
    }
    return null;
  }

  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    if (messageId.startsWith('temp_')) return const [];
    final response = await _dio.get(
      '/chat/messages/$messageId/reactions',
      options: await _authOptions(),
    );
    final reactions = _parseReactions(response.data);
    _publish(messageId, reactions);
    return reactions;
  }

  Future<Map<String, List<MessageReaction>>> getMultipleMessageReactions(
    List<String> messageIds,
  ) async {
    final validIds = messageIds
        .where((id) => id.isNotEmpty && !id.startsWith('temp_'))
        .toList(growable: false);
    if (validIds.isEmpty) return const {};

    final response = await _dio.post(
      '/chat/reactions/batch',
      data: {'message_ids': validIds},
      options: await _authOptions(),
    );
    final raw = response.data is Map ? response.data['reactions'] : null;
    final result = <String, List<MessageReaction>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final messageId = entry.key.toString();
        final reactions = _parseReactionList(entry.value);
        result[messageId] = reactions;
        _publish(messageId, reactions);
      }
    }
    return result;
  }

  Stream<List<MessageReaction>> watchMessageReactions(String messageId) {
    if (messageId.startsWith('temp_')) return Stream.value(const []);
    _ensureSseSubscription();
    final controller = _controllers.putIfAbsent(
      messageId,
      () => StreamController<List<MessageReaction>>.broadcast(
        onListen: () {
          controllerAdd(messageId, _cache[messageId] ?? const []);
        },
      ),
    );
    return controller.stream;
  }

  Future<void> removeAllUserReactions({required String messageId}) async {}

  Future<void> deleteAllMessageReactions(String messageId) async {}

  Future<Map<String, int>> getUserReactionStats(String userId) async =>
      const {};

  void dispose() {
    unawaited(_sseSubscription?.cancel());
    _sseSubscription = null;
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _cache.clear();
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  List<MessageReaction> _parseReactions(dynamic payload) {
    if (payload is Map) {
      return _parseReactionList(payload['reactions']);
    }
    return const [];
  }

  List<MessageReaction> _parseReactionList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => MessageReaction.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  void _publish(String messageId, List<MessageReaction> reactions) {
    _cache[messageId] = reactions;
    controllerAdd(messageId, reactions);
  }

  void controllerAdd(String messageId, List<MessageReaction> reactions) {
    final controller = _controllers[messageId];
    if (controller == null || controller.isClosed) return;
    controller.add(reactions);
  }

  void _ensureSseSubscription() {
    if (_sseSubscription != null) return;
    SseManager.instance.start();
    _sseSubscription = SseManager.instance.eventsOfType('reaction_updated').listen(
      (event) {
        final data = event['data'];
        if (data is! Map) return;
        final messageId = data['message_id']?.toString() ?? '';
        if (messageId.isEmpty) return;
        _publish(messageId, _parseReactionList(data['reactions']));
      },
      onError: (Object error, StackTrace stackTrace) {
        logInfo('MessageReactionsService SSE error: $error');
      },
    );
  }
}
