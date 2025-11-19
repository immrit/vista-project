import 'dart:async';
import 'package:flutter/material.dart';
import '../DB/advanced_settings_service.dart';
import '../security/logging_utility.dart';
import '../main.dart';

/// سرویس مدیریت قفل خودکار اپلیکیشن
class AutoLockService {
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  DateTime? _lastActiveTime;
  Timer? _lockTimer;
  bool _isLocked = false;
  bool _isInitialized = false;

  bool get isLocked => _isLocked;
  DateTime? get lastActiveTime => _lastActiveTime;

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _updateLastActiveTime();
    _startLockTimer();
    logInfo('🔒 Auto Lock Service initialized');
  }

  /// به‌روزرسانی زمان آخرین فعالیت
  void _updateLastActiveTime() {
    _lastActiveTime = DateTime.now();
  }

  /// شروع تایمر قفل خودکار
  void _startLockTimer() {
    _lockTimer?.cancel();

    try {
      final advancedService = AdvancedSettingsService();
      final appSettings = advancedService.getAdvancedAppSettings();
      final security = appSettings['security'] as Map<String, dynamic>? ?? {};
      final autoLockEnabled = security['auto_lock_enabled'] as bool? ?? false;
      final timeoutMinutes = security['auto_lock_timeout_minutes'] as int? ?? 5;

      if (!autoLockEnabled) {
        logInfo('🔓 Auto lock is disabled');
        return;
      }

      final timeout = Duration(minutes: timeoutMinutes);
      _lockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkAndLock(timeout);
      });

      logInfo('🔒 Auto lock timer started: ${timeoutMinutes} minutes');
    } catch (e) {
      logInfo('⚠️ Error starting auto lock timer: $e');
    }
  }

  /// بررسی و قفل کردن در صورت نیاز
  void _checkAndLock(Duration timeout) {
    if (_lastActiveTime == null) {
      _updateLastActiveTime();
      return;
    }

    final timeSinceLastActive = DateTime.now().difference(_lastActiveTime!);
    if (timeSinceLastActive >= timeout && !_isLocked) {
      _lockApp();
    }
  }

  /// قفل کردن اپلیکیشن
  void _lockApp() {
    if (_isLocked) return;

    _isLocked = true;
    logInfo('🔒 App auto-locked');

    // هدایت به صفحه لاگین
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth',
        (route) => false,
      );
    }
  }

  /// باز کردن قفل (بعد از لاگین موفق)
  void unlock() {
    _isLocked = false;
    _updateLastActiveTime();
    logInfo('🔓 App unlocked');
  }

  /// ثبت فعالیت کاربر
  void recordUserActivity() {
    if (_isLocked) return;
    _updateLastActiveTime();
  }

  /// به‌روزرسانی تنظیمات
  void refreshSettings() {
    _startLockTimer();
  }

  /// Dispose
  void dispose() {
    _lockTimer?.cancel();
    _isInitialized = false;
    logInfo('🧹 Auto Lock Service disposed');
  }
}


