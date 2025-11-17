import 'dart:async';

/// ✅ مدیریت Deferred Initialization - الگوی تلگرام
/// عملیات سنگین را تا زمان باز شدن کیبورد به تعویق می‌اندازد
class DeferredInitializationManager {
  static final DeferredInitializationManager _instance =
      DeferredInitializationManager._internal();
  factory DeferredInitializationManager() => _instance;
  DeferredInitializationManager._internal();

  final List<Future<void> Function()> _pendingTasks = [];
  bool _isProcessing = false;
  bool _isKeyboardVisible = false;
  Timer? _idleTimer;

  /// ✅ ثبت یک task برای اجرای بعدی
  void defer(Future<void> Function() task) {
    _pendingTasks.add(task);
    _scheduleProcessing();
  }

  /// ✅ اعلام باز شدن کیبورد - تمام taskها معلق می‌شوند
  void keyboardOpened() {
    _isKeyboardVisible = true;
    _idleTimer?.cancel();
    print('⌨️ Keyboard opened - pausing background tasks');
  }

  /// ✅ اعلام بسته شدن کیبورد - ادامه پردازش
  void keyboardClosed() {
    _isKeyboardVisible = false;
    _scheduleProcessing();
    print('⌨️ Keyboard closed - resuming background tasks');
  }

  /// ✅ زمان‌بندی پردازش taskها
  void _scheduleProcessing() {
    if (_isProcessing || _isKeyboardVisible) return;

    // صبر 300ms برای idle بودن UI
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 300), () {
      _processPendingTasks();
    });
  }

  /// ✅ پردازش taskهای معلق
  Future<void> _processPendingTasks() async {
    if (_isProcessing || _isKeyboardVisible || _pendingTasks.isEmpty) return;

    _isProcessing = true;

    while (_pendingTasks.isNotEmpty && !_isKeyboardVisible) {
      final task = _pendingTasks.removeAt(0);

      try {
        // اجرا در microtask برای جلوگیری از block کردن UI
        await Future.microtask(() async {
          await task();
        });

        // فاصله 16ms (یک frame) بین هر task
        await Future.delayed(const Duration(milliseconds: 16));
      } catch (e) {
        print('⚠️ Deferred task error: $e');
      }
    }

    _isProcessing = false;

    // اگر task باقی مانده باشد، دوباره schedule کن
    if (_pendingTasks.isNotEmpty) {
      _scheduleProcessing();
    }
  }

  /// ✅ پاک کردن تمام taskها
  void clear() {
    _pendingTasks.clear();
    _idleTimer?.cancel();
  }

  /// ✅ بررسی وضعیت
  bool get isKeyboardVisible => _isKeyboardVisible;
  bool get isProcessing => _isProcessing;
  int get pendingTasksCount => _pendingTasks.length;
}

