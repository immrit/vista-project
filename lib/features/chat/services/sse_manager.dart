// lib/features/chat/services/sse_manager.dart
//
// ✅ Singleton Realtime connection manager (Migrated to WebSocket)
// - یه کانکشن واحد به /v1/chat/ws
// - Reconnect با exponential backoff
// - Broadcast stream — همه provider ها از یه connection استفاده می‌کنن
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:Vista/utils/env_config.dart';

import '../../auth/providers/auth_controller.dart';
import '../../../services/session_manager_service_v2.dart';

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
  WebSocket? _activeClient;

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  // ─── Lifecycle ────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  void stop() {
    _running = false;
    _activeClient?.close();
    _activeClient = null;
    _setState(SseConnectionState.disconnected);
  }

  void reconnect() {
    _activeClient?.close();
    _activeClient = null;
  }

  // ─── Core loop with exponential backoff ───────────────────────────

  Future<void> _loop() async {
    var backoffSeconds = 1;

    while (_running) {
      _setState(SseConnectionState.connecting);

      try {
        final sessionReady =
            await SessionManagerServiceV2.instance.ensureValidAuthSession();
        if (!sessionReady) {
          debugPrint('SseManager: no valid session, waiting 5s...');
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        final token = await TokenStorage.getAccessToken();
        if (token == null || token.isEmpty) {
          debugPrint('SseManager: no token, waiting 5s...');
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        // تبدیل آدرس HTTP به آدرس استاندارد WebSocket
        var wsUrl = _backendUrl.replaceFirst('http', 'ws');
        if (wsUrl.endsWith('/')) {
          wsUrl = wsUrl.substring(0, wsUrl.length - 1);
        }
        wsUrl += '/v1/chat/ws';

        _activeClient = await WebSocket.connect(
          wsUrl,
          headers: {
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 15));

        // پینگ برای حفظ زنده بودن اتصال (بکند هم هر ۳۰ ثانیه می‌فرستد)
        _activeClient!.pingInterval = const Duration(seconds: 20);

        _setState(SseConnectionState.connected);
        backoffSeconds = 1; // ریست شدن زمان تایم‌اوت بعد از اتصال موفق

        await for (final dynamic message in _activeClient!) {
          if (!_running) break;
          
          if (message is String) {
            final parsed = _parseWsMessage(message);
            if (parsed != null) {
              _eventController.add(parsed);
            }
          }
        }
      } catch (e) {
        debugPrint('SseManager (WS): error: $e');
      }

      if (!_running) break;

      _setState(SseConnectionState.disconnected);
      _activeClient?.close();
      _activeClient = null;
      
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
      final data = event['data'];
      if (data is Map<String, dynamic>) {
        return data['conversation_id']?.toString() == conversationId;
      }
      return false;
    });
  }
}

