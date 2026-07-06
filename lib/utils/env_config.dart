import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class EnvConfig {
  // 1. Compile-time overrides via --dart-define.
  //    API_BASE_URL is canonical; BACKEND_URL is honored as a legacy alias so
  //    older build scripts keep working (previously the two keys drove two
  //    separate config paths and could point at different servers).
  static const String _apiDefine = String.fromEnvironment('API_BASE_URL');
  static const String _legacyBackendDefine =
      String.fromEnvironment('BACKEND_URL');
  static const String _wsDefine = String.fromEnvironment('WS_BASE_URL');
  static const String _releaseApiFallback =
      String.fromEnvironment('RELEASE_API_BASE_URL', defaultValue: '');
  static const String _releaseWsFallback =
      String.fromEnvironment('RELEASE_WS_BASE_URL', defaultValue: '');

  // 2. Dynamic getters that choose the best environment/IP
  static String get apiBaseUrl {
    if (_apiDefine.isNotEmpty) {
      return _apiDefine;
    }
    if (_legacyBackendDefine.isNotEmpty) {
      return _legacyBackendDefine;
    }

    if (kReleaseMode) {
      return _releaseApiFallback.isNotEmpty
          ? _releaseApiFallback
          : 'https://api.coffevista.ir';
    }

    if (kIsWeb) {
      return 'https://api.coffevista.ir';
    }

    if (Platform.isAndroid) {
      return 'https://api.coffevista.ir';
    }

    return 'https://api.coffevista.ir';
  }

  static String get wsBaseUrl {
    if (_wsDefine.isNotEmpty) {
      return _wsDefine;
    }

    if (kReleaseMode) {
      return _releaseWsFallback.isNotEmpty
          ? _releaseWsFallback
          : 'wss://api.coffevista.ir';
    }

    if (kIsWeb) {
      return 'wss://api.coffevista.ir';
    }

    if (Platform.isAndroid) {
      return 'wss://api.coffevista.ir';
    }

    return 'wss://api.coffevista.ir';
  }

  // P5: Supabase config removed — backend migrated off Supabase to the Go API.
  static const String paymentGateway = String.fromEnvironment(
      'PAYMENT_GATEWAY',
      defaultValue: 'bazaar'); // values: bazaar | zibal
}
