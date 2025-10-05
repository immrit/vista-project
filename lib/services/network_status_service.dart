import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// سرویس مدیریت وضعیت شبکه برای نمایش وضعیت اتصال به کاربر
class NetworkStatusService extends ChangeNotifier {
  static final NetworkStatusService _instance =
      NetworkStatusService._internal();
  factory NetworkStatusService() => _instance;
  NetworkStatusService._internal();

  bool _isOnline = true;
  bool _isInitialized = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  /// مقداردهی اولیه سرویس
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // بررسی وضعیت فعلی شبکه
      final result = await Connectivity().checkConnectivity();
      _isOnline = result != ConnectivityResult.none;

      // گوش دادن به تغییرات شبکه
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (ConnectivityResult result) {
          final wasOnline = _isOnline;
          _isOnline = result != ConnectivityResult.none;

          if (wasOnline != _isOnline) {
            if (kDebugMode) {
              print(
                  '🌐 Network status changed: ${_isOnline ? "Online" : "Offline"}');
            }
            notifyListeners();
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('❌ Network status monitoring error: $error');
          }
        },
      );

      _isInitialized = true;
      if (kDebugMode) {
        print(
            '✅ NetworkStatusService initialized - Status: ${_isOnline ? "Online" : "Offline"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize NetworkStatusService: $e');
      }
      // در صورت خطا، فرض کن که آنلاین هستیم
      _isOnline = true;
      _isInitialized = true;
    }
  }

  /// بررسی دستی وضعیت شبکه
  Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final isConnected = result != ConnectivityResult.none;

      if (_isOnline != isConnected) {
        _isOnline = isConnected;
        notifyListeners();
      }

      return isConnected;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Manual connectivity check failed: $e');
      }
      return _isOnline; // برگرداندن آخرین وضعیت شناخته شده
    }
  }

  /// دریافت پیام وضعیت شبکه
  String get statusMessage {
    if (!_isInitialized) return 'بررسی وضعیت شبکه...';
    return _isOnline ? 'آنلاین' : 'آفلاین';
  }

  /// دریافت رنگ وضعیت شبکه
  Color get statusColor {
    if (!_isInitialized) return Colors.orange;
    return _isOnline ? Colors.green : Colors.red;
  }

  /// دریافت آیکون وضعیت شبکه
  String get statusIcon {
    if (!_isInitialized) return '🔄';
    return _isOnline ? '🌐' : '📴';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
