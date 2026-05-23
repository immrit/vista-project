import '../security/logging_utility.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NetworkStatusService extends ChangeNotifier {
  static final NetworkStatusService _instance =
      NetworkStatusService._internal();
  factory NetworkStatusService() => _instance;
  NetworkStatusService._internal();

  bool _isOnline = true;
  // ✅ اضافه شده: ذخیره نوع اتصال
  ConnectivityResult _connectionType = ConnectivityResult.none;
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  // ✅ اضافه شده: دسترسی به نوع اتصال
  ConnectivityResult get connectionType => _connectionType;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final result = await Connectivity().checkConnectivity();
      _updateStatus(result); // ✅ استفاده از تابع مشترک

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _updateStatus(results);
        },
        onError: (error) {
          if (kDebugMode) logInfo('❌ Network error: $error');
        },
      );

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) logInfo('❌ Failed to initialize: $e');
      _isOnline = true;
      _isInitialized = true;
    }
  }

  // ✅ تابع جدید برای مدیریت تغییرات
  void _updateStatus(List<ConnectivityResult> results) {
    final result = results.first;
    final wasOnline = _isOnline;
    final oldType = _connectionType;

    _isOnline = result != ConnectivityResult.none;
    _connectionType = result; // ذخیره نوع جدید

    // اگر وضعیت آنلاین/آفلاین یا نوع شبکه تغییر کرد
    if (wasOnline != _isOnline || oldType != _connectionType) {
      notifyListeners();
      if (kDebugMode) {
        print('🌐 Network Changed: $result (Online: $_isOnline)');
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // متدهای کمکی UI (رنگ و آیکون) همان‌طور که بود بماند...
  String get statusMessage => _isOnline ? 'آنلاین' : 'آفلاین';
  Color get statusColor => _isOnline ? Colors.green : Colors.red;

  /// ارائه یک آیکون متنی جهت نمایش سریع در بنر
  String get statusIcon {
    if (!_isInitialized) return '🔄';
    if (!_isOnline) return '📴';
    // آنلاین: نشانگر بر اساس نوع اتصال
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return '📶';
      case ConnectivityResult.mobile:
        return '📱';
      case ConnectivityResult.ethernet:
        return '🔌';
      default:
        return '🌐';
    }
  }

  /// متد کمکی برای بررسی دستی اتصال و بروزرسانی وضعیت
  Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateStatus(result);
      return _isOnline;
    } catch (e) {
      if (kDebugMode) logInfo('❌ Manual connectivity check failed: $e');
      return _isOnline;
    }
  }
}
