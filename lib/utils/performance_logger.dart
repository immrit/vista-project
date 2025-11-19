import 'dart:collection';

/// ✅ Performance Logger - برای ردیابی زمان عملیات
class PerformanceLogger {
  static final Map<String, Stopwatch> _timers = {};
  static final Queue<Map<String, dynamic>> _history = Queue();
  static const int _maxHistorySize = 100;

  /// ✅ شروع تایمر
  static void start(String label) {
    _timers[label] = Stopwatch()..start();
  }

  /// ✅ پایان تایمر و نمایش نتیجه
  static void end(String label) {
    final timer = _timers[label];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds;
      
      print('⏱️ $label: ${duration}ms');
      
      // ذخیره در history
      _history.add({
        'label': label,
        'duration': duration,
        'timestamp': DateTime.now(),
      });
      
      // محدود کردن history
      if (_history.length > _maxHistorySize) {
        _history.removeFirst();
      }
      
      _timers.remove(label);
    }
  }

  /// ✅ دریافت آمار عملکرد
  static Map<String, dynamic> getStats() {
    if (_history.isEmpty) {
      return {
        'total_operations': 0,
        'average_duration': 0,
        'max_duration': 0,
        'min_duration': 0,
      };
    }

    final durations = _history.map((e) => e['duration'] as int).toList();
    final total = durations.reduce((a, b) => a + b);
    final average = total / durations.length;

    return {
      'total_operations': _history.length,
      'average_duration': average.toStringAsFixed(2),
      'max_duration': durations.reduce((a, b) => a > b ? a : b),
      'min_duration': durations.reduce((a, b) => a < b ? a : b),
    };
  }

  /// ✅ پاک کردن history
  static void clear() {
    _timers.clear();
    _history.clear();
  }

  /// ✅ نمایش آمار کامل
  static void printStats() {
    final stats = getStats();
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 PERFORMANCE STATS');
    print('Total Operations: ${stats['total_operations']}');
    print('Average Duration: ${stats['average_duration']}ms');
    print('Max Duration: ${stats['max_duration']}ms');
    print('Min Duration: ${stats['min_duration']}ms');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}








