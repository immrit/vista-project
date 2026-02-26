import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:Vista/security/logging_utility.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';

part 'chat_connection_status_provider.g.dart';

enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
}

@riverpod
Stream<ConnectionStatus> chatConnectionStatus(
    ChatConnectionStatusRef ref) async* {
  // Initial status
  yield ConnectionStatus.connecting;

  try {
    final repo = ref.watch(chatRepositoryProvider);
    ConnectionStatus? lastStatus;
    await for (final status in repo.realtimeStatus) {
      final mapped = status == RealtimeSubscribeStatus.subscribed
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected;
      if (mapped == lastStatus) continue;
      lastStatus = mapped;
      yield mapped;
    }
  } catch (e) {
    logInfo('Connection Status Error: $e');
    yield ConnectionStatus.disconnected;
  }
}
