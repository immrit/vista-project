import 'dart:async';
import '../security/logging_utility.dart';

/// سرویس مدیریت قفل خودکار اپلیکیشن (اصلاح شده برای رفتار مثل ویستا)
class AutoLockService {
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  Timer? _lockTimer;
  bool _isInitialized = false;

  /// مقداردهی اولیه
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _startLockTimer();
    logInfo('🔒 Auto Lock Service initialized (Passive Mode - No Auto-Logout)');
  }

  /// شروع تایمر قفل خودکار
  void _startLockTimer() {
    _lockTimer?.cancel();
    logInfo('⏸️ Auto lock timer is disabled (Social Media Mode)');
  }

  /// باز کردن قفل
  void unlock() {
    logInfo('🔓 App unlocked (or never locked)');
  }

  /// ثبت فعالیت کاربر
  void recordUserActivity() {
    // متد خالی - قفل خودکار غیرفعال است
  }

  /// به‌روزرسانی تنظیمات
  void refreshSettings() {
    // متد خالی - قفل خودکار غیرفعال است
  }

  /// Dispose
  void dispose() {
    _lockTimer?.cancel();
    _isInitialized = false;
    logInfo('🧹 Auto Lock Service disposed');
  }
}
