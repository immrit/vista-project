// lib/utils/network_utils.dart
//
// Utility functions برای کار با Network State
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/network_state.dart';
import '../provider/network_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 📦 EXTENSION METHODS
// ═══════════════════════════════════════════════════════════════════════════

/// Extension methods برای کار راحت‌تر با Network State
extension NetworkStateExtensions on WidgetRef {
  /// آیا اتصال برای ارسال پیام کافی است؟
  bool get canSendMessage {
    final state = read(currentNetworkStateProvider);
    return state.canSendMessage;
  }

  /// آیا باید media compress بشه؟
  bool get shouldCompressMedia {
    final state = read(currentNetworkStateProvider);
    return state.shouldCompressMedia;
  }

  /// آیا اتصال برای دانلود فایل کافی است؟
  bool get canDownloadMedia {
    final state = read(currentNetworkStateProvider);
    return state.canDownloadMedia;
  }

  /// کیفیت فعلی شبکه
  NetworkQuality get networkQuality {
    final state = read(currentNetworkStateProvider);
    return state.quality;
  }

  /// آیا آفلاین هستیم؟
  bool get isOffline {
    final state = read(currentNetworkStateProvider);
    return !state.isConnected;
  }

  /// آیا آنلاین هستیم؟
  bool get isOnline {
    final state = read(currentNetworkStateProvider);
    return state.isConnected;
  }

