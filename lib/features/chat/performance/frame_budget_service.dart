import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'chat_performance_profile.dart';

class FrameBudgetService {
  FrameBudgetService._();
  static final FrameBudgetService instance = FrameBudgetService._();

  static const int _windowSize = 180;
  static const int _targetFrameMicros = 16667; // 60 FPS

  final List<int> _framesMicros = <int>[];
  bool _isMonitoring = false;
  bool _hasCallback = false;

  final ValueNotifier<FrameBudgetSnapshot> snapshotNotifier =
      ValueNotifier<FrameBudgetSnapshot>(const FrameBudgetSnapshot.empty());
  final ValueNotifier<ChatPerformanceProfile> profileNotifier =
      ValueNotifier<ChatPerformanceProfile>(ChatPerformanceProfile.high);

  bool get isMonitoring => _isMonitoring;

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    if (!_hasCallback) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _hasCallback = true;
    }
  }

  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    if (_hasCallback) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _hasCallback = false;
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_isMonitoring || timings.isEmpty) return;

    for (final timing in timings) {
      _framesMicros.add(timing.totalSpan.inMicroseconds);
    }

    if (_framesMicros.length > _windowSize) {
      _framesMicros.removeRange(0, _framesMicros.length - _windowSize);
    }

    if (_framesMicros.length < 12) return;

    final sorted = List<int>.from(_framesMicros)..sort();
    final p50 = _percentile(sorted, 0.50) / 1000.0;
    final p95 = _percentile(sorted, 0.95) / 1000.0;
    final p99 = _percentile(sorted, 0.99) / 1000.0;
    final jankCount =
        _framesMicros.where((value) => value > _targetFrameMicros).length;
    final jankRatio =
        _framesMicros.isEmpty ? 0.0 : jankCount / _framesMicros.length;

    final snapshot = FrameBudgetSnapshot(
      p50Ms: p50,
      p95Ms: p95,
      p99Ms: p99,
      jankRatio: jankRatio,
      sampleCount: _framesMicros.length,
    );
    snapshotNotifier.value = snapshot;

    profileNotifier.value = _toProfile(snapshot.p95Ms);
  }

  int _percentile(List<int> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = min(sorted.length - 1, max(0, (sorted.length * p).floor()));
    return sorted[index];
  }

  ChatPerformanceProfile _toProfile(double p95Ms) {
    if (p95Ms <= 16.7) {
      return ChatPerformanceProfile.high;
    }
    if (p95Ms <= 24.0) {
      return ChatPerformanceProfile.medium;
    }
    return ChatPerformanceProfile.low;
  }
}
