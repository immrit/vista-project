// lib/features/chat/providers/chat_connection_status_provider.dart
//
// Go backend realtime status provider
// وضعیت connection از SseManager واقعی خوانده میشه

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:Vista/security/logging_utility.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/features/chat/services/sse_manager.dart';

part 'chat_connection_status_provider.g.dart';

enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
}

@riverpod
Stream<ConnectionStatus> chatConnectionStatus(
    ChatConnectionStatusRef ref) async* {
  yield ConnectionStatus.connecting;

  try {
    final repo = ref.watch(chatRepositoryProvider);

    await for (final status in repo.realtimeStatus) {
      final mapped = switch (status) {
        SseConnectionState.connected => ConnectionStatus.connected,
        SseConnectionState.connecting => ConnectionStatus.connecting,
        SseConnectionState.disconnected => ConnectionStatus.disconnected,
      };
      yield mapped;
    }
  } catch (e) {
    logInfo('Connection Status Error: $e');
    yield ConnectionStatus.disconnected;
  }
}
