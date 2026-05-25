import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class EnvConfig {
  // 1. Compile-time overrides via --dart-define.
  static const String _apiDefine = String.fromEnvironment('API_BASE_URL');
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

    if (kReleaseMode) {
      return _releaseApiFallback.isNotEmpty
          ? _releaseApiFallback
          : 'https://api.coffevista.ir';
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
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
      return 'ws://localhost:8080';
    }

    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8080';
    }

    return 'ws://localhost:8080';
  }

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'YOUR_SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY');
}