  /// نوع اتصال
  ConnectionType get connectionType {
    final state = read(currentNetworkStateProvider);
    return state.connectionType;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 💬 ERROR MESSAGES
// ═══════════════════════════════════════════════════════════════════════════

/// Helper function برای نمایش پیام خطا بر اساس وضعیت شبکه
String getNetworkErrorMessage(NetworkState state) {
  if (!state.isConnected) {
    return 'اتصال به اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.';
  }

  switch (state.quality) {
    case NetworkQuality.poor:
      return 'کیفیت اتصال بسیار ضعیف است. ممکن است عملیات با تأخیر انجام شود.';
    case NetworkQuality.fair:
      return 'کیفیت اتصال ضعیف است. برخی عملیات ممکن است کندتر باشند.';
    default:
      return 'خطایی رخ داده است. لطفاً دوباره تلاش کنید.';
  }
}

/// پیام کوتاه برای toast/snackbar
String getNetworkShortMessage(NetworkState state) {
  if (!state.isConnected) {
    return 'اتصال برقرار نیست';
  }

  switch (state.quality) {
    case NetworkQuality.poor:
      return 'اتصال ضعیف';
    case NetworkQuality.fair:
      return 'اتصال متوسط';
    case NetworkQuality.good:
      return 'اتصال خوب';
    case NetworkQuality.excellent:
      return 'اتصال عالی';
    case NetworkQuality.none:
      return 'بدون اتصال';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ WARNINGS & CHECKS
// ═══════════════════════════════════════════════════════════════════════════

/// بررسی و نمایش warning قبل از دانلود فایل بزرگ
bool shouldWarnBeforeDownload(NetworkState state, int fileSizeBytes) {
  // اگر آفلاین هستیم، اصلاً اجازه نده
  if (!state.isConnected) return true;

  // فایل‌های کوچک‌تر از 1MB همیشه OK هستن
  if (fileSizeBytes < 1024 * 1024) return false;

  // فایل‌های 1-5MB با کیفیت متوسط یا بالاتر OK هستن
  if (fileSizeBytes < 5 * 1024 * 1024) {
    return state.quality == NetworkQuality.poor;
  }

  // فایل‌های 5-10MB فقط با کیفیت خوب یا عالی OK هستن
  if (fileSizeBytes < 10 * 1024 * 1024) {
    return state.quality == NetworkQuality.poor ||
        state.quality == NetworkQuality.fair;
  }

  // فایل‌های بزرگ‌تر از 10MB فقط با کیفیت عالی و WiFi OK هستن
  return !(state.quality == NetworkQuality.excellent && state.isWifi);
}

/// پیام warning برای دانلود
String getDownloadWarningMessage(NetworkState state, int fileSizeBytes) {
  final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

  if (!state.isConnected) {
    return 'اتصال به اینترنت برقرار نیست. امکان دانلود وجود ندارد.';
  }

  if (state.isCellular && fileSizeBytes > 10 * 1024 * 1024) {
    return 'این فایل $sizeMB مگابایت است و از اینترنت موبایل استفاده می‌شود. آیا ادامه می‌دهید؟';
  }

  if (state.quality == NetworkQuality.poor) {
    return 'کیفیت اتصال ضعیف است. دانلود این فایل ($sizeMB مگابایت) ممکن است زمان‌بر باشد.';
  }

  if (state.quality == NetworkQuality.fair) {
    return 'کیفیت اتصال متوسط است. دانلود این فایل ($sizeMB مگابایت) ممکن است چند دقیقه طول بکشد.';
  }

  return 'آیا می‌خواهید این فایل ($sizeMB مگابایت) را دانلود کنید؟';
}

// ═══════════════════════════════════════════════════════════════════════════
// ⏱️ TIMEOUT CALCULATION
// ═══════════════════════════════════════════════════════════════════════════

/// محاسبه timeout مناسب بر اساس کیفیت شبکه
Duration getTimeoutDuration(NetworkQuality quality) {
  switch (quality) {
    case NetworkQuality.excellent:
      return const Duration(seconds: 10);
    case NetworkQuality.good:
      return const Duration(seconds: 20);
    case NetworkQuality.fair:
      return const Duration(seconds: 30);
    case NetworkQuality.poor:
      return const Duration(seconds: 45);
    case NetworkQuality.none:
      return const Duration(seconds: 5);
  }
}

/// محاسبه timeout برای آپلود بر اساس سایز فایل و کیفیت شبکه
Duration getUploadTimeout(NetworkQuality quality, int fileSizeBytes) {
  final baseTimeout = getTimeoutDuration(quality);
  final sizeMB = fileSizeBytes / (1024 * 1024);

  // هر مگابایت 5 ثانیه اضافه
  final additionalSeconds = (sizeMB * 5).toInt();

  return baseTimeout + Duration(seconds: additionalSeconds);
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 RETRY CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// تعداد retry مناسب بر اساس کیفیت شبکه
int getRetryCount(NetworkQuality quality) {
  switch (quality) {
    case NetworkQuality.excellent:
      return 2;
    case NetworkQuality.good:
      return 3;
    case NetworkQuality.fair:
      return 4;
    case NetworkQuality.poor:
      return 5;
    case NetworkQuality.none:
      return 1;
  }
}

/// تأخیر بین retry ها بر اساس کیفیت شبکه
Duration getRetryDelay(NetworkQuality quality, int attemptNumber) {
  final baseDelay = switch (quality) {
    NetworkQuality.excellent => const Duration(milliseconds: 500),
    NetworkQuality.good => const Duration(seconds: 1),
    NetworkQuality.fair => const Duration(seconds: 2),
    NetworkQuality.poor => const Duration(seconds: 3),
    NetworkQuality.none => const Duration(seconds: 5),
  };

  // Exponential backoff
  return baseDelay * (attemptNumber + 1);
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// رنگ بر اساس کیفیت شبکه
Color getQualityColor(NetworkQuality quality) {
  switch (quality) {
    case NetworkQuality.excellent:
      return Colors.green;
    case NetworkQuality.good:
      return Colors.lightGreen;
    case NetworkQuality.fair:
      return Colors.orange;
    case NetworkQuality.poor:
      return Colors.red;
    case NetworkQuality.none:
      return Colors.grey;
  }
}

/// آیکون بر اساس کیفیت شبکه
IconData getQualityIcon(NetworkQuality quality) {
  switch (quality) {
    case NetworkQuality.excellent:
      return Icons.signal_cellular_4_bar_rounded;
    case NetworkQuality.good:
      return Icons.signal_cellular_alt_rounded;
    case NetworkQuality.fair:
      return Icons.signal_cellular_alt_2_bar_rounded;
    case NetworkQuality.poor:
      return Icons.signal_cellular_alt_1_bar_rounded;
    case NetworkQuality.none:
      return Icons.signal_cellular_off_rounded;
  }
}

/// آیکون بر اساس نوع اتصال
IconData getConnectionTypeIcon(ConnectionType type) {
  switch (type) {
    case ConnectionType.wifi:
      return Icons.wifi_rounded;
    case ConnectionType.cellular:
      return Icons.signal_cellular_alt_rounded;
    case ConnectionType.ethernet:
      return Icons.settings_ethernet_rounded;
    case ConnectionType.vpn:
      return Icons.vpn_key_rounded;
    case ConnectionType.none:
      return Icons.signal_cellular_off_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📱 SNACKBAR HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// نمایش snackbar وضعیت شبکه
void showNetworkSnackBar(BuildContext context, NetworkState state) {
  final message = getNetworkShortMessage(state);
  final color = getQualityColor(state.quality);
  final icon = state.isConnected 
      ? getQualityIcon(state.quality) 
      : Icons.cloud_off_rounded;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(message),
          if (state.latencyMs != null) ...[
            const Spacer(),
            Text(
              '${state.latencyMs}ms',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// نمایش dialog هشدار شبکه
Future<bool> showNetworkWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'ادامه',
  String cancelText = 'انصراف',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result ?? false;
}

