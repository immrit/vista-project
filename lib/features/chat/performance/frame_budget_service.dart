import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'chat_performance_profile.dart';
import 'device_capability_service.dart';

class FrameBudgetService {
  FrameBudgetService._();
  static final FrameBudgetService instance = FrameBudgetService._();

  static const int _windowSize = 180;
  static const int _targetFrameMicros = 16667; // 60 FPS

  final List<int> _framesMicros = <int>[];
  bool _isMonitoring = false;
  bool _hasCallback = false;
  bool _didApplyWarmStart = false;
  DevicePerformanceTier _deviceTier = DevicePerformanceTier.medium;
  String _warmStartReason = 'pending';

  final ValueNotifier<FrameBudgetSnapshot> snapshotNotifier =
      ValueNotifier<FrameBudgetSnapshot>(const FrameBudgetSnapshot.empty());
  final ValueNotifier<ChatPerformanceProfile> profileNotifier =
      ValueNotifier<ChatPerformanceProfile>(ChatPerformanceProfile.high);

  bool get isMonitoring => _isMonitoring;
  DevicePerformanceTier get deviceTier => _deviceTier;
  String get warmStartReason => _warmStartReason;

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _applyWarmStartProfileIfNeeded();
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

    profileNotifier.value = _toProfile(
      p95Ms: snapshot.p95Ms,
      jankRatio: snapshot.jankRatio,
      currentProfile: profileNotifier.value,
    );
  }

  int _percentile(List<int> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = min(sorted.length - 1, max(0, (sorted.length * p).floor()));
    return sorted[index];
  }

  ChatPerformanceProfile _toProfile({
    required double p95Ms,
    required double jankRatio,
    required ChatPerformanceProfile currentProfile,
  }) {
    // Hard guard for obvious instability.
    if (jankRatio >= 0.25 || p95Ms >= 32.0) {
      return ChatPerformanceProfile.low;
    }

    // Hysteresis: avoid profile flapping on noisy frame windows.
    switch (currentProfile) {
      case ChatPerformanceProfile.high:
        if (p95Ms > 19.0) return ChatPerformanceProfile.medium;
        return ChatPerformanceProfile.high;
      case ChatPerformanceProfile.medium:
        if (p95Ms > 27.0) return ChatPerformanceProfile.low;
        if (p95Ms < 15.5 && jankRatio < 0.08) {
          return ChatPerformanceProfile.high;
        }
        return ChatPerformanceProfile.medium;
      case ChatPerformanceProfile.low:
        if (p95Ms < 22.0 && jankRatio < 0.14) {
          return ChatPerformanceProfile.medium;
        }
        return ChatPerformanceProfile.low;
    }
  }

  void _applyWarmStartProfileIfNeeded() {
    if (_didApplyWarmStart) return;
    final view = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first
        : null;
    if (view == null) {
      _deviceTier = DevicePerformanceTier.medium;
      _warmStartReason = 'no_view_fallback';
      _didApplyWarmStart = true;
      return;
    }

    final physicalSize = view.physicalSize;
    final dpr = view.devicePixelRatio;
    final shortestSide =
        min(physicalSize.width / dpr, physicalSize.height / dpr);
    final totalPhysicalPixels = physicalSize.width * physicalSize.height;

    _warmStartReason = 'detecting';
    DeviceCapabilityService.instance
        .detectTier(
      shortestLogicalSide: shortestSide,
      totalPhysicalPixels: totalPhysicalPixels,
      devicePixelRatio: dpr,
    )
        .then((snapshot) {
      _deviceTier = snapshot.tier;
      _warmStartReason = snapshot.reason;
      final warmProfile = switch (_deviceTier) {
        DevicePerformanceTier.high => ChatPerformanceProfile.high,
        DevicePerformanceTier.medium => ChatPerformanceProfile.medium,
        DevicePerformanceTier.low => ChatPerformanceProfile.low,
      };
      if (_framesMicros.length < 12) {
        profileNotifier.value = warmProfile;
      }
    }).catchError((_) {
      _deviceTier = DevicePerformanceTier.medium;
      _warmStartReason = 'device_capability_error';
      if (_framesMicros.length < 12) {
        profileNotifier.value = ChatPerformanceProfile.medium;
      }
    });

    // Conservative immediate fallback until async capability probe finishes.
    final fallbackTier =
        _detectFallbackTier(shortestSide, totalPhysicalPixels, dpr);
    _deviceTier = fallbackTier;
    _warmStartReason = 'screen_cpu_fallback';
    profileNotifier.value = switch (_deviceTier) {
      DevicePerformanceTier.high => ChatPerformanceProfile.high,
      DevicePerformanceTier.medium => ChatPerformanceProfile.medium,
      DevicePerformanceTier.low => ChatPerformanceProfile.low,
    };
    _didApplyWarmStart = true;
  }

  DevicePerformanceTier _detectFallbackTier(
    double shortestSide,
    double totalPhysicalPixels,
    double devicePixelRatio,
  ) {
    if (shortestSide < 380 || totalPhysicalPixels < 1.2e6) {
      return DevicePerformanceTier.low;
    }
    if (shortestSide >= 430 &&
        totalPhysicalPixels >= 2.6e6 &&
        devicePixelRatio >= 2.5) {
      return DevicePerformanceTier.high;
    }
    return DevicePerformanceTier.medium;
  }
}
