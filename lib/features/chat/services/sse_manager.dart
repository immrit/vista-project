// lib/features/chat/services/sse_manager.dart
//
// ✅ Singleton Realtime connection manager (Migrated to WebSocket)
// - یه کانکشن واحد به /v1/chat/ws
// - Reconnect با exponential backoff
// - Broadcast stream — همه provider ها از یه connection استفاده می‌کنن
//

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:Vista/utils/env_config.dart';
import 'package:Vista/security/logging_utility.dart';

import '../../auth/providers/auth_controller.dart';
import '../../../services/session_manager_service_v2.dart';

enum SseConnectionState { disconnected, connecting, connected }

/// Bounded replay protection for realtime envelopes.
///
/// Legacy events without an event ID remain supported during rollout. New
/// envelopes are accepted once even if Redis, WebSocket reconnect, or an
/// intermediary replays the same event.
class RealtimeEventDeduplicator {
  RealtimeEventDeduplicator({this.capacity = 1024})
      : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final Queue<String> _order = Queue<String>();
  final Set<String> _seen = <String>{};

  bool accept(Map<String, dynamic> event) {
    final eventId = event['event_id']?.toString().trim();
    if (eventId == null || eventId.isEmpty) return true;
    if (!_seen.add(eventId)) return false;
    _order.addLast(eventId);
    while (_order.length > capacity) {
      _seen.remove(_order.removeFirst());
    }
    return true;
  }

  void clear() {
    _order.clear();
    _seen.clear();
  }
}

class SseManager {
  SseManager._internal();
  static final SseManager instance = SseManager._internal();

  // ─── Public streams ───────────────────────────────────────────────
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// جریان رویدادهای یک `type` مشخص. رویدادها یک‌بار سمت manager بر اساس
  /// `type` مسیر‌دهی می‌شوند، پس شنونده‌ی مثلاً `reaction_updated` دیگر روی
  /// هر `new_message`/`typing`/`read_receipt` بیدار نمی‌شود. این جلوی هزینه‌ی
  /// O(listeners) روی هر رویداد را می‌گیرد؛ مهم‌ترین‌جا `watchReactions` که
  /// به‌ازای هر پیامِ قابل‌مشاهده یک شنونده می‌سازد.
  Stream<Map<String, dynamic>> eventsOfType(String type) {
    return _typeControllers
        .putIfAbsent(
            type, () => StreamController<Map<String, dynamic>>.broadcast())
        .stream;
  }

  Stream<SseConnectionState> get connectionState async* {
    yield _currentState;
    yield* _stateController.stream;
  }

  SseConnectionState get currentState => _currentState;

  // ─── Internals ────────────────────────────────────────────────────
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<SseConnectionState>.broadcast();
  // کنترلرهای per-type برای مسیردهی هدفمند رویدادها (به‌صورت lazy ساخته می‌شوند).
  final Map<String, StreamController<Map<String, dynamic>>> _typeControllers =
      {};
  final RealtimeEventDeduplicator _deduplicator = RealtimeEventDeduplicator();

  SseConnectionState _currentState = SseConnectionState.disconnected;
  bool _running = false;
  int _loopGeneration = 0;
  WebSocket? _activeClient;

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  // ─── Lifecycle ────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    final generation = ++_loopGeneration;
    unawaited(_loop(generation));
  }

  void stop() {
    _running = false;
    _loopGeneration++;
    _activeClient?.close();
    _activeClient = null;
    _deduplicator.clear();
    _setState(SseConnectionState.disconnected);
  }

  void reconnect() {
    _activeClient?.close();
    _activeClient = null;
  }

  // ─── Core loop with exponential backoff ───────────────────────────

  Future<void> _loop(int generation) async {
    var backoffSeconds = 1;

    while (_isCurrentLoop(generation)) {
      _setState(SseConnectionState.connecting);

      try {
        final sessionReady =
            await SessionManagerServiceV2.instance.ensureValidAuthSession();
        if (!sessionReady) {
          logInfo('SseManager: no valid session, waiting 5s...');
          await Future.delayed(const Duration(seconds: 5));
          if (!_isCurrentLoop(generation)) break;
          continue;
        }

        final token = await TokenStorage.getAccessToken();
        if (token == null || token.isEmpty) {
          logInfo('SseManager: no token, waiting 5s...');
          await Future.delayed(const Duration(seconds: 5));
          if (!_isCurrentLoop(generation)) break;
          continue;
        }

        // تبدیل آدرس HTTP به آدرس استاندارد WebSocket
        var wsUrl = _backendUrl.replaceFirst('http', 'ws');
        if (wsUrl.endsWith('/')) {
          wsUrl = wsUrl.substring(0, wsUrl.length - 1);
        }
        wsUrl += '/v1/chat/ws';

        // اگر timeout بخورد ولی connect بعداً resolve شود، سوکت باز می‌ماند و
        // نشت می‌کند — پس نتیجه‌ی دیرهنگام را حتماً ببند.
        final connectFuture = WebSocket.connect(
          wsUrl,
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        _activeClient = await connectFuture.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            unawaited(
                connectFuture.then((ws) => ws.close()).catchError((_) => null));
            throw TimeoutException('WebSocket connect timed out');
          },
        );
        if (!_isCurrentLoop(generation)) {
          await _activeClient?.close();
          _activeClient = null;
          break;
        }

        // پینگ برای حفظ زنده بودن اتصال (بکند هم هر ۳۰ ثانیه می‌فرستد)
        _activeClient!.pingInterval = const Duration(seconds: 20);

        _setState(SseConnectionState.connected);
        backoffSeconds = 1; // ریست شدن زمان تایم‌اوت بعد از اتصال موفق

        await for (final dynamic message in _activeClient!) {
          if (!_isCurrentLoop(generation)) break;

          if (message is String) {
            final parsed = _parseWsMessage(message);
            if (parsed != null && _deduplicator.accept(parsed)) {
              _eventController.add(parsed);
              // مسیردهی هدفمند به شنونده‌های همان type (اگر شنونده‌ای دارد).
              final type = parsed['type'];
              if (type is String) {
                _typeControllers[type]?.add(parsed);
              }
            }
          }
        }
      } catch (e) {
        logError('SseManager (WS): error: $e');
      }

      if (!_isCurrentLoop(generation)) break;

      _setState(SseConnectionState.disconnected);
      _activeClient?.close();
      _activeClient = null;

      final jitter = (math.Random().nextDouble() * 0.4) - 0.2; // +/- 20%
      final delaySeconds = (backoffSeconds * (1 + jitter)).toInt().clamp(1, 30);

      logInfo('SseManager: reconnecting in ${delaySeconds}s...');
      await Future.delayed(Duration(seconds: delaySeconds));
      if (!_isCurrentLoop(generation)) break;
      backoffSeconds = (backoffSeconds * 2).clamp(1, 30);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _setState(SseConnectionState state) {
    if (_currentState == state) return;
    _currentState = state;
    _stateController.add(state);
  }

  bool _isCurrentLoop(int generation) =>
      _running && generation == _loopGeneration;

  Map<String, dynamic>? _parseWsMessage(String payload) {
    if (payload.trim().isEmpty) return null;

    try {
      final decoded = json.decode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // نادیده گرفتن پیام‌های نامعتبر
    }
    return null;
  }

  Stream<Map<String, dynamic>> eventsForConversation(String conversationId) {
    return events.where((event) {
      if (event['conversation_id']?.toString() == conversationId) return true;
      final data = event['data'];
      if (data is Map<String, dynamic>) {
        return data['conversation_id']?.toString() == conversationId;
      }
      return false;
    });
  }
}
