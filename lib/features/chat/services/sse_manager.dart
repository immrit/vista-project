// lib/features/chat/services/sse_manager.dart
//
// ✅ Singleton SSE connection manager
// - یه کانکشن واحد به /v1/chat/stream
// - Reconnect با exponential backoff
// - Broadcast stream — همه provider ها از یه connection استفاده می‌کنن
//

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../auth/providers/auth_controller.dart';

enum SseConnectionState { disconnected, connecting, connected }

class SseManager {
  SseManager._internal();
  static final SseManager instance = SseManager._internal();

  // ─── Public streams ───────────────────────────────────────────────
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  Stream<SseConnectionState> get connectionState async* {
    yield _currentState;
    yield* _stateController.stream;
  }

  SseConnectionState get currentState => _currentState;

  // ─── Internals ────────────────────────────────────────────────────
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<SseConnectionState>.broadcast();

  SseConnectionState _currentState = SseConnectionState.disconnected;
  bool _running = false;
  Dio? _activeClient;

  static String get _backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080';

  // ─── Lifecycle ────────────────────────────────────────────────────

  /// صدا زده بشه وقتی کاربر login می‌کنه یا app شروع میشه
  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  /// صدا زده بشه وقتی کاربر logout می‌کنه
  void stop() {
    _running = false;
    _activeClient?.close(force: true);
    _activeClient = null;
    _setState(SseConnectionState.disconnected);
  }

  /// برای reconnect فوری (مثلاً بعد از برگشتن app به foreground)
  void reconnect() {
    _activeClient?.close(force: true);
    _activeClient = null;
  }

  // ─── Core loop with exponential backoff ───────────────────────────

  Future<void> _loop() async {
    var backoffSeconds = 1;

    while (_running) {
      _setState(SseConnectionState.connecting);

      try {
        final token = await TokenStorage.getAccessToken();
        if (token == null || token.isEmpty) {
          debugPrint('SseManager: no token, waiting 5s...');
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        _activeClient = Dio(BaseOptions(
          baseUrl: _backendUrl,
          connectTimeout: const Duration(seconds: 10),
          // receiveTimeout نباشه — SSE بلند مدته
        ));

        final response = await _activeClient!.get<ResponseBody>(
          '/v1/chat/stream',
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );

        _setState(SseConnectionState.connected);
        backoffSeconds = 1; // reset backoff after successful connect

        String buffer = '';
        await for (final chunk in response.data!.stream) {
          if (!_running) break;
          buffer += utf8.decode(chunk);
          buffer = buffer.replaceAll('\r\n', '\n');

          while (buffer.contains('\n\n')) {
            final idx = buffer.indexOf('\n\n');
            final block = buffer.substring(0, idx).trim();
            buffer = buffer.substring(idx + 2);

            if (block.isEmpty || block.startsWith(':')) continue;

            final dataLine =
                block.startsWith('data: ') ? block.substring(6) : block;
            try {
              final decoded = json.decode(dataLine);
              if (decoded is Map<String, dynamic>) {
                _eventController.add(decoded);
              }
            } catch (_) {
              // ignore malformed events
            }
          }
        }
      } on DioException catch (e) {
        debugPrint('SseManager: DioException: ${e.message}');
      } catch (e) {
        debugPrint('SseManager: error: $e');
      }

      if (!_running) break;

      _setState(SseConnectionState.disconnected);
      debugPrint('SseManager: reconnecting in ${backoffSeconds}s...');
      await Future.delayed(Duration(seconds: backoffSeconds));
      backoffSeconds = (backoffSeconds * 2).clamp(1, 30);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _setState(SseConnectionState state) {
    if (_currentState == state) return;
    _currentState = state;
    _stateController.add(state);
  }

  /// Filter events برای یه conversation خاص
  Stream<Map<String, dynamic>> eventsForConversation(String conversationId) {
    return events.where((event) {
      final data = event['data'];
      if (data is Map<String, dynamic>) {
        return data['conversation_id']?.toString() == conversationId;
      }
      return false;
    });
  }
}
