// lib/provider/network_provider.dart
//
// Provider های Riverpod برای مدیریت وضعیت شبکه
//

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/network_state.dart';
import '../services/network_state_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای NetworkStateService (Singleton)
final networkServiceProvider = Provider<NetworkStateService>((ref) {
  final service = NetworkStateService();

  // Cleanup on dispose
  ref.onDispose(() {
    // Note: Service is singleton, don't dispose it here
    // service.dispose();
  });

  return service;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📡 STREAM PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای stream وضعیت شبکه (Real-time)
/// 
/// استفاده:
/// ```dart
/// final networkAsync = ref.watch(networkStateStreamProvider);
/// networkAsync.when(
///   data: (state) => state.isConnected ? ... : ...,
///   loading: () => ...,
///   error: (e, s) => ...,
/// );
/// ```
final networkStateStreamProvider = StreamProvider<NetworkState>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.stateStream;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📊 CURRENT STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای وضعیت فعلی شبکه (synchronous)
/// 
/// استفاده:
/// ```dart
/// final networkState = ref.watch(currentNetworkStateProvider);
/// if (networkState.isConnected) { ... }
/// ```
final currentNetworkStateProvider = Provider<NetworkState>((ref) {
  // Watch stream to trigger rebuilds
  ref.watch(networkStateStreamProvider);

  // Return current state from service
  final service = ref.watch(networkServiceProvider);
  return service.currentState;
});

// ═══════════════════════════════════════════════════════════════════════════
// ✅ BOOLEAN PROVIDERS (برای استفاده راحت‌تر)
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای check کردن اتصال
/// 
/// استفاده:
/// ```dart
/// final isConnected = ref.watch(isConnectedProvider);
/// ```
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.isConnected;
});

/// Provider برای کیفیت شبکه
final networkQualityProvider = Provider<NetworkQuality>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.quality;
});

/// Provider برای check توانایی ارسال پیام
final canSendMessageProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.canSendMessage;
});

/// Provider برای check توانایی دانلود media
final canDownloadMediaProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.canDownloadMedia;
});

/// Provider برای check نیاز به فشرده‌سازی media
final shouldCompressMediaProvider = Provider<bool>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.shouldCompressMedia;
});

/// Provider برای نوع اتصال
final connectionTypeProvider = Provider<ConnectionType>((ref) {
  final state = ref.watch(currentNetworkStateProvider);
  return state.connectionType;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📈 STATS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای آمار شبکه
final networkStatsProvider = Provider<Map<String, dynamic>>((ref) {
  // Watch stream to get updates
  ref.watch(networkStateStreamProvider);
  
  final service = ref.watch(networkServiceProvider);
  return service.getStats();
});

// ═══════════════════════════════════════════════════════════════════════════
// 🎬 ACTIONS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای عملیات شبکه
/// 
/// استفاده:
/// ```dart
/// await ref.read(networkActionsProvider).refresh();
/// ```
final networkActionsProvider = Provider<NetworkActions>((ref) {
  final service = ref.watch(networkServiceProvider);
  return NetworkActions(service);
});

/// کلاس برای عملیات شبکه
class NetworkActions {
  final NetworkStateService _service;

  NetworkActions(this._service);

  /// رفرش وضعیت شبکه
  Future<void> refresh() async {
    await _service.refresh();
  }

  /// چک کردن توانایی انجام عملیات
  bool canPerform(NetworkOperation operation) {
    return _service.canPerform(operation);
  }

  /// گرفتن آمار
  Map<String, dynamic> getStats() {
    return _service.getStats();
  }

  /// زمان از آخرین قطعی
  Duration? get timeSinceDisconnect => _service.timeSinceDisconnect;
}

