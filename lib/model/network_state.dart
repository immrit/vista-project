// lib/model/network_state.dart
//
// مدل وضعیت شبکه برای مدیریت Error Handling هوشمند
//

import 'package:equatable/equatable.dart';

/// کیفیت اتصال شبکه
enum NetworkQuality {
  excellent, // <50ms ping - عالی
  good, // 50-150ms ping - خوب
  fair, // 150-300ms ping - متوسط
  poor, // >300ms ping - ضعیف
  none, // آفلاین
}

/// نوع اتصال
enum ConnectionType {
  wifi,
  cellular,
  ethernet,
  vpn,
  none,
}

/// وضعیت شبکه
class NetworkState extends Equatable {
  final bool isConnected;
  final ConnectionType connectionType;
  final NetworkQuality quality;
  final DateTime lastChecked;
  final int? latencyMs; // Ping time
  final double? downloadSpeedMbps;

  const NetworkState({
    required this.isConnected,
    required this.connectionType,
    required this.quality,
    required this.lastChecked,
    this.latencyMs,
    this.downloadSpeedMbps,
  });

  /// وضعیت پیش‌فرض (آفلاین)
  factory NetworkState.initial() => NetworkState(
        isConnected: false,
        connectionType: ConnectionType.none,
        quality: NetworkQuality.none,
        lastChecked: DateTime.now(),
      );

  /// وضعیت آنلاین با کیفیت پیش‌فرض
  factory NetworkState.connected({
    ConnectionType type = ConnectionType.wifi,
    NetworkQuality quality = NetworkQuality.good,
    int? latencyMs,
  }) =>
      NetworkState(
        isConnected: true,
        connectionType: type,
        quality: quality,
        lastChecked: DateTime.now(),
        latencyMs: latencyMs,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 HELPER GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// آیا اتصال برای ارسال پیام کافی است؟
  bool get canSendMessage => isConnected && quality != NetworkQuality.none;

  /// آیا اتصال برای دانلود فایل کافی است؟
  bool get canDownloadMedia =>
      isConnected &&
      (quality == NetworkQuality.excellent || quality == NetworkQuality.good);

  /// آیا باید media quality رو کاهش بدیم؟
  bool get shouldCompressMedia =>
      quality == NetworkQuality.fair || quality == NetworkQuality.poor;

  /// آیا اتصال WiFi هست؟
  bool get isWifi => connectionType == ConnectionType.wifi;

  /// آیا اتصال Cellular هست؟
  bool get isCellular => connectionType == ConnectionType.cellular;

  /// آیا کیفیت خوب یا عالی هست؟
  bool get hasGoodQuality =>
      quality == NetworkQuality.excellent || quality == NetworkQuality.good;

  /// متن فارسی کیفیت
  String get qualityText {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'عالی';
      case NetworkQuality.good:
        return 'خوب';
      case NetworkQuality.fair:
        return 'متوسط';
      case NetworkQuality.poor:
        return 'ضعیف';
      case NetworkQuality.none:
        return 'قطع';
    }
  }

  /// متن فارسی نوع اتصال
  String get connectionTypeText {
    switch (connectionType) {
      case ConnectionType.wifi:
        return 'WiFi';
      case ConnectionType.cellular:
        return 'داده موبایل';
      case ConnectionType.ethernet:
        return 'کابل شبکه';
      case ConnectionType.vpn:
        return 'VPN';
      case ConnectionType.none:
        return 'قطع';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📋 COPY & EQUALITY
  // ═══════════════════════════════════════════════════════════════════════════

  NetworkState copyWith({
    bool? isConnected,
    ConnectionType? connectionType,
    NetworkQuality? quality,
    DateTime? lastChecked,
    int? latencyMs,
    double? downloadSpeedMbps,
  }) {
    return NetworkState(
      isConnected: isConnected ?? this.isConnected,
      connectionType: connectionType ?? this.connectionType,
      quality: quality ?? this.quality,
      lastChecked: lastChecked ?? this.lastChecked,
      latencyMs: latencyMs ?? this.latencyMs,
      downloadSpeedMbps: downloadSpeedMbps ?? this.downloadSpeedMbps,
    );
  }

  @override
  List<Object?> get props => [
        isConnected,
        connectionType,
        quality,
        lastChecked,
        latencyMs,
        downloadSpeedMbps,
      ];

  @override
  String toString() {
    return 'NetworkState(connected: $isConnected, type: $connectionType, '
        'quality: $quality, latency: ${latencyMs}ms)';
  }
}
