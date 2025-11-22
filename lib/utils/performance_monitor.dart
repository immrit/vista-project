import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final List<Duration> _frameTimes = [];
  int _droppedFrames = 0;
  bool _isMonitoring = false;

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
    print('📊 Performance monitor started');
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    SchedulerBinding.instance.removeTimingsCallback(_handleTimings);
    _isMonitoring = false;
    print('📊 Performance monitor stopped');
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final frameDuration = timing.totalSpan;
      _frameTimes.add(frameDuration);
      if (frameDuration.inMilliseconds > 16) {
        _droppedFrames++;
        // Frame drop detection disabled to reduce log noise
      }
    }

    // محدود کردن به 120 فریم اخیر
    if (_frameTimes.length > 120) {
      _frameTimes.removeRange(0, _frameTimes.length - 120);
    }
  }

  void printStats() {
    if (_frameTimes.isEmpty) {
      print('📊 Performance monitor: no data yet');
      return;
    }

    final totalMicros = _frameTimes
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    final averageMicros = totalMicros / _frameTimes.length;
    final fps = averageMicros == 0 ? 0 : (1000000 / averageMicros);

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📈 PERFORMANCE STATS');
    print('Average frame: ${(averageMicros / 1000).toStringAsFixed(2)} ms');
    print('FPS: ${fps.toStringAsFixed(1)}');
    print('Dropped frames: $_droppedFrames');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}












